#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib '../lib';
use lib 'lib';

# Navigation tests - requires Chrome running or auto-start enabled

use_ok('ChromeDriver');
use_ok('Page::Navigation');

# Skip if CHROME_TEST env var not set (CI-friendly)
my $run_integration = $ENV{CHROME_TEST} || 0;

SKIP: {
    skip "Set CHROME_TEST=1 to run integration tests", 15 unless $run_integration;

    # Try auto-start (headless)
    my $chrome = ChromeDriver->new(
        headless => 1,
        timeout  => 30,
    );

    ok($chrome, 'ChromeDriver created');

    # Connect to page
    my $connected = $chrome->connect_to_page();

    skip "Could not connect to Chrome: " . ($chrome->error // 'unknown'), 14 unless $connected;

    ok($connected, 'Connected to Chrome page target');

    # Create Navigation instance
    my $nav = Page::Navigation->new(chrome => $chrome);
    ok($nav, 'Navigation instance created');

    # Test: Navigate to a URL
    subtest 'navigate to URL' => sub {
        plan tests => 2;

        my $result = $nav->navigate('https://example.com');
        ok($result, 'Navigation to example.com succeeded') or diag($nav->error);

        my $url = $nav->current_url();
        like($url, qr/example\.com/, 'Current URL contains example.com');
    };

    # Test: Get current URL
    subtest 'current_url' => sub {
        plan tests => 1;

        my $url = $nav->current_url();
        ok(defined $url, 'Got current URL') or diag($nav->error);
        diag("URL: $url") if $url;
    };

    # Test: wait_for_selector
    subtest 'wait_for_selector' => sub {
        plan tests => 2;

        # Example.com has h1 and p elements
        my $found = $nav->wait_for_selector('h1', timeout => 5);
        ok($found, 'Found h1 element');

        # Test non-existent selector
        my $not_found = $nav->wait_for_selector('#nonexistent-element-12345', timeout => 1);
        ok(!$not_found, 'Correctly timed out on non-existent selector');
    };

    # Test: wait_for_function
    subtest 'wait_for_function' => sub {
        plan tests => 1;

        my $result = $nav->wait_for_function('function() { return document.readyState === "complete"; }', timeout => 5);
        ok($result, 'wait_for_function returned truthy');
    };

    # Test: reload
    subtest 'reload' => sub {
        plan tests => 1;

        my $result = $nav->reload(timeout => 10);
        ok($result, 'Page reload succeeded') or diag($nav->error);
    };

    # Test: Navigate to another page for history tests
    subtest 'navigate for history' => sub {
        plan tests => 1;

        my $result = $nav->navigate('https://www.iana.org/domains/reserved');
        ok($result, 'Navigated to second page') or diag($nav->error);
    };

    # Test: history
    subtest 'history' => sub {
        plan tests => 2;

        my $history = $nav->history();
        ok($history, 'Got navigation history');
        ok($history->{entries} && @{$history->{entries}} >= 2, 'History has at least 2 entries');
        diag("History entries: " . scalar(@{$history->{entries}})) if $history->{entries};
    };

    # Test: back
    subtest 'back' => sub {
        plan tests => 2;

        my $result = $nav->back(timeout => 10);
        ok($result, 'Navigated back') or diag($nav->error);

        my $url = $nav->current_url();
        like($url, qr/example\.com/, 'Back to example.com');
    };

    # Test: forward
    subtest 'forward' => sub {
        plan tests => 2;

        my $result = $nav->forward(timeout => 10);
        ok($result, 'Navigated forward') or diag($nav->error);

        my $url = $nav->current_url();
        like($url, qr/iana\.org/, 'Forward to iana.org');
    };

    # Test: wait_until options
    subtest 'navigate with wait_until options' => sub {
        plan tests => 2;

        # Test domcontentloaded
        my $result = $nav->navigate('https://example.com', wait_until => 'domcontentloaded');
        ok($result, 'Navigation with domcontentloaded succeeded');

        # Test none (no wait)
        $result = $nav->navigate('https://example.org', wait_until => 'none');
        ok($result, 'Navigation with no wait succeeded');
    };

    # Cleanup
    $chrome->quit();
    ok(1, 'Chrome quit successfully');
}

done_testing();
