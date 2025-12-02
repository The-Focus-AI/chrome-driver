#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib '../lib';
use lib 'lib';

# JavaScript execution tests

use_ok('ChromeDriver');
use_ok('JS::Execute');

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

    # Create JS::Execute instance
    my $js = JS::Execute->new(chrome => $chrome);
    ok($js, 'JS::Execute instance created');

    # Test: Simple evaluation
    subtest 'simple evaluation' => sub {
        plan tests => 4;

        my $result = $js->evaluate('1 + 2');
        is($result, 3, 'Simple arithmetic works');

        $result = $js->evaluate('"hello " + "world"');
        is($result, 'hello world', 'String concatenation works');

        $result = $js->evaluate('document.title');
        ok(defined $result, 'Got document title');
        like($result, qr/Example/i, 'Title contains "Example"');
        diag("Page title: $result");
    };

    # Test: Complex expressions
    subtest 'complex expressions' => sub {
        plan tests => 3;

        my $result = $js->evaluate('JSON.parse(\'{"a":1,"b":2}\')');
        ok(ref $result eq 'HASH', 'JSON parse returns hash');
        is($result->{a}, 1, 'JSON parsed correctly');

        $result = $js->evaluate('[1,2,3].map(x => x * 2)');
        ok(ref $result eq 'ARRAY', 'Array map returns array');
    };

    # Test: Error handling
    subtest 'error handling' => sub {
        plan tests => 2;

        my $result = $js->evaluate('nonexistent_variable');
        ok(!defined $result, 'Error returns undef');
        like($js->error(), qr/not defined|error/i, 'Error message set');
        diag("Error: " . $js->error());
    };

    # Test: Evaluate on object
    subtest 'evaluate on object' => sub {
        plan tests => 2;

        # First get an element
        my $el = $chrome->send('Runtime.evaluate', {
            expression => 'document.querySelector("h1")',
            returnByValue => \0,
        });

        ok($el && $el->{result}{objectId}, 'Got element object ID');

        my $text = $js->evaluate_on(
            $el->{result}{objectId},
            'function() { return this.textContent; }'
        );
        like($text, qr/Example/i, 'Got element text via evaluate_on');
    };

    # Test: Remote object
    subtest 'remote object' => sub {
        plan tests => 4;

        my $obj = $js->create_remote_object('document.querySelector("p")');
        ok($obj, 'Created remote object');
        ok($obj->{objectId}, 'Object has objectId');

        my $text = $js->evaluate_on($obj->{objectId}, 'function() { return this.tagName; }');
        is($text, 'P', 'Got tag name from remote object');

        $js->release_object($obj->{objectId});
        ok(1, 'Released object');
    };

    # Test: CDP send
    subtest 'cdp send' => sub {
        plan tests => 2;

        my $result = $js->cdp_send('DOM.getDocument');
        ok($result, 'CDP send works');
        ok($result->{root}, 'Got document root');
    };

    # Cleanup
    $chrome->quit();
    ok(1, 'Chrome quit successfully');
}

done_testing();
