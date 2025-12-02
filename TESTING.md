# Testing Guide for chrome-driver Plugin

This guide covers comprehensive testing strategies for the chrome-driver plugin.

## Table of Contents

1. [Unit Testing (Perl Modules)](#unit-testing)
2. [Plugin Installation Testing](#plugin-installation-testing)
3. [Component Testing](#component-testing)
4. [Integration Testing](#integration-testing)
5. [Manual Testing Scenarios](#manual-testing-scenarios)
6. [Automated Testing](#automated-testing)

## Unit Testing

### Run All Perl Tests

```bash
# All tests
prove -Ilib t/

# Verbose output
prove -Ilib -v t/

# Specific test
perl -Ilib t/01-frame.t
```

### Run Integration Tests with Chrome

```bash
# Requires Chrome to be running
CHROME_TEST=1 prove -Ilib t/

# Or specific integration test
CHROME_TEST=1 perl -Ilib t/03-integration.t
```

### Expected Results

- 12 test files
- 197 total tests
- All should pass

## Plugin Installation Testing

### Step 1: Create Development Marketplace

The plugin already has a local development marketplace configured. To install:

```bash
# Add this plugin directory as a marketplace
/plugin marketplace add /Users/wschenk/The-Focus-AI/chrome-driver

# Install the plugin from local source
/plugin install chrome-driver@chrome-driver

# Restart Claude Code
# Exit and restart the claude CLI
```

### Step 2: Verify Installation

```bash
# List installed plugins
/plugin list

# Should show: chrome-driver@chrome-driver v0.1.0
```

### Step 3: Test Uninstall/Reinstall

```bash
# Uninstall
/plugin uninstall chrome-driver@chrome-driver

# Reinstall
/plugin install chrome-driver@chrome-driver
# Restart Claude Code
```

## Component Testing

### Test 1: Skill Activation

The `browser-automation` skill should automatically activate when you mention browser tasks.

**Test Cases:**

```
1. Ask: "Take a screenshot of example.com"
   Expected: Skill activates, uses ChromeDriver modules

2. Ask: "Extract text from https://news.ycombinator.com"
   Expected: Skill activates, uses content extraction

3. Ask: "Generate a PDF of a webpage"
   Expected: Skill activates, offers to help

4. Ask: "Fill out a login form"
   Expected: Skill activates, uses DOM interaction
```

**How to verify:**
- Claude should mention using chrome-driver or browser automation
- Should use Perl commands with `-Ilib` flag
- Should reference the modules (ChromeDriver, Page::Navigation, etc.)

### Test 2: Slash Commands

Test each command individually:

#### `/browser`

```bash
/browser
```

**Expected behavior:**
- Checks if Chrome is running (curl http://localhost:9222/json/version)
- Shows Chrome status
- Offers to start Chrome if not running
- Shows available actions

#### `/screenshot URL`

```bash
# Basic
/screenshot https://example.com

# With options
/screenshot https://example.com --full-page
/screenshot https://example.com --selector="article"
/screenshot https://example.com --format=jpeg --output=/tmp/test.jpg
```

**Expected behavior:**
- Starts Chrome if needed
- Navigates to URL
- Captures screenshot
- Reports file path and size

#### `/pdf URL`

```bash
# Basic
/pdf https://example.com

# With options
/pdf https://example.com --paper=a4 --margin=1
/pdf https://example.com --landscape
```

**Expected behavior:**
- Starts Chrome if needed
- Navigates to URL
- Generates PDF
- Reports file path and size

#### `/extract URL`

```bash
# Basic (markdown)
/extract https://example.com

# Different formats
/extract https://example.com --format=text
/extract https://example.com --format=html

# With selector
/extract https://example.com --selector="article"

# With extras
/extract https://example.com --links --images
```

**Expected behavior:**
- Starts Chrome if needed
- Navigates to URL
- Extracts content in requested format
- Shows links/images if requested

### Test 3: Hooks

The cleanup hook should run when Claude session ends.

**Test procedure:**

1. Start Chrome manually:
   ```bash
   google-chrome --remote-debugging-port=9222 --headless &
   echo $! > /tmp/chrome-test.pid
   ```

2. Use the plugin (take a screenshot, etc.)

3. Exit Claude Code completely

4. Check if Chrome was killed:
   ```bash
   ps aux | grep "chrome.*--remote-debugging-port"
   # Should return no results
   ```

**Expected behavior:**
- Chrome processes with `--remote-debugging-port` are terminated
- Temporary profile directories are cleaned up

## Integration Testing

### End-to-End Test 1: Web Scraping

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

use ChromeDriver;
use Page::Navigation;
use Content::Extraction;

# Start Chrome
my $chrome = ChromeDriver->new(headless => 1);
die "Failed to connect: " . $chrome->error unless $chrome->connect_to_page();

# Navigate
my $nav = Page::Navigation->new(chrome => $chrome);
$nav->goto('https://example.com') or die "Navigation failed";

# Extract content
my $content = Content::Extraction->new(chrome => $chrome);
my $text = $content->text('body');
my @links = $content->links();
my $markdown = $content->markdown();

# Verify
die "No text extracted" unless length($text) > 0;
die "No links found" unless @links > 0;
die "No markdown generated" unless length($markdown) > 0;

print "✓ Web scraping test passed\n";
print "  - Extracted " . length($text) . " chars of text\n";
print "  - Found " . scalar(@links) . " links\n";
print "  - Generated " . length($markdown) . " chars of markdown\n";

$chrome->close();
```

### End-to-End Test 2: Screenshot Capture

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

use ChromeDriver;
use Page::Navigation;
use Visual::Capture;

my $chrome = ChromeDriver->new(headless => 1);
$chrome->connect_to_page() or die $chrome->error;

my $nav = Page::Navigation->new(chrome => $chrome);
my $capture = Visual::Capture->new(chrome => $chrome);

$nav->goto('https://example.com');

# Test different formats
my @tests = (
    { file => '/tmp/test-png.png', format => 'png' },
    { file => '/tmp/test-jpg.jpg', format => 'jpeg', quality => 80 },
    { file => '/tmp/test-full.png', format => 'png', full_page => 1 },
);

for my $test (@tests) {
    $capture->screenshot(%$test) or die "Screenshot failed: $!";
    die "File not created: $test->{file}" unless -f $test->{file};
    my $size = -s $test->{file};
    die "File is empty: $test->{file}" unless $size > 0;
    print "✓ Screenshot test passed: $test->{file} ($size bytes)\n";
    unlink $test->{file};
}

$chrome->close();
```

### End-to-End Test 3: Form Filling

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

use ChromeDriver;
use Page::Navigation;
use DOM::Elements;

my $chrome = ChromeDriver->new(headless => 1);
$chrome->connect_to_page() or die $chrome->error;

my $nav = Page::Navigation->new(chrome => $chrome);
my $dom = DOM::Elements->new(chrome => $chrome);

# Navigate to a form page (use a test page)
$nav->goto('https://httpbin.org/forms/post');

# Fill form
$dom->type('input[name="custname"]', 'Test User') or die "Type failed";
$dom->type('input[name="custtel"]', '555-1234') or die "Type failed";
$dom->type('input[name="custemail"]', 'test@example.com') or die "Type failed";

# Verify values were set
my $name_val = $dom->get_attribute('input[name="custname"]', 'value');
die "Form fill failed" unless $name_val eq 'Test User';

print "✓ Form filling test passed\n";

$chrome->close();
```

## Manual Testing Scenarios

### Scenario 1: Basic Web Scraping

```
You: "Scrape the main content from https://example.com and show me the text"

Expected:
1. Claude uses chrome-driver skill
2. Runs ChromeDriver, Navigation, and Content::Extraction modules
3. Returns extracted text
4. Provides structured data
```

### Scenario 2: Screenshot with Options

```
You: "Take a full-page screenshot of example.com in JPEG format"

Expected:
1. Uses Visual::Capture with full_page=1 and format=jpeg
2. Saves to /tmp/
3. Reports file path
4. Offers to show image if possible
```

### Scenario 3: PDF Generation

```
You: "Generate an A4 PDF of example.com with 1 inch margins"

Expected:
1. Uses Print::PDF with a4() method
2. Sets margin=1
3. Enables print_background
4. Reports PDF path and size
```

### Scenario 4: Form Automation

```
You: "Go to httpbin.org/forms/post and fill in the form with test data"

Expected:
1. Uses DOM::Elements for form interaction
2. Types into input fields
3. Could click submit button
4. Waits for result
```

### Scenario 5: Help System

```
You: "How do I take a screenshot with chrome-driver?"

Expected:
1. Claude mentions Help::Browser module
2. May run browser_help('screenshot')
3. Shows documentation about Visual::Capture
4. Provides code examples
```

## Automated Testing

### Create a Test Suite

Save as `test-plugin.sh`:

```bash
#!/bin/bash
set -e

echo "=== chrome-driver Plugin Test Suite ==="
echo

# 1. Perl unit tests
echo "1. Running Perl unit tests..."
prove -Ilib t/
echo "✓ Perl tests passed"
echo

# 2. Integration tests
echo "2. Running integration tests (requires Chrome)..."
CHROME_TEST=1 prove -Ilib t/03-integration.t
echo "✓ Integration tests passed"
echo

# 3. Module import tests
echo "3. Testing module imports..."
perl -Ilib -e 'use ChromeDriver; print "✓ ChromeDriver\n"'
perl -Ilib -e 'use Page::Navigation; print "✓ Page::Navigation\n"'
perl -Ilib -e 'use Content::Extraction; print "✓ Content::Extraction\n"'
perl -Ilib -e 'use Visual::Capture; print "✓ Visual::Capture\n"'
perl -Ilib -e 'use Print::PDF; print "✓ Print::PDF\n"'
perl -Ilib -e 'use DOM::Elements; print "✓ DOM::Elements\n"'
perl -Ilib -e 'use JS::Execute; print "✓ JS::Execute\n"'
perl -Ilib -e 'use Session::Cookies; print "✓ Session::Cookies\n"'
perl -Ilib -e 'use Help::Browser; print "✓ Help::Browser\n"'
echo

# 4. Plugin structure
echo "4. Verifying plugin structure..."
test -f .claude-plugin/plugin.json && echo "✓ plugin.json exists"
test -d skills && echo "✓ skills/ directory exists"
test -d commands && echo "✓ commands/ directory exists"
test -d hooks && echo "✓ hooks/ directory exists"
test -f skills/browser-automation/SKILL.md && echo "✓ SKILL.md exists"
echo

# 5. Documentation
echo "5. Checking documentation..."
test -f README.md && echo "✓ README.md"
test -f TROUBLESHOOTING.md && echo "✓ TROUBLESHOOTING.md"
test -f CHANGELOG.md && echo "✓ CHANGELOG.md"
test -f LICENSE && echo "✓ LICENSE"
echo

echo "=== All tests passed! ==="
```

Make it executable:
```bash
chmod +x test-plugin.sh
./test-plugin.sh
```

## Testing Checklist

Use this checklist for comprehensive testing:

### Plugin Structure
- [ ] `.claude-plugin/plugin.json` exists and is valid JSON
- [ ] `plugin.json` has correct relative paths (starting with `./`)
- [ ] All referenced files exist
- [ ] Skills, commands, hooks are at plugin root

### Perl Modules
- [ ] All unit tests pass (`prove -Ilib t/`)
- [ ] Integration tests pass with Chrome (`CHROME_TEST=1 prove -Ilib t/`)
- [ ] All modules import without errors
- [ ] No dependency on external CPAN modules

### Plugin Components
- [ ] Skill activates on browser-related tasks
- [ ] `/browser` command works
- [ ] `/screenshot` command works
- [ ] `/pdf` command works
- [ ] `/extract` command works
- [ ] Cleanup hook runs on session end

### Documentation
- [ ] README is comprehensive
- [ ] TROUBLESHOOTING covers common issues
- [ ] CHANGELOG documents version
- [ ] LICENSE is included
- [ ] All code has POD documentation

### Integration
- [ ] Can scrape websites
- [ ] Can take screenshots
- [ ] Can generate PDFs
- [ ] Can fill forms
- [ ] Can execute JavaScript
- [ ] Can manage cookies

### Error Handling
- [ ] Graceful errors when Chrome not found
- [ ] Clear error messages
- [ ] Proper cleanup on failure
- [ ] Timeout handling works

## Troubleshooting Test Failures

### Tests Fail
- Check Chrome is installed: `google-chrome --version`
- Kill orphan Chrome: `pkill -f 'chrome.*--remote-debugging-port'`
- Check port 9222: `lsof -i :9222`
- Run verbose: `prove -Ilib -v t/test-name.t`

### Plugin Not Loading
- Check plugin.json syntax: `cat .claude-plugin/plugin.json | python3 -m json.tool`
- Verify paths are relative: Should start with `./`
- Restart Claude Code completely
- Check plugin directory: `/plugin list`

### Skill Not Activating
- Check SKILL.md has trigger phrases
- Verify description is clear and specific
- Test with exact matching phrases
- Check skill is in `skills/` at root

### Commands Not Working
- Check command files are in `commands/` at root
- Verify markdown format is correct
- Test command syntax in isolation
- Check if script has execute permissions

## Continuous Testing

For ongoing development:

```bash
# Watch for changes and run tests
while true; do
    inotifywait -r -e modify lib/ t/
    clear
    prove -Ilib t/
done
```

Or use `prove` watch mode:
```bash
prove -Ilib --watch t/
```

## Next Steps

After testing is complete:

1. ✅ All tests pass
2. Document any issues in GitHub Issues
3. Tag a release: `git tag v0.1.0`
4. Push to GitHub
5. Share with team
6. Gather feedback
7. Iterate

For production release, see README.md installation instructions.
