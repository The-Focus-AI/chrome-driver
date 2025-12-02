package Help::Browser;
use strict;
use warnings;

# Interactive help system for chrome-driver
# Provides on-demand documentation, examples, and CDP reference

# Help topics database
my %HELP = (
    overview => {
        title => 'Chrome Driver Overview',
        content => <<'END',
chrome-driver is a pure Perl Chrome DevTools Protocol plugin.

MODULES:
  ChromeDriver       - Core browser connection and CDP commands
  Page::Navigation   - Navigation and history management
  Content::Extraction - Content extraction (HTML, text, markdown)
  Visual::Capture    - Screenshots and viewport control
  Print::PDF         - PDF generation
  DOM::Elements      - DOM queries and interactions
  JS::Execute        - JavaScript execution
  Session::Cookies   - Cookie management

QUICK START:
  use ChromeDriver;
  my $chrome = ChromeDriver->new(headless => 1);
  $chrome->connect_to_page() or die $chrome->error;
  $chrome->enable('Page');
  $chrome->send('Page.navigate', { url => 'https://example.com' });
  $chrome->wait_for_event('Page.loadEventFired', 10);

Use browser_help('topic') for detailed help on any topic.
END
    },

    navigation => {
        title => 'Page Navigation',
        content => <<'END',
Page::Navigation provides navigation methods.

METHODS:
  goto($url)         - Navigate to URL, wait for load
  reload()           - Reload current page
  back()             - Go back in history
  forward()          - Go forward in history
  current_url()      - Get current page URL
  title()            - Get page title
  history()          - Get navigation history

EXAMPLE:
  use Page::Navigation;
  my $nav = Page::Navigation->new(chrome => $chrome);

  $nav->goto('https://example.com');
  my $url = $nav->current_url();
  my $title = $nav->title();
  $nav->back();

OPTIONS:
  goto() accepts:
    - timeout => N seconds (default: 30)
    - wait_until => 'load' | 'domcontentloaded' | 'networkidle'
END
    },

    content => {
        title => 'Content Extraction',
        content => <<'END',
Content::Extraction extracts page content.

METHODS:
  html($selector?)       - Get HTML content
  text($selector?)       - Get text content
  markdown($selector?)   - Get content as markdown
  title()                - Get page title
  links()                - Get all links [{href, text}]
  images()               - Get all images [{src, alt}]
  metadata()             - Get meta tags {name => content}

EXAMPLE:
  use Content::Extraction;
  my $content = Content::Extraction->new(chrome => $chrome);

  my $html = $content->html('body');
  my $text = $content->text('article');
  my $md = $content->markdown();
  my @links = $content->links();

MARKDOWN CONVERSION:
  Supports: headings, paragraphs, links, images, lists,
  code blocks, emphasis, strong, blockquotes, tables
END
    },

    screenshot => {
        title => 'Screenshots (Visual::Capture)',
        content => <<'END',
Visual::Capture provides screenshot capabilities.

METHODS:
  screenshot(%opts)     - Capture screenshot
  set_viewport(w, h)    - Set viewport size
  clear_viewport()      - Reset viewport

SCREENSHOT OPTIONS:
  format     => 'png' | 'jpeg' | 'webp'
  quality    => 0-100 (for jpeg/webp)
  file       => '/path/to/save.png'
  full_page  => 1 (capture entire page)
  selector   => 'CSS selector' (capture element)
  clip       => {x, y, width, height}

EXAMPLE:
  use Visual::Capture;
  my $capture = Visual::Capture->new(chrome => $chrome);

  # Save PNG screenshot
  $capture->screenshot(file => '/tmp/page.png');

  # Full page JPEG
  $capture->screenshot(
      file => '/tmp/full.jpg',
      format => 'jpeg',
      quality => 80,
      full_page => 1
  );

  # Element screenshot
  $capture->screenshot(
      selector => 'h1',
      file => '/tmp/header.png'
  );
END
    },

    pdf => {
        title => 'PDF Generation (Print::PDF)',
        content => <<'END',
Print::PDF generates PDFs from pages.

METHODS:
  pdf(%opts)            - Generate PDF
  letter(%opts)         - Letter size shortcut
  a4(%opts)             - A4 size shortcut
  landscape(%opts)      - Landscape shortcut
  with_header_footer()  - Include header/footer

PDF OPTIONS:
  file             => '/path/to/save.pdf'
  paper_size       => 'letter' | 'legal' | 'a4' | 'a3' | 'a5' | 'tabloid'
                      or {width => N, height => N} (inches)
  landscape        => 1
  margin           => 0.5 (all margins in inches)
  margin_top/bottom/left/right => N
  print_background => 1
  scale            => 0.1 to 2.0
  page_ranges      => '1-5, 8, 11-13'
  header_template  => '<html>...'
  footer_template  => '<html>...'

EXAMPLE:
  use Print::PDF;
  my $pdf = Print::PDF->new(chrome => $chrome);

  $pdf->pdf(file => '/tmp/page.pdf');
  $pdf->a4(file => '/tmp/doc.pdf', margin => 1);
  $pdf->with_header_footer(file => '/tmp/report.pdf');
END
    },

    dom => {
        title => 'DOM Interaction (DOM::Elements)',
        content => <<'END',
DOM::Elements provides element queries and actions.

QUERY METHODS:
  query($selector)      - Find single element
  query_all($selector)  - Find all elements
  exists($selector)     - Check if element exists
  wait_for($selector)   - Wait for element
  is_visible($selector) - Check visibility

ACTION METHODS:
  click($el_or_sel)     - Click element
  type($el, $text)      - Type into element
  select($el, $value)   - Select dropdown option
  hover($el)            - Hover over element
  focus($el)            - Focus element
  scroll_to($el)        - Scroll element into view
  set_value($el, $val)  - Set input value

INFO METHODS:
  get_text($el)         - Get text content
  get_attribute($el, $attr)
  get_property($el, $prop)
  get_box($el)          - Get bounding box

EXAMPLE:
  use DOM::Elements;
  my $dom = DOM::Elements->new(chrome => $chrome);

  my $input = $dom->query('input[name="email"]');
  $dom->type($input, 'user@example.com');
  $dom->click('button[type="submit"]');

  my $el = $dom->wait_for('.success-message', 10);
  my $text = $dom->get_text($el);
END
    },

    javascript => {
        title => 'JavaScript Execution (JS::Execute)',
        content => <<'END',
JS::Execute runs JavaScript in the browser.

METHODS:
  evaluate($expr)       - Evaluate JS expression
  evaluate_async($expr) - Evaluate async/Promise
  evaluate_on($obj_id, $fn) - Evaluate on object
  cdp_send($method, $params) - Raw CDP command
  cdp_subscribe($event, $cb) - Subscribe to event

EVALUATE OPTIONS:
  return_by_value => 1|0
  user_gesture => 1
  timeout => 30000 (ms, for async)

EXAMPLE:
  use JS::Execute;
  my $js = JS::Execute->new(chrome => $chrome);

  # Simple evaluation
  my $result = $js->evaluate('1 + 2');  # 3
  my $title = $js->evaluate('document.title');

  # Parse JSON
  my $data = $js->evaluate('JSON.parse(\'{"a":1}\')');

  # Async/fetch
  my $response = $js->evaluate_async(
      'fetch("/api").then(r => r.json())'
  );

  # Raw CDP
  my $doc = $js->cdp_send('DOM.getDocument');
END
    },

    cookies => {
        title => 'Cookie Management (Session::Cookies)',
        content => <<'END',
Session::Cookies manages browser cookies.

METHODS:
  get_all()              - Get all cookies
  get(urls => ...)       - Get cookies for URLs
  get_cookie($name)      - Get specific cookie
  set(%opts)             - Set a cookie
  delete($name, %opts)   - Delete cookie
  clear()                - Clear all cookies
  save($file)            - Save to JSON file
  load($file)            - Load from JSON file

SET OPTIONS:
  name, value (required)
  domain, path, secure, http_only
  same_site => 'Strict' | 'Lax' | 'None'
  expires => epoch_timestamp

EXAMPLE:
  use Session::Cookies;
  my $cookies = Session::Cookies->new(chrome => $chrome);

  $cookies->set(
      name => 'session',
      value => 'abc123',
      domain => 'example.com',
      secure => 1
  );

  my $cookie = $cookies->get_cookie('session');
  $cookies->save('/tmp/cookies.json');
  $cookies->clear();
END
    },

    cdp => {
        title => 'Chrome DevTools Protocol Reference',
        content => <<'END',
Common CDP domains and methods.

PAGE DOMAIN:
  Page.enable
  Page.navigate {url}
  Page.reload
  Page.printToPDF {...}
  Page.captureScreenshot {...}
  Events: Page.loadEventFired, Page.domContentEventFired

RUNTIME DOMAIN:
  Runtime.evaluate {expression, returnByValue}
  Runtime.callFunctionOn {objectId, functionDeclaration}
  Runtime.getProperties {objectId}

DOM DOMAIN:
  DOM.getDocument
  DOM.querySelector {nodeId, selector}
  DOM.querySelectorAll {nodeId, selector}
  DOM.getBoxModel {nodeId}

NETWORK DOMAIN:
  Network.enable
  Network.getCookies
  Network.setCookie {...}
  Network.deleteCookies {name}
  Network.clearBrowserCookies
  Events: Network.requestWillBeSent, Network.responseReceived

INPUT DOMAIN:
  Input.dispatchMouseEvent {type, x, y, button}
  Input.dispatchKeyEvent {type, text}

EMULATION DOMAIN:
  Emulation.setDeviceMetricsOverride {width, height, ...}
  Emulation.clearDeviceMetricsOverride
  Emulation.setEmulatedMedia {media}

FULL REFERENCE:
  https://chromedevtools.github.io/devtools-protocol/
END
    },

    examples => {
        title => 'Common Examples',
        content => <<'END',
SCRAPE A PAGE:
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

FILL A FORM:
  use DOM::Elements;
  my $dom = DOM::Elements->new(chrome => $chrome);

  $dom->type('input[name="email"]', 'user@example.com');
  $dom->type('input[name="password"]', 'secret');
  $dom->click('button[type="submit"]');
  $dom->wait_for('.dashboard', 10);

GENERATE PDF:
  use Print::PDF;
  my $pdf = Print::PDF->new(chrome => $chrome);
  $pdf->a4(file => 'report.pdf', margin => 1);

TAKE SCREENSHOT:
  use Visual::Capture;
  my $capture = Visual::Capture->new(chrome => $chrome);
  $capture->screenshot(file => 'page.png', full_page => 1);

SAVE/LOAD SESSION:
  use Session::Cookies;
  my $cookies = Session::Cookies->new(chrome => $chrome);
  # After login...
  $cookies->save('session.json');
  # Later...
  $cookies->load('session.json');
END
    },
);

sub new {
    my ($class, %opts) = @_;
    return bless {}, $class;
}

# Get help on a topic
sub help {
    my ($self, $topic) = @_;
    $topic //= 'overview';
    $topic = lc($topic);

    # Handle aliases
    my %aliases = (
        'nav'       => 'navigation',
        'extract'   => 'content',
        'capture'   => 'screenshot',
        'image'     => 'screenshot',
        'print'     => 'pdf',
        'element'   => 'dom',
        'elements'  => 'dom',
        'js'        => 'javascript',
        'eval'      => 'javascript',
        'cookie'    => 'cookies',
        'session'   => 'cookies',
        'protocol'  => 'cdp',
        'devtools'  => 'cdp',
        'example'   => 'examples',
    );

    $topic = $aliases{$topic} if exists $aliases{$topic};

    if (exists $HELP{$topic}) {
        return "=== $HELP{$topic}{title} ===\n\n$HELP{$topic}{content}";
    }

    # Return topic list if not found
    return $self->topics();
}

# List available topics
sub topics {
    my ($self) = @_;

    my $text = "=== Available Help Topics ===\n\n";
    $text .= "  overview    - Plugin overview and quick start\n";
    $text .= "  navigation  - Page navigation (goto, back, forward)\n";
    $text .= "  content     - Content extraction (HTML, text, markdown)\n";
    $text .= "  screenshot  - Screenshots and viewport control\n";
    $text .= "  pdf         - PDF generation\n";
    $text .= "  dom         - DOM queries and interactions\n";
    $text .= "  javascript  - JavaScript execution\n";
    $text .= "  cookies     - Cookie management\n";
    $text .= "  cdp         - Chrome DevTools Protocol reference\n";
    $text .= "  examples    - Common usage examples\n";
    $text .= "\nUse browser_help('topic') to get help on a specific topic.\n";

    return $text;
}

# Convenience function (exportable)
sub browser_help {
    my ($topic) = @_;
    my $helper = Help::Browser->new();
    return $helper->help($topic);
}

1;

__END__

=head1 NAME

Help::Browser - Interactive help system for chrome-driver

=head1 SYNOPSIS

    use Help::Browser;

    # Object-oriented
    my $help = Help::Browser->new();
    print $help->help('navigation');
    print $help->topics();

    # Functional
    use Help::Browser qw(browser_help);
    print browser_help('screenshot');

=head1 DESCRIPTION

Help::Browser provides on-demand documentation for the chrome-driver plugin.
It includes help on all modules, examples, and CDP reference.

=head1 METHODS

=head2 new()

Create a new Help::Browser instance.

=head2 help($topic)

Get help on a specific topic. Returns overview if no topic specified.

Topics: overview, navigation, content, screenshot, pdf, dom, javascript,
cookies, cdp, examples

=head2 topics()

List all available help topics.

=head1 FUNCTION

=head2 browser_help($topic)

Convenience function that can be exported.

=head1 AUTHOR

Generated for chrome-driver plugin

=cut
