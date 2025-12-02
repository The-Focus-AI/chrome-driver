# Quick Screenshot

Take a screenshot of a web page.

## Usage

When the user types `/screenshot [URL] [options]`, perform these actions:

1. **Parse the command:**
   - Extract URL (required)
   - Extract options: `--full-page`, `--selector="CSS"`, `--format=png|jpeg|webp`, `--output=path`
   - Default output: `/tmp/screenshot-{timestamp}.png`

2. **Take the screenshot using Perl:**
   ```perl
   use ChromeDriver;
   use Page::Navigation;
   use Visual::Capture;

   my $chrome = ChromeDriver->new(headless => 1);
   $chrome->connect_to_page() or die $chrome->error;

   my $nav = Page::Navigation->new(chrome => $chrome);
   my $capture = Visual::Capture->new(chrome => $chrome);

   $nav->goto('URL');

   my %opts = (
       file => 'OUTPUT_PATH',
       format => 'png',        # or jpeg, webp
       full_page => 0,         # 1 if --full-page
   );

   # Add selector if provided
   $opts{selector} = 'SELECTOR' if 'SELECTOR';

   $capture->screenshot(%opts);
   $chrome->close();

   print "Screenshot saved to: OUTPUT_PATH\n";
   ```

3. **Report results:**
   - Show the file path where screenshot was saved
   - Show file size
   - Offer to display the image if in a compatible environment

## Examples

```bash
# Basic screenshot
/screenshot https://example.com

# Full page screenshot
/screenshot https://example.com --full-page

# Specific element
/screenshot https://example.com --selector="article.main"

# JPEG with custom output
/screenshot https://example.com --format=jpeg --output=/tmp/page.jpg
```

## Options

- `--full-page` - Capture entire scrollable page (default: viewport only)
- `--selector="CSS"` - Capture specific element matching CSS selector
- `--format=FORMAT` - Output format: png (default), jpeg, webp
- `--quality=N` - JPEG/WebP quality 0-100 (default: 80)
- `--output=PATH` - Save to specific path (default: /tmp/screenshot-*.png)

## Notes

- Chrome will be automatically started if not running
- Screenshots are saved locally to the specified path
- Use Visual::Capture module directly for more control
