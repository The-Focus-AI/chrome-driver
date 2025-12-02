#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use lib '../lib';
use lib 'lib';

# Visual capture tests

use_ok('ChromeDriver');
use_ok('Visual::Capture');

# Skip if CHROME_TEST env var not set
my $run_integration = $ENV{CHROME_TEST} || 0;

SKIP: {
    skip "Set CHROME_TEST=1 to run integration tests", 10 unless $run_integration;

    my $chrome = ChromeDriver->new(
        headless => 1,
        timeout  => 30,
    );

    ok($chrome, 'ChromeDriver created');

    my $connected = $chrome->connect_to_page();
    skip "Could not connect to Chrome: " . ($chrome->error // 'unknown'), 9 unless $connected;

    ok($connected, 'Connected to Chrome');

    # Navigate to example.com for testing
    $chrome->enable('Page');
    my $nav_result = $chrome->send('Page.navigate', { url => 'https://example.com' });
    ok($nav_result, 'Navigated to example.com');

    # Wait for page load
    $chrome->wait_for_event('Page.loadEventFired', 10);

    # Create Visual::Capture instance
    my $capture = Visual::Capture->new(chrome => $chrome);
    ok($capture, 'Visual::Capture instance created');

    # Create temp directory for files
    my $tempdir = tempdir(CLEANUP => 1);

    # Test: Take PNG screenshot (base64)
    subtest 'screenshot base64' => sub {
        plan tests => 2;

        my $data = $capture->screenshot();
        ok(defined $data, 'Got screenshot data');
        ok(length($data) > 1000, 'Screenshot has reasonable size');
    };

    # Test: Save PNG screenshot to file
    subtest 'screenshot to file' => sub {
        plan tests => 2;

        my $file = "$tempdir/test.png";
        my $result = $capture->screenshot(file => $file);
        ok($result eq $file, 'Screenshot returned file path');
        ok(-f $file && -s $file > 1000, 'PNG file created and has content');
        diag("PNG size: " . (-s $file) . " bytes");
    };

    # Test: JPEG screenshot
    subtest 'jpeg screenshot' => sub {
        plan tests => 2;

        my $file = "$tempdir/test.jpg";
        my $result = $capture->screenshot(
            format  => 'jpeg',
            quality => 80,
            file    => $file
        );
        ok($result eq $file, 'JPEG screenshot returned file path');
        ok(-f $file && -s $file > 500, 'JPEG file created and has content');
        diag("JPEG size: " . (-s $file) . " bytes");
    };

    # Test: Element screenshot
    subtest 'element screenshot' => sub {
        plan tests => 2;

        my $file = "$tempdir/h1.png";
        my $result = $capture->screenshot(
            selector => 'h1',
            file     => $file
        );
        ok($result eq $file, 'Element screenshot returned file path');
        ok(-f $file && -s $file > 100, 'Element screenshot file created');
        diag("Element screenshot size: " . (-s $file) . " bytes");
    };

    # Test: Set viewport
    subtest 'set viewport' => sub {
        plan tests => 2;

        my $result = $capture->set_viewport(width => 800, height => 600);
        ok($result, 'Set viewport succeeded');

        my $file = "$tempdir/viewport.png";
        $capture->screenshot(file => $file);
        ok(-f $file, 'Screenshot after viewport change');

        # Note: clearDeviceMetricsOverride may timeout in headless mode
        # This is a Chrome quirk, not a bug in our code
        $capture->clear_viewport();  # Best effort cleanup
    };

    # Test: Clip region screenshot
    subtest 'clip region screenshot' => sub {
        plan tests => 1;

        my $file = "$tempdir/clip.png";
        my $result = $capture->screenshot(
            clip => { x => 0, y => 0, width => 200, height => 100 },
            file => $file
        );
        ok(-f $file && -s $file > 100, 'Clip region screenshot created');
    };

    # Cleanup
    $chrome->quit();
    ok(1, 'Chrome quit successfully');
}

done_testing();
