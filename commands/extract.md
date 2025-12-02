# Quick Content Extraction

Extract content from a web page in various formats.

## Usage

When the user types `/extract [URL] [options]`, perform these actions:

1. **Parse the command:**
   - Extract URL (required)
   - Extract options: `--format=html|text|markdown`, `--selector="CSS"`, `--links`, `--images`
   - Default format: markdown

2. **Extract content using Perl:**
   ```perl
   use ChromeDriver;
   use Page::Navigation;
   use Content::Extraction;

   my $chrome = ChromeDriver->new(headless => 1);
   $chrome->connect_to_page() or die $chrome->error;

   my $nav = Page::Navigation->new(chrome => $chrome);
   my $content = Content::Extraction->new(chrome => $chrome);

   $nav->goto('URL');

   # Extract based on format
   my $result;
   if ($format eq 'html') {
       $result = $content->html('SELECTOR');
   } elsif ($format eq 'text') {
       $result = $content->text('SELECTOR');
   } else {  # markdown (default)
       $result = $content->markdown('SELECTOR');
   }

   # Additional extractions
   my @links = $content->links() if '--links';
   my @images = $content->images() if '--images';
   my %meta = $content->metadata();

   $chrome->close();

   # Output results
   print $result;
   ```

3. **Format and display results:**
   - Show extracted content in requested format
   - If `--links` requested, show list of links with text and href
   - If `--images` requested, show list of images with src and alt
   - Show page metadata (title, description, etc.)

## Examples

```bash
# Extract as markdown (default)
/extract https://example.com

# Extract as text
/extract https://example.com --format=text

# Extract specific element
/extract https://example.com --selector="article.main"

# Extract with links
/extract https://example.com --links

# Extract HTML of specific section
/extract https://example.com --format=html --selector="div.content"
```

## Options

- `--format=FORMAT` - Output format: markdown (default), html, text
- `--selector="CSS"` - Extract specific element (default: entire page)
- `--links` - Also extract all links as structured data
- `--images` - Also extract all images as structured data
- `--metadata` - Show page metadata (title, description, etc.)

## Output Formats

### Markdown
Converts HTML to markdown with:
- Headings (h1-h6)
- Links with URLs
- Lists (ordered/unordered)
- Tables
- Code blocks
- Bold/italic
- Images as `![alt](src)`

### Text
Plain text with:
- Whitespace normalized
- No HTML tags
- Readable structure preserved

### HTML
Raw HTML as returned by the browser

## Examples of Structured Data

### Links (with `--links`)
```
Links found (15):
  1. "Home" -> https://example.com/
  2. "About" -> https://example.com/about
  3. "Contact" -> https://example.com/contact
```

### Images (with `--images`)
```
Images found (8):
  1. "Company logo" -> https://example.com/logo.png
  2. "Product shot" -> https://example.com/product.jpg
```

### Metadata (with `--metadata`)
```
Page Metadata:
  Title: Example Domain
  Description: Example website description
  Keywords: example, demo, test
  Author: IANA
  og:title: Example Domain
  og:description: Example website...
```

## Notes

- Chrome will be automatically started if not running
- Markdown conversion preserves document structure
- Use Content::Extraction module directly for more control
- Selectors use standard CSS selector syntax
