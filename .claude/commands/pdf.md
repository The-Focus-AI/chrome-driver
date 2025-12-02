# Quick PDF Generation

Generate a PDF from a web page.

## Usage

When the user types `/pdf [URL] [options]`, perform these actions:

1. **Parse the command:**
   - Extract URL (required)
   - Extract options: `--paper=letter|a4|legal`, `--landscape`, `--margin=N`, `--output=path`
   - Default output: `/tmp/page-{timestamp}.pdf`

2. **Generate the PDF using Perl:**
   ```perl
   use ChromeDriver;
   use Page::Navigation;
   use Print::PDF;

   my $chrome = ChromeDriver->new(headless => 1);
   $chrome->connect_to_page() or die $chrome->error;

   my $nav = Page::Navigation->new(chrome => $chrome);
   my $pdf = Print::PDF->new(chrome => $chrome);

   $nav->goto('URL');

   my %opts = (
       file => 'OUTPUT_PATH',
       print_background => 1
   );

   # Add paper size
   $opts{paper_size} = 'letter';  # or 'a4', 'legal', etc.

   # Add margins
   $opts{margin} = 0.5;  # or specific value from --margin

   # Add landscape if requested
   $opts{landscape} = 1 if '--landscape';

   $pdf->pdf(%opts);
   $chrome->close();

   print "PDF saved to: OUTPUT_PATH\n";
   ```

3. **Report results:**
   - Show the file path where PDF was saved
   - Show file size
   - Show page count if available

## Examples

```bash
# Basic PDF
/pdf https://example.com

# A4 with margins
/pdf https://example.com --paper=a4 --margin=1

# Landscape
/pdf https://example.com --landscape --output=/tmp/report.pdf

# Custom margins
/pdf https://example.com --margin=0.75
```

## Options

- `--paper=SIZE` - Paper size: letter (default), a4, legal, a3, a5, tabloid
- `--landscape` - Landscape orientation (default: portrait)
- `--margin=N` - All margins in inches (default: 0.4)
- `--no-background` - Don't print background colors/images
- `--scale=N` - Scale factor 0.1-2.0 (default: 1.0)
- `--output=PATH` - Save to specific path (default: /tmp/page-*.pdf)

## Advanced Options

For more control, use Print::PDF directly:

```perl
$pdf->pdf(
    file => '/tmp/custom.pdf',
    paper_size => { width => 8.5, height => 11 },
    margin_top => 1,
    margin_bottom => 1,
    margin_left => 0.5,
    margin_right => 0.5,
    header_template => '<div>Header</div>',
    footer_template => '<div>Page <span class="pageNumber"></span></div>',
    page_ranges => '1-5, 8, 11-13'
);
```

## Notes

- Chrome will be automatically started if not running
- Background graphics are included by default
- Use Print::PDF module directly for advanced options like headers/footers
