package Print::PDF;
use strict;
use warnings;
use MIME::Base64 ();

# PDF Generation module for chrome-driver
# Print pages to PDF with full option control

# Paper size presets (width x height in inches)
my %PAPER_SIZES = (
    letter => { width => 8.5,  height => 11 },
    legal  => { width => 8.5,  height => 14 },
    a4     => { width => 8.27, height => 11.69 },
    a3     => { width => 11.69, height => 16.54 },
    a5     => { width => 5.83, height => 8.27 },
    tabloid => { width => 11, height => 17 },
);

sub new {
    my ($class, %opts) = @_;

    my $chrome = $opts{chrome} or die "chrome parameter required";

    return bless {
        chrome  => $chrome,
        error   => undef,
    }, $class;
}

# Generate PDF from the current page
sub pdf {
    my ($self, %opts) = @_;

    # Paper size
    my $paper_size = $opts{paper_size} // 'letter';
    my ($paper_width, $paper_height);

    if (ref $paper_size eq 'HASH') {
        $paper_width  = $paper_size->{width};
        $paper_height = $paper_size->{height};
    }
    elsif (exists $PAPER_SIZES{lc $paper_size}) {
        $paper_width  = $PAPER_SIZES{lc $paper_size}{width};
        $paper_height = $PAPER_SIZES{lc $paper_size}{height};
    }
    else {
        $self->{error} = "Unknown paper size: $paper_size";
        return undef;
    }

    # Orientation
    my $landscape = $opts{landscape} // 0;
    if ($landscape) {
        ($paper_width, $paper_height) = ($paper_height, $paper_width);
    }

    # Margins (in inches, default 0.4)
    my $margin_top    = $opts{margin_top}    // $opts{margin} // 0.4;
    my $margin_bottom = $opts{margin_bottom} // $opts{margin} // 0.4;
    my $margin_left   = $opts{margin_left}   // $opts{margin} // 0.4;
    my $margin_right  = $opts{margin_right}  // $opts{margin} // 0.4;

    # Build parameters
    my %params = (
        landscape           => $landscape ? \1 : \0,
        printBackground     => ($opts{print_background} // 1) ? \1 : \0,
        paperWidth          => $paper_width,
        paperHeight         => $paper_height,
        marginTop           => $margin_top,
        marginBottom        => $margin_bottom,
        marginLeft          => $margin_left,
        marginRight         => $margin_right,
        preferCSSPageSize   => ($opts{prefer_css_page_size} // 0) ? \1 : \0,
    );

    # Scale (0.1 to 2.0)
    if (defined $opts{scale}) {
        my $scale = $opts{scale};
        $scale = 0.1 if $scale < 0.1;
        $scale = 2.0 if $scale > 2.0;
        $params{scale} = $scale;
    }

    # Page ranges (e.g., "1-5, 8, 11-13")
    if (defined $opts{page_ranges}) {
        $params{pageRanges} = $opts{page_ranges};
    }

    # Header template
    if (defined $opts{header_template}) {
        $params{displayHeaderFooter} = \1;
        $params{headerTemplate} = $opts{header_template};
    }

    # Footer template
    if (defined $opts{footer_template}) {
        $params{displayHeaderFooter} = \1;
        $params{footerTemplate} = $opts{footer_template};
    }

    # Generate media type (screen or print)
    if (defined $opts{emulate_media}) {
        $self->{chrome}->send('Emulation.setEmulatedMedia', {
            media => $opts{emulate_media},
        });
    }

    # Generate PDF
    my $result = $self->{chrome}->send('Page.printToPDF', \%params);

    unless (defined $result && $result->{data}) {
        $self->{error} = $self->{chrome}->error() // "PDF generation failed";
        return undef;
    }

    my $data = $result->{data};

    # Save to file if path provided
    my $file = $opts{file};
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

# Convenience method for letter size PDF
sub letter {
    my ($self, %opts) = @_;
    return $self->pdf(%opts, paper_size => 'letter');
}

# Convenience method for A4 size PDF
sub a4 {
    my ($self, %opts) = @_;
    return $self->pdf(%opts, paper_size => 'a4');
}

# Convenience method for landscape PDF
sub landscape {
    my ($self, %opts) = @_;
    return $self->pdf(%opts, landscape => 1);
}

# Get available paper sizes
sub paper_sizes {
    return keys %PAPER_SIZES;
}

# Create PDF with custom header/footer
sub with_header_footer {
    my ($self, %opts) = @_;

    # Default header with page title and date
    my $header = $opts{header_template} // <<'HTML';
<div style="font-size: 10px; width: 100%; text-align: center;">
    <span class="title"></span>
</div>
HTML

    # Default footer with page number
    my $footer = $opts{footer_template} // <<'HTML';
<div style="font-size: 10px; width: 100%; text-align: center;">
    Page <span class="pageNumber"></span> of <span class="totalPages"></span>
</div>
HTML

    return $self->pdf(
        %opts,
        header_template => $header,
        footer_template => $footer,
    );
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

1;

__END__

=head1 NAME

Print::PDF - PDF generation for chrome-driver

=head1 SYNOPSIS

    use Print::PDF;

    my $pdf = Print::PDF->new(chrome => $chrome);

    # Generate PDF (returns base64 data)
    my $data = $pdf->pdf();

    # Save to file
    $pdf->pdf(file => '/tmp/page.pdf');

    # With options
    $pdf->pdf(
        file            => '/tmp/page.pdf',
        paper_size      => 'a4',
        landscape       => 1,
        margin          => 1,  # inches
        print_background => 1,
        scale           => 0.8,
        page_ranges     => '1-5',
    );

    # With header/footer
    $pdf->with_header_footer(file => '/tmp/page.pdf');

=head1 DESCRIPTION

Print::PDF provides PDF generation functionality for the chrome-driver plugin.
It uses Chrome's Page.printToPDF CDP method for high-quality PDF output.

=head1 METHODS

=head2 new(%options)

Create a new Print::PDF instance.

Options:
  - chrome: ChromeDriver instance (required)

=head2 pdf(%options)

Generate a PDF from the current page.

Options:
  - file: Save to file path (returns path on success)
  - paper_size: 'letter', 'legal', 'a4', 'a3', 'a5', 'tabloid',
                or { width => N, height => N } in inches
  - landscape: Enable landscape orientation if true
  - margin: Set all margins in inches (default: 0.4)
  - margin_top, margin_bottom, margin_left, margin_right: Individual margins
  - print_background: Include backgrounds (default: true)
  - scale: Page scale (0.1 to 2.0)
  - page_ranges: Page range string (e.g., "1-5, 8, 11-13")
  - header_template: HTML template for header
  - footer_template: HTML template for footer
  - prefer_css_page_size: Use CSS-defined page size if true
  - emulate_media: 'screen' or 'print'

Returns base64-encoded PDF data, or file path if file option given.

=head2 letter(%options)

Convenience method for letter-size PDF.

=head2 a4(%options)

Convenience method for A4-size PDF.

=head2 landscape(%options)

Convenience method for landscape PDF.

=head2 with_header_footer(%options)

Generate PDF with default header (title) and footer (page numbers).

=head2 paper_sizes()

Returns list of available paper size presets.

=head2 error()

Get the last error message.

=head1 HEADER/FOOTER TEMPLATES

Header and footer templates are HTML strings that can include these classes:

  - date: Current date
  - title: Page title
  - url: Page URL
  - pageNumber: Current page number
  - totalPages: Total page count

Example:
  <div style="font-size: 10px;">
    Page <span class="pageNumber"></span> of <span class="totalPages"></span>
  </div>

=head1 AUTHOR

Generated for chrome-driver plugin

=cut
