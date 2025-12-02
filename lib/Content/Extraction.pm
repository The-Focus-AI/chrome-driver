package Content::Extraction;
use strict;
use warnings;

# Content Extraction module for chrome-driver
# Extracts HTML, text, and markdown from web pages

sub new {
    my ($class, %opts) = @_;

    my $chrome = $opts{chrome} or die "chrome parameter required";

    return bless {
        chrome  => $chrome,
        error   => undef,
    }, $class;
}

# Get the HTML content of the page or a specific element
sub html {
    my ($self, %opts) = @_;

    my $selector = $opts{selector};
    my $outer = $opts{outer} // 1;  # outerHTML by default

    my $js;
    if ($selector) {
        my $prop = $outer ? 'outerHTML' : 'innerHTML';
        $js = qq{
            (function() {
                var el = document.querySelector('$selector');
                return el ? el.$prop : null;
            })()
        };
    }
    else {
        # Get full document HTML
        $js = 'document.documentElement.outerHTML';
    }

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression    => $js,
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

# Get the text content of the page or a specific element
sub text {
    my ($self, %opts) = @_;

    my $selector = $opts{selector};

    my $js;
    if ($selector) {
        $js = qq{
            (function() {
                var el = document.querySelector('$selector');
                return el ? el.innerText : null;
            })()
        };
    }
    else {
        $js = 'document.body.innerText';
    }

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression    => $js,
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

# Get page content as markdown
sub markdown {
    my ($self, %opts) = @_;

    my $selector = $opts{selector};

    # Get HTML first
    my $html = $self->html(selector => $selector, outer => 0);
    return undef unless defined $html;

    # Convert to markdown
    return $self->_html_to_markdown($html);
}

# Convert HTML to Markdown
sub _html_to_markdown {
    my ($self, $html) = @_;

    return '' unless defined $html && length $html;

    # Use a Perl-based HTML to Markdown converter
    # This is a simplified implementation - handles common cases

    my $md = $html;

    # Normalize whitespace in the source
    $md =~ s/\r\n/\n/g;
    $md =~ s/\r/\n/g;

    # Remove scripts and styles
    $md =~ s/<script[^>]*>.*?<\/script>//gis;
    $md =~ s/<style[^>]*>.*?<\/style>//gis;
    $md =~ s/<noscript[^>]*>.*?<\/noscript>//gis;

    # Handle headings (h1-h6)
    for my $level (1..6) {
        my $prefix = '#' x $level;
        $md =~ s/<h$level[^>]*>(.*?)<\/h$level>/\n$prefix $1\n/gis;
    }

    # Handle paragraphs
    $md =~ s/<p[^>]*>(.*?)<\/p>/\n$1\n/gis;

    # Handle line breaks
    $md =~ s/<br\s*\/?>/\n/gi;

    # Handle emphasis and strong
    $md =~ s/<(strong|b)[^>]*>(.*?)<\/\1>/**$2**/gis;
    $md =~ s/<(em|i)[^>]*>(.*?)<\/\1>/*$2*/gis;

    # Handle code blocks
    $md =~ s/<pre[^>]*><code[^>]*>(.*?)<\/code><\/pre>/\n```\n$1\n```\n/gis;
    $md =~ s/<pre[^>]*>(.*?)<\/pre>/\n```\n$1\n```\n/gis;

    # Handle inline code
    $md =~ s/<code[^>]*>(.*?)<\/code>/`$1`/gis;

    # Handle links
    $md =~ s/<a[^>]*href=["']([^"']+)["'][^>]*>(.*?)<\/a>/[$2]($1)/gis;

    # Handle images
    $md =~ s/<img[^>]*src=["']([^"']+)["'][^>]*alt=["']([^"']*)["'][^>]*\/?>/![$2]($1)/gis;
    $md =~ s/<img[^>]*alt=["']([^"']*)["'][^>]*src=["']([^"']+)["'][^>]*\/?>/![$1]($2)/gis;
    $md =~ s/<img[^>]*src=["']([^"']+)["'][^>]*\/?>/![]($1)/gis;

    # Handle unordered lists
    $md =~ s/<ul[^>]*>(.*?)<\/ul>/$self->_convert_list($1, '-')/gies;

    # Handle ordered lists
    $md =~ s/<ol[^>]*>(.*?)<\/ol>/$self->_convert_list($1, '1.')/gies;

    # Handle blockquotes
    $md =~ s/<blockquote[^>]*>(.*?)<\/blockquote>/$self->_convert_blockquote($1)/gies;

    # Handle horizontal rules
    $md =~ s/<hr\s*\/?>/\n---\n/gi;

    # Handle tables (simplified - basic structure only)
    $md =~ s/<table[^>]*>(.*?)<\/table>/$self->_convert_table($1)/gies;

    # Remove remaining HTML tags
    $md =~ s/<[^>]+>//g;

    # Decode common HTML entities
    $md =~ s/&nbsp;/ /g;
    $md =~ s/&lt;/</g;
    $md =~ s/&gt;/>/g;
    $md =~ s/&amp;/&/g;
    $md =~ s/&quot;/"/g;
    $md =~ s/&#39;/'/g;
    $md =~ s/&apos;/'/g;
    $md =~ s/&#(\d+);/chr($1)/ge;
    $md =~ s/&#x([0-9a-fA-F]+);/chr(hex($1))/ge;

    # Clean up whitespace
    $md =~ s/[ \t]+/ /g;          # Collapse horizontal whitespace
    $md =~ s/\n{3,}/\n\n/g;       # Max 2 consecutive newlines
    $md =~ s/^\s+//;              # Trim leading whitespace
    $md =~ s/\s+$//;              # Trim trailing whitespace

    return $md;
}

# Helper: Convert list items
sub _convert_list {
    my ($self, $content, $marker) = @_;

    my $result = "\n";
    my $count = 1;

    while ($content =~ /<li[^>]*>(.*?)<\/li>/gis) {
        my $item = $1;
        $item =~ s/<[^>]+>//g;  # Strip inner tags
        $item =~ s/^\s+|\s+$//g;

        if ($marker eq '1.') {
            $result .= "$count. $item\n";
            $count++;
        }
        else {
            $result .= "$marker $item\n";
        }
    }

    return $result;
}

# Helper: Convert blockquote
sub _convert_blockquote {
    my ($self, $content) = @_;

    $content =~ s/<[^>]+>//g;  # Strip inner tags
    $content =~ s/^\s+|\s+$//g;

    my @lines = split /\n/, $content;
    return "\n" . join("\n", map { "> $_" } @lines) . "\n";
}

# Helper: Convert table (simplified)
sub _convert_table {
    my ($self, $content) = @_;

    my @rows;
    my $header_done = 0;

    # Extract rows
    while ($content =~ /<tr[^>]*>(.*?)<\/tr>/gis) {
        my $row_content = $1;
        my @cells;

        # Handle th and td
        while ($row_content =~ /<(th|td)[^>]*>(.*?)<\/\1>/gis) {
            my $cell = $2;
            $cell =~ s/<[^>]+>//g;  # Strip inner tags
            $cell =~ s/^\s+|\s+$//g;
            push @cells, $cell;
        }

        if (@cells) {
            push @rows, \@cells;

            # Add header separator after first row
            if (!$header_done) {
                my @sep = map { '---' } @cells;
                push @rows, \@sep;
                $header_done = 1;
            }
        }
    }

    return '' unless @rows;

    # Format as markdown table
    my $result = "\n";
    for my $row (@rows) {
        $result .= '| ' . join(' | ', @$row) . " |\n";
    }

    return $result;
}

# Get title of the page
sub title {
    my ($self) = @_;

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression    => 'document.title',
        returnByValue => \1,
    });

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return undef;
    }

    return $result->{result}{value};
}

# Get all links from the page
sub links {
    my ($self, %opts) = @_;

    my $selector = $opts{selector} // 'a[href]';

    my $js = qq{
        (function() {
            var links = [];
            var elements = document.querySelectorAll('$selector');
            for (var i = 0; i < elements.length; i++) {
                var el = elements[i];
                links.push({
                    href: el.href,
                    text: el.innerText.trim(),
                    title: el.title || ''
                });
            }
            return links;
        })()
    };

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression    => $js,
        returnByValue => \1,
    });

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return undef;
    }

    if ($result->{exceptionDetails}) {
        $self->{error} = "JavaScript error";
        return undef;
    }

    return $result->{result}{value} // [];
}

# Get all images from the page
sub images {
    my ($self, %opts) = @_;

    my $selector = $opts{selector} // 'img[src]';

    my $js = qq{
        (function() {
            var images = [];
            var elements = document.querySelectorAll('$selector');
            for (var i = 0; i < elements.length; i++) {
                var el = elements[i];
                images.push({
                    src: el.src,
                    alt: el.alt || '',
                    width: el.naturalWidth,
                    height: el.naturalHeight
                });
            }
            return images;
        })()
    };

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression    => $js,
        returnByValue => \1,
    });

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return undef;
    }

    if ($result->{exceptionDetails}) {
        $self->{error} = "JavaScript error";
        return undef;
    }

    return $result->{result}{value} // [];
}

# Get metadata from the page (meta tags)
sub metadata {
    my ($self) = @_;

    my $js = q{
        (function() {
            var meta = {};
            var tags = document.querySelectorAll('meta');
            for (var i = 0; i < tags.length; i++) {
                var tag = tags[i];
                var name = tag.getAttribute('name') ||
                           tag.getAttribute('property') ||
                           tag.getAttribute('http-equiv');
                if (name) {
                    meta[name] = tag.getAttribute('content') || '';
                }
            }
            return meta;
        })()
    };

    my $result = $self->{chrome}->send('Runtime.evaluate', {
        expression    => $js,
        returnByValue => \1,
    });

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error();
        return undef;
    }

    return $result->{result}{value} // {};
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

1;

__END__

=head1 NAME

Content::Extraction - Extract content from web pages

=head1 SYNOPSIS

    use Content::Extraction;

    my $content = Content::Extraction->new(chrome => $chrome);

    # Get HTML
    my $html = $content->html();
    my $element_html = $content->html(selector => '#main');

    # Get text
    my $text = $content->text();
    my $element_text = $content->text(selector => 'article');

    # Get markdown
    my $md = $content->markdown();

    # Get page title
    my $title = $content->title();

    # Get all links
    my $links = $content->links();

    # Get all images
    my $images = $content->images();

    # Get metadata
    my $meta = $content->metadata();

=head1 DESCRIPTION

Content::Extraction provides methods for extracting content from web pages
in various formats: HTML, plain text, and Markdown.

=head1 METHODS

=head2 new(%options)

Create a new Content::Extraction instance.

Options:
  - chrome: ChromeDriver instance (required)

=head2 html(%options)

Get the HTML content of the page or a specific element.

Options:
  - selector: CSS selector for specific element
  - outer: Return outerHTML (default) or innerHTML if false

=head2 text(%options)

Get the text content (innerText) of the page or element.

Options:
  - selector: CSS selector for specific element

=head2 markdown(%options)

Get page content converted to Markdown format.

Options:
  - selector: CSS selector for specific element

=head2 title()

Get the page title.

=head2 links(%options)

Get all links from the page as an array of hashes with
href, text, and title keys.

Options:
  - selector: CSS selector (default: 'a[href]')

=head2 images(%options)

Get all images from the page as an array of hashes with
src, alt, width, and height keys.

Options:
  - selector: CSS selector (default: 'img[src]')

=head2 metadata()

Get page metadata (meta tags) as a hash.

=head2 error()

Get the last error message.

=head1 AUTHOR

Generated for chrome-driver plugin

=cut
