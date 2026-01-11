---
description: Automate Chrome browser via DevTools Protocol. Use when user asks to scrape websites, take screenshots, generate PDFs, interact with web pages, extract content, fill forms, or automate browser tasks. (project)
---

# Browser Automation with Chrome DevTools Protocol

Control Chrome browser programmatically using simple command-line scripts. All scripts auto-start Chrome in headless mode if not running.

## Global Options (All Commands)

All commands support these options for session persistence and interactive use:

- `--no-headless` - Run Chrome with a visible window (required for interactive sites, login, etc.)
- `--user-data=PATH` - Use a specific Chrome profile directory to preserve cookies, logins, and session state between runs

**Example: Persistent session for logged-in sites**
```bash
# First time: login interactively with visible browser
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://instacart.com --no-headless --user-data=~/.chrome-instacart

# After logging in manually, future commands use same profile (cookies preserved)
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://instacart.com/store/market-32 --user-data=~/.chrome-instacart
${CLAUDE_PLUGIN_ROOT}/bin/screenshot https://instacart.com/account --user-data=~/.chrome-instacart /tmp/account.png
```

## Available Commands

All scripts are in `${CLAUDE_PLUGIN_ROOT}/bin/`:

### screenshot - Capture web pages as images

```bash
${CLAUDE_PLUGIN_ROOT}/bin/screenshot URL [OUTPUT] [OPTIONS]
```

Options:
- `--full-page` - Capture entire scrollable page
- `--selector=CSS` - Capture specific element
- `--format=png|jpeg|webp` - Output format (default: png)
- `--quality=N` - JPEG/WebP quality 0-100
- `--width=N --height=N` - Set viewport size
- `--max-dimension=N` - Max output dimension (default: 8000, auto-scales large pages)

Examples:
```bash
# Basic screenshot
${CLAUDE_PLUGIN_ROOT}/bin/screenshot https://example.com /tmp/page.png

# Full page as JPEG
${CLAUDE_PLUGIN_ROOT}/bin/screenshot https://example.com /tmp/full.jpg --full-page --format=jpeg

# Capture specific element
${CLAUDE_PLUGIN_ROOT}/bin/screenshot https://example.com /tmp/header.png --selector="header"
```

### pdf - Generate PDFs from web pages

```bash
${CLAUDE_PLUGIN_ROOT}/bin/pdf URL [OUTPUT] [OPTIONS]
```

Options:
- `--paper=letter|a4|legal|a3|a5|tabloid` - Paper size (default: letter)
- `--landscape` - Landscape orientation
- `--margin=INCHES` - All margins (default: 0.4)
- `--scale=FACTOR` - Scale 0.1-2.0 (default: 1.0)
- `--no-background` - Skip background colors/images

Examples:
```bash
# Basic PDF
${CLAUDE_PLUGIN_ROOT}/bin/pdf https://example.com /tmp/doc.pdf

# A4 landscape
${CLAUDE_PLUGIN_ROOT}/bin/pdf https://example.com /tmp/report.pdf --paper=a4 --landscape

# Tight margins
${CLAUDE_PLUGIN_ROOT}/bin/pdf https://example.com /tmp/compact.pdf --margin=0.25
```

### extract - Extract content from web pages

```bash
${CLAUDE_PLUGIN_ROOT}/bin/extract URL [OPTIONS]
```

Options:
- `--format=markdown|text|html` - Output format (default: markdown)
- `--selector=CSS` - Extract specific element only
- `--links` - Also list all links
- `--images` - Also list all images
- `--metadata` - Also show page metadata

Examples:
```bash
# Get page as markdown
${CLAUDE_PLUGIN_ROOT}/bin/extract https://example.com

# Get plain text from article
${CLAUDE_PLUGIN_ROOT}/bin/extract https://example.com --format=text --selector="article"

# Get all links and metadata
${CLAUDE_PLUGIN_ROOT}/bin/extract https://example.com --links --metadata
```

### navigate - Navigate and interact with pages

```bash
${CLAUDE_PLUGIN_ROOT}/bin/navigate URL [OPTIONS]
```

Options:
- `--wait-for=SELECTOR` - Wait for element to appear
- `--click=SELECTOR` - Click an element
- `--type=SELECTOR=TEXT` - Type text into input field
- `--eval=JAVASCRIPT` - Execute JavaScript and print result
- `--timeout=SECONDS` - Timeout (default: 30)

Examples:
```bash
# Navigate and wait for content
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://example.com --wait-for="#content"

# Fill form and submit
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://google.com --type="input[name=q]=hello" --click="input[type=submit]"

# Get page title via JavaScript
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://example.com --eval="document.title"
```

### form - Fill out and submit web forms

```bash
${CLAUDE_PLUGIN_ROOT}/bin/form URL [OPTIONS]
```

Options:
- `--fill=SELECTOR=VALUE` - Fill input field (can repeat)
- `--select=SELECTOR=VALUE` - Select dropdown option (can repeat)
- `--fill-json='{"sel":"val"}'` - Fill multiple fields from JSON
- `--submit=SELECTOR` - Click submit button after filling
- `--wait-for=SELECTOR` - Wait for element before filling
- `--wait-after=SELECTOR` - Wait for element after submit
- `--screenshot=PATH` - Take screenshot after completion

Examples:
```bash
# Login form
${CLAUDE_PLUGIN_ROOT}/bin/form https://example.com/login \
  --fill='#username=john' \
  --fill='#password=secret' \
  --submit='button[type=submit]'

# Form with dropdowns
${CLAUDE_PLUGIN_ROOT}/bin/form https://example.com/register \
  --fill='#name=John Doe' \
  --fill='#email=john@example.com' \
  --select='#country=US' \
  --submit='#register-btn'

# Using JSON
${CLAUDE_PLUGIN_ROOT}/bin/form https://example.com/contact \
  --fill-json='{"#name":"John","#email":"john@test.com"}' \
  --submit='button.send'
```

### record - Record screencast frames

```bash
${CLAUDE_PLUGIN_ROOT}/bin/record URL OUTPUT_DIR [OPTIONS]
```

Options:
- `--duration=SECONDS` - Recording duration (default: 5)
- `--count=N` - Exact number of frames to capture
- `--format=jpeg|png` - Frame format (default: jpeg)
- `--quality=N` - JPEG quality 0-100 (default: 80)
- `--max-width=N` - Maximum frame width
- `--max-height=N` - Maximum frame height
- `--fps=N` - Approximate frames per second (default: 10)

Examples:
```bash
# Record 5 seconds
${CLAUDE_PLUGIN_ROOT}/bin/record https://example.com /tmp/frames

# Record 30 PNG frames
${CLAUDE_PLUGIN_ROOT}/bin/record https://example.com /tmp/frames --count=30 --format=png

# Convert to video with ffmpeg
ffmpeg -framerate 10 -i /tmp/frames/frame-%04d.jpg -c:v libx264 output.mp4
```

### interact - Interact with current page (no navigation)

```bash
${CLAUDE_PLUGIN_ROOT}/bin/interact [OPTIONS]
```

**This is the key command for multi-step workflows.** Unlike `navigate`, this command connects to the already-open browser tab and performs actions WITHOUT reloading the page. Essential for:
- Multi-step processes (search → click result → add to cart)
- Single-page applications (SPAs)
- Sites where navigation resets state

Options:
- `--click=SELECTOR` - Click element matching CSS selector
- `--type=SELECTOR=TEXT` - Type text into input field
- `--eval=JAVASCRIPT` - Execute JavaScript and print result
- `--wait-for=SELECTOR` - Wait for element to appear
- `--select=SELECTOR=VALUE` - Select dropdown option
- `--focus=SELECTOR` - Focus an element
- `--text=SELECTOR` - Get text content of element
- `--timeout=SECONDS` - Timeout (default: 30)

Examples:
```bash
# Execute JavaScript on current page
${CLAUDE_PLUGIN_ROOT}/bin/interact --eval="document.title" --user-data=~/.chrome-mysite

# Click a button on current page
${CLAUDE_PLUGIN_ROOT}/bin/interact --click="#submit-btn" --user-data=~/.chrome-mysite

# Type into an input without navigating away
${CLAUDE_PLUGIN_ROOT}/bin/interact --type="#search=query" --user-data=~/.chrome-mysite

# Chain actions: focus, type, then click
${CLAUDE_PLUGIN_ROOT}/bin/interact --focus="#search" --type="#search=pork" --click="#search-btn" --user-data=~/.chrome-mysite

# Get text from an element
${CLAUDE_PLUGIN_ROOT}/bin/interact --text="h1.title" --user-data=~/.chrome-mysite
```

### chrome-status - Check browser status

```bash
${CLAUDE_PLUGIN_ROOT}/bin/chrome-status
```

Shows whether Chrome is running, version info, and open tabs.

## Common Workflows

### Screenshot a page
```bash
${CLAUDE_PLUGIN_ROOT}/bin/screenshot https://example.com /tmp/screenshot.png
```

### Convert page to PDF
```bash
${CLAUDE_PLUGIN_ROOT}/bin/pdf https://example.com /tmp/document.pdf --paper=a4
```

### Scrape page content
```bash
${CLAUDE_PLUGIN_ROOT}/bin/extract https://example.com --format=markdown
```

### Fill and submit a form
```bash
${CLAUDE_PLUGIN_ROOT}/bin/form https://example.com/login \
  --fill='#username=user' \
  --fill='#password=pass' \
  --submit='button[type=submit]' \
  --wait-after='.dashboard'
```

### Record a screencast
```bash
${CLAUDE_PLUGIN_ROOT}/bin/record https://example.com /tmp/frames --duration=10
ffmpeg -framerate 10 -i /tmp/frames/frame-%04d.jpg -c:v libx264 video.mp4
```

## Notes

- Chrome auto-starts in headless mode when needed (use `--no-headless` for visible browser)
- Chrome continues running between commands for speed
- Use `--user-data=PATH` to preserve login/cookies between sessions
- Use `pkill -f 'chrome.*--remote-debugging-port'` to stop Chrome manually
- Default port is 9222; set `CHROME_DRIVER_PORT` to change
- All scripts support `--help` for full usage info
- Large screenshots are auto-scaled to fit within 8000px (API limit)

## Session Management Tips

For sites requiring login (Instacart, Amazon, banking, etc.):

1. **Create a persistent profile**: Use `--user-data=~/.chrome-sitename` consistently
2. **First-time login**: Use `--no-headless` to see the browser and log in manually
3. **Subsequent automation**: Same `--user-data` path preserves your session
4. **Multiple accounts**: Use different `--user-data` paths for different accounts/sites

---

## Multi-Step Workflow Guide: Shopping Sites (Instacart, Amazon, etc.)

This section walks through automating complex multi-step processes on sites that require login and multiple interactions. The key insight is using **two commands together**:

- `navigate` - Go to a URL (use for initial navigation)
- `interact` - Work with the current page without reloading (use for everything after)

### Understanding the Two-Command Pattern

**Why `navigate` alone isn't enough:**
- `navigate` ALWAYS loads/reloads the specified URL
- Each `navigate` call is independent - it doesn't "continue" from the previous state
- Multi-step workflows (search → select → add to cart) break because each step resets

**Why `interact` is essential:**
- `interact` connects to the EXISTING browser tab
- It performs actions on whatever page is currently displayed
- The page state is preserved between `interact` calls
- Perfect for SPAs and multi-step processes

### Complete Example: Adding Items to Instacart Cart

Here's a real-world example that works:

#### Step 1: Initial Setup - Create Profile and Login

First time only - open browser visibly so user can log in:

```bash
# Open Instacart with visible browser and persistent profile
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://www.instacart.com \
  --no-headless \
  --user-data=~/.chrome-instacart

# USER ACTION: Log in manually in the browser window
# Your cookies/session will be saved to ~/.chrome-instacart
```

#### Step 2: Navigate to Store

After login, go to the desired store:

```bash
# First, find the correct store URL by checking the homepage
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://www.instacart.com/store \
  --no-headless \
  --user-data=~/.chrome-instacart

# Use JavaScript to find links containing your store name
${CLAUDE_PLUGIN_ROOT}/bin/interact \
  --eval="Array.from(document.querySelectorAll('a')).filter(a => a.innerText.includes('Market 32')).map(a => a.href).join('\n')" \
  --no-headless \
  --user-data=~/.chrome-instacart

# Navigate to the store (use the URL found above)
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://www.instacart.com/store/price-chopper-ny/storefront \
  --no-headless \
  --user-data=~/.chrome-instacart
```

#### Step 3: Search for Product (Multi-Step with interact)

Now use `interact` to search WITHOUT navigating away:

```bash
# Click the search input
${CLAUDE_PLUGIN_ROOT}/bin/interact \
  --click="#search-bar-input" \
  --no-headless \
  --user-data=~/.chrome-instacart

# Type the search query
${CLAUDE_PLUGIN_ROOT}/bin/interact \
  --type="#search-bar-input=pork shoulder" \
  --no-headless \
  --user-data=~/.chrome-instacart

# Submit the search using JavaScript (trigger form submit event)
${CLAUDE_PLUGIN_ROOT}/bin/interact \
  --eval="var input = document.querySelector('#search-bar-input'); var form = input.closest('form'); form.dispatchEvent(new Event('submit', {bubbles: true, cancelable: true})); 'submitted'" \
  --no-headless \
  --user-data=~/.chrome-instacart
```

#### Step 4: View Search Results

Check what products are available:

```bash
# Wait a moment for results to load, then check the page content
sleep 2

${CLAUDE_PLUGIN_ROOT}/bin/interact \
  --eval="document.body.innerText.substring(0, 2000)" \
  --no-headless \
  --user-data=~/.chrome-instacart
```

#### Step 5: Add Product to Cart

Click the Add button for the desired product:

```bash
# Find and click the first "Add" button
${CLAUDE_PLUGIN_ROOT}/bin/interact \
  --eval="var addBtns = Array.from(document.querySelectorAll('button')).filter(b => b.innerText.trim() === 'Add'); if (addBtns.length > 0) { addBtns[0].click(); 'Added to cart'; } else { 'No Add button found'; }" \
  --no-headless \
  --user-data=~/.chrome-instacart
```

#### Step 6: Verify Cart Updated

Confirm the item was added:

```bash
# Check cart count or page state
${CLAUDE_PLUGIN_ROOT}/bin/interact \
  --eval="document.body.innerText.includes('2') ? 'Cart has 2 items' : document.body.innerText.substring(0, 500)" \
  --no-headless \
  --user-data=~/.chrome-instacart
```

### Key Techniques for Multi-Step Automation

#### 1. Finding Elements with JavaScript

When CSS selectors are complex or dynamic, use `--eval` to find elements:

```bash
# Find all buttons with specific text
--eval="Array.from(document.querySelectorAll('button')).filter(b => b.innerText.includes('Add')).length"

# Find links by text content
--eval="Array.from(document.querySelectorAll('a')).filter(a => a.innerText.includes('Checkout'))[0].href"

# Get input field IDs/names
--eval="JSON.stringify(Array.from(document.querySelectorAll('input')).map(i => ({id: i.id, name: i.name, placeholder: i.placeholder})))"
```

#### 2. Clicking Elements via JavaScript

When `--click` doesn't work (dynamic elements, overlays, etc.):

```bash
# Click by finding element with JS
--eval="document.querySelector('.add-to-cart-btn').click(); 'clicked'"

# Click first matching element
--eval="Array.from(document.querySelectorAll('button')).filter(b => b.innerText === 'Add')[0].click(); 'clicked'"
```

#### 3. Submitting Forms

Different approaches for form submission:

```bash
# Method 1: Dispatch submit event (most reliable for SPAs)
--eval="document.querySelector('form').dispatchEvent(new Event('submit', {bubbles: true, cancelable: true})); 'submitted'"

# Method 2: Click submit button
--click="button[type=submit]"

# Method 3: Call submit() directly
--eval="document.querySelector('form').submit(); 'submitted'"
```

#### 4. Waiting for Dynamic Content

Use `--wait-for` or JavaScript polling:

```bash
# Wait for element to appear
--wait-for=".search-results"

# Or use JavaScript with timeout
--eval="new Promise(r => { let i = setInterval(() => { if (document.querySelector('.results')) { clearInterval(i); r('found'); }}, 100); setTimeout(() => { clearInterval(i); r('timeout'); }, 5000); })"
```

#### 5. Reading Page State

Extract information to make decisions:

```bash
# Get current URL
--eval="window.location.href"

# Check if logged in
--eval="document.body.innerText.includes('Sign Out') ? 'logged in' : 'not logged in'"

# Get cart count
--eval="document.querySelector('.cart-count')?.innerText || '0'"

# Get product prices
--eval="JSON.stringify(Array.from(document.querySelectorAll('.price')).map(p => p.innerText))"
```

### Troubleshooting Multi-Step Workflows

#### Problem: Page resets between commands
**Solution**: Use `interact` instead of `navigate` for all steps after initial navigation.

#### Problem: Elements not found
**Solution**:
1. Use `--eval` to inspect the page structure
2. Wait for dynamic content with `--wait-for` or `sleep`
3. Check if element is in an iframe

#### Problem: Click doesn't work
**Solution**:
1. Try JavaScript click: `--eval="document.querySelector('...').click()"`
2. Scroll element into view first
3. Check for overlays blocking the element

#### Problem: Form doesn't submit
**Solution**:
1. Use form submit event: `form.dispatchEvent(new Event('submit', ...))`
2. Check if it's a SPA with custom form handling
3. Look for and click the actual submit button

#### Problem: Login session lost
**Solution**:
1. Always use same `--user-data` path
2. Check if cookies expired
3. Some sites require re-login periodically

### Best Practices

1. **Always use `--user-data`** for sites requiring login
2. **Use `--no-headless`** during development to see what's happening
3. **Start with `navigate`** to load the initial page
4. **Switch to `interact`** for all subsequent actions on that page
5. **Use `--eval` liberally** to inspect page state and find elements
6. **Add `sleep` between actions** if the site needs time to update
7. **Check results after each step** to verify the action worked
