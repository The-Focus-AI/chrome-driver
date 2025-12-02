# chrome-driver

A Claude Code plugin that enables LLMs to interact with web pages through Chrome DevTools Protocol, implemented in pure Perl with no external dependencies.

## Features

- **Browser Automation**: Navigate, click, type, interact with web pages
- **Content Extraction**: Extract HTML, text, or markdown from pages
- **Visual Capture**: Take screenshots (PNG, JPEG, WebP)
- **PDF Generation**: Convert pages to PDF with full control
- **JavaScript Execution**: Run JavaScript in browser context
- **Session Management**: Save/load cookies and authentication state
- **Zero Dependencies**: Pure Perl 5.14+ with standard modules only

## Installation

### Prerequisites

- Perl 5.14 or later (included with macOS/Linux)
- Chrome or Chromium browser

### Install Plugin

```bash
# Clone repository
git clone https://github.com/Focus-AI/chrome-driver
cd chrome-driver

# Install to Claude Code
cp -r .claude-plugin ~/.config/claude/plugins/chrome-driver
cp -r .claude/skills ~/.config/claude/plugins/chrome-driver/
cp -r .claude/commands ~/.config/claude/plugins/chrome-driver/
cp -r .claude/hooks ~/.config/claude/plugins/chrome-driver/

# Or use Claude Code plugin manager (if available)
/plugin install chrome-driver
```

## Quick Start

### Use with Claude Code

Simply ask Claude to interact with websites:

```
> Take a screenshot of example.com
> Extract the text from https://news.ycombinator.com
> Generate a PDF of this page
> Fill out the login form at https://example.com/login
```

The browser-automation skill will automatically activate.

### Slash Commands

Quick commands for common tasks:

```bash
/browser              # Check browser status
/screenshot URL       # Take screenshot
/pdf URL              # Generate PDF
/extract URL          # Extract content
```

### Direct Perl Usage

```perl
use ChromeDriver;
use Page::Navigation;
use Content::Extraction;

# Start browser
my $chrome = ChromeDriver->new(headless => 1);
$chrome->connect_to_page() or die $chrome->error;

# Navigate
my $nav = Page::Navigation->new(chrome => $chrome);
$nav->goto('https://example.com');

# Extract content
my $content = Content::Extraction->new(chrome => $chrome);
my $markdown = $content->markdown();
my @links = $content->links();

# Clean up
$chrome->close();
```

## Modules

| Module | Purpose |
|--------|---------|
| `ChromeDriver` | Core CDP connection and messaging |
| `Page::Navigation` | Navigate, reload, history |
| `Content::Extraction` | Extract HTML, text, markdown, links, images |
| `Visual::Capture` | Screenshots and viewport control |
| `Print::PDF` | PDF generation with full options |
| `DOM::Elements` | Query, click, type, interact with elements |
| `JS::Execute` | Execute JavaScript in browser |
| `Session::Cookies` | Cookie management and persistence |
| `Help::Browser` | Interactive help system |

## Examples

### Scrape Website Content

```perl
use ChromeDriver;
use Page::Navigation;
use Content::Extraction;

my $chrome = ChromeDriver->new(headless => 1);
$chrome->connect_to_page();

my $nav = Page::Navigation->new(chrome => $chrome);
my $content = Content::Extraction->new(chrome => $chrome);

$nav->goto('https://example.com');
my $text = $content->text('article');
my @links = $content->links();

print "Content: $text\n";
print "Found " . scalar(@links) . " links\n";

$chrome->close();
```

### Fill Form and Submit

```perl
use ChromeDriver;
use Page::Navigation;
use DOM::Elements;

my $chrome = ChromeDriver->new(headless => 1);
$chrome->connect_to_page();

my $nav = Page::Navigation->new(chrome => $chrome);
my $dom = DOM::Elements->new(chrome => $chrome);

$nav->goto('https://example.com/login');
$dom->type('input[name="email"]', 'user@example.com');
$dom->type('input[name="password"]', 'secret');
$dom->click('button[type="submit"]');

$dom->wait_for('.dashboard', 10);
print "Logged in successfully!\n";

$chrome->close();
```

### Generate PDF Report

```perl
use ChromeDriver;
use Page::Navigation;
use Print::PDF;

my $chrome = ChromeDriver->new(headless => 1);
$chrome->connect_to_page();

my $nav = Page::Navigation->new(chrome => $chrome);
my $pdf = Print::PDF->new(chrome => $chrome);

$nav->goto('https://example.com/report');
$pdf->a4(
    file => '/tmp/report.pdf',
    margin => 1,
    print_background => 1
);

print "PDF saved to /tmp/report.pdf\n";

$chrome->close();
```

### Take Full-Page Screenshot

```perl
use ChromeDriver;
use Page::Navigation;
use Visual::Capture;

my $chrome = ChromeDriver->new(headless => 1);
$chrome->connect_to_page();

my $nav = Page::Navigation->new(chrome => $chrome);
my $capture = Visual::Capture->new(chrome => $chrome);

$nav->goto('https://example.com');
$capture->screenshot(
    file => '/tmp/page.png',
    full_page => 1
);

print "Screenshot saved to /tmp/page.png\n";

$chrome->close();
```

## Testing

```bash
# Unit tests
prove -Ilib t/

# Integration tests (requires Chrome)
CHROME_TEST=1 prove -Ilib t/

# Specific test
perl -Ilib t/01-frame.t
```

## Documentation

### Get Help in Code

```perl
use Help::Browser qw(browser_help);

print browser_help();              # Overview
print browser_help('navigation');  # Topic help
print browser_help('examples');    # Usage examples
```

### Available Help Topics

- `overview` - Plugin overview and quick start
- `navigation` - Page navigation (goto, back, forward)
- `content` - Content extraction (HTML, text, markdown)
- `screenshot` - Screenshots and viewport control
- `pdf` - PDF generation
- `dom` - DOM queries and interactions
- `javascript` - JavaScript execution
- `cookies` - Cookie management
- `cdp` - Chrome DevTools Protocol reference
- `examples` - Common usage examples

## Troubleshooting

### Chrome Won't Start

```bash
# Check if Chrome is installed
google-chrome --version

# Try starting manually
google-chrome --remote-debugging-port=9222 --headless

# Kill orphan processes
pkill -f 'chrome.*--remote-debugging-port'
```

### Connection Issues

```bash
# Check if Chrome is running
curl http://localhost:9222/json/version

# Check port availability
lsof -i :9222

# View Chrome debugging targets
curl http://localhost:9222/json
```

### Element Not Found

- Use `$dom->wait_for($selector, $timeout)` for dynamic content
- Verify selector with browser DevTools (F12)
- Ensure page has fully loaded
- Check for iframes (content may be in a different frame)

## Architecture

### How It Works

1. **Chrome Startup**: Auto-detects and launches Chrome with `--remote-debugging-port=9222`
2. **WebSocket Connection**: Implements RFC 6455 WebSocket handshake in pure Perl
3. **CDP Protocol**: Sends JSON-RPC messages over WebSocket
4. **Event Handling**: Subscribes to CDP events for async operations
5. **Cleanup**: Hooks ensure Chrome processes are killed when session ends

### No External Dependencies

Uses only Perl standard library modules:
- `IO::Socket::INET` - TCP sockets
- `HTTP::Tiny` - HTTP requests
- `JSON::PP` - JSON encoding/decoding
- `Digest::SHA` - WebSocket handshake
- `MIME::Base64` - Base64 encoding

## Contributing

Contributions welcome! Please:

1. Follow existing code style
2. Add tests for new features
3. Update documentation
4. Keep dependencies at zero (core Perl only)

## License

MIT License - see LICENSE file for details

## Credits

Built with Claude Code for automated browser interactions via Chrome DevTools Protocol.

## Links

- Chrome DevTools Protocol: https://chromedevtools.github.io/devtools-protocol/
- RFC 6455 (WebSocket): https://tools.ietf.org/html/rfc6455
- Claude Code: https://claude.com/claude-code
