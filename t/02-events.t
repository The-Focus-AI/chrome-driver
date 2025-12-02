#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib '../lib';
use lib 'lib';

use_ok('CDP::Events');

my $events = CDP::Events->new();

# Test basic subscription
{
    my $called = 0;
    my $received;

    my $id = $events->on('test.event', sub {
        my ($params) = @_;
        $called++;
        $received = $params;
    });

    ok($id, 'Got handler ID');
    ok($events->has_handlers('test.event'), 'Handler registered');
    is($events->handler_count('test.event'), 1, 'One handler registered');

    $events->dispatch('test.event', { foo => 'bar' });
    is($called, 1, 'Handler called');
    is_deeply($received, { foo => 'bar' }, 'Params received');

    # Should still be registered
    $events->dispatch('test.event', { foo => 'baz' });
    is($called, 2, 'Handler called again');
}

# Test once subscription
{
    my $called = 0;

    my $id = $events->once('once.event', sub {
        $called++;
    });

    $events->dispatch('once.event', {});
    is($called, 1, 'Once handler called');

    $events->dispatch('once.event', {});
    is($called, 1, 'Once handler not called again');

    ok(!$events->has_handlers('once.event'), 'Once handler removed');
}

# Test unsubscribe
{
    my $called = 0;

    my $id = $events->on('unsub.event', sub {
        $called++;
    });

    $events->dispatch('unsub.event', {});
    is($called, 1, 'Handler called before unsub');

    $events->off('unsub.event', $id);
    $events->dispatch('unsub.event', {});
    is($called, 1, 'Handler not called after unsub');
}

# Test multiple handlers
{
    my @called;

    $events->on('multi.event', sub { push @called, 'a' });
    $events->on('multi.event', sub { push @called, 'b' });
    $events->on('multi.event', sub { push @called, 'c' });

    is($events->handler_count('multi.event'), 3, 'Three handlers');

    $events->dispatch('multi.event', {});
    is_deeply(\@called, ['a', 'b', 'c'], 'All handlers called in order');
}

# Test off_all
{
    $events->on('clear.event', sub {});
    $events->on('clear.event', sub {});

    $events->off_all('clear.event');
    ok(!$events->has_handlers('clear.event'), 'All handlers cleared');
}

# Test event queue
{
    my $called = 0;

    $events->queue('queued.event', { data => 1 });
    $events->queue('queued.event', { data => 2 });

    is($called, 0, 'Queue does not dispatch immediately');

    $events->on('queued.event', sub { $called++ });
    my $flushed = $events->flush();

    is($flushed, 2, 'Two events flushed');
    is($called, 2, 'Handler called for each queued event');
}

# Test error handling in handlers
{
    my $called = 0;

    $events->on('error.event', sub { die "Test error" });
    $events->on('error.event', sub { $called++ });

    # Should not die, should continue to next handler
    eval { $events->dispatch('error.event', {}) };
    ok(!$@, 'Dispatch did not propagate error');
    is($called, 1, 'Second handler called despite first error');
}

# Test events listing
{
    my $e = CDP::Events->new();
    $e->on('foo', sub {});
    $e->on('bar', sub {});
    $e->on('baz', sub {});

    my @events = sort $e->events();
    is_deeply(\@events, ['bar', 'baz', 'foo'], 'Events list correct');
}

# Test common CDP event helpers
{
    my $e = CDP::Events->new();

    $e->on_page_load(sub {});
    ok($e->has_handlers('Page.loadEventFired'), 'Page load handler');

    $e->on_console(sub {});
    ok($e->has_handlers('Runtime.consoleAPICalled'), 'Console handler');

    $e->on_exception(sub {});
    ok($e->has_handlers('Runtime.exceptionThrown'), 'Exception handler');
}

done_testing();
