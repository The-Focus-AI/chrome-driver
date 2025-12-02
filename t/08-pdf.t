#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use lib '../lib';
use lib 'lib';

# PDF generation tests

use_ok('ChromeDriver');
use_ok('Print::PDF');

# Skip if CHROME_TEST env var not set
my $run_integration = $ENV{CHROME_TEST} || 0;

SKIP: {
    skip "Set CHROME_TEST=1 to run integration tests", 9 unless $run_integration;

    my $chrome = ChromeDriver->new(
        headless => 1,
        timeout  => 30,
    );

    ok($chrome, 'ChromeDriver created');

    my $connected = $chrome->connect_to_page();
    skip "Could not connect to Chrome: " . ($chrome->error // 'unknown'), 8 unless $connected;

    ok($connected, 'Connected to Chrome');

    # Navigate to example.com for testing
    $chrome->enable('Page');
    my $nav_result = $chrome->send('Page.navigate', { url => 'https://example.com' });
    ok($nav_result, 'Navigated to example.com');

    # Wait for page load
    $chrome->wait_for_event('Page.loadEventFired', 10);

    # Create Print::PDF instance
    my $pdf = Print::PDF->new(chrome => $chrome);
    ok($pdf, 'Print::PDF instance created');

    # Create temp directory for files
    my $tempdir = tempdir(CLEANUP => 1);

    # Test: Generate PDF (base64)
    subtest 'pdf base64' => sub {
        plan tests => 2;

        my $data = $pdf->pdf();
        ok(defined $data, 'Got PDF data');
        ok(length($data) > 1000, 'PDF has reasonable size');
    };

    # Test: Save PDF to file
    subtest 'pdf to file' => sub {
        plan tests => 3;

        my $file = "$tempdir/test.pdf";
        my $result = $pdf->pdf(file => $file);
        ok($result eq $file, 'PDF returned file path');
        ok(-f $file, 'PDF file exists');
        ok(-s $file > 1000, 'PDF file has content');
        diag("PDF size: " . (-s $file) . " bytes");
    };

    # Test: PDF with options
    subtest 'pdf with options' => sub {
        plan tests => 2;

        my $file = "$tempdir/options.pdf";
        my $result = $pdf->pdf(
            file            => $file,
            paper_size      => 'a4',
            landscape       => 1,
            margin          => 0.5,
            print_background => 1,
        );
        ok(-f $file, 'PDF with options created');
        ok(-s $file > 1000, 'PDF has content');
    };

    # Test: Convenience methods
    subtest 'convenience methods' => sub {
        plan tests => 2;

        my $file = "$tempdir/letter.pdf";
        my $result = $pdf->letter(file => $file);
        ok(-f $file, 'Letter PDF created');

        $file = "$tempdir/a4.pdf";
        $result = $pdf->a4(file => $file);
        ok(-f $file, 'A4 PDF created');
    };

    # Cleanup
    $chrome->quit();
    ok(1, 'Chrome quit successfully');
}

done_testing();
