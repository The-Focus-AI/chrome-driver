package ChromeDriver;
use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP;
use CDP::Protocol;
use Browser::Launcher;
use Browser::Lifecycle;

# Chrome DevTools Protocol Driver
# Main orchestrator for Chrome automation

our $VERSION = '0.01';

sub new {
    my ($class, %opts) = @_;

    my $port = $opts{port} // $ENV{CHROME_DRIVER_PORT} // 9222;

    return bless {
        host         => $opts{host} // 'localhost',
        port         => $port,
        timeout      => $opts{timeout} // $ENV{CHROME_DRIVER_TIMEOUT} // 30,
        headless     => $opts{headless} // 1,
        auto_start   => $opts{auto_start} // 1,
        keep_running => $opts{keep_running} // 0,  # Don't shutdown Chrome on exit
        user_data    => $opts{user_data},
        protocol     => undef,
        target_id    => undef,
        launcher     => undef,
        lifecycle    => Browser::Lifecycle->new(port => $port),
        error        => undef,
    }, $class;
}

# Ensure Chrome is running (auto-start if needed)
sub ensure_chrome {
    my ($self) = @_;

    # Check if Chrome is already running on our port
    if ($self->{lifecycle}->health_check()) {
        return 1;  # Already running
    }

    # Auto-start if enabled
    unless ($self->{auto_start}) {
        $self->{error} = "Chrome not running on port $self->{port} (auto_start disabled)";
        return 0;
    }

    # Create launcher if needed
    unless ($self->{launcher}) {
        $self->{launcher} = Browser::Launcher->new(
            port         => $self->{port},
            headless     => $self->{headless},
            keep_running => $self->{keep_running},
            user_data    => $self->{user_data},
            timeout      => $self->{timeout},
        );
    }

    # Launch Chrome
    unless ($self->{launcher}->launch()) {
        $self->{error} = $self->{launcher}->error();
        return 0;
    }

    # Write PID for tracking
    if ($self->{launcher}->pid()) {
        $self->{lifecycle}->write_pid($self->{launcher}->pid());
    }

    return 1;
}

# Connect to Chrome DevTools endpoint
sub connect {
    my ($self) = @_;

    # Ensure Chrome is running
    unless ($self->ensure_chrome()) {
        return 0;
    }

    my $http = HTTP::Tiny->new(timeout => 5);
    my $base = "http://$self->{host}:$self->{port}";

    # Get browser info
    my $resp = $http->get("$base/json/version");
    unless ($resp->{success}) {
        $self->{error} = "Cannot connect to Chrome at $base: " .
                         ($resp->{reason} // 'unknown error');
        return 0;
    }

    my $info = eval { decode_json($resp->{content}) };
    if ($@) {
        $self->{error} = "Invalid JSON from Chrome: $@";
        return 0;
    }

    my $ws_url = $info->{webSocketDebuggerUrl};
    unless ($ws_url) {
        $self->{error} = "No webSocketDebuggerUrl in Chrome response";
        return 0;
    }

    # Connect via WebSocket
    $self->{protocol} = CDP::Protocol->new(timeout => $self->{timeout});
    unless ($self->{protocol}->connect($ws_url)) {
        $self->{error} = $self->{protocol}->error();
        return 0;
    }

    return 1;
}

# Connect to a specific page target
sub connect_to_page {
    my ($self, $target_id) = @_;

    # Ensure Chrome is running
    unless ($self->ensure_chrome()) {
        return 0;
    }

    # Get available targets
    my $http = HTTP::Tiny->new(timeout => 5);
    my $resp = $http->get("http://$self->{host}:$self->{port}/json/list");

    unless ($resp->{success}) {
        $self->{error} = "Cannot list targets";
        return 0;
    }

    my $targets = eval { decode_json($resp->{content}) };
    if ($@) {
        $self->{error} = "Invalid JSON: $@";
        return 0;
    }

    # Find target
    my $target;
    if ($target_id) {
        ($target) = grep { $_->{id} eq $target_id } @$targets;
    }
    else {
        # Find first page target
        ($target) = grep { $_->{type} eq 'page' } @$targets;
    }

    unless ($target) {
        $self->{error} = "No suitable target found";
        return 0;
    }

    my $ws_url = $target->{webSocketDebuggerUrl};
    unless ($ws_url) {
        $self->{error} = "Target has no WebSocket URL (already connected?)";
        return 0;
    }

    # Connect
    $self->{protocol} = CDP::Protocol->new(timeout => $self->{timeout});
    unless ($self->{protocol}->connect($ws_url)) {
        $self->{error} = $self->{protocol}->error();
        return 0;
    }

    $self->{target_id} = $target->{id};

    return 1;
}

# Send CDP command
sub send {
    my ($self, $method, $params) = @_;

    unless ($self->{protocol}) {
        $self->{error} = "Not connected";
        return undef;
    }

    my $result = $self->{protocol}->send($method, $params);
    unless (defined $result) {
        $self->{error} = $self->{protocol}->error();
    }

    return $result;
}

# Subscribe to CDP event
sub on {
    my ($self, $event, $callback) = @_;
    return undef unless $self->{protocol};
    return $self->{protocol}->on($event, $callback);
}

# Unsubscribe from CDP event
sub off {
    my ($self, $event, $id) = @_;
    return undef unless $self->{protocol};
    return $self->{protocol}->off($event, $id);
}

# Wait for CDP event
sub wait_for_event {
    my ($self, $event, $timeout, $predicate) = @_;
    return undef unless $self->{protocol};
    return $self->{protocol}->wait_for_event($event, $timeout, $predicate);
}

# Enable a domain
sub enable {
    my ($self, $domain) = @_;
    return $self->send("$domain.enable");
}

# Disable a domain
sub disable {
    my ($self, $domain) = @_;
    return $self->send("$domain.disable");
}

# Poll for events
sub poll {
    my ($self, $timeout) = @_;
    return 0 unless $self->{protocol};
    return $self->{protocol}->poll($timeout);
}

# Close connection
sub close {
    my ($self) = @_;
    if ($self->{protocol}) {
        $self->{protocol}->close();
        $self->{protocol} = undef;
    }
}

# Close connection and shutdown browser
sub quit {
    my ($self) = @_;

    # Close WebSocket connection first
    $self->close();

    # Shutdown Chrome if we launched it (unless keep_running is set)
    if ($self->{launcher} && $self->{launcher}->launched() && !$self->{keep_running}) {
        $self->{launcher}->shutdown();
        $self->{lifecycle}->remove_pid();
    }
}

# Check connection
sub is_connected {
    my ($self) = @_;
    return $self->{protocol} && $self->{protocol}->is_connected();
}

# Check if browser is running
sub is_browser_running {
    my ($self) = @_;
    return $self->{lifecycle}->health_check();
}

# Get browser status
sub browser_status {
    my ($self) = @_;
    return $self->{lifecycle}->status();
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

# Get protocol object for advanced use
sub protocol {
    my ($self) = @_;
    return $self->{protocol};
}

# Get launcher object for advanced use
sub launcher {
    my ($self) = @_;
    return $self->{launcher};
}

# Get lifecycle object for advanced use
sub lifecycle {
    my ($self) = @_;
    return $self->{lifecycle};
}

# List available targets
sub list_targets {
    my ($self) = @_;

    my $http = HTTP::Tiny->new(timeout => 5);
    my $resp = $http->get("http://$self->{host}:$self->{port}/json/list");

    unless ($resp->{success}) {
        $self->{error} = "Cannot list targets";
        return undef;
    }

    return eval { decode_json($resp->{content}) };
}

# Get browser version info
sub version {
    my ($self) = @_;

    my $http = HTTP::Tiny->new(timeout => 5);
    my $resp = $http->get("http://$self->{host}:$self->{port}/json/version");

    unless ($resp->{success}) {
        return undef;
    }

    return eval { decode_json($resp->{content}) };
}

sub DESTROY {
    my ($self) = @_;
    $self->quit();
}

1;

__END__

=head1 NAME

ChromeDriver - Pure Perl Chrome DevTools Protocol client

=head1 SYNOPSIS

    use ChromeDriver;

    # Auto-start Chrome and connect (headless by default)
    my $chrome = ChromeDriver->new();
    $chrome->connect_to_page() or die $chrome->error();

    # Enable Page domain
    $chrome->enable('Page');

    # Navigate to URL
    $chrome->send('Page.navigate', { url => 'https://example.com' });

    # Wait for load
    $chrome->wait_for_event('Page.loadEventFired', 30);

    # Execute JavaScript
    my $result = $chrome->send('Runtime.evaluate', {
        expression => 'document.title'
    });
    print "Title: $result->{result}{value}\n";

    # Quit closes connection and shuts down Chrome
    $chrome->quit();

=head1 DESCRIPTION

ChromeDriver provides a pure Perl interface to the Chrome DevTools Protocol.
It requires no external dependencies beyond Perl 5.14+ core modules.

Features:
  - Auto-starts Chrome if not running
  - Headless mode by default
  - PID tracking and lifecycle management
  - macOS, Linux, and WSL support

=head1 METHODS

=head2 new(%options)

Create a new ChromeDriver instance.

Options:
  - host: Chrome host (default: localhost)
  - port: Chrome debugging port (default: 9222)
  - timeout: Command timeout in seconds (default: 30)
  - headless: Run in headless mode (default: 1)
  - auto_start: Auto-start Chrome if not running (default: 1)
  - user_data: Chrome profile directory (optional)

=head2 connect()

Connect to the browser-level WebSocket endpoint.

=head2 connect_to_page($target_id)

Connect to a specific page target. If no target_id is given,
connects to the first available page.

=head2 send($method, $params)

Send a CDP command and wait for response.
Returns the result or undef on error.

=head2 on($event, $callback)

Subscribe to a CDP event. Returns a handler ID.

=head2 off($event, $id)

Unsubscribe from a CDP event.

=head2 wait_for_event($event, $timeout, $predicate)

Wait for a specific CDP event. Optional predicate function
for filtering events.

=head2 enable($domain)

Enable a CDP domain (e.g., 'Page', 'DOM', 'Network').

=head2 disable($domain)

Disable a CDP domain.

=head2 poll($timeout)

Process incoming events for up to $timeout seconds.

=head2 close()

Close the WebSocket connection.

=head2 is_connected()

Returns true if connected.

=head2 error()

Returns the last error message.

=head2 list_targets()

Returns list of available targets.

=head2 version()

Returns Chrome version information.

=head1 AUTHOR

Generated for chrome-driver plugin

=cut
