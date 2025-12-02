#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib '../lib';
use lib 'lib';

# Content extraction tests

use_ok('ChromeDriver');
use_ok('Content::Extraction');

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

    # Create Content::Extraction instance
    my $content = Content::Extraction->new(chrome => $chrome);
    ok($content, 'Content::Extraction instance created');

    # Test: Get page title
    subtest 'title' => sub {
        plan tests => 2;

        my $title = $content->title();
        ok(defined $title, 'Got title');
        like($title, qr/Example Domain/i, 'Title contains "Example Domain"');
    };

    # Test: Get HTML
    subtest 'html' => sub {
        plan tests => 4;

        my $html = $content->html();
        ok(defined $html, 'Got full page HTML');
        like($html, qr/<html/i, 'HTML contains <html> tag');

        # Get specific element
        my $h1_html = $content->html(selector => 'h1');
        ok(defined $h1_html, 'Got h1 element HTML');
        like($h1_html, qr/>Example Domain</i, 'H1 contains "Example Domain"');
    };

    # Test: Get text
    subtest 'text' => sub {
        plan tests => 4;

        my $text = $content->text();
        ok(defined $text, 'Got page text');
        like($text, qr/Example Domain/i, 'Text contains "Example Domain"');

        # Get specific element text
        my $p_text = $content->text(selector => 'p');
        ok(defined $p_text, 'Got p element text');
        like($p_text, qr/domain/i, 'P text mentions "domain"');
    };

    # Test: Get markdown
    subtest 'markdown' => sub {
        plan tests => 3;

        my $md = $content->markdown();
        ok(defined $md, 'Got markdown');
        like($md, qr/#.*Example Domain/, 'Markdown has heading');
        unlike($md, qr/<[^>]+>/, 'Markdown has no HTML tags');
    };

    # Test: Get links
    subtest 'links' => sub {
        plan tests => 2;

        my $links = $content->links();
        ok(defined $links && ref $links eq 'ARRAY', 'Got links array');
        ok(@$links > 0, 'Found at least one link');
        if (@$links) {
            diag("First link: $links->[0]{href}");
        }
    };

    # Test: Get images (example.com may not have images)
    subtest 'images' => sub {
        plan tests => 1;

        my $images = $content->images();
        ok(defined $images && ref $images eq 'ARRAY', 'Got images array');
        diag("Found " . scalar(@$images) . " images");
    };

    # Test: Get metadata
    subtest 'metadata' => sub {
        plan tests => 1;

        my $meta = $content->metadata();
        ok(defined $meta && ref $meta eq 'HASH', 'Got metadata hash');
        if ($meta && %$meta) {
            diag("Metadata keys: " . join(', ', keys %$meta));
        }
    };

    # Cleanup
    $chrome->quit();
    ok(1, 'Chrome quit successfully');
}

done_testing();
