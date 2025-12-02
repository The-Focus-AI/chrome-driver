#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib '../lib';
use lib 'lib';

# DOM interaction tests

use_ok('ChromeDriver');
use_ok('DOM::Elements');

# Skip if CHROME_TEST env var not set
my $run_integration = $ENV{CHROME_TEST} || 0;

SKIP: {
    skip "Set CHROME_TEST=1 to run integration tests", 12 unless $run_integration;

    my $chrome = ChromeDriver->new(
        headless => 1,
        timeout  => 30,
    );

    ok($chrome, 'ChromeDriver created');

    my $connected = $chrome->connect_to_page();
    skip "Could not connect to Chrome: " . ($chrome->error // 'unknown'), 11 unless $connected;

    ok($connected, 'Connected to Chrome');

    # Navigate to example.com for testing
    $chrome->enable('Page');
    my $nav_result = $chrome->send('Page.navigate', { url => 'https://example.com' });
    ok($nav_result, 'Navigated to example.com');

    # Wait for page load
    $chrome->wait_for_event('Page.loadEventFired', 10);

    # Create DOM::Elements instance
    my $dom = DOM::Elements->new(chrome => $chrome);
    ok($dom, 'DOM::Elements instance created');

    # Test: Query single element
    subtest 'query single element' => sub {
        plan tests => 3;

        my $h1 = $dom->query('h1');
        ok($h1, 'Found h1 element');
        ok($h1->{object_id}, 'Element has object_id');

        my $nonexistent = $dom->query('.nonexistent-class');
        ok(!$nonexistent, 'Non-existent element returns undef');
    };

    # Test: Query all elements
    subtest 'query all elements' => sub {
        plan tests => 2;

        my @links = $dom->query_all('a');
        ok(scalar(@links) >= 1, 'Found at least one link');
        diag("Found " . scalar(@links) . " links");

        my @ps = $dom->query_all('p');
        ok(scalar(@ps) >= 1, 'Found at least one paragraph');
    };

    # Test: Get text
    subtest 'get text' => sub {
        plan tests => 2;

        my $text = $dom->get_text('h1');
        ok(defined $text, 'Got h1 text');
        like($text, qr/Example/i, 'Text contains "Example"');
        diag("H1 text: $text");
    };

    # Test: Get attribute
    subtest 'get attribute' => sub {
        plan tests => 1;

        my $href = $dom->get_attribute('a', 'href');
        ok(defined $href, 'Got link href attribute');
        diag("Link href: $href");
    };

    # Test: Element exists
    subtest 'element exists' => sub {
        plan tests => 2;

        ok($dom->exists('h1'), 'h1 exists');
        ok(!$dom->exists('.definitely-not-there'), 'Non-existent element does not exist');
    };

    # Test: Is visible
    subtest 'is visible' => sub {
        plan tests => 1;

        my $visible = $dom->is_visible('h1');
        ok($visible, 'h1 is visible');
    };

    # Test: Get bounding box
    subtest 'get bounding box' => sub {
        plan tests => 4;

        my $box = $dom->get_box('h1');
        ok($box, 'Got bounding box');
        ok(defined $box->{width}, 'Box has width');
        ok(defined $box->{height}, 'Box has height');
        ok($box->{width} > 0 && $box->{height} > 0, 'Box has positive dimensions');
        diag("H1 box: ${$box}{width}x${$box}{height} at (${$box}{x}, ${$box}{y})");
    };

    # Test: Wait for element (already exists)
    subtest 'wait for element' => sub {
        plan tests => 1;

        my $el = $dom->wait_for('h1', 2);
        ok($el, 'Wait for existing element succeeds');
    };

    # Cleanup
    $chrome->quit();
    ok(1, 'Chrome quit successfully');
}

done_testing();
