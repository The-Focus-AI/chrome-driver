# Troubleshooting Guide

This guide covers common issues and solutions when using chrome-driver.

## Table of Contents

- [Chrome Won't Start](#chrome-wont-start)
- [Connection Issues](#connection-issues)
- [WebSocket Errors](#websocket-errors)
- [Element Not Found](#element-not-found)
- [Screenshot/PDF Problems](#screenshotpdf-problems)
- [Content Extraction Issues](#content-extraction-issues)
- [Performance Problems](#performance-problems)
- [Platform-Specific Issues](#platform-specific-issues)

## Chrome Won't Start

### Symptom
```
Error: Could not start Chrome
Error: Chrome not found
```

### Solutions

**1. Verify Chrome is installed:**
```bash
# macOS
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version

# Linux
google-chrome --version
# or
chromium --version

# WSL
/mnt/c/Program\ Files/Google/Chrome/Application/chrome.exe --version
```

**2. Try starting Chrome manually:**
```bash
google-chrome --remote-debugging-port=9222 --headless --user-data-dir=/tmp/chrome-test
```

**3. Check for port conflicts:**
```bash
# See if port 9222 is already in use
lsof -i :9222

# Kill process using the port
kill -9 <PID>
```

**4. Kill orphan Chrome processes:**
```bash
pkill -f 'chrome.*--remote-debugging-port'

# Or more aggressive (kills all Chrome)
pkill chrome
```

**5. Specify Chrome location explicitly:**
```perl
my $chrome = ChromeDriver->new(
    chrome_binary => '/path/to/chrome',
    port => 9222
);
```

## Connection Issues

### Symptom
```
Error: Could not connect to Chrome
Error: WebSocket handshake failed
Error: Connection refused
```

### Solutions

**1. Check if Chrome is running:**
```bash
curl -s http://localhost:9222/json/version
```

Should return JSON with Chrome version and WebSocket URL.

**2. Verify debugging is enabled:**
Chrome must be started with `--remote-debugging-port=9222`

**3. Check firewall settings:**
- Ensure localhost connections are allowed
- Port 9222 should not be blocked

**4. Check for SSL/certificate issues:**
Chrome DevTools Protocol uses `ws://` (not `wss://`) on localhost, so SSL shouldn't be an issue. If it is, check for proxy/VPN interference.

**5. Restart Chrome:**
```perl
$chrome->restart();  # If method exists
# or
system("pkill -f 'chrome.*--remote-debugging-port'");
sleep 2;
# Start new instance
```

## WebSocket Errors

### Symptom
```
Error: WebSocket frame error
Error: Invalid handshake response
Error: Connection closed unexpectedly
```

### Solutions

**1. Check Chrome version:**
```bash
google-chrome --version
```

Ensure Chrome is reasonably up-to-date (version 90+).

**2. Verify WebSocket endpoint:**
```bash
curl -s http://localhost:9222/json | jq '.[0].webSocketDebuggerUrl'
```

**3. Test manual WebSocket connection:**
```bash
# Install websocat if needed
websocat "$(curl -s http://localhost:9222/json | jq -r '.[0].webSocketDebuggerUrl')"

# Send test message
{"id":1,"method":"Browser.getVersion"}
```

**4. Check for proxy interference:**
WebSocket connections can be blocked by proxies. Temporarily disable proxy:
```bash
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
```

## Element Not Found

### Symptom
```
Error: Element not found: selector
Error: querySelector returned null
```

### Solutions

**1. Wait for element to load:**
```perl
# Bad - element might not exist yet
my $el = $dom->query('.dynamic-element');

# Good - wait for it
my $el = $dom->wait_for('.dynamic-element', 10);
die "Element not found" unless $el;
```

**2. Verify selector in browser DevTools:**
1. Open page in Chrome
2. Press F12 to open DevTools
3. In Console, test selector:
   ```javascript
   document.querySelector('your-selector')
   ```

**3. Check for iframes:**
Content in an iframe requires switching frames first:
```perl
# Get frame
my $frame_id = $chrome->send('Page.getFrameTree')->{result}{frameTree}{frame}{id};

# Execute in frame context
$chrome->send('Runtime.evaluate', {
    expression => 'document.querySelector("selector")',
    contextId => $frame_id
});
```

**4. Wait for page load:**
```perl
$nav->goto('https://example.com');
$chrome->wait_for_event('Page.loadEventFired', 30);
# Now query elements
```

**5. Use more specific selectors:**
```perl
# Bad - too generic
$dom->query('div');

# Good - specific
$dom->query('div.main-content > article#post-123');
```

## Screenshot/PDF Problems

### Symptom
```
Error: Screenshot failed
Error: PDF generation failed
Empty/blank screenshots or PDFs
```

### Solutions

**1. Ensure page is loaded:**
```perl
$nav->goto('https://example.com');
$chrome->wait_for_event('Page.loadEventFired', 30);
sleep 1;  # Extra time for rendering
$capture->screenshot(file => '/tmp/page.png');
```

**2. Check viewport size:**
```perl
# Set explicit viewport before screenshot
$capture->set_viewport(1920, 1080);
$capture->screenshot(file => '/tmp/page.png');
```

**3. Enable background graphics for PDF:**
```perl
$pdf->pdf(
    file => '/tmp/page.pdf',
    print_background => 1  # Include backgrounds
);
```

**4. Wait for images to load:**
```perl
# Wait for all images
$js->evaluate(qq{
    Promise.all(
        Array.from(document.images)
            .filter(img => !img.complete)
            .map(img => new Promise(resolve => {
                img.onload = img.onerror = resolve;
            }))
    )
});
```

**5. Check file permissions:**
```bash
# Ensure output directory is writable
ls -la /tmp/
touch /tmp/test-write && rm /tmp/test-write
```

**6. Try different format:**
```perl
# PNG is most reliable
$capture->screenshot(
    file => '/tmp/page.png',
    format => 'png'
);
```

## Content Extraction Issues

### Symptom
```
Empty content returned
Incomplete text extraction
Markdown conversion errors
```

### Solutions

**1. Wait for content to load:**
```perl
$nav->goto('https://example.com');
$chrome->wait_for_event('Page.loadEventFired', 30);

# Wait for specific element
$dom->wait_for('article', 10);

# Now extract
my $content = $content->markdown();
```

**2. Use specific selectors:**
```perl
# Bad - might get navigation/footer/ads
my $text = $content->text();

# Good - target main content
my $text = $content->text('article.main-content');
```

**3. Check for JavaScript-rendered content:**
Some pages load content via JavaScript. Add a delay:
```perl
$nav->goto('https://example.com');
sleep 2;  # Wait for JS to execute
my $content = $content->markdown();
```

**4. Handle infinite scroll:**
```perl
# Scroll to bottom to trigger content load
$js->evaluate(qq{
    window.scrollTo(0, document.body.scrollHeight);
});
sleep 1;
my $content = $content->markdown();
```

**5. Disable JavaScript if it's problematic:**
```perl
$chrome->send('Emulation.setScriptExecutionDisabled', { value => 1 });
$nav->goto('https://example.com');
```

## Performance Problems

### Symptom
```
Slow page loads
High memory usage
Chrome becomes unresponsive
```

### Solutions

**1. Use headless mode:**
```perl
my $chrome = ChromeDriver->new(headless => 1);  # Faster
```

**2. Disable images:**
```perl
$chrome->send('Network.setBlockedURLs', {
    urls => ['*.jpg', '*.jpeg', '*.png', '*.gif', '*.webp']
});
```

**3. Set shorter timeouts:**
```perl
$nav->goto('https://example.com', timeout => 10);  # Don't wait forever
```

**4. Close pages when done:**
```perl
$chrome->close();  # Free memory
```

**5. Limit cache size:**
```perl
my $chrome = ChromeDriver->new(
    user_data_dir => '/tmp/chrome-minimal',  # Temporary profile
    headless => 1
);
```

**6. Restart Chrome periodically:**
For long-running scripts, restart Chrome every N pages:
```perl
for my $i (1..100) {
    $nav->goto($urls[$i]);
    # ... do work ...

    if ($i % 10 == 0) {
        $chrome->close();
        sleep 1;
        $chrome = ChromeDriver->new(headless => 1);
        $chrome->connect_to_page();
    }
}
```

## Platform-Specific Issues

### macOS

**Chrome location issues:**
```perl
my $chrome = ChromeDriver->new(
    chrome_binary => '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
);
```

**Permission dialogs:**
Grant Terminal/iTerm access to "Developer Tools" in System Preferences.

### Linux

**Missing libraries:**
```bash
# Ubuntu/Debian
sudo apt-get install -y google-chrome-stable

# Or Chromium
sudo apt-get install -y chromium-browser

# Check dependencies
ldd $(which google-chrome)
```

**No display (headless server):**
```bash
# Install Xvfb
sudo apt-get install -y xvfb

# Run with virtual display
xvfb-run google-chrome --remote-debugging-port=9222
```

### WSL (Windows Subsystem for Linux)

**Chrome path:**
```perl
my $chrome = ChromeDriver->new(
    chrome_binary => '/mnt/c/Program Files/Google/Chrome/Application/chrome.exe'
);
```

**Display issues:**
```bash
# Install VcXsrv or similar X server on Windows
export DISPLAY=:0
```

**Slow networking:**
WSL1 has slow network performance. Use WSL2:
```bash
wsl --set-version Ubuntu 2
```

## Still Having Issues?

### Enable verbose logging

```perl
# Add debug output
$chrome->{debug} = 1;  # If supported

# Or manually log CDP traffic
my $original_send = \&ChromeDriver::send;
*ChromeDriver::send = sub {
    my ($self, $method, $params) = @_;
    warn ">>> $method: " . JSON::PP->new->encode($params) . "\n";
    my $result = $original_send->($self, $method, $params);
    warn "<<< " . JSON::PP->new->encode($result) . "\n";
    return $result;
};
```

### Check Perl version

```bash
perl -v
```

Requires Perl 5.14+.

### Verify module availability

```bash
perl -e 'use IO::Socket::INET; print "OK\n"'
perl -e 'use HTTP::Tiny; print "OK\n"'
perl -e 'use JSON::PP; print "OK\n"'
perl -e 'use Digest::SHA; print "OK\n"'
perl -e 'use MIME::Base64; print "OK\n"'
```

All should print "OK".

### Get help

Run the interactive help system:
```perl
use Help::Browser qw(browser_help);
print browser_help();           # Overview
print browser_help('topic');    # Specific topic
```

### Report bugs

1. Include error message
2. Include Perl version (`perl -v`)
3. Include Chrome version (`google-chrome --version`)
4. Include platform (macOS/Linux/WSL)
5. Include minimal reproduction code

Submit issues at: https://github.com/Focus-AI/chrome-driver/issues
