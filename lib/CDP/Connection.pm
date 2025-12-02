package CDP::Connection;
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use Digest::SHA qw(sha1_base64);
use MIME::Base64 ();
use CDP::Frame;

# WebSocket Connection Manager for Chrome DevTools Protocol

use constant {
    WS_GUID   => '258EAFA5-E914-47DA-95CA-C5AB0DC85B11',
    READ_SIZE => 65536,
};

sub new {
    my ($class, %opts) = @_;
    return bless {
        host     => $opts{host} // 'localhost',
        port     => $opts{port} // 9222,
        path     => $opts{path} // '/',
        timeout  => $opts{timeout} // 30,
        socket   => undef,
        select   => undef,
        frame    => CDP::Frame->new(),
        connected => 0,
        error    => undef,
    }, $class;
}

# Connect to WebSocket server
sub connect {
    my ($self) = @_;

    # Create TCP socket
    $self->{socket} = IO::Socket::INET->new(
        PeerHost => $self->{host},
        PeerPort => $self->{port},
        Proto    => 'tcp',
        Timeout  => $self->{timeout},
    ) or do {
        $self->{error} = "Failed to connect to $self->{host}:$self->{port}: $!";
        return 0;
    };

    $self->{socket}->autoflush(1);
    $self->{select} = IO::Select->new($self->{socket});

    # Perform WebSocket handshake
    return $self->_handshake();
}

# WebSocket upgrade handshake
sub _handshake {
    my ($self) = @_;

    # Generate random key
    my $key = MIME::Base64::encode_base64(pack('N4', map { rand(0xFFFFFFFF) } 1..4), '');

    # Build HTTP upgrade request
    my $request = join("\r\n",
        "GET $self->{path} HTTP/1.1",
        "Host: $self->{host}:$self->{port}",
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Key: $key",
        "Sec-WebSocket-Version: 13",
        "",
        ""
    );

    # Send request
    my $sock = $self->{socket};
    print $sock $request;

    # Read response
    my $response = '';
    my $timeout = time() + $self->{timeout};

    while (time() < $timeout) {
        if ($self->{select}->can_read(1)) {
            my $chunk;
            my $read = sysread($sock, $chunk, READ_SIZE);
            if (!defined $read || $read == 0) {
                $self->{error} = "Connection closed during handshake";
                return 0;
            }
            $response .= $chunk;
            last if $response =~ /\r\n\r\n/;
        }
    }

    # Verify response
    unless ($response =~ m{^HTTP/1\.1 101}i) {
        $self->{error} = "Invalid WebSocket handshake response: " .
                         (split(/\r\n/, $response))[0];
        return 0;
    }

    # Verify Sec-WebSocket-Accept
    my $expected_accept = sha1_base64($key . WS_GUID) . '=';
    unless ($response =~ /Sec-WebSocket-Accept:\s*(\S+)/i && $1 eq $expected_accept) {
        $self->{error} = "Invalid Sec-WebSocket-Accept header";
        return 0;
    }

    $self->{connected} = 1;

    # Store any extra data after headers as frame data
    if ($response =~ /\r\n\r\n(.+)$/s) {
        $self->{frame}->decode($1);
    }

    return 1;
}

# Send a text message
sub send {
    my ($self, $message) = @_;

    unless ($self->{connected}) {
        $self->{error} = "Not connected";
        return 0;
    }

    my $frame = $self->{frame}->text_frame($message);
    my $written = syswrite($self->{socket}, $frame);

    unless (defined $written && $written == length($frame)) {
        $self->{error} = "Failed to send message: $!";
        $self->{connected} = 0;
        return 0;
    }

    return 1;
}

# Receive a message (blocking with timeout)
sub recv {
    my ($self, $timeout) = @_;
    $timeout //= $self->{timeout};

    unless ($self->{connected}) {
        $self->{error} = "Not connected";
        return undef;
    }

    my $end_time = time() + $timeout;
    my @messages;

    while (time() < $end_time) {
        # Check for complete frames in buffer
        while (my $frame = $self->{frame}->decode(undef)) {
            my $result = $self->_handle_frame($frame);
            push @messages, $result if defined $result;
        }

        return $messages[0] if @messages;

        # Read more data
        my $remaining = $end_time - time();
        $remaining = 0.1 if $remaining < 0.1;

        if ($self->{select}->can_read($remaining)) {
            my $data;
            my $read = sysread($self->{socket}, $data, READ_SIZE);

            if (!defined $read) {
                $self->{error} = "Read error: $!";
                $self->{connected} = 0;
                return undef;
            }
            elsif ($read == 0) {
                $self->{error} = "Connection closed by server";
                $self->{connected} = 0;
                return undef;
            }

            # Decode frames - pass data once, then decode remaining buffer
            my $input = $data;
            while (my $frame = $self->{frame}->decode($input)) {
                $input = undef;  # Only pass data on first iteration
                my $result = $self->_handle_frame($frame);
                push @messages, $result if defined $result;
            }

            return $messages[0] if @messages;
        }
    }

    $self->{error} = "Receive timeout";
    return undef;
}

# Non-blocking receive - returns message or undef
sub recv_nb {
    my ($self) = @_;

    unless ($self->{connected}) {
        return undef;
    }

    # Check for complete frames in buffer first
    while (my $frame = $self->{frame}->decode(undef)) {
        my $result = $self->_handle_frame($frame);
        return $result if defined $result;
    }

    # Check if data available
    return undef unless $self->{select}->can_read(0);

    my $data;
    my $read = sysread($self->{socket}, $data, READ_SIZE);

    return undef if !defined $read || $read == 0;

    my $input = $data;
    while (my $frame = $self->{frame}->decode($input)) {
        $input = undef;  # Only pass data on first iteration
        my $result = $self->_handle_frame($frame);
        return $result if defined $result;
    }

    return undef;
}

# Handle a decoded frame
sub _handle_frame {
    my ($self, $frame) = @_;

    my $opcode = $frame->{opcode};

    # Handle control frames
    if ($opcode == CDP::Frame::OPCODE_CLOSE) {
        # Send close response
        my $close_frame = $self->{frame}->close_frame();
        syswrite($self->{socket}, $close_frame);
        $self->{connected} = 0;
        return undef;
    }
    elsif ($opcode == CDP::Frame::OPCODE_PING) {
        # Send pong response
        my $pong = $self->{frame}->pong_frame($frame->{payload});
        syswrite($self->{socket}, $pong);
        return undef;
    }
    elsif ($opcode == CDP::Frame::OPCODE_PONG) {
        # Ignore pong
        return undef;
    }
    elsif ($opcode == CDP::Frame::OPCODE_TEXT ||
           $opcode == CDP::Frame::OPCODE_BINARY) {
        return $frame->{payload};
    }

    return undef;
}

# Close the connection
sub close {
    my ($self) = @_;

    if ($self->{socket} && $self->{connected}) {
        # Send close frame
        my $close_frame = $self->{frame}->close_frame(1000, 'Normal closure');
        syswrite($self->{socket}, $close_frame);
    }

    if ($self->{socket}) {
        $self->{socket}->close();
        $self->{socket} = undef;
    }

    $self->{connected} = 0;
    $self->{select} = undef;
}

# Check if connected
sub is_connected {
    my ($self) = @_;
    return $self->{connected};
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

# Get socket for external select()
sub socket {
    my ($self) = @_;
    return $self->{socket};
}

sub DESTROY {
    my ($self) = @_;
    $self->close() if $self->{connected};
}

1;
