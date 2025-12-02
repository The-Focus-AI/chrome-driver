#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use Browser::Launcher;
use Browser::Lifecycle;

# Test Browser::Launcher

my $launcher = Browser::Launcher->new(
    port     => 9333,  # Use different port for testing
    headless => 1,
);

ok($launcher, 'Browser::Launcher created');
is($launcher->port(), 9333, 'Port set correctly');

# Test platform detection (internal method)
my $platform = $launcher->_platform();
ok($platform =~ /^(darwin|linux|wsl|unknown)$/, "Platform detected: $platform");

# Test Chrome detection
my $chrome_path = $launcher->find_chrome();
SKIP: {
    skip "Chrome not installed", 3 unless $chrome_path;

    ok(-e $chrome_path, "Chrome exists at: $chrome_path");
    ok(-x $chrome_path || $chrome_path =~ /\.exe$/, 'Chrome is executable');

    # Test version detection
    my $version = $launcher->chrome_version($chrome_path);
    if ($version) {
        ok($version->{major} >= 70, "Chrome version $version->{string} is supported");
        diag("Chrome version: $version->{string}");
    }
    else {
        pass("Version detection optional");
    }
}

# Test Browser::Lifecycle

my $lifecycle = Browser::Lifecycle->new(port => 9333);

ok($lifecycle, 'Browser::Lifecycle created');
is($lifecycle->port(), 9333, 'Lifecycle port correct');

# Test port availability check
my $port_in_use = $lifecycle->port_in_use(9333);
ok(defined $port_in_use, 'port_in_use returns a value');

# Test available port finder
my $available = $lifecycle->find_available_port(19000, 10);
ok($available, "Found available port: $available");

# Test PID file operations
my $test_pid = $$;  # Use our own PID for testing

ok($lifecycle->write_pid($test_pid), 'write_pid succeeds');
is($lifecycle->read_pid(), $test_pid, 'read_pid returns correct PID');
ok($lifecycle->is_process_alive($test_pid), 'Our process is alive');

# Clean up test PID file
ok($lifecycle->remove_pid(), 'remove_pid succeeds');
is($lifecycle->read_pid(), undef, 'PID file removed');

# Test health check (should fail - no Chrome on test port)
ok(!$lifecycle->health_check(), 'Health check fails when Chrome not running');

# Test status
my $status = $lifecycle->status();
ok($status, 'status returns hash');
is($status->{port}, 9333, 'Status has correct port');
is($status->{healthy}, 0, 'Status shows not healthy');

# Integration test - actually launch Chrome (if available)
SKIP: {
    skip "Chrome not installed - skipping launch test", 5 unless $chrome_path;
    skip "Set CHROME_TEST=1 to run Chrome launch tests", 5 unless $ENV{CHROME_TEST};

    diag("Running Chrome launch tests...");

    my $test_launcher = Browser::Launcher->new(
        port     => 9334,
        headless => 1,
    );

    ok($test_launcher->launch(), 'Chrome launched successfully') or do {
        diag("Launch error: " . ($test_launcher->error() // 'unknown'));
        skip "Chrome failed to launch", 4;
    };

    ok($test_launcher->ws_url(), 'WebSocket URL available: ' . ($test_launcher->ws_url() // ''));
    ok($test_launcher->pid(), 'PID captured: ' . ($test_launcher->pid() // ''));

    # Test health check
    my $test_lifecycle = Browser::Lifecycle->new(port => 9334);
    ok($test_lifecycle->health_check(), 'Chrome is healthy');

    # Shutdown
    ok($test_launcher->shutdown(), 'Chrome shutdown successfully');

    # Wait a moment and verify
    select(undef, undef, undef, 0.5);
    ok(!$test_lifecycle->health_check(), 'Chrome stopped responding after shutdown');
}

done_testing();
