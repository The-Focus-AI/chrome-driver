package DOM::Elements;
use strict;
use warnings;

# DOM Interaction module for chrome-driver
# Element queries and high-level actions

sub new {
    my ($class, %opts) = @_;

    my $chrome = $opts{chrome} or die "chrome parameter required";

    return bless {
        chrome  => $chrome,
        error   => undef,
    }, $class;
}

# Query for a single element by CSS selector
sub query {
    my ($self, $selector) = @_;

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression => qq{document.querySelector('$selector')},
        returnByValue => \0,
    });

    unless (defined $result && $result->{result}) {
        $self->{error} = $self->{chrome}->error() // "Query failed";
        return undef;
    }

    if ($result->{result}{subtype} && $result->{result}{subtype} eq 'null') {
        $self->{error} = "Element not found: $selector";
        return undef;
    }

    my $object_id = $result->{result}{objectId};
    unless ($object_id) {
        $self->{error} = "No object ID returned for element";
        return undef;
    }

    return {
        selector  => $selector,
        object_id => $object_id,
    };
}

# Query for all elements matching CSS selector
sub query_all {
    my ($self, $selector) = @_;

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression => qq{Array.from(document.querySelectorAll('$selector'))},
        returnByValue => \0,
    });

    unless (defined $result && $result->{result}) {
        $self->{error} = $self->{chrome}->error() // "Query failed";
        return ();
    }

    my $object_id = $result->{result}{objectId};
    unless ($object_id) {
        return ();
    }

    # Get array properties
    my $props = $self->{chrome}->send('Runtime.getProperties', {
        objectId => $object_id,
        ownProperties => \1,
    });

    my @elements;
    if ($props && $props->{result}) {
        for my $prop (@{$props->{result}}) {
            next unless $prop->{name} =~ /^\d+$/;  # Array indices
            next unless $prop->{value} && $prop->{value}{objectId};

            push @elements, {
                selector  => $selector,
                index     => $prop->{name},
                object_id => $prop->{value}{objectId},
            };
        }
    }

    return @elements;
}

# Click on an element
sub click {
    my ($self, $element_or_selector) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return 0 unless $element;

    # Scroll into view first
    $self->scroll_to($element);

    # Get element center coordinates
    my $box = $self->_get_box($element);
    unless ($box) {
        $self->{error} //= "Could not get element bounding box";
        return 0;
    }

    my $x = $box->{x} + ($box->{width} / 2);
    my $y = $box->{y} + ($box->{height} / 2);

    # Dispatch mouse events
    $self->_mouse_click($x, $y);

    return 1;
}

# Type text into an element
sub type {
    my ($self, $element_or_selector, $text, %opts) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return 0 unless $element;

    # Focus the element first
    $self->focus($element);

    # Clear existing content if requested
    if ($opts{clear}) {
        $self->_select_all();
    }

    # Dispatch keyboard events for each character
    for my $char (split //, $text) {
        $self->_type_char($char);
    }

    return 1;
}

# Select an option from dropdown
sub select {
    my ($self, $element_or_selector, $value, %opts) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return 0 unless $element;

    my $object_id = $element->{object_id};

    # Determine selection method
    my $by = $opts{by} // 'value';  # value, text, or index

    my $js;
    if ($by eq 'index') {
        $js = qq{
            (function(el) {
                el.selectedIndex = $value;
                el.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            })(arguments[0])
        };
    }
    elsif ($by eq 'text') {
        my $escaped = $value;
        $escaped =~ s/'/\\'/g;
        $js = qq{
            (function(el) {
                for (var i = 0; i < el.options.length; i++) {
                    if (el.options[i].text === '$escaped') {
                        el.selectedIndex = i;
                        el.dispatchEvent(new Event('change', { bubbles: true }));
                        return true;
                    }
                }
                return false;
            })(arguments[0])
        };
    }
    else {  # by value
        my $escaped = $value;
        $escaped =~ s/'/\\'/g;
        $js = qq{
            (function(el) {
                el.value = '$escaped';
                el.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            })(arguments[0])
        };
    }

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', {
        objectId => $object_id,
        functionDeclaration => $js,
        returnByValue => \1,
    });

    unless ($result && $result->{result}{value}) {
        $self->{error} = "Could not select option: $value";
        return 0;
    }

    return 1;
}

# Hover over an element
sub hover {
    my ($self, $element_or_selector) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return 0 unless $element;

    # Scroll into view first
    $self->scroll_to($element);

    # Get element center coordinates
    my $box = $self->_get_box($element);
    unless ($box) {
        $self->{error} //= "Could not get element bounding box";
        return 0;
    }

    my $x = $box->{x} + ($box->{width} / 2);
    my $y = $box->{y} + ($box->{height} / 2);

    # Move mouse to element
    $self->{chrome}->send('Input.dispatchMouseEvent', {
        type => 'mouseMoved',
        x    => $x,
        y    => $y,
    });

    return 1;
}

# Focus an element
sub focus {
    my ($self, $element_or_selector) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return 0 unless $element;

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', {
        objectId => $element->{object_id},
        functionDeclaration => 'function() { this.focus(); return true; }',
        returnByValue => \1,
    });

    unless ($result && $result->{result}) {
        $self->{error} = $self->{chrome}->error() // "Focus failed";
        return 0;
    }

    return 1;
}

# Scroll element into view
sub scroll_to {
    my ($self, $element_or_selector, %opts) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return 0 unless $element;

    my $behavior = $opts{smooth} ? 'smooth' : 'instant';
    my $block = $opts{block} // 'center';
    my $inline = $opts{inline} // 'center';

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', {
        objectId => $element->{object_id},
        functionDeclaration => qq{
            function() {
                this.scrollIntoView({
                    behavior: '$behavior',
                    block: '$block',
                    inline: '$inline'
                });
                return true;
            }
        },
        returnByValue => \1,
    });

    unless ($result && $result->{result}) {
        $self->{error} = $self->{chrome}->error() // "Scroll failed";
        return 0;
    }

    # Small delay to let scroll complete
    CORE::select(undef, undef, undef, 0.1);

    return 1;
}

# Get element text content
sub get_text {
    my ($self, $element_or_selector) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return undef unless $element;

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', {
        objectId => $element->{object_id},
        functionDeclaration => 'function() { return this.textContent; }',
        returnByValue => \1,
    });

    unless ($result && $result->{result}) {
        $self->{error} = $self->{chrome}->error() // "Get text failed";
        return undef;
    }

    return $result->{result}{value};
}

# Get element attribute
sub get_attribute {
    my ($self, $element_or_selector, $attr) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return undef unless $element;

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', {
        objectId => $element->{object_id},
        functionDeclaration => qq{function() { return this.getAttribute('$attr'); }},
        returnByValue => \1,
    });

    unless ($result && $result->{result}) {
        $self->{error} = $self->{chrome}->error() // "Get attribute failed";
        return undef;
    }

    return $result->{result}{value};
}

# Get element property (JS property, not HTML attribute)
sub get_property {
    my ($self, $element_or_selector, $prop) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return undef unless $element;

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', {
        objectId => $element->{object_id},
        functionDeclaration => qq{function() { return this['$prop']; }},
        returnByValue => \1,
    });

    unless ($result && $result->{result}) {
        $self->{error} = $self->{chrome}->error() // "Get property failed";
        return undef;
    }

    return $result->{result}{value};
}

# Set input value
sub set_value {
    my ($self, $element_or_selector, $value) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return 0 unless $element;

    my $escaped = $value;
    $escaped =~ s/\\/\\\\/g;
    $escaped =~ s/'/\\'/g;

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', {
        objectId => $element->{object_id},
        functionDeclaration => qq{
            function() {
                this.value = '$escaped';
                this.dispatchEvent(new Event('input', { bubbles: true }));
                this.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            }
        },
        returnByValue => \1,
    });

    unless ($result && $result->{result}) {
        $self->{error} = $self->{chrome}->error() // "Set value failed";
        return 0;
    }

    return 1;
}

# Check if element exists
sub exists {
    my ($self, $selector) = @_;

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression => qq{document.querySelector('$selector') !== null},
        returnByValue => \1,
    });

    return $result && $result->{result}{value} ? 1 : 0;
}

# Wait for element to appear
sub wait_for {
    my ($self, $selector, $timeout) = @_;
    $timeout //= 10;

    my $end_time = time() + $timeout;

    while (time() < $end_time) {
        if ($self->exists($selector)) {
            return $self->query($selector);
        }
        CORE::select(undef, undef, undef, 0.1);
    }

    $self->{error} = "Timeout waiting for element: $selector";
    return undef;
}

# Get element bounding box
sub get_box {
    my ($self, $element_or_selector) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return undef unless $element;

    return $self->_get_box($element);
}

# Check if element is visible
sub is_visible {
    my ($self, $element_or_selector) = @_;

    my $element = $self->_resolve_element($element_or_selector);
    return 0 unless $element;

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', {
        objectId => $element->{object_id},
        functionDeclaration => q{
            function() {
                var style = window.getComputedStyle(this);
                if (style.display === 'none') return false;
                if (style.visibility !== 'visible') return false;
                if (parseFloat(style.opacity) === 0) return false;
                var rect = this.getBoundingClientRect();
                if (rect.width === 0 || rect.height === 0) return false;
                return true;
            }
        },
        returnByValue => \1,
    });

    return $result && $result->{result}{value} ? 1 : 0;
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

# --- Private helper methods ---

sub _resolve_element {
    my ($self, $element_or_selector) = @_;

    if (ref $element_or_selector eq 'HASH' && $element_or_selector->{object_id}) {
        return $element_or_selector;
    }

    return $self->query($element_or_selector);
}

sub _get_box {
    my ($self, $element) = @_;

    my $result = $self->{chrome}->send('Runtime.callFunctionOn', {
        objectId => $element->{object_id},
        functionDeclaration => q{
            function() {
                var rect = this.getBoundingClientRect();
                return {
                    x: rect.x,
                    y: rect.y,
                    width: rect.width,
                    height: rect.height,
                    top: rect.top,
                    right: rect.right,
                    bottom: rect.bottom,
                    left: rect.left
                };
            }
        },
        returnByValue => \1,
    });

    unless ($result && $result->{result}{value}) {
        $self->{error} = $self->{chrome}->error() // "Could not get bounding box";
        return undef;
    }

    return $result->{result}{value};
}

sub _mouse_click {
    my ($self, $x, $y) = @_;

    # Mouse down
    $self->{chrome}->send('Input.dispatchMouseEvent', {
        type       => 'mousePressed',
        x          => $x,
        y          => $y,
        button     => 'left',
        clickCount => 1,
    });

    # Mouse up
    $self->{chrome}->send('Input.dispatchMouseEvent', {
        type       => 'mouseReleased',
        x          => $x,
        y          => $y,
        button     => 'left',
        clickCount => 1,
    });
}

sub _type_char {
    my ($self, $char) = @_;

    # Send keyDown, char, keyUp events
    $self->{chrome}->send('Input.dispatchKeyEvent', {
        type => 'keyDown',
        text => $char,
    });

    $self->{chrome}->send('Input.dispatchKeyEvent', {
        type => 'keyUp',
        text => $char,
    });
}

sub _select_all {
    my ($self) = @_;

    # Ctrl+A / Cmd+A to select all
    $self->{chrome}->send('Input.dispatchKeyEvent', {
        type => 'keyDown',
        key  => 'a',
        modifiers => 2,  # Ctrl
    });

    $self->{chrome}->send('Input.dispatchKeyEvent', {
        type => 'keyUp',
        key  => 'a',
        modifiers => 2,
    });
}

1;

__END__

=head1 NAME

DOM::Elements - DOM interaction for chrome-driver

=head1 SYNOPSIS

    use DOM::Elements;

    my $dom = DOM::Elements->new(chrome => $chrome);

    # Query elements
    my $element = $dom->query('input[name="email"]');
    my @links = $dom->query_all('a.nav-link');

    # Actions
    $dom->click('button.submit');
    $dom->type('input[name="email"]', 'user@example.com');
    $dom->select('select#country', 'US');
    $dom->hover('.dropdown-trigger');
    $dom->focus('input[name="password"]');
    $dom->scroll_to('#section-5');

    # Get element info
    my $text = $dom->get_text('h1');
    my $href = $dom->get_attribute('a', 'href');
    my $value = $dom->get_property('input', 'value');
    my $box = $dom->get_box('img.hero');

    # Set values
    $dom->set_value('input[name="email"]', 'new@example.com');

    # Element state
    if ($dom->exists('.error-message')) { ... }
    if ($dom->is_visible('.modal')) { ... }
    my $el = $dom->wait_for('.loading-complete', 10);

=head1 DESCRIPTION

DOM::Elements provides high-level DOM interaction for the chrome-driver plugin.
It supports element queries, mouse/keyboard actions, and element inspection.

=head1 METHODS

=head2 new(%options)

Create a new DOM::Elements instance.

Options:
  - chrome: ChromeDriver instance (required)

=head2 query($selector)

Find a single element by CSS selector. Returns element hash or undef.

=head2 query_all($selector)

Find all elements matching CSS selector. Returns list of element hashes.

=head2 click($element_or_selector)

Click on an element. Scrolls into view first.

=head2 type($element_or_selector, $text, %options)

Type text into an element.

Options:
  - clear: Clear existing content first (default: false)

=head2 select($element_or_selector, $value, %options)

Select an option from a dropdown.

Options:
  - by: Selection method - 'value', 'text', or 'index' (default: 'value')

=head2 hover($element_or_selector)

Hover over an element.

=head2 focus($element_or_selector)

Focus an element.

=head2 scroll_to($element_or_selector, %options)

Scroll element into view.

Options:
  - smooth: Use smooth scrolling (default: false)
  - block: Vertical alignment - 'start', 'center', 'end', 'nearest' (default: 'center')
  - inline: Horizontal alignment (default: 'center')

=head2 get_text($element_or_selector)

Get text content of an element.

=head2 get_attribute($element_or_selector, $attr)

Get HTML attribute value.

=head2 get_property($element_or_selector, $prop)

Get JavaScript property value.

=head2 set_value($element_or_selector, $value)

Set input value and dispatch input/change events.

=head2 exists($selector)

Check if element exists. Returns true/false.

=head2 wait_for($selector, $timeout)

Wait for element to appear. Returns element or undef on timeout.

=head2 get_box($element_or_selector)

Get element bounding box (x, y, width, height, top, right, bottom, left).

=head2 is_visible($element_or_selector)

Check if element is visible (not display:none, visibility:hidden, or opacity:0).

=head2 error()

Get the last error message.

=head1 AUTHOR

Generated for chrome-driver plugin

=cut
