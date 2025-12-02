package Browser::Lifecycle;
use strict;
use warnings;
use HTTP::Tiny;
use File::Spec;

# Chrome Lifecycle Manager
# Handles PID tracking, health checks, cleanup, and port management

use constant {
    DEFAULT_PORT    => 9222,
    HEALTH_TIMEOUT  => 2,
    SHUTDOWN_GRACE  => 5,
};

sub new {
    my ($class, %opts) = @_;

    my $port = $opts{port} // $ENV{CHROME_DRIVER_PORT} // DEFAULT_PORT;
    my $tmp = $ENV{TMPDIR} // $ENV{TMP} // '/tmp';

    return bless {
        port         => $port,
        pid_file     => $opts{pid_file} // "$tmp/chrome-driver-$port.pid",
        launcher     => $opts{launcher},
        error        => undef,
    }, $class;
}

# Write PID file
sub write_pid {
    my ($self, $pid) = @_;

    open my $fh, '>', $self->{pid_file} or do {
        $self->{error} = "Cannot write PID file: $!";
        return 0;
    };

    print $fh "$pid\n";
    print $fh "port=$self->{port}\n";
    print $fh "started=" . time() . "\n";
    close $fh;

    return 1;
}

# Read PID file
sub read_pid {
    my ($self) = @_;

    return undef unless -f $self->{pid_file};

    open my $fh, '<', $self->{pid_file} or return undef;
    my $content = do { local $/; <$fh> };
    close $fh;

    my ($pid) = $content =~ /^(\d+)/m;
    return $pid;
}

# Remove PID file
sub remove_pid {
    my ($self) = @_;
    unlink $self->{pid_file} if -f $self->{pid_file};
    return 1;
}

# Check if process is alive
sub is_process_alive {
    my ($self, $pid) = @_;
    $pid //= $self->read_pid();
    return 0 unless $pid;

    # kill 0 checks if process exists
    return kill(0, $pid) ? 1 : 0;
}

# Health check - verify Chrome is responding
sub health_check {
    my ($self) = @_;

    my $http = HTTP::Tiny->new(timeout => HEALTH_TIMEOUT);
    my $resp = $http->get("http://localhost:$self->{port}/json/version");

    return $resp->{success} ? 1 : 0;
}

# Get detailed status
sub status {
    my ($self) = @_;

    my $result = {
        port      => $self->{port},
        pid       => $self->read_pid(),
        alive     => 0,
        healthy   => 0,
        info      => undef,
    };

    $result->{alive} = $self->is_process_alive($result->{pid});

    if ($result->{alive} || $self->health_check()) {
        $result->{healthy} = 1;
        $result->{info} = $self->_get_chrome_info();
    }

    return $result;
}

# Get Chrome info
sub _get_chrome_info {
    my ($self) = @_;

    my $http = HTTP::Tiny->new(timeout => HEALTH_TIMEOUT);
    my $resp = $http->get("http://localhost:$self->{port}/json/version");

    return undef unless $resp->{success};

    require JSON::PP;
    return eval { JSON::PP::decode_json($resp->{content}) };
}

# Check if port is in use
sub port_in_use {
    my ($self, $port) = @_;
    $port //= $self->{port};

    require IO::Socket::INET;
    my $sock = IO::Socket::INET->new(
        LocalPort => $port,
        Proto     => 'tcp',
        ReuseAddr => 1,
    );

    if ($sock) {
        close $sock;
        return 0;  # Port is free
    }

    return 1;  # Port is in use
}

# Find available port
sub find_available_port {
    my ($self, $start, $count) = @_;
    $start //= 9222;
    $count //= 100;

    for my $port ($start .. $start + $count - 1) {
        return $port unless $self->port_in_use($port);
    }

    return undef;
}

# Shutdown Chrome by PID
sub shutdown_pid {
    my ($self, $pid) = @_;
    $pid //= $self->read_pid();
    return 1 unless $pid;
    return 1 unless $self->is_process_alive($pid);

    # Try SIGTERM first
    kill 'TERM', $pid;

    # Wait for graceful shutdown
    my $waited = 0;
    while ($waited < SHUTDOWN_GRACE) {
        return 1 unless $self->is_process_alive($pid);
        select(undef, undef, undef, 0.1);
        $waited += 0.1;
    }

    # Force kill if still running
    kill 'KILL', $pid;
    waitpid($pid, 0);

    return 1;
}

# Cleanup - shutdown and remove PID file
sub cleanup {
    my ($self) = @_;

    my $pid = $self->read_pid();
    if ($pid) {
        $self->shutdown_pid($pid);
    }

    $self->remove_pid();

    # Also clean up user data directory if it's our temp dir
    my $tmp = $ENV{TMPDIR} // $ENV{TMP} // '/tmp';
    my $data_dir = "$tmp/chrome-driver-$pid" if $pid;
    if ($data_dir && -d $data_dir) {
        # Best effort cleanup
        system("rm", "-rf", $data_dir);
    }

    return 1;
}

# Clean up zombie Chrome processes
sub cleanup_zombies {
    my ($self) = @_;

    # Find Chrome processes on our ports
    my @killed;

    # Check for PID files
    my $tmp = $ENV{TMPDIR} // $ENV{TMP} // '/tmp';
    opendir my $dh, $tmp or return \@killed;

    for my $file (readdir $dh) {
        next unless $file =~ /^chrome-driver-(\d+)\.pid$/;
        my $port = $1;

        my $pid_file = "$tmp/$file";
        open my $fh, '<', $pid_file or next;
        my ($pid) = <$fh> =~ /^(\d+)/;
        close $fh;

        next unless $pid;

        # Check if process is actually running
        if ($self->is_process_alive($pid)) {
            # Check if it's responding on its port
            my $http = HTTP::Tiny->new(timeout => 2);
            my $resp = $http->get("http://localhost:$port/json/version");

            unless ($resp->{success}) {
                # Process alive but not responding - zombie
                $self->shutdown_pid($pid);
                unlink $pid_file;
                push @killed, { pid => $pid, port => $port };
            }
        }
        else {
            # Stale PID file
            unlink $pid_file;
        }
    }

    closedir $dh;

    return \@killed;
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

# Get port
sub port {
    my ($self) = @_;
    return $self->{port};
}

# Get PID file path
sub pid_file {
    my ($self) = @_;
    return $self->{pid_file};
}

1;

__END__

=head1 NAME

Browser::Lifecycle - Chrome process lifecycle management

=head1 SYNOPSIS

    use Browser::Lifecycle;

    my $lifecycle = Browser::Lifecycle->new(port => 9222);

    # Check status
    my $status = $lifecycle->status();
    print "Chrome running: $status->{healthy}\n";

    # Health check
    if ($lifecycle->health_check()) {
        print "Chrome is responding\n";
    }

    # Find available port
    my $port = $lifecycle->find_available_port(9222);

    # Cleanup
    $lifecycle->cleanup();

    # Clean zombie processes
    my $killed = $lifecycle->cleanup_zombies();

=head1 DESCRIPTION

Browser::Lifecycle handles Chrome process lifecycle management including
PID tracking, health monitoring, and cleanup operations.

=head1 METHODS

=head2 new(%options)

Create a new lifecycle manager.

Options:
  - port: Chrome debugging port (default: 9222)
  - pid_file: Path to PID file

=head2 write_pid($pid)

Write PID to tracking file.

=head2 read_pid()

Read PID from tracking file.

=head2 remove_pid()

Remove PID tracking file.

=head2 is_process_alive($pid)

Check if process is running.

=head2 health_check()

Check if Chrome is responding on the debugging port.

=head2 status()

Get detailed status hash with port, pid, alive, healthy, info.

=head2 port_in_use($port)

Check if a port is in use.

=head2 find_available_port($start, $count)

Find an available port starting from $start.

=head2 shutdown_pid($pid)

Gracefully shutdown Chrome by PID.

=head2 cleanup()

Full cleanup - shutdown and remove tracking files.

=head2 cleanup_zombies()

Find and kill zombie Chrome processes.

=cut
