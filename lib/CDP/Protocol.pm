package CDP::Protocol;
use strict;
use warnings;
use JSON::PP;
use CDP::Connection;
use CDP::Events;

# Chrome DevTools Protocol Handler
# Manages CDP commands, responses, and events

sub new {
    my ($class, %opts) = @_;

    my $events = CDP::Events->new();

    return bless {
        connection  => undef,
        message_id  => 0,
        pending     => {},        # id -> { callback, timeout }
        timeout     => $opts{timeout} // 30,
        events      => $events,
        error       => undef,
        session_id  => undef,     # For target sessions
    }, $class;
}

# Connect to Chrome at WebSocket URL
sub connect {
    my ($self, $ws_url) = @_;

    # Parse WebSocket URL
    unless ($ws_url =~ m{^ws://([^:/]+):(\d+)(.*)$}) {
        $self->{error} = "Invalid WebSocket URL: $ws_url";
        return 0;
    }

    my ($host, $port, $path) = ($1, $2, $3);
    $path ||= '/';

    $self->{connection} = CDP::Connection->new(
        host    => $host,
        port    => $port,
        path    => $path,
        timeout => $self->{timeout},
    );

    unless ($self->{connection}->connect()) {
        $self->{error} = $self->{connection}->error();
        return 0;
    }

    return 1;
}

# Send a CDP command and wait for response
sub send {
    my ($self, $method, $params, %opts) = @_;

    my $timeout = $opts{timeout} // $self->{timeout};

    unless ($self->{connection} && $self->{connection}->is_connected()) {
        $self->{error} = "Not connected";
        return undef;
    }

    # Build message
    my $id = ++$self->{message_id};
    my $message = {
        id     => $id,
        method => $method,
    };
    $message->{params} = $params if defined $params && keys %$params;
    $message->{sessionId} = $self->{session_id} if $self->{session_id};

    my $json = encode_json($message);

    # Send message
    unless ($self->{connection}->send($json)) {
        $self->{error} = $self->{connection}->error();
        return undef;
    }

    # Wait for response
    my $end_time = time() + $timeout;

    while (time() < $end_time) {
        my $remaining = $end_time - time();
        my $data = $self->{connection}->recv($remaining > 1 ? 1 : $remaining);

        if (defined $data) {
            my $msg = eval { decode_json($data) };
            if ($@) {
                $self->{error} = "Invalid JSON response: $@";
                next;
            }

            # Check if this is our response
            if (exists $msg->{id} && $msg->{id} == $id) {
                if (exists $msg->{error}) {
                    $self->{error} = "$msg->{error}{message} (code: $msg->{error}{code})";
                    return undef;
                }
                return $msg->{result} // {};
            }

            # Handle event
            if (exists $msg->{method}) {
                $self->{events}->dispatch($msg->{method}, $msg->{params});
            }
        }
        elsif (!$self->{connection}->is_connected()) {
            $self->{error} = "Connection lost";
            return undef;
        }
    }

    $self->{error} = "Command timeout: $method";
    return undef;
}

# Send command without waiting for response
sub send_async {
    my ($self, $method, $params, $callback) = @_;

    unless ($self->{connection} && $self->{connection}->is_connected()) {
        $self->{error} = "Not connected";
        return 0;
    }

    my $id = ++$self->{message_id};
    my $message = {
        id     => $id,
        method => $method,
    };
    $message->{params} = $params if defined $params && keys %$params;
    $message->{sessionId} = $self->{session_id} if $self->{session_id};

    my $json = encode_json($message);

    unless ($self->{connection}->send($json)) {
        $self->{error} = $self->{connection}->error();
        return 0;
    }

    # Store callback if provided
    if ($callback) {
        $self->{pending}{$id} = {
            callback => $callback,
            time     => time(),
        };
    }

    return $id;
}

# Process incoming messages (for event handling)
sub poll {
    my ($self, $timeout) = @_;
    $timeout //= 0;

    unless ($self->{connection} && $self->{connection}->is_connected()) {
        return 0;
    }

    my $end_time = time() + $timeout;

    do {
        my $data = $self->{connection}->recv_nb();

        if (defined $data) {
            my $msg = eval { decode_json($data) };
            next if $@;

            # Handle response
            if (exists $msg->{id}) {
                my $pending = delete $self->{pending}{$msg->{id}};
                if ($pending && $pending->{callback}) {
                    if (exists $msg->{error}) {
                        $pending->{callback}->($msg->{error}, undef);
                    }
                    else {
                        $pending->{callback}->(undef, $msg->{result});
                    }
                }
            }

            # Handle event
            if (exists $msg->{method}) {
                $self->{events}->dispatch($msg->{method}, $msg->{params});
            }
        }

        # Clean up old pending requests
        my $now = time();
        for my $id (keys %{$self->{pending}}) {
            if ($now - $self->{pending}{$id}{time} > $self->{timeout}) {
                my $pending = delete $self->{pending}{$id};
                if ($pending->{callback}) {
                    $pending->{callback}->({message => 'Timeout'}, undef);
                }
            }
        }

    } while ($timeout > 0 && time() < $end_time);

    return 1;
}

# Subscribe to CDP event
sub on {
    my ($self, $event, $callback) = @_;
    return $self->{events}->on($event, $callback);
}

# Unsubscribe from CDP event
sub off {
    my ($self, $event, $id) = @_;
    return $self->{events}->off($event, $id);
}

# Subscribe to event (fires once)
sub once {
    my ($self, $event, $callback) = @_;
    return $self->{events}->once($event, $callback);
}

# Wait for a specific event
sub wait_for_event {
    my ($self, $event, $timeout, $predicate) = @_;
    $timeout //= $self->{timeout};

    my $result;
    my $done = 0;

    my $id = $self->once($event, sub {
        my ($params) = @_;
        if (!$predicate || $predicate->($params)) {
            $result = $params;
            $done = 1;
        }
    });

    my $end_time = time() + $timeout;
    while (!$done && time() < $end_time) {
        $self->poll(0.1);
    }

    $self->off($event, $id) unless $done;

    return $result;
}

# Enable a domain (e.g., Page, DOM, Network)
sub enable {
    my ($self, $domain) = @_;
    return $self->send("$domain.enable");
}

# Disable a domain
sub disable {
    my ($self, $domain) = @_;
    return $self->send("$domain.disable");
}

# Set session ID for target
sub set_session {
    my ($self, $session_id) = @_;
    $self->{session_id} = $session_id;
}

# Get session ID
sub session_id {
    my ($self) = @_;
    return $self->{session_id};
}

# Close connection
sub close {
    my ($self) = @_;
    if ($self->{connection}) {
        $self->{connection}->close();
        $self->{connection} = undef;
    }
}

# Check if connected
sub is_connected {
    my ($self) = @_;
    return $self->{connection} && $self->{connection}->is_connected();
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

# Get events handler
sub events {
    my ($self) = @_;
    return $self->{events};
}

sub DESTROY {
    my ($self) = @_;
    $self->close();
}

1;
