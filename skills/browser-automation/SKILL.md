---
name: browser-automation
description: Automate Chrome browser via DevTools Protocol. Use when user asks to scrape websites, take screenshots, generate PDFs, interact with web pages, extract content, fill forms, or automate browser tasks.
allowed-tools: Bash, Read, Write
---

# Browser Automation with Chrome DevTools Protocol

This skill enables you to control a Chrome browser programmatically using pure Perl and the Chrome DevTools Protocol (CDP).

## When to Use This Skill

Activate this skill when the user asks to:
- Scrape or extract content from websites
- Take screenshots of web pages
- Generate PDFs from web pages
- Interact with web pages (click, type, navigate)
- Fill out forms automatically
- Monitor or test web applications
- Extract structured data from websites
- Automate any browser-based task

## Available Tools

All tools are implemented as Perl modules in the `lib/` directory. Run them with:
```bash
perl -Ilib -M<Module> -e '<code>'
```

### Core Module: ChromeDriver

The main entry point for browser control:

```perl
use ChromeDriver;

# Create connection
my $chrome = ChromeDriver->new(
    headless => 1,           # Run without UI
    port => 9222,            # Debugging port
    user_data_dir => undef   # Temporary profile
);

# Connect to browser
$chrome->connect_to_page() or die $chrome->error;

# Enable domains
$chrome->enable('Page');
$chrome->enable('Runtime');
$chrome->enable('DOM');

# Send CDP commands
my $result = $chrome->send('Page.navigate', { url => 'https://example.com' });

# Wait for events
$chrome->wait_for_event('Page.loadEventFired', 30);

# Close
$chrome->close();
```

### Navigation (Page::Navigation)

```perl
use Page::Navigation;
my $nav = Page::Navigation->new(chrome => $chrome);

$nav->goto('https://example.com');
$nav->back();
$nav->forward();
$nav->reload();

my $url = $nav->current_url();
my $title = $nav->title();
```

### Content Extraction (Content::Extraction)

```perl
use Content::Extraction;
my $content = Content::Extraction->new(chrome => $chrome);

my $html = $content->html();              # Full page HTML
my $text = $content->text('article');    # Text from selector
my $markdown = $content->markdown();      # Page as markdown
my @links = $content->links();            # [{href, text}, ...]
my @images = $content->images();          # [{src, alt}, ...]
my %meta = $content->metadata();          # Meta tags
```

### Screenshots (Visual::Capture)

```perl
use Visual::Capture;
my $capture = Visual::Capture->new(chrome => $chrome);

# Basic screenshot
$capture->screenshot(file => '/tmp/page.png');

# Full page
$capture->screenshot(
    file => '/tmp/full.png',
    full_page => 1
);

# Element screenshot
$capture->screenshot(
    selector => 'h1',
    file => '/tmp/header.png'
);

# Custom format/quality
$capture->screenshot(
    file => '/tmp/page.jpg',
    format => 'jpeg',
    quality => 80
);
```

### PDF Generation (Print::PDF)

```perl
use Print::PDF;
my $pdf = Print::PDF->new(chrome => $chrome);

# Simple PDF
$pdf->pdf(file => '/tmp/page.pdf');

# With options
$pdf->a4(
    file => '/tmp/doc.pdf',
    margin => 1,
    print_background => 1
);

# Custom size
$pdf->pdf(
    file => '/tmp/custom.pdf',
    paper_size => { width => 8.5, height => 11 },
    landscape => 1
);
```

### DOM Interaction (DOM::Elements)

```perl
use DOM::Elements;
my $dom = DOM::Elements->new(chrome => $chrome);

# Query elements
my $el = $dom->query('input[name="email"]');
my @els = $dom->query_all('a.link');
my $exists = $dom->exists('.modal');

# Interact
$dom->click('button#submit');
$dom->type($el, 'user@example.com');
$dom->select($dropdown, 'option-value');
$dom->hover('.menu-item');
$dom->scroll_to($el);

# Wait
my $el = $dom->wait_for('.success-message', 10);

# Get info
my $text = $dom->get_text($el);
my $value = $dom->get_attribute($el, 'href');
my $box = $dom->get_box($el);  # {x, y, width, height}
```

### JavaScript Execution (JS::Execute)

```perl
use JS::Execute;
my $js = JS::Execute->new(chrome => $chrome);

# Evaluate expression
my $result = $js->evaluate('document.title');
my $sum = $js->evaluate('1 + 2');

# Async/Promises
my $data = $js->evaluate_async(
    'fetch("/api").then(r => r.json())'
);

# Raw CDP
my $doc = $js->cdp_send('DOM.getDocument');
```

### Session Management (Session::Cookies)

```perl
use Session::Cookies;
my $cookies = Session::Cookies->new(chrome => $chrome);

# Set cookie
$cookies->set(
    name => 'session',
    value => 'abc123',
    domain => 'example.com'
);

# Get cookies
my @all = $cookies->get_all();
my $cookie = $cookies->get_cookie('session');

# Persist
$cookies->save('/tmp/session.json');
$cookies->load('/tmp/session.json');

# Clear
$cookies->clear();
```

### Help System (Help::Browser)

```perl
use Help::Browser qw(browser_help);

print browser_help();              # Overview
print browser_help('navigation');  # Topic help
print browser_help('examples');    # Usage examples
```

## Common Patterns

### Scrape a Website

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

$chrome->close();
```

### Fill a Form and Submit

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

$chrome->close();
```

## Implementation Notes

- **Pure Perl**: Uses only standard Perl 5.14+ modules (no CPAN dependencies)
- **WebSocket**: Manual RFC 6455 implementation for CDP communication
- **Auto-lifecycle**: Chrome launches automatically, but you should explicitly close connections
- **Error handling**: Always check return values and call `$chrome->error` on failure
- **Timeouts**: Most operations have default timeouts, adjustable via parameters

## Troubleshooting

**Chrome won't start:**
- Check if Chrome/Chromium is installed
- Try running: `google-chrome --remote-debugging-port=9222`
- Check for orphan processes: `pkill -f 'chrome.*--remote-debugging-port'`

**WebSocket connection fails:**
- Ensure Chrome is running with debugging enabled
- Check port 9222 is not in use: `lsof -i :9222`
- Review connection logs in ChromeDriver

**Element not found:**
- Use `$dom->wait_for($selector, $timeout)` to wait for dynamic content
- Check selector is correct with browser DevTools
- Ensure page has fully loaded

## Getting Help

For detailed documentation on any topic:
```perl
use Help::Browser qw(browser_help);
print browser_help('topic');
```

Topics: overview, navigation, content, screenshot, pdf, dom, javascript, cookies, cdp, examples
