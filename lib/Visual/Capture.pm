package Visual::Capture;
use strict;
use warnings;
use MIME::Base64 ();

# Visual Capture module for chrome-driver
# Screenshots and screencast frame capture

sub new {
    my ($class, %opts) = @_;

    my $chrome = $opts{chrome} or die "chrome parameter required";

    return bless {
        chrome  => $chrome,
        error   => undef,
    }, $class;
}

# Take a screenshot of the page
sub screenshot {
    my ($self, %opts) = @_;

    my $format = $opts{format} // 'png';       # png, jpeg, webp
    my $quality = $opts{quality} // 80;        # 0-100 for jpeg/webp
    my $full_page = $opts{full_page} // 0;     # Capture full scrollable page
    my $selector = $opts{selector};            # Capture specific element
    my $clip = $opts{clip};                    # { x, y, width, height, scale }
    my $file = $opts{file};                    # Save to file path

    # Validate format
    unless ($format =~ /^(png|jpeg|webp)$/) {
        $self->{error} = "Invalid format: $format (use png, jpeg, or webp)";
        return undef;
    }

    my %params = (
        format => $format,
    );

    # Quality only applies to jpeg and webp
    if ($format ne 'png') {
        $params{quality} = $quality;
    }

    # Handle full page capture
    if ($full_page) {
        $params{captureBeyondViewport} = \1;

        # Get the full page dimensions
        my $metrics = $self->_get_page_metrics();
        if ($metrics) {
            $params{clip} = {
                x      => 0,
                y      => 0,
                width  => $metrics->{contentWidth},
                height => $metrics->{contentHeight},
                scale  => 1,
            };
        }
    }

    # Handle element capture
    if ($selector) {
        my $box = $self->_get_element_box($selector);
        if ($box) {
            $params{clip} = {
                x      => $box->{x},
                y      => $box->{y},
                width  => $box->{width},
                height => $box->{height},
                scale  => 1,
            };
        }
        else {
            return undef;  # Error already set
        }
    }

    # Handle custom clip region
    if ($clip && ref $clip eq 'HASH') {
        $params{clip} = {
            x      => $clip->{x} // 0,
            y      => $clip->{y} // 0,
            width  => $clip->{width} // 800,
            height => $clip->{height} // 600,
            scale  => $clip->{scale} // 1,
        };
    }

    # Take the screenshot
    my $result = $self->{chrome}->send('Page.captureScreenshot', \%params);

    unless (defined $result && $result->{data}) {
        $self->{error} = $self->{chrome}->error() // "Screenshot failed";
        return undef;
    }

    my $data = $result->{data};

    # Save to file if path provided
    if ($file) {
        my $binary = MIME::Base64::decode_base64($data);
        if (open(my $fh, '>', $file)) {
            binmode($fh);
            print $fh $binary;
            close($fh);
            return $file;
        }
        else {
            $self->{error} = "Failed to write file: $!";
            return undef;
        }
    }

    # Return base64 data
    return $data;
}

# Get viewport metrics for full-page screenshots
sub _get_page_metrics {
    my ($self) = @_;

    my $result = $self->{chrome}->send('Page.getLayoutMetrics');
    return undef unless defined $result;

    return {
        contentWidth  => $result->{contentSize}{width},
        contentHeight => $result->{contentSize}{height},
    };
}

# Get bounding box of an element
sub _get_element_box {
    my ($self, $selector) = @_;

    my $js = qq{
        (function() {
            var el = document.querySelector('$selector');
            if (!el) return null;
            var rect = el.getBoundingClientRect();
            return {
                x: rect.x + window.scrollX,
                y: rect.y + window.scrollY,
                width: rect.width,
                height: rect.height
            };
        })()
    };

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression    => $js,
        returnByValue => \1,
    });

    unless (defined $result && $result->{result}{value}) {
        $self->{error} = "Element not found: $selector";
        return undef;
    }

    return $result->{result}{value};
}

# Set viewport size
sub set_viewport {
    my ($self, %opts) = @_;

    my $width = $opts{width} // 1280;
    my $height = $opts{height} // 720;
    my $device_scale_factor = $opts{device_scale_factor} // 1;
    my $mobile = $opts{mobile} // 0;

    my $result = $self->{chrome}->send('Emulation.setDeviceMetricsOverride', {
        width             => $width,
        height            => $height,
        deviceScaleFactor => $device_scale_factor,
        mobile            => $mobile ? \1 : \0,
    });

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return 0;
    }

    return 1;
}

# Clear viewport override
sub clear_viewport {
    my ($self) = @_;

    # This command returns empty result on success
    my $result = $self->{chrome}->send('Emulation.clearDeviceMetricsOverride');

    # Check that we got a response (even if empty)
    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return 0;
    }

    return 1;
}

# Start screencast (video frame capture)
sub start_screencast {
    my ($self, %opts) = @_;

    my $format = $opts{format} // 'jpeg';  # jpeg or png
    my $quality = $opts{quality} // 80;
    my $max_width = $opts{max_width};
    my $max_height = $opts{max_height};
    my $every_nth = $opts{every_nth} // 1;  # Frame interval

    my %params = (
        format       => $format,
        quality      => $quality,
        everyNthFrame => $every_nth,
    );

    $params{maxWidth} = $max_width if defined $max_width;
    $params{maxHeight} = $max_height if defined $max_height;

    my $result = $self->{chrome}->send('Page.startScreencast', \%params);

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return 0;
    }

    return 1;
}

# Stop screencast
sub stop_screencast {
    my ($self) = @_;

    my $result = $self->{chrome}->send('Page.stopScreencast');
    return defined $result;
}

# Acknowledge screencast frame (must call after receiving)
sub ack_screencast_frame {
    my ($self, $session_id) = @_;

    my $result = $self->{chrome}->send('Page.screencastFrameAck', {
        sessionId => $session_id,
    });

    return defined $result;
}

# Subscribe to screencast frames
sub on_screencast_frame {
    my ($self, $callback) = @_;

    return $self->{chrome}->on('Page.screencastFrame', sub {
        my ($params) = @_;

        # Auto-acknowledge frame
        $self->ack_screencast_frame($params->{sessionId});

        # Call user callback with frame data
        $callback->({
            data       => $params->{data},
            metadata   => $params->{metadata},
            session_id => $params->{sessionId},
        });
    });
}

# Capture multiple frames from screencast
sub capture_frames {
    my ($self, %opts) = @_;

    my $count = $opts{count} // 10;
    my $timeout = $opts{timeout} // 10;
    my $format = $opts{format} // 'jpeg';
    my $quality = $opts{quality} // 80;

    my @frames;

    # Start screencast
    unless ($self->start_screencast(format => $format, quality => $quality)) {
        return undef;
    }

    # Collect frames
    my $end_time = time() + $timeout;

    while (@frames < $count && time() < $end_time) {
        # Poll for frames
        $self->{chrome}->poll(0.1);
    }

    # Stop screencast
    $self->stop_screencast();

    return \@frames;
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

1;

__END__

=head1 NAME

Visual::Capture - Screenshots and screencast for chrome-driver

=head1 SYNOPSIS

    use Visual::Capture;

    my $capture = Visual::Capture->new(chrome => $chrome);

    # Take a screenshot
    my $png_data = $capture->screenshot();
    my $jpeg_data = $capture->screenshot(format => 'jpeg', quality => 90);

    # Save to file
    $capture->screenshot(file => '/tmp/page.png');

    # Full page screenshot
    $capture->screenshot(full_page => 1, file => '/tmp/full.png');

    # Element screenshot
    $capture->screenshot(selector => '#header', file => '/tmp/header.png');

    # Set viewport size
    $capture->set_viewport(width => 1920, height => 1080);

    # Mobile viewport
    $capture->set_viewport(width => 375, height => 812, mobile => 1);

=head1 DESCRIPTION

Visual::Capture provides screenshot and screencast functionality for
the chrome-driver plugin.

=head1 METHODS

=head2 new(%options)

Create a new Visual::Capture instance.

Options:
  - chrome: ChromeDriver instance (required)

=head2 screenshot(%options)

Take a screenshot of the page.

Options:
  - format: 'png' (default), 'jpeg', or 'webp'
  - quality: 0-100 for jpeg/webp (default: 80)
  - full_page: Capture entire scrollable page if true
  - selector: CSS selector for specific element
  - clip: { x, y, width, height, scale } for custom region
  - file: Save to file path (returns path on success)

Returns base64-encoded image data, or file path if file option given.

=head2 set_viewport(%options)

Set the viewport size.

Options:
  - width: Viewport width (default: 1280)
  - height: Viewport height (default: 720)
  - device_scale_factor: Device scale factor (default: 1)
  - mobile: Enable mobile mode if true

=head2 clear_viewport()

Clear viewport override.

=head2 start_screencast(%options)

Start capturing screencast frames.

Options:
  - format: 'jpeg' (default) or 'png'
  - quality: 0-100 (default: 80)
  - max_width: Maximum frame width
  - max_height: Maximum frame height
  - every_nth: Capture every Nth frame (default: 1)

=head2 stop_screencast()

Stop screencast frame capture.

=head2 on_screencast_frame($callback)

Subscribe to screencast frame events. Callback receives hash with
data, metadata, and session_id.

=head2 error()

Get the last error message.

=head1 AUTHOR

Generated for chrome-driver plugin

=cut
