package JS::Execute;
use strict;
use warnings;

# JavaScript execution module for chrome-driver
# Evaluate JS, handle async operations, and provide raw CDP access

sub new {
    my ($class, %opts) = @_;

    my $chrome = $opts{chrome} or die "chrome parameter required";

    return bless {
        chrome     => $chrome,
        error      => undef,
        subscribers => {},
    }, $class;
}

# Evaluate JavaScript expression and return result
sub evaluate {
    my ($self, $expression, %opts) = @_;

    my %params = (
        expression     => $expression,
        returnByValue  => $opts{return_by_value} // \1,
        userGesture    => $opts{user_gesture} ? \1 : \0,
    );

    # Wrap in exception handling if requested
    if ($opts{include_command_line_api}) {
        $params{includeCommandLineAPI} = \1;
    }

    my $result = $self->{chrome}->send('Runtime.evaluate', \%params);

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error() // "Evaluate failed";
        return undef;
    }

    # Check for exceptions
    if ($result->{exceptionDetails}) {
        my $exception = $result->{exceptionDetails};
        my $text = $exception->{text} // 'Unknown error';
        if ($exception->{exception} && $exception->{exception}{description}) {
            $text = $exception->{exception}{description};
        }
        $self->{error} = "JavaScript error: $text";
        return undef;
    }

    # Return the value
    if ($result->{result}) {
        if ($opts{return_by_value} // 1) {
            return $result->{result}{value};
        }
        else {
            # Return remote object info
            return $result->{result};
        }
    }

    return undef;
}

# Evaluate async JavaScript (await expressions)
sub evaluate_async {
    my ($self, $expression, %opts) = @_;

    my $timeout = $opts{timeout} // 30000;  # 30 seconds default

    my %params = (
        expression     => $expression,
        awaitPromise   => \1,
        returnByValue  => $opts{return_by_value} // \1,
        userGesture    => $opts{user_gesture} ? \1 : \0,
    );

    if ($opts{include_command_line_api}) {
        $params{includeCommandLineAPI} = \1;
    }

    # Use a longer timeout for async operations
    my $original_timeout = $self->{chrome}->{timeout};
    $self->{chrome}->{timeout} = $timeout / 1000;

    my $result = $self->{chrome}->send('Runtime.evaluate', \%params);

    $self->{chrome}->{timeout} = $original_timeout;

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error() // "Async evaluate failed";
        return undef;
    }

    # Check for exceptions
    if ($result->{exceptionDetails}) {
        my $exception = $result->{exceptionDetails};
        my $text = $exception->{text} // 'Unknown error';
        if ($exception->{exception} && $exception->{exception}{description}) {
            $text = $exception->{exception}{description};
        }
        $self->{error} = "JavaScript error: $text";
        return undef;
    }

    if ($result->{result}) {
        if ($opts{return_by_value} // 1) {
            return $result->{result}{value};
        }
        else {
            return $result->{result};
        }
    }

    return undef;
}

# Evaluate JavaScript on a specific object (by object ID)
sub evaluate_on {
    my ($self, $object_id, $function, %opts) = @_;

    my %params = (
        objectId            => $object_id,
        functionDeclaration => $function,
        returnByValue       => $opts{return_by_value} // \1,
        userGesture         => $opts{user_gesture} ? \1 : \0,
    );

    # Pass arguments if provided
    if ($opts{arguments}) {
        my @call_args;
        for my $arg (@{$opts{arguments}}) {
            if (ref $arg eq 'HASH' && $arg->{objectId}) {
                push @call_args, { objectId => $arg->{objectId} };
            }
            else {
                push @call_args, { value => $arg };
            }
        }
        $params{arguments} = \@call_args;
    }

    if ($opts{await_promise}) {
        $params{awaitPromise} = \1;
    }

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', \%params);

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error() // "Evaluate on object failed";
        return undef;
    }

    # Check for exceptions
    if ($result->{exceptionDetails}) {
        my $exception = $result->{exceptionDetails};
        my $text = $exception->{text} // 'Unknown error';
        if ($exception->{exception} && $exception->{exception}{description}) {
            $text = $exception->{exception}{description};
        }
        $self->{error} = "JavaScript error: $text";
        return undef;
    }

    if ($result->{result}) {
        if ($opts{return_by_value} // 1) {
            return $result->{result}{value};
        }
        else {
            return $result->{result};
        }
    }

    return undef;
}

# Send raw CDP command
sub cdp_send {
    my ($self, $method, $params) = @_;
    $params //= {};

    my $result = $self->{chrome}->send($method, $params);

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error() // "CDP command failed: $method";
    }

    return $result;
}

# Subscribe to CDP events
sub cdp_subscribe {
    my ($self, $event, $callback) = @_;

    # Store callback
    $self->{subscribers}{$event} //= [];
    push @{$self->{subscribers}{$event}}, $callback;

    # Enable the domain if needed
    my ($domain) = $event =~ /^([^.]+)\./;
    if ($domain) {
        $self->{chrome}->enable($domain);
    }

    # Register with the protocol's event handler
    $self->{chrome}->on($event, sub {
        my ($params) = @_;
        for my $cb (@{$self->{subscribers}{$event} // []}) {
            eval { $cb->($params); };
            if ($@) {
                warn "Event callback error: $@";
            }
        }
    });

    return 1;
}

# Unsubscribe from CDP events
sub cdp_unsubscribe {
    my ($self, $event) = @_;

    delete $self->{subscribers}{$event};
    return 1;
}

# Wait for a specific event
sub cdp_wait_for {
    my ($self, $event, $timeout) = @_;
    $timeout //= 10;

    return $self->{chrome}->wait_for_event($event, $timeout);
}

# Add script to evaluate on new documents
sub add_script_on_new_document {
    my ($self, $source) = @_;

    my $result = $self->{chrome}->send('Page.addScriptToEvaluateOnNewDocument', {
        source => $source,
    });

    unless ($result && $result->{identifier}) {
        $self->{error} = $self->{chrome}->error() // "Failed to add script";
        return undef;
    }

    return $result->{identifier};
}

# Remove previously added script
sub remove_script_on_new_document {
    my ($self, $identifier) = @_;

    my $result = $self->{chrome}->send('Page.removeScriptToEvaluateOnNewDocument', {
        identifier => $identifier,
    });

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error() // "Failed to remove script";
        return 0;
    }

    return 1;
}

# Execute a function in page context and return a remote object
sub create_remote_object {
    my ($self, $expression) = @_;

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression    => $expression,
        returnByValue => \0,
    });

    unless ($result && $result->{result} && $result->{result}{objectId}) {
        $self->{error} = $self->{chrome}->error() // "Failed to create remote object";
        return undef;
    }

    return {
        objectId    => $result->{result}{objectId},
        type        => $result->{result}{type},
        subtype     => $result->{result}{subtype},
        className   => $result->{result}{className},
        description => $result->{result}{description},
    };
}

# Get properties of a remote object
sub get_properties {
    my ($self, $object_id, %opts) = @_;

    my %params = (
        objectId => $object_id,
    );

    $params{ownProperties} = \1 if $opts{own_only};
    $params{accessorPropertiesOnly} = \1 if $opts{accessors_only};

    my $result = $self->{chrome}->send('Runtime.getProperties', \%params);

    unless ($result && $result->{result}) {
        $self->{error} = $self->{chrome}->error() // "Failed to get properties";
        return ();
    }

    my @props;
    for my $prop (@{$result->{result}}) {
        push @props, {
            name      => $prop->{name},
            value     => $prop->{value}{value},
            type      => $prop->{value}{type},
            writable  => $prop->{writable},
            enumerable => $prop->{enumerable},
        };
    }

    return @props;
}

# Release a remote object
sub release_object {
    my ($self, $object_id) = @_;

    $self->{chrome}->send('Runtime.releaseObject', {
        objectId => $object_id,
    });

    return 1;
}

# Execute script in isolated world (sandboxed context)
sub evaluate_in_isolated_world {
    my ($self, $frame_id, $source, %opts) = @_;

    my $world_name = $opts{world_name} // '__chrome_driver_isolated__';

    my $result = $self->{chrome}->send('Page.createIsolatedWorld', {
        frameId   => $frame_id,
        worldName => $world_name,
    });

    unless ($result && $result->{executionContextId}) {
        $self->{error} = $self->{chrome}->error() // "Failed to create isolated world";
        return undef;
    }

    my $context_id = $result->{executionContextId};

    # Execute in the isolated context
    $result = $self->{chrome}->send('Runtime.evaluate', {
        expression       => $source,
        contextId        => $context_id,
        returnByValue    => $opts{return_by_value} // \1,
    });

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error() // "Isolated evaluation failed";
        return undef;
    }

    if ($result->{exceptionDetails}) {
        my $text = $result->{exceptionDetails}{text} // 'Unknown error';
        $self->{error} = "JavaScript error: $text";
        return undef;
    }

    if ($result->{result}) {
        return $opts{return_by_value} // 1 ? $result->{result}{value} : $result->{result};
    }

    return undef;
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

1;

__END__

=head1 NAME

JS::Execute - JavaScript execution for chrome-driver

=head1 SYNOPSIS

    use JS::Execute;

    my $js = JS::Execute->new(chrome => $chrome);

    # Simple evaluation
    my $result = $js->evaluate('1 + 2');          # 3
    my $title = $js->evaluate('document.title');

    # Complex expressions
    my $data = $js->evaluate('JSON.parse(\'{"a":1}\')');

    # Async evaluation (for promises)
    my $response = $js->evaluate_async(
        'fetch("/api/data").then(r => r.json())'
    );

    # Evaluate on a specific element
    my $text = $js->evaluate_on(
        $element->{object_id},
        'function() { return this.textContent; }'
    );

    # Raw CDP access
    my $result = $js->cdp_send('DOM.getDocument');

    # Subscribe to events
    $js->cdp_subscribe('Network.requestWillBeSent', sub {
        my ($params) = @_;
        print "Request: $params->{request}{url}\n";
    });

=head1 DESCRIPTION

JS::Execute provides JavaScript execution capabilities for the chrome-driver
plugin. It wraps Chrome's Runtime domain for convenient JS evaluation and
provides raw CDP access for advanced use cases.

=head1 METHODS

=head2 new(%options)

Create a new JS::Execute instance.

Options:
  - chrome: ChromeDriver instance (required)

=head2 evaluate($expression, %options)

Evaluate a JavaScript expression and return the result.

Options:
  - return_by_value: Return actual value (default: true)
  - user_gesture: Execute with user gesture context
  - include_command_line_api: Allow console API ($0, $_, etc.)

=head2 evaluate_async($expression, %options)

Evaluate a JavaScript expression that returns a Promise.
Waits for the promise to resolve before returning.

Options:
  - timeout: Maximum wait time in ms (default: 30000)
  - Plus all evaluate() options

=head2 evaluate_on($object_id, $function, %options)

Evaluate a function on a specific remote object.

Options:
  - arguments: Array of arguments to pass
  - await_promise: Wait for promise resolution
  - Plus return_by_value, user_gesture

=head2 cdp_send($method, $params)

Send a raw CDP command and return the result.

=head2 cdp_subscribe($event, $callback)

Subscribe to a CDP event. Callback receives event params.

=head2 cdp_unsubscribe($event)

Unsubscribe from a CDP event.

=head2 cdp_wait_for($event, $timeout)

Wait for a specific CDP event to occur.

=head2 add_script_on_new_document($source)

Add a script to execute on every new document.
Returns an identifier for later removal.

=head2 remove_script_on_new_document($identifier)

Remove a previously added script.

=head2 create_remote_object($expression)

Create a remote object reference from an expression.
Returns object info including objectId for use with evaluate_on().

=head2 get_properties($object_id, %options)

Get properties of a remote object.

Options:
  - own_only: Only own properties
  - accessors_only: Only accessor properties

=head2 release_object($object_id)

Release a remote object (free memory).

=head2 evaluate_in_isolated_world($frame_id, $source, %options)

Execute script in an isolated context, sandboxed from the page.

=head2 error()

Get the last error message.

=head1 AUTHOR

Generated for chrome-driver plugin

=cut
