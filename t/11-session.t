#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use lib '../lib';
use lib 'lib';

# Session management tests

use_ok('ChromeDriver');
use_ok('Session::Cookies');

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
    $chrome->enable('Network');
    $chrome->send('Page.navigate', { url => 'https://example.com' });

    # Wait for page load
    $chrome->wait_for_event('Page.loadEventFired', 10);
    ok(1, 'Page setup complete');

    # Create Session::Cookies instance
    my $cookies = Session::Cookies->new(chrome => $chrome);
    ok($cookies, 'Session::Cookies instance created');

    # Create temp directory for files
    my $tempdir = tempdir(CLEANUP => 1);

    # Test: Set and get cookie
    subtest 'set and get cookie' => sub {
        plan tests => 4;

        my $result = $cookies->set(
            name   => 'test_cookie',
            value  => 'test_value_123',
            domain => 'example.com',
            path   => '/',
        );
        ok($result, 'Set cookie succeeded');

        my $cookie = $cookies->get_cookie('test_cookie');
        ok($cookie, 'Got cookie back');
        is($cookie->{name}, 'test_cookie', 'Cookie name matches');
        is($cookie->{value}, 'test_value_123', 'Cookie value matches');
    };

    # Test: Get all cookies
    subtest 'get all cookies' => sub {
        plan tests => 1;

        my @all = $cookies->get_all();
        ok(scalar(@all) >= 1, 'Got at least one cookie');
        diag("Total cookies: " . scalar(@all));
    };

    # Test: Delete cookie
    subtest 'delete cookie' => sub {
        plan tests => 2;

        my $result = $cookies->delete('test_cookie', domain => 'example.com');
        ok($result, 'Delete cookie succeeded');

        my $cookie = $cookies->get_cookie('test_cookie');
        ok(!$cookie, 'Cookie no longer exists');
    };

    # Test: Save and load cookies
    subtest 'save and load cookies' => sub {
        plan tests => 4;

        # Set a cookie first
        $cookies->set(
            name   => 'save_test',
            value  => 'save_value',
            domain => 'example.com',
            path   => '/',
        );

        my $file = "$tempdir/cookies.json";
        my $result = $cookies->save($file);
        ok($result, 'Save cookies succeeded');
        ok(-f $file, 'Cookie file created');

        # Clear and reload
        $cookies->clear();
        my $loaded = $cookies->load($file);
        ok($loaded > 0, "Loaded $loaded cookies");

        my $cookie = $cookies->get_cookie('save_test');
        ok($cookie && $cookie->{value} eq 'save_value', 'Loaded cookie has correct value');
    };

    # Test: Clear all cookies
    subtest 'clear all cookies' => sub {
        plan tests => 2;

        # Set a cookie first
        $cookies->set(
            name   => 'clear_test',
            value  => 'clear_value',
            domain => 'example.com',
        );

        my $result = $cookies->clear();
        ok($result, 'Clear cookies succeeded');

        my @all = $cookies->get_all();
        is(scalar(@all), 0, 'No cookies after clear');
    };

    # Cleanup
    $chrome->quit();
    ok(1, 'Chrome quit successfully');
}

done_testing();
