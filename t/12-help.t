#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib '../lib';
use lib 'lib';

# Help system tests (no Chrome required)

use_ok('Help::Browser');

# Create help instance
my $help = Help::Browser->new();
ok($help, 'Help::Browser instance created');

# Test: Get overview
subtest 'overview topic' => sub {
    plan tests => 3;

    my $text = $help->help('overview');
    ok(defined $text, 'Got overview text');
    like($text, qr/Chrome Driver Overview/i, 'Contains title');
    like($text, qr/ChromeDriver/i, 'Contains module mention');
};

# Test: Get topics list
subtest 'topics list' => sub {
    plan tests => 4;

    my $text = $help->topics();
    ok(defined $text, 'Got topics list');
    like($text, qr/navigation/i, 'Lists navigation');
    like($text, qr/screenshot/i, 'Lists screenshot');
    like($text, qr/cookies/i, 'Lists cookies');
};

# Test: Navigation help
subtest 'navigation topic' => sub {
    plan tests => 3;

    my $text = $help->help('navigation');
    like($text, qr/Navigation/i, 'Contains title');
    like($text, qr/goto/i, 'Contains goto method');
    like($text, qr/reload/i, 'Contains reload method');
};

# Test: Screenshot help
subtest 'screenshot topic' => sub {
    plan tests => 3;

    my $text = $help->help('screenshot');
    like($text, qr/Screenshots/i, 'Contains title');
    like($text, qr/png.*jpeg/i, 'Mentions formats');
    like($text, qr/full_page/i, 'Contains full_page option');
};

# Test: PDF help
subtest 'pdf topic' => sub {
    plan tests => 3;

    my $text = $help->help('pdf');
    like($text, qr/PDF/i, 'Contains title');
    like($text, qr/paper_size/i, 'Contains paper_size');
    like($text, qr/letter.*a4/i, 'Lists paper sizes');
};

# Test: DOM help
subtest 'dom topic' => sub {
    plan tests => 3;

    my $text = $help->help('dom');
    like($text, qr/DOM/i, 'Contains title');
    like($text, qr/click/i, 'Contains click');
    like($text, qr/type/i, 'Contains type');
};

# Test: JavaScript help
subtest 'javascript topic' => sub {
    plan tests => 3;

    my $text = $help->help('javascript');
    like($text, qr/JavaScript/i, 'Contains title');
    like($text, qr/evaluate/i, 'Contains evaluate');
    like($text, qr/cdp_send/i, 'Contains cdp_send');
};

# Test: Cookies help
subtest 'cookies topic' => sub {
    plan tests => 3;

    my $text = $help->help('cookies');
    like($text, qr/Cookie/i, 'Contains title');
    like($text, qr/get_all/i, 'Contains get_all');
    like($text, qr/save.*file/i, 'Contains save method');
};

# Test: CDP help
subtest 'cdp topic' => sub {
    plan tests => 3;

    my $text = $help->help('cdp');
    like($text, qr/DevTools Protocol/i, 'Contains title');
    like($text, qr/Page\.navigate/i, 'Contains Page.navigate');
    like($text, qr/Runtime\.evaluate/i, 'Contains Runtime.evaluate');
};

# Test: Examples help
subtest 'examples topic' => sub {
    plan tests => 3;

    my $text = $help->help('examples');
    like($text, qr/Examples/i, 'Contains title');
    like($text, qr/SCRAPE/i, 'Contains scrape example');
    like($text, qr/FILL.*FORM/i, 'Contains form example');
};

# Test: Aliases
subtest 'topic aliases' => sub {
    plan tests => 4;

    like($help->help('nav'), qr/Navigation/i, 'nav alias works');
    like($help->help('js'), qr/JavaScript/i, 'js alias works');
    like($help->help('cookie'), qr/Cookie/i, 'cookie alias works');
    like($help->help('capture'), qr/Screenshots/i, 'capture alias works');
};

# Test: Unknown topic returns topic list
subtest 'unknown topic' => sub {
    plan tests => 2;

    my $text = $help->help('nonexistent');
    like($text, qr/Available Help Topics/i, 'Returns topic list');
    like($text, qr/overview/i, 'Lists overview');
};

# Test: Convenience function
subtest 'browser_help function' => sub {
    plan tests => 2;

    my $text = Help::Browser::browser_help('overview');
    ok(defined $text, 'Function returns text');
    like($text, qr/Chrome Driver/i, 'Contains expected content');
};

done_testing();
