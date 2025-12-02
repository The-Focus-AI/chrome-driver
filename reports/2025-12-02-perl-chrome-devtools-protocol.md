---
title: "Chrome DevTools Protocol: Pure Perl Implementation with Standard Modules"
date: 2025-12-02
topic: perl-cdp-standard-modules
recommendation: "Raw WebSocket Implementation using IO::Socket::INET + Manual Frame Encoding"
version_researched: "Perl 5.14+ (for JSON::PP core availability)"
use_when:
  - Building Chrome automation tools that must work on any system with Perl installed
  - Creating lightweight CDP clients without CPAN dependencies
  - Environments where installing external modules is not permitted
  - Scripts that need to be portable across macOS, Linux, and other Unix systems
avoid_when:
  - SSL/TLS (wss://) connections are required (would need IO::Socket::SSL from CPAN)
  - High-performance, production automation is needed (use Puppeteer/Playwright instead)
  - Complex event handling with multiple concurrent WebSocket streams
project_context:
  language: Perl
  relevant_dependencies: []
---

## Summary

Chrome DevTools Protocol (CDP) enables programmatic control of Chrome/Chromium browsers through a WebSocket-based JSON-RPC interface[1]. While most CDP client implementations rely on third-party WebSocket libraries, it is entirely feasible to implement a working CDP client using only Perl's standard modules: `IO::Socket::INET` for TCP connections, `HTTP::Tiny` for HTTP requests, `JSON::PP` for JSON encoding/decoding, `Digest::SHA` for WebSocket handshake, and `MIME::Base64` for encoding[2][3][4].

The key insight is that the WebSocket protocol (RFC 6455) is relatively straightforward: it begins with an HTTP Upgrade handshake, then transitions to a simple binary framing protocol over the existing TCP connection[5]. By implementing the frame encoding/decoding manually (approximately 100-150 lines of Perl), we can create a fully functional CDP client without any CPAN dependencies.

This approach has been validated on Perl 5.40.2 (macOS) and should work on any system with Perl 5.14+ where `JSON::PP` became a core module[4]. The solution handles the essential CDP operations: navigating pages, executing JavaScript, capturing screenshots, and printing to PDF.

## Philosophy & Mental Model

### CDP Architecture

CDP follows a client-server model where Chrome acts as the server[1]:

1. **Launch Chrome** with `--remote-debugging-port=9222`
2. **HTTP Discovery**: GET `/json/version` returns the WebSocket URL
3. **WebSocket Connection**: Upgrade HTTP to persistent bidirectional channel
4. **JSON-RPC Messages**: Send commands, receive responses and events

### Message Types

```
Client -> Chrome:  {"id": 1, "method": "Page.navigate", "params": {"url": "..."}}
Chrome -> Client:  {"id": 1, "result": {"frameId": "...", "loaderId": "..."}}
Chrome -> Client:  {"method": "Page.loadEventFired", "params": {...}}  // Events (no id)
```

### WebSocket Frame Mental Model

Think of WebSocket as "TCP with message boundaries":
- Each message is wrapped in a frame header (2-14 bytes)
- Clients MUST mask their data; servers do NOT mask
- Frame header contains: FIN bit, opcode (text/binary/close/ping/pong), mask bit, payload length[5]

## Setup

### Launching Chrome with Remote Debugging

**macOS:**
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/ChromeDevProfile"
```

**Linux:**
```bash
google-chrome --remote-debugging-port=9222 --user-data-dir="$HOME/ChromeDevProfile"
```

**Headless mode (no GUI):**
```bash
google-chrome --headless --remote-debugging-port=9222 --user-data-dir="$HOME/ChromeDevProfile"
```

Important: Close all existing Chrome instances first, or use a separate `--user-data-dir`[6].

### Verify Chrome is Listening

```bash
curl http://localhost:9222/json/version
```

Expected response:
```json
{
  "Browser": "Chrome/xxx.x.xxxx.xxx",
  "Protocol-Version": "1.3",
  "webSocketDebuggerUrl": "ws://localhost:9222/devtools/browser/xxxxxxxx-xxxx-..."
}
```

## Core Usage Patterns

### Pattern 1: Complete CDP Client Module

This is the full implementation using only standard Perl modules:

```perl
#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;

package CDP::Client;

use IO::Socket::INET;
use IO::Select;
use HTTP::Tiny;
use JSON::PP;
use Digest::SHA qw(sha1);
use MIME::Base64 qw(encode_base64 decode_base64);

# WebSocket magic GUID per RFC 6455
use constant WS_GUID => '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        host    => $args{host} // 'localhost',
        port    => $args{port} // 9222,
        timeout => $args{timeout} // 30,
        msg_id  => 0,
        pending => {},
    }, $class;
    return $self;
}

# Discover WebSocket URL via HTTP endpoint
sub get_ws_url {
    my ($self) = @_;
    my $http = HTTP::Tiny->new(timeout => $self->{timeout});
    my $url = "http://$self->{host}:$self->{port}/json/version";
    my $response = $http->get($url);

    die "Failed to get /json/version: $response->{status} $response->{reason}\n"
        unless $response->{success};

    my $data = decode_json($response->{content});
    return $data->{webSocketDebuggerUrl};
}

# Get list of open pages/tabs
sub get_pages {
    my ($self) = @_;
    my $http = HTTP::Tiny->new(timeout => $self->{timeout});
    my $url = "http://$self->{host}:$self->{port}/json";
    my $response = $http->get($url);

    die "Failed to get /json: $response->{status} $response->{reason}\n"
        unless $response->{success};

    return decode_json($response->{content});
}

# Connect to a specific WebSocket URL
sub connect {
    my ($self, $ws_url) = @_;

    # Parse ws://host:port/path
    my ($host, $port, $path) = $ws_url =~ m{^ws://([^:/]+):?(\d*)(.*)$};
    $port ||= 80;
    $path ||= '/';

    # Create TCP socket
    $self->{socket} = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => $self->{timeout},
    ) or die "Cannot connect to $host:$port: $!\n";

    $self->{socket}->autoflush(1);

    # Perform WebSocket handshake
    $self->_ws_handshake($host, $port, $path);

    return $self;
}

# WebSocket opening handshake (RFC 6455 Section 4)
sub _ws_handshake {
    my ($self, $host, $port, $path) = @_;
    my $sock = $self->{socket};

    # Generate random 16-byte key, base64 encode it
    my $key = encode_base64(pack("N4", map { int(rand(2**32)) } 1..4), '');

    # Send HTTP Upgrade request
    my $request = join("\r\n",
        "GET $path HTTP/1.1",
        "Host: $host:$port",
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Key: $key",
        "Sec-WebSocket-Version: 13",
        "", ""
    );

    print $sock $request;

    # Read response headers
    my $response = '';
    while (my $line = <$sock>) {
        $response .= $line;
        last if $line eq "\r\n";
    }

    # Verify 101 Switching Protocols
    die "WebSocket handshake failed: $response\n"
        unless $response =~ /^HTTP\/1\.1 101/;

    # Verify Sec-WebSocket-Accept header
    my $expected = encode_base64(sha1($key . WS_GUID), '');
    die "Invalid Sec-WebSocket-Accept\n"
        unless $response =~ /Sec-WebSocket-Accept:\s*\Q$expected\E/i;

    return 1;
}

# Encode a WebSocket frame (client frames MUST be masked)
sub _ws_encode_frame {
    my ($self, $payload, $opcode) = @_;
    $opcode //= 0x01;  # Text frame

    my $len = length($payload);
    my $frame = '';

    # First byte: FIN=1, RSV=0, opcode
    $frame .= chr(0x80 | $opcode);

    # Second byte: MASK=1, payload length
    if ($len <= 125) {
        $frame .= chr(0x80 | $len);
    } elsif ($len <= 65535) {
        $frame .= chr(0x80 | 126);
        $frame .= pack('n', $len);  # 16-bit big-endian
    } else {
        $frame .= chr(0x80 | 127);
        $frame .= pack('Q>', $len);  # 64-bit big-endian
    }

    # Generate 4-byte mask key
    my @mask = map { int(rand(256)) } 1..4;
    $frame .= pack('C4', @mask);

    # XOR payload with mask
    my @payload = unpack('C*', $payload);
    for my $i (0..$#payload) {
        $payload[$i] ^= $mask[$i % 4];
    }
    $frame .= pack('C*', @payload);

    return $frame;
}

# Decode a WebSocket frame from server (unmasked)
sub _ws_decode_frame {
    my ($self) = @_;
    my $sock = $self->{socket};

    # Read first 2 bytes
    my $header;
    read($sock, $header, 2) or die "Connection closed\n";
    my ($b1, $b2) = unpack('CC', $header);

    my $fin    = ($b1 & 0x80) >> 7;
    my $opcode = $b1 & 0x0F;
    my $masked = ($b2 & 0x80) >> 7;
    my $len    = $b2 & 0x7F;

    # Extended payload length
    if ($len == 126) {
        read($sock, my $ext, 2);
        $len = unpack('n', $ext);
    } elsif ($len == 127) {
        read($sock, my $ext, 8);
        $len = unpack('Q>', $ext);
    }

    # Read mask if present (servers shouldn't mask, but handle it)
    my @mask;
    if ($masked) {
        read($sock, my $m, 4);
        @mask = unpack('C4', $m);
    }

    # Read payload
    my $payload = '';
    if ($len > 0) {
        read($sock, $payload, $len);
        if ($masked) {
            my @data = unpack('C*', $payload);
            $data[$_] ^= $mask[$_ % 4] for 0..$#data;
            $payload = pack('C*', @data);
        }
    }

    return {
        fin     => $fin,
        opcode  => $opcode,
        payload => $payload,
    };
}

# Send a CDP command and wait for response
sub send_command {
    my ($self, $method, $params) = @_;
    $params //= {};

    my $id = ++$self->{msg_id};
    my $message = encode_json({
        id     => $id,
        method => $method,
        params => $params,
    });

    # Send WebSocket frame
    my $frame = $self->_ws_encode_frame($message);
    print { $self->{socket} } $frame;

    # Wait for response with matching id
    while (1) {
        my $ws_frame = $self->_ws_decode_frame();

        # Handle close frame
        if ($ws_frame->{opcode} == 0x08) {
            die "WebSocket closed by server\n";
        }

        # Handle ping with pong
        if ($ws_frame->{opcode} == 0x09) {
            my $pong = $self->_ws_encode_frame($ws_frame->{payload}, 0x0A);
            print { $self->{socket} } $pong;
            next;
        }

        # Process text frames
        if ($ws_frame->{opcode} == 0x01) {
            my $data = decode_json($ws_frame->{payload});

            # Check if this is our response
            if (exists $data->{id} && $data->{id} == $id) {
                die "CDP Error: $data->{error}{message}\n" if $data->{error};
                return $data->{result};
            }

            # Otherwise it's an event - store or ignore
            # (In production, you'd want an event queue)
        }
    }
}

# Close WebSocket connection
sub disconnect {
    my ($self) = @_;
    if ($self->{socket}) {
        # Send close frame
        my $close = $self->_ws_encode_frame('', 0x08);
        print { $self->{socket} } $close;
        close($self->{socket});
        delete $self->{socket};
    }
}

1;
```

### Pattern 2: Navigation and Page Control

```perl
#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;

# Include the CDP::Client from Pattern 1 or use 'require'

my $cdp = CDP::Client->new(port => 9222);

# Get available pages
my $pages = $cdp->get_pages();
die "No pages available\n" unless @$pages;

# Connect to the first page
my $page_ws = $pages->[0]{webSocketDebuggerUrl};
$cdp->connect($page_ws);

# Enable Page domain events
$cdp->send_command('Page.enable');

# Navigate to a URL
my $result = $cdp->send_command('Page.navigate', {
    url => 'https://example.com'
});
say "Navigated to frame: $result->{frameId}";

# Wait for load (simple approach - just sleep)
sleep(2);

# Get page title via JavaScript
my $eval_result = $cdp->send_command('Runtime.evaluate', {
    expression => 'document.title'
});
say "Page title: $eval_result->{result}{value}";

$cdp->disconnect();
```

### Pattern 3: Capturing Screenshots

```perl
# Capture full-page screenshot
my $screenshot = $cdp->send_command('Page.captureScreenshot', {
    format  => 'png',
    captureBeyondViewport => JSON::PP::true,
});

# Decode and save
use MIME::Base64;
my $png_data = decode_base64($screenshot->{data});
open my $fh, '>:raw', 'screenshot.png' or die $!;
print $fh $png_data;
close $fh;
say "Screenshot saved to screenshot.png";
```

### Pattern 4: Print to PDF

```perl
# Print page as PDF
my $pdf = $cdp->send_command('Page.printToPDF', {
    landscape       => JSON::PP::false,
    printBackground => JSON::PP::true,
    paperWidth      => 8.5,
    paperHeight     => 11,
    marginTop       => 0.5,
    marginBottom    => 0.5,
    marginLeft      => 0.5,
    marginRight     => 0.5,
});

my $pdf_data = decode_base64($pdf->{data});
open my $fh, '>:raw', 'page.pdf' or die $!;
print $fh $pdf_data;
close $fh;
say "PDF saved to page.pdf";
```

### Pattern 5: Extract Page Content

```perl
# Get the DOM document
$cdp->send_command('DOM.enable');
my $doc = $cdp->send_command('DOM.getDocument', { depth => -1 });

# Get outer HTML of the entire document
my $html = $cdp->send_command('DOM.getOuterHTML', {
    nodeId => $doc->{root}{nodeId}
});
say "HTML length: ", length($html->{outerHTML}), " bytes";

# Or use JavaScript to extract text content
my $text = $cdp->send_command('Runtime.evaluate', {
    expression => 'document.body.innerText'
});
say "Page text:\n$text->{result}{value}";
```

## Anti-Patterns & Pitfalls

### X Don't: Forget to Enable Domains

```perl
# BAD - trying to use Page commands without enabling
my $result = $cdp->send_command('Page.navigate', { url => '...' });
# May fail or not receive events
```

**Why it's wrong:** CDP domains like `Page`, `DOM`, `Network` must be explicitly enabled to receive events and for some commands to work properly[1].

### Check Instead: Enable Required Domains First

```perl
# GOOD - enable before using
$cdp->send_command('Page.enable');
$cdp->send_command('DOM.enable');
$cdp->send_command('Network.enable');

my $result = $cdp->send_command('Page.navigate', { url => '...' });
```

### X Don't: Ignore WebSocket Pings

```perl
# BAD - blocking read that ignores control frames
sub bad_receive {
    my $frame = decode_frame();
    return decode_json($frame->{payload});  # Might be a ping!
}
```

**Why it's wrong:** WebSocket servers may send ping frames to keep the connection alive. Ignoring them can cause disconnection[5].

### Check Instead: Handle All Frame Types

```perl
# GOOD - handle control frames
while (1) {
    my $frame = $self->_ws_decode_frame();
    if ($frame->{opcode} == 0x09) {  # Ping
        my $pong = $self->_ws_encode_frame($frame->{payload}, 0x0A);
        print { $self->{socket} } $pong;
        next;
    }
    if ($frame->{opcode} == 0x08) {  # Close
        die "Connection closed\n";
    }
    # Process text/binary frames...
}
```

### X Don't: Use Unmasked Client Frames

```perl
# BAD - no masking
sub bad_encode {
    my $frame = chr(0x81) . chr(length($payload)) . $payload;
    return $frame;
}
```

**Why it's wrong:** RFC 6455 requires all client-to-server frames to be masked. Servers must close connections that receive unmasked client frames[5].

### Check Instead: Always Mask Client Frames

```perl
# GOOD - proper masking (see Pattern 1 _ws_encode_frame)
# Second byte has MASK bit (0x80) set
# 4-byte random mask follows length
# Payload XORed with mask
```

### X Don't: Assume Synchronous Response Order

```perl
# BAD - assuming responses arrive in order
my $id1 = send_command('Page.navigate', ...);
my $id2 = send_command('Runtime.evaluate', ...);
my $result1 = wait_for_response();  # Might get result2!
my $result2 = wait_for_response();
```

**Why it's wrong:** CDP responses may arrive in any order, and events may interleave with responses[1].

### Check Instead: Match Responses by ID

```perl
# GOOD - match by id
sub wait_for_response {
    my ($self, $expected_id) = @_;
    while (1) {
        my $frame = $self->_ws_decode_frame();
        my $data = decode_json($frame->{payload});
        return $data->{result} if $data->{id} && $data->{id} == $expected_id;
        # Store events/other responses for later
    }
}
```

## Caveats

- **No SSL/TLS Support**: The standard `IO::Socket::INET` does not support encrypted connections. Chrome's local debugging uses plain `ws://`, but if you need `wss://` connections (e.g., remote debugging), you would need `IO::Socket::SSL` from CPAN or shell out to `websocat`[7].

- **Blocking I/O**: The implementation uses blocking sockets. For complex automation with multiple concurrent operations, you would need `IO::Select` for multiplexing or a non-blocking architecture[2].

- **No Event Queue**: The basic implementation waits synchronously for command responses. CDP sends many events (page lifecycle, network requests, console messages) that would be lost. Production implementations should maintain an event queue.

- **Perl Version Requirements**: `JSON::PP` is only in core since Perl 5.14 (2011), and `HTTP::Tiny` since Perl 5.14. For Perl 5.10 or earlier, you would need to bundle these modules or use alternative approaches[4].

- **No Connection Pooling**: Each CDP client maintains a single WebSocket connection. For multi-tab automation, you need separate connections to each page's WebSocket URL.

- **Frame Fragmentation**: The implementation assumes messages fit in single frames. Very large responses (like full-page screenshots) should work due to extended payload lengths, but fragmented messages (FIN=0) would require reassembly.

- **No Compression**: WebSocket compression (`permessage-deflate`) is not implemented. Chrome's CDP typically works fine without it for local debugging.

## Alternative Approach: Shell Out to websocat

If implementing WebSocket frames feels too complex, you can use `websocat` as a subprocess[8]:

```perl
#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use JSON::PP;
use HTTP::Tiny;
use IPC::Open2;

# Get WebSocket URL
my $http = HTTP::Tiny->new();
my $resp = $http->get('http://localhost:9222/json/version');
my $ws_url = decode_json($resp->{content})->{webSocketDebuggerUrl};

# Open bidirectional pipe to websocat
my $pid = open2(my $from_ws, my $to_ws, "websocat", $ws_url);

# Send CDP command
my $cmd = encode_json({
    id => 1,
    method => 'Page.navigate',
    params => { url => 'https://example.com' }
});
print $to_ws "$cmd\n";

# Read response
my $response = <$from_ws>;
my $result = decode_json($response);
say "Response: ", encode_json($result);

# Cleanup
close($to_ws);
close($from_ws);
waitpid($pid, 0);
```

This requires installing `websocat` (`brew install websocat` on macOS), but keeps Perl code simple.

## References

[1] [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/) - Official CDP documentation and protocol specification

[2] [Writing a WebSocket Client in Perl 5](https://greg-kennedy.com/wordpress/2019/03/11/writing-a-websocket-client-in-perl-5/) - Detailed tutorial on WebSocket implementation in Perl using IO::Socket::INET

[3] [IO::Socket::INET - Perldoc](https://perldoc.perl.org/IO::Socket::INET) - Official documentation for Perl's core socket module

[4] [JSON::PP - Perldoc](https://perldoc.perl.org/JSON::PP) - Core JSON module documentation, available since Perl 5.14

[5] [Writing WebSocket Servers - MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers) - Comprehensive guide to WebSocket frame format and protocol

[6] [GitHub Gist - Chrome Remote Debugging on Mac](https://gist.github.com/bobdobbalina/64450fb391dab3863e047295cb155410) - Command to launch Chrome with remote debugging on macOS

[7] [Net::WebSocket::Server - MetaCPAN](https://metacpan.org/pod/Net::WebSocket::Server) - CPAN WebSocket implementation for reference (not used, but documents patterns)

[8] [websocat - GitHub](https://github.com/vi/websocat) - Command-line WebSocket client tool as alternative to implementing WebSocket in Perl

[9] [Digest::SHA - Perldoc](https://perldoc.perl.org/Digest::SHA) - Core module for SHA-1 hashing, needed for WebSocket handshake

[10] [MIME::Base64 - Perldoc](https://perldoc.perl.org/MIME::Base64) - Core module for Base64 encoding/decoding

[11] [HTTP::Tiny - Perldoc](https://perldoc.perl.org/HTTP::Tiny) - Core HTTP client module for discovery endpoints

[12] [Chrome DevTools Protocol - Page Domain](https://chromedevtools.github.io/devtools-protocol/tot/Page/) - Page.navigate, captureScreenshot, printToPDF command documentation
