#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib '../lib';
use lib 'lib';

# Integration test - requires Chrome running with --remote-debugging-port=9222

use_ok('ChromeDriver');
use_ok('CDP::Protocol');
use_ok('CDP::Connection');
use_ok('CDP::Events');
use_ok('CDP::Frame');

my $chrome = ChromeDriver->new(auto_start => 0);

# Try to get version info (doesn't require WebSocket)
my $version = $chrome->version();

SKIP: {
    skip "Chrome not running on port 9222 - skipping integration tests", 7 unless $version;

diag("Chrome version: $version->{Browser}") if $version->{Browser};

# Test target listing
my $targets = $chrome->list_targets();
ok($targets, 'Got targets list');
ok(ref($targets) eq 'ARRAY', 'Targets is array');

# Try to connect to a page if available
my @pages = grep { $_->{type} eq 'page' } @$targets;
if (@pages) {
    ok($chrome->connect_to_page(), 'Connected to page target');
    ok($chrome->is_connected(), 'Connection confirmed');

    # Enable Page domain
    my $result = $chrome->enable('Page');
    ok($result, 'Page domain enabled');

    # Get current URL
    my $info = $chrome->send('Runtime.evaluate', {
        expression => 'window.location.href'
    });
    ok($info, 'Got Runtime.evaluate result');
    diag("Current URL: $info->{result}{value}") if $info->{result};

    $chrome->close();
    ok(!$chrome->is_connected(), 'Disconnected');
}
else {
    diag("No page targets available - open a page in Chrome");
}

}  # End SKIP block

done_testing();
