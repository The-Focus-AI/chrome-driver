package Page::Navigation;
use strict;
use warnings;

# Navigation module for chrome-driver
# Handles URL navigation, history, and page load waiting

sub new {
    my ($class, %opts) = @_;

    my $chrome = $opts{chrome} or die "chrome parameter required";

    return bless {
        chrome   => $chrome,
        timeout  => $opts{timeout} // 30,
        error    => undef,
    }, $class;
}

# Navigate to a URL and wait for load
sub navigate {
    my ($self, $url, %opts) = @_;

    my $timeout = $opts{timeout} // $self->{timeout};
    my $wait_until = $opts{wait_until} // 'load';  # 'load', 'domcontentloaded', 'none'

    # Enable Page domain if not already
    $self->{chrome}->enable('Page');

    # Start navigation
    my $result = $self->{chrome}->send('Page.navigate', { url => $url });
    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return 0;
    }

    # Check for navigation error
    if ($result->{errorText}) {
        $self->{error} = "Navigation error: $result->{errorText}";
        return 0;
    }

    # Wait for appropriate event
    if ($wait_until eq 'none') {
        return 1;
    }
    elsif ($wait_until eq 'domcontentloaded') {
        return $self->wait_for_navigation(
            timeout => $timeout,
            wait_until => 'domcontentloaded'
        );
    }
    else {
        # Default: wait for load event
        return $self->wait_for_navigation(timeout => $timeout);
    }
}

# Reload the current page
sub reload {
    my ($self, %opts) = @_;

    my $ignore_cache = $opts{ignore_cache} // 0;
    my $timeout = $opts{timeout} // $self->{timeout};

    $self->{chrome}->enable('Page');

    my $result = $self->{chrome}->send('Page.reload', {
        ignoreCache => $ignore_cache ? \1 : \0,
    });

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return 0;
    }

    # Wait for load
    return $self->wait_for_navigation(timeout => $timeout);
}

# Navigate back in history
sub back {
    my ($self, %opts) = @_;

    my $timeout = $opts{timeout} // $self->{timeout};

    # Get current URL before navigation
    my $old_url = $self->current_url();

    # Navigate back using JavaScript
    $self->{chrome}->send('Runtime.evaluate', {
        expression => 'window.history.back()',
    });

    # Wait for URL to change (bfcache may not fire load events)
    return $self->_wait_for_url_change($old_url, $timeout);
}

# Navigate forward in history
sub forward {
    my ($self, %opts) = @_;

    my $timeout = $opts{timeout} // $self->{timeout};

    # Get current URL before navigation
    my $old_url = $self->current_url();

    # Navigate forward using JavaScript
    $self->{chrome}->send('Runtime.evaluate', {
        expression => 'window.history.forward()',
    });

    # Wait for URL to change (bfcache may not fire load events)
    return $self->_wait_for_url_change($old_url, $timeout);
}

# Helper: Wait for URL to change from the given URL
sub _wait_for_url_change {
    my ($self, $old_url, $timeout) = @_;

    my $end_time = time() + $timeout;

    # Small delay to let the navigation start (bfcache transitions may
    # temporarily make Runtime.evaluate unavailable)
    select(undef, undef, undef, 0.2);

    while (time() < $end_time) {
        my $new_url = $self->current_url();

        # If current_url returns undef, it might be mid-transition
        # Keep polling rather than treating as failure
        if (defined $new_url && $new_url ne $old_url) {
            return 1;
        }

        select(undef, undef, undef, 0.1);
    }

    $self->{error} = "Timeout waiting for URL change";
    return 0;
}

# Get current URL
sub current_url {
    my ($self) = @_;

    # Use Runtime.evaluate to get window.location.href
    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression => 'window.location.href',
        returnByValue => \1,
    });

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return undef;
    }

    if ($result->{exceptionDetails}) {
        $self->{error} = "JavaScript error: " .
            ($result->{exceptionDetails}{text} // 'unknown');
        return undef;
    }

    return $result->{result}{value};
}

# Wait for navigation to complete
sub wait_for_navigation {
    my ($self, %opts) = @_;

    my $timeout = $opts{timeout} // $self->{timeout};
    my $wait_until = $opts{wait_until} // 'load';  # 'load' or 'domcontentloaded'

    my $event = $wait_until eq 'domcontentloaded'
        ? 'Page.domContentEventFired'
        : 'Page.loadEventFired';

    my $result = $self->{chrome}->wait_for_event($event, $timeout);

    unless (defined $result) {
        $self->{error} = "Navigation timeout after ${timeout}s";
        return 0;
    }

    return 1;
}

# Wait for a selector to appear in the page
sub wait_for_selector {
    my ($self, $selector, %opts) = @_;

    my $timeout = $opts{timeout} // $self->{timeout};
    my $visible = $opts{visible} // 0;  # Wait for element to be visible
    my $hidden = $opts{hidden} // 0;    # Wait for element to disappear

    my $end_time = time() + $timeout;

    while (time() < $end_time) {
        my $js;

        if ($hidden) {
            # Check if element is NOT present or NOT visible
            $js = qq{
                (function() {
                    var el = document.querySelector('$selector');
                    if (!el) return true;
                    var style = window.getComputedStyle(el);
                    return style.display === 'none' || style.visibility === 'hidden';
                })()
            };
        }
        elsif ($visible) {
            # Check if element is present AND visible
            $js = qq{
                (function() {
                    var el = document.querySelector('$selector');
                    if (!el) return false;
                    var style = window.getComputedStyle(el);
                    return style.display !== 'none' && style.visibility !== 'hidden';
                })()
            };
        }
        else {
            # Just check if element exists
            $js = qq{ document.querySelector('$selector') !== null };
        }

        my $result = $self->{chrome}->send('Runtime.evaluate', {
            expression => $js,
            returnByValue => \1,
        });

        if (defined $result && $result->{result}{value}) {
            return 1;
        }

        # Poll every 100ms
        select(undef, undef, undef, 0.1);
    }

    $self->{error} = "Timeout waiting for selector: $selector";
    return 0;
}

# Wait for a JavaScript function to return truthy
sub wait_for_function {
    my ($self, $js_function, %opts) = @_;

    my $timeout = $opts{timeout} // $self->{timeout};
    my $polling = $opts{polling} // 0.1;  # Poll interval in seconds

    my $end_time = time() + $timeout;

    while (time() < $end_time) {
        my $result = $self->{chrome}->send('Runtime.evaluate', {
            expression => "($js_function)()",
            returnByValue => \1,
        });

        if (defined $result && !$result->{exceptionDetails}) {
            my $value = $result->{result}{value};
            if ($value) {
                return $value;
            }
        }

        select(undef, undef, undef, $polling);
    }

    $self->{error} = "Timeout waiting for function to return truthy";
    return undef;
}

# Wait for network to be idle (no requests for a period)
sub wait_for_network_idle {
    my ($self, %opts) = @_;

    my $timeout = $opts{timeout} // $self->{timeout};
    my $idle_time = $opts{idle_time} // 0.5;  # Time with no requests
    my $max_connections = $opts{max_connections} // 0;

    # Enable Network domain
    $self->{chrome}->enable('Network');

    my $active_requests = {};
    my $last_activity = time();

    # Subscribe to network events
    my $request_id = $self->{chrome}->on('Network.requestWillBeSent', sub {
        my ($params) = @_;
        $active_requests->{$params->{requestId}} = 1;
        $last_activity = time();
    });

    my $response_id = $self->{chrome}->on('Network.loadingFinished', sub {
        my ($params) = @_;
        delete $active_requests->{$params->{requestId}};
        $last_activity = time();
    });

    my $failed_id = $self->{chrome}->on('Network.loadingFailed', sub {
        my ($params) = @_;
        delete $active_requests->{$params->{requestId}};
        $last_activity = time();
    });

    my $end_time = time() + $timeout;
    my $success = 0;

    while (time() < $end_time) {
        $self->{chrome}->poll(0.1);

        my $num_active = scalar keys %$active_requests;
        if ($num_active <= $max_connections &&
            (time() - $last_activity) >= $idle_time) {
            $success = 1;
            last;
        }
    }

    # Unsubscribe from events
    $self->{chrome}->off('Network.requestWillBeSent', $request_id);
    $self->{chrome}->off('Network.loadingFinished', $response_id);
    $self->{chrome}->off('Network.loadingFailed', $failed_id);

    unless ($success) {
        $self->{error} = "Timeout waiting for network idle";
        return 0;
    }

    return 1;
}

# Get navigation history
sub history {
    my ($self) = @_;

    my $result = $self->{chrome}->send('Page.getNavigationHistory');
    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return undef;
    }

    return {
        current_index => $result->{currentIndex},
        entries => [ map {
            {
                id => $_->{id},
                url => $_->{url},
                title => $_->{title},
            }
        } @{$result->{entries} // []} ],
    };
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

1;

__END__

=head1 NAME

Page::Navigation - URL navigation and page loading for chrome-driver

=head1 SYNOPSIS

    use Page::Navigation;

    my $nav = Page::Navigation->new(chrome => $chrome);

    # Navigate to URL
    $nav->navigate('https://example.com') or die $nav->error;

    # Wait for specific element
    $nav->wait_for_selector('#content') or die $nav->error;

    # Get current URL
    my $url = $nav->current_url();

    # History navigation
    $nav->back();
    $nav->forward();
    $nav->reload();

=head1 DESCRIPTION

Page::Navigation provides URL navigation, history management, and page load
waiting functionality for the chrome-driver plugin.

=head1 METHODS

=head2 new(%options)

Create a new Navigation instance.

Options:
  - chrome: ChromeDriver instance (required)
  - timeout: Default timeout in seconds (default: 30)

=head2 navigate($url, %options)

Navigate to the specified URL and wait for load.

Options:
  - timeout: Override default timeout
  - wait_until: 'load' (default), 'domcontentloaded', or 'none'

Returns 1 on success, 0 on failure.

=head2 reload(%options)

Reload the current page.

Options:
  - ignore_cache: Bypass cache if true
  - timeout: Override default timeout

=head2 back(%options)

Navigate back in browser history.

=head2 forward(%options)

Navigate forward in browser history.

=head2 current_url()

Returns the current page URL, or undef on error.

=head2 wait_for_navigation(%options)

Wait for navigation to complete.

Options:
  - timeout: Maximum wait time
  - wait_until: 'load' (default) or 'domcontentloaded'

=head2 wait_for_selector($selector, %options)

Wait for a CSS selector to match an element.

Options:
  - timeout: Maximum wait time
  - visible: Wait for element to be visible
  - hidden: Wait for element to disappear

=head2 wait_for_function($js_function, %options)

Wait for a JavaScript function to return truthy value.

Options:
  - timeout: Maximum wait time
  - polling: Poll interval in seconds (default: 0.1)

=head2 wait_for_network_idle(%options)

Wait for network activity to stop.

Options:
  - timeout: Maximum wait time
  - idle_time: Time with no activity to consider idle (default: 0.5s)
  - max_connections: Allow up to N concurrent connections (default: 0)

=head2 history()

Returns navigation history as a hash with:
  - current_index: Index of current page
  - entries: Array of {id, url, title}

=head2 error()

Returns the last error message.

=head1 AUTHOR

Generated for chrome-driver plugin

=cut
