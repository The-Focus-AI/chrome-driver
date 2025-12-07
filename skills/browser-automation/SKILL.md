---
name: browser-automation
description: Automate Chrome browser via DevTools Protocol. Use when user asks to scrape websites, take screenshots, generate PDFs, interact with web pages, extract content, fill forms, or automate browser tasks.
allowed-tools: Bash, Read, Write
---

# Browser Automation with Chrome DevTools Protocol

Control Chrome browser programmatically using simple command-line scripts. All scripts auto-start Chrome in headless mode if not running.

## Available Commands

All scripts are in `bin/`:

### screenshot - Capture web pages as images

```bash
bin/screenshot URL [OUTPUT] [OPTIONS]
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
bin/screenshot https://example.com /tmp/page.png

# Full page as JPEG
bin/screenshot https://example.com /tmp/full.jpg --full-page --format=jpeg

# Capture specific element
bin/screenshot https://example.com /tmp/header.png --selector="header"
```

### pdf - Generate PDFs from web pages

```bash
bin/pdf URL [OUTPUT] [OPTIONS]
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
bin/pdf https://example.com /tmp/doc.pdf

# A4 landscape
bin/pdf https://example.com /tmp/report.pdf --paper=a4 --landscape

# Tight margins
bin/pdf https://example.com /tmp/compact.pdf --margin=0.25
```

### extract - Extract content from web pages

```bash
bin/extract URL [OPTIONS]
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
bin/extract https://example.com

# Get plain text from article
bin/extract https://example.com --format=text --selector="article"

# Get all links and metadata
bin/extract https://example.com --links --metadata
```

### navigate - Navigate and interact with pages

```bash
bin/navigate URL [OPTIONS]
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
bin/navigate https://example.com --wait-for="#content"

# Fill form and submit
bin/navigate https://google.com --type="input[name=q]=hello" --click="input[type=submit]"

# Get page title via JavaScript
bin/navigate https://example.com --eval="document.title"
```

### form - Fill out and submit web forms

```bash
bin/form URL [OPTIONS]
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
bin/form https://example.com/login \
  --fill='#username=john' \
  --fill='#password=secret' \
  --submit='button[type=submit]'

# Form with dropdowns
bin/form https://example.com/register \
  --fill='#name=John Doe' \
  --fill='#email=john@example.com' \
  --select='#country=US' \
  --submit='#register-btn'

# Using JSON
bin/form https://example.com/contact \
  --fill-json='{"#name":"John","#email":"john@test.com"}' \
  --submit='button.send'
```

### record - Record screencast frames

```bash
bin/record URL OUTPUT_DIR [OPTIONS]
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
bin/record https://example.com /tmp/frames

# Record 30 PNG frames
bin/record https://example.com /tmp/frames --count=30 --format=png

# Convert to video with ffmpeg
ffmpeg -framerate 10 -i /tmp/frames/frame-%04d.jpg -c:v libx264 output.mp4
```

### cookies - Manage sessions and cookies

```bash
bin/cookies COMMAND [OPTIONS]
```

Commands:
- `list` - List all cookies (or filter by --url or --name)
- `get` - Alias for list
- `set` - Set a cookie
- `delete` - Delete a cookie
- `clear` - Clear all cookies
- `save` - Save cookies to JSON file
- `load` - Load cookies from JSON file

Options:
- `--name=NAME` - Cookie name
- `--value=VALUE` - Cookie value (required for set)
- `--domain=DOMAIN` - Cookie domain
- `--url=URL` - URL for cookie operations
- `--secure` - Set Secure flag
- `--http-only` - Set HttpOnly flag
- `--same-site=MODE` - SameSite: Strict, Lax, or None
- `--expires=EPOCH` - Expiration timestamp (epoch seconds)
- `--file=PATH` - File path for save/load
- `--json` - Output in JSON format

Examples:
```bash
# List all cookies
bin/cookies list

# List cookies as JSON
bin/cookies list --json

# Get specific cookie by name
bin/cookies get --name=session_id

# Set a session cookie
bin/cookies set --name=auth_token --value=abc123 --domain=example.com

# Set secure cookie with expiration (1 week from now)
bin/cookies set --name=remember_me --value=user123 \
  --domain=example.com --secure --http-only \
  --expires=$(date -v+7d +%s)

# Delete a cookie
bin/cookies delete --name=auth_token --domain=example.com

# Clear all cookies
bin/cookies clear

# Save session for later
bin/cookies save /tmp/session.json

# Restore session
bin/cookies load /tmp/session.json
```

### chrome-status - Check browser status

```bash
bin/chrome-status
```

Shows whether Chrome is running, version info, and open tabs.

## Common Workflows

### Screenshot a page
```bash
bin/screenshot https://example.com /tmp/screenshot.png
```

### Convert page to PDF
```bash
bin/pdf https://example.com /tmp/document.pdf --paper=a4
```

### Scrape page content
```bash
bin/extract https://example.com --format=markdown
```

### Fill and submit a form
```bash
bin/form https://example.com/login \
  --fill='#username=user' \
  --fill='#password=pass' \
  --submit='button[type=submit]' \
  --wait-after='.dashboard'
```

### Record a screencast
```bash
bin/record https://example.com /tmp/frames --duration=10
ffmpeg -framerate 10 -i /tmp/frames/frame-%04d.jpg -c:v libx264 video.mp4
```

### Manage sessions (login persistence)
```bash
# Login to a site
bin/form https://example.com/login \
  --fill='#email=user@example.com' \
  --fill='#password=secret' \
  --submit='button[type=submit]'

# Save the session cookies
bin/cookies save /tmp/my_session.json

# Later, restore the session (skip login)
bin/cookies load /tmp/my_session.json

# Now you can access authenticated pages
bin/screenshot https://example.com/dashboard /tmp/dashboard.png
```

### Automate authenticated workflows
```bash
# Load saved session
bin/cookies load ~/.sessions/mysite.json

# Perform authenticated actions
bin/extract https://example.com/account --format=text
bin/screenshot https://example.com/orders /tmp/orders.png

# Save any new cookies (e.g., refreshed tokens)
bin/cookies save ~/.sessions/mysite.json
```

## Notes

- Chrome auto-starts in headless mode when needed
- Chrome continues running between commands for speed
- Cookies persist between commands while Chrome is running
- Use `bin/cookies save/load` to persist sessions across browser restarts
- Use `pkill -f 'chrome.*--remote-debugging-port'` to stop Chrome manually
- Default port is 9222; set `CHROME_DRIVER_PORT` to change
- All scripts support `--help` for full usage info
- Large screenshots are auto-scaled to fit within 8000px (API limit)
