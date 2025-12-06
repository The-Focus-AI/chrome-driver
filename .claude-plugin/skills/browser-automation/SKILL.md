---
description: Automate Chrome browser via DevTools Protocol. Use when user asks to scrape websites, take screenshots, generate PDFs, interact with web pages, extract content, fill forms, or automate browser tasks. (project)
---

# Browser Automation with Chrome DevTools Protocol

Control Chrome browser programmatically using simple command-line scripts. All scripts auto-start Chrome in headless mode if not running.

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

- Chrome auto-starts in headless mode when needed
- Chrome continues running between commands for speed
- Use `pkill -f 'chrome.*--remote-debugging-port'` to stop Chrome manually
- Default port is 9222; set `CHROME_DRIVER_PORT` to change
- All scripts support `--help` for full usage info
- Large screenshots are auto-scaled to fit within 8000px (API limit)
