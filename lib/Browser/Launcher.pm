package Browser::Launcher;
use strict;
use warnings;
use HTTP::Tiny;
use File::Spec;

# Chrome Browser Launcher
# Handles detection, startup, and initial connection to Chrome

use constant {
    DEFAULT_PORT    => 9222,
    STARTUP_TIMEOUT => 15,
    STARTUP_POLL    => 0.2,
};

# Common Chrome locations by platform
my %CHROME_PATHS = (
    darwin => [
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
        '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
        "$ENV{HOME}/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    ],
    linux => [
        '/usr/bin/google-chrome',
        '/usr/bin/google-chrome-stable',
        '/usr/bin/chromium',
        '/usr/bin/chromium-browser',
        '/snap/bin/chromium',
        '/usr/local/bin/google-chrome',
        '/opt/google/chrome/google-chrome',
    ],
    # WSL detection happens at runtime
    wsl => [
        '/mnt/c/Program Files/Google/Chrome/Application/chrome.exe',
        '/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    ],
);

sub new {
    my ($class, %opts) = @_;

    my $self = bless {
        port         => $opts{port} // $ENV{CHROME_DRIVER_PORT} // DEFAULT_PORT,
        headless     => $opts{headless} // 1,
        user_data    => $opts{user_data},
        chrome_path  => $opts{chrome_path},
        extra_args   => $opts{extra_args} // [],
        pid          => undef,
        ws_url       => undef,
        error        => undef,
        timeout      => $opts{timeout} // STARTUP_TIMEOUT,
    }, $class;

    return $self;
}

# Detect current platform
sub _platform {
    my ($self) = @_;

    # Check for WSL first
    if ($^O eq 'linux' && -e '/proc/version') {
        my $version = do { local $/; open my $fh, '<', '/proc/version'; <$fh> };
        return 'wsl' if $version && $version =~ /microsoft|wsl/i;
    }

    return 'darwin' if $^O eq 'darwin';
    return 'linux'  if $^O eq 'linux';
    return 'unknown';
}

# Find Chrome executable
sub find_chrome {
    my ($self) = @_;

    # User-specified path
    if ($self->{chrome_path}) {
        if (-x $self->{chrome_path}) {
            return $self->{chrome_path};
        }
        $self->{error} = "Specified Chrome path not found: $self->{chrome_path}";
        return undef;
    }

    my $platform = $self->_platform();

    # Check PATH first
    for my $name (qw(google-chrome google-chrome-stable chromium chromium-browser chrome)) {
        for my $dir (File::Spec->path()) {
            my $path = File::Spec->catfile($dir, $name);
            return $path if -x $path;
        }
    }

    # Check platform-specific locations
    my @paths = @{$CHROME_PATHS{$platform} // []};

    # On WSL, also check Linux paths
    if ($platform eq 'wsl') {
        push @paths, @{$CHROME_PATHS{linux}};
    }

    for my $path (@paths) {
        return $path if -e $path && (-x $path || $path =~ /\.exe$/i);
    }

    $self->{error} = $self->_chrome_not_found_message($platform);
    return undef;
}

# Generate helpful error message for missing Chrome
sub _chrome_not_found_message {
    my ($self, $platform) = @_;

    my $msg = "Chrome/Chromium not found. ";

    if ($platform eq 'darwin') {
        $msg .= "Install from: https://www.google.com/chrome/ or 'brew install --cask google-chrome'";
    }
    elsif ($platform eq 'linux') {
        $msg .= "Install via your package manager: apt install chromium-browser, yum install chromium, etc.";
    }
    elsif ($platform eq 'wsl') {
        $msg .= "Install Chrome in Windows or install chromium in WSL: apt install chromium-browser";
    }
    else {
        $msg .= "Please install Google Chrome or Chromium.";
    }

    return $msg;
}

# Get Chrome version
sub chrome_version {
    my ($self, $chrome_path) = @_;
    $chrome_path //= $self->find_chrome();
    return undef unless $chrome_path;

    my $output = `"$chrome_path" --version 2>/dev/null`;
    if ($output && $output =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/) {
        return {
            major => $1,
            minor => $2,
            build => $3,
            patch => $4,
            string => "$1.$2.$3.$4",
        };
    }
    return undef;
}

# Build Chrome command line arguments
sub _build_args {
    my ($self) = @_;

    my @args = (
        "--remote-debugging-port=$self->{port}",
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-background-networking',
        '--disable-client-side-phishing-detection',
        '--disable-default-apps',
        '--disable-extensions',
        '--disable-hang-monitor',
        '--disable-popup-blocking',
        '--disable-prompt-on-repost',
        '--disable-sync',
        '--disable-translate',
        '--metrics-recording-only',
        '--safebrowsing-disable-auto-update',
    );

    if ($self->{headless}) {
        # Modern Chrome uses --headless=new
        my $version = $self->chrome_version();
        if ($version && $version->{major} >= 109) {
            push @args, '--headless=new';
        }
        else {
            push @args, '--headless';
        }
        push @args, '--disable-gpu';
        push @args, '--hide-scrollbars';
        push @args, '--mute-audio';
    }

    # User data directory
    if ($self->{user_data}) {
        push @args, "--user-data-dir=$self->{user_data}";
    }
    else {
        # Use temp directory
        my $tmp = $ENV{TMPDIR} // $ENV{TMP} // '/tmp';
        my $dir = "$tmp/chrome-driver-$$";
        push @args, "--user-data-dir=$dir";
    }

    # Extra user-specified args
    push @args, @{$self->{extra_args}};

    # Start with blank page
    push @args, 'about:blank';

    return @args;
}

# Check if Chrome is already running on our port
sub is_running {
    my ($self) = @_;

    my $http = HTTP::Tiny->new(timeout => 2);
    my $resp = $http->get("http://localhost:$self->{port}/json/version");

    return $resp->{success};
}

# Get Chrome info from running instance
sub get_chrome_info {
    my ($self) = @_;

    my $http = HTTP::Tiny->new(timeout => 5);
    my $resp = $http->get("http://localhost:$self->{port}/json/version");

    unless ($resp->{success}) {
        $self->{error} = "Cannot connect to Chrome at port $self->{port}";
        return undef;
    }

    require JSON::PP;
    return eval { JSON::PP::decode_json($resp->{content}) };
}

# Launch Chrome
sub launch {
    my ($self) = @_;

    # Check if already running
    if ($self->is_running()) {
        my $info = $self->get_chrome_info();
        if ($info && $info->{webSocketDebuggerUrl}) {
            $self->{ws_url} = $info->{webSocketDebuggerUrl};
            return 1;  # Already running, reuse it
        }
    }

    # Find Chrome
    my $chrome = $self->find_chrome();
    return 0 unless $chrome;

    # Build arguments
    my @args = $self->_build_args();

    # Fork and exec
    my $pid = fork();

    if (!defined $pid) {
        $self->{error} = "Fork failed: $!";
        return 0;
    }

    if ($pid == 0) {
        # Child process
        # Redirect stdout/stderr to /dev/null
        open STDOUT, '>', '/dev/null';
        open STDERR, '>', '/dev/null';

        # Start new session
        POSIX::setsid() if eval { require POSIX; 1 };

        exec($chrome, @args) or exit(1);
    }

    # Parent process
    $self->{pid} = $pid;

    # Wait for Chrome to start
    return $self->_wait_for_ready();
}

# Wait for Chrome to be ready
sub _wait_for_ready {
    my ($self) = @_;

    my $start = time();
    my $http = HTTP::Tiny->new(timeout => 2);

    while (time() - $start < $self->{timeout}) {
        my $resp = $http->get("http://localhost:$self->{port}/json/version");

        if ($resp->{success}) {
            require JSON::PP;
            my $info = eval { JSON::PP::decode_json($resp->{content}) };
            if ($info && $info->{webSocketDebuggerUrl}) {
                $self->{ws_url} = $info->{webSocketDebuggerUrl};
                return 1;
            }
        }

        # Check if child died
        if ($self->{pid}) {
            my $kid = waitpid($self->{pid}, 1);  # WNOHANG
            if ($kid == $self->{pid}) {
                $self->{error} = "Chrome process exited unexpectedly";
                $self->{pid} = undef;
                return 0;
            }
        }

        select(undef, undef, undef, STARTUP_POLL);
    }

    $self->{error} = "Chrome startup timeout after $self->{timeout}s";
    $self->shutdown();
    return 0;
}

# Graceful shutdown
sub shutdown {
    my ($self) = @_;

    return 1 unless $self->{pid};

    # Send SIGTERM first
    kill 'TERM', $self->{pid};

    # Wait up to 5 seconds for graceful exit
    my $waited = 0;
    while ($waited < 5) {
        my $kid = waitpid($self->{pid}, 1);  # WNOHANG
        if ($kid == $self->{pid} || $kid == -1) {
            $self->{pid} = undef;
            return 1;
        }
        select(undef, undef, undef, 0.1);
        $waited += 0.1;
    }

    # Force kill
    kill 'KILL', $self->{pid};
    waitpid($self->{pid}, 0);
    $self->{pid} = undef;

    return 1;
}

# Get WebSocket URL
sub ws_url {
    my ($self) = @_;
    return $self->{ws_url};
}

# Get PID
sub pid {
    my ($self) = @_;
    return $self->{pid};
}

# Get port
sub port {
    my ($self) = @_;
    return $self->{port};
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

# Check if we launched Chrome
sub launched {
    my ($self) = @_;
    return defined $self->{pid};
}

sub DESTROY {
    my ($self) = @_;
    $self->shutdown() if $self->{pid};
}

1;

__END__

=head1 NAME

Browser::Launcher - Chrome process launcher and detector

=head1 SYNOPSIS

    use Browser::Launcher;

    my $launcher = Browser::Launcher->new(
        port     => 9222,
        headless => 1,
    );

    # Find Chrome installation
    my $chrome_path = $launcher->find_chrome();
    print "Found: $chrome_path\n";

    # Launch Chrome
    $launcher->launch() or die $launcher->error();
    print "WebSocket URL: " . $launcher->ws_url() . "\n";

    # ... do stuff ...

    $launcher->shutdown();

=head1 DESCRIPTION

Browser::Launcher handles finding and starting Chrome with the DevTools
Protocol enabled. It supports macOS, Linux, and WSL.

=head1 METHODS

=head2 new(%options)

Create a new launcher.

Options:
  - port: Debugging port (default: 9222)
  - headless: Run headless (default: 1)
  - user_data: Chrome profile directory
  - chrome_path: Explicit path to Chrome executable
  - extra_args: Additional command-line arguments

=head2 find_chrome()

Returns the path to Chrome executable, or undef if not found.

=head2 chrome_version($path)

Returns Chrome version info hash with major, minor, build, patch, string.

=head2 is_running()

Returns true if Chrome is already running on our port.

=head2 launch()

Start Chrome. Returns true on success.

=head2 shutdown()

Stop Chrome gracefully.

=head2 ws_url()

Returns the WebSocket debugger URL after launch.

=head2 pid()

Returns the Chrome process ID if we launched it.

=head2 error()

Returns the last error message.

=cut
