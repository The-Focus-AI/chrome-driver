package CDP::Events;
use strict;
use warnings;

# CDP Event Subscription Manager
# Handles event registration, dispatch, and cleanup

sub new {
    my ($class) = @_;
    return bless {
        handlers     => {},        # event -> [ { id, callback, once } ]
        next_id      => 0,
        event_queue  => [],        # Buffered events
        queue_size   => 1000,      # Max queued events
    }, $class;
}

# Subscribe to an event
sub on {
    my ($self, $event, $callback) = @_;

    my $id = ++$self->{next_id};

    $self->{handlers}{$event} //= [];
    push @{$self->{handlers}{$event}}, {
        id       => $id,
        callback => $callback,
        once     => 0,
    };

    return $id;
}

# Subscribe to event (fires once then auto-removes)
sub once {
    my ($self, $event, $callback) = @_;

    my $id = ++$self->{next_id};

    $self->{handlers}{$event} //= [];
    push @{$self->{handlers}{$event}}, {
        id       => $id,
        callback => $callback,
        once     => 1,
    };

    return $id;
}

# Unsubscribe from event
sub off {
    my ($self, $event, $id) = @_;

    return 0 unless exists $self->{handlers}{$event};

    my $handlers = $self->{handlers}{$event};
    my @remaining;

    for my $h (@$handlers) {
        push @remaining, $h unless $h->{id} == $id;
    }

    if (@remaining) {
        $self->{handlers}{$event} = \@remaining;
    }
    else {
        delete $self->{handlers}{$event};
    }

    return 1;
}

# Remove all handlers for an event
sub off_all {
    my ($self, $event) = @_;

    if (defined $event) {
        delete $self->{handlers}{$event};
    }
    else {
        $self->{handlers} = {};
    }

    return 1;
}

# Dispatch an event to handlers
sub dispatch {
    my ($self, $event, $params) = @_;

    return 0 unless exists $self->{handlers}{$event};

    my $handlers = $self->{handlers}{$event};
    my @keep;

    for my $h (@$handlers) {
        eval {
            $h->{callback}->($params);
        };
        if ($@) {
            warn "Event handler error for $event: $@";
        }

        push @keep, $h unless $h->{once};
    }

    if (@keep) {
        $self->{handlers}{$event} = \@keep;
    }
    else {
        delete $self->{handlers}{$event};
    }

    return 1;
}

# Queue an event for later dispatch
sub queue {
    my ($self, $event, $params) = @_;

    push @{$self->{event_queue}}, {
        event  => $event,
        params => $params,
        time   => time(),
    };

    # Trim queue if too large
    if (@{$self->{event_queue}} > $self->{queue_size}) {
        shift @{$self->{event_queue}};
    }

    return 1;
}

# Process queued events
sub flush {
    my ($self) = @_;

    my @queue = @{$self->{event_queue}};
    $self->{event_queue} = [];

    for my $e (@queue) {
        $self->dispatch($e->{event}, $e->{params});
    }

    return scalar @queue;
}

# Check if any handlers exist for event
sub has_handlers {
    my ($self, $event) = @_;
    return exists $self->{handlers}{$event} &&
           @{$self->{handlers}{$event}} > 0;
}

# Get list of events with handlers
sub events {
    my ($self) = @_;
    return keys %{$self->{handlers}};
}

# Get handler count for event
sub handler_count {
    my ($self, $event) = @_;
    return 0 unless exists $self->{handlers}{$event};
    return scalar @{$self->{handlers}{$event}};
}

# Create a promise-like waiter for an event
sub wait_for {
    my ($self, $event, $predicate) = @_;

    my $result;
    my $done = 0;

    my $id = $self->once($event, sub {
        my ($params) = @_;
        if (!$predicate || $predicate->($params)) {
            $result = $params;
            $done = 1;
        }
    });

    return sub {
        my ($timeout) = @_;
        $timeout //= 30;
        my $end = time() + $timeout;
        while (!$done && time() < $end) {
            select(undef, undef, undef, 0.01);
        }
        $self->off($event, $id) unless $done;
        return $result;
    };
}

# Common CDP event patterns
sub on_page_load {
    my ($self, $callback) = @_;
    return $self->on('Page.loadEventFired', $callback);
}

sub on_console {
    my ($self, $callback) = @_;
    return $self->on('Runtime.consoleAPICalled', $callback);
}

sub on_exception {
    my ($self, $callback) = @_;
    return $self->on('Runtime.exceptionThrown', $callback);
}

sub on_request {
    my ($self, $callback) = @_;
    return $self->on('Network.requestWillBeSent', $callback);
}

sub on_response {
    my ($self, $callback) = @_;
    return $self->on('Network.responseReceived', $callback);
}

sub on_target_created {
    my ($self, $callback) = @_;
    return $self->on('Target.targetCreated', $callback);
}

sub on_target_destroyed {
    my ($self, $callback) = @_;
    return $self->on('Target.targetDestroyed', $callback);
}

1;
