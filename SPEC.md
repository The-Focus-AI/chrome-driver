# chrome-driver Plugin Specification

A Claude Code plugin that enables LLMs to interact with web pages through Chrome DevTools Protocol, implemented in pure Perl with no external dependencies.

## Overview

**Name:** chrome-driver
**Type:** Claude Code Plugin (skills + slash commands + hooks)
**Implementation:** Pure Perl 5.14+ (standard modules only)
**Platforms:** macOS, Linux, WSL

## Design Philosophy

- **Composable primitives** - Small, focused tools that the LLM combines as needed
- **Self-documenting** - Interactive help system for on-demand documentation
- **Zero dependencies** - Works on any system with Perl 5.14+ and Chrome/Chromium
- **Full control** - Expose all CDP capabilities, don't hide complexity

## Core Requirements

### 1. Chrome Lifecycle Management

**Behavior:** Auto-start when needed, auto-stop when session ends

| Requirement | Description |
|-------------|-------------|
| Auto-detection | Find Chrome/Chromium on macOS, Linux, WSL |
| Auto-start | Launch with `--remote-debugging-port` if not running |
| PID tracking | Track spawned Chrome processes for cleanup |
| Graceful shutdown | Kill Chrome when Claude session ends (via hooks) |
| Health checks | Detect if Chrome crashed and restart |

**Chrome locations to check:**
- macOS: `/Applications/Google Chrome.app`, `~/Applications/Google Chrome.app`
- Linux: `google-chrome`, `chromium`, `chromium-browser` (via PATH)
- WSL: `/mnt/c/Program Files/Google/Chrome/Application/chrome.exe`

### 2. Content Extraction

**Formats:** Both HTML and Markdown returned, LLM chooses what to use

| Tool | Output |
|------|--------|
| `get_html()` | Raw HTML of current page or selector |
| `get_text()` | Visible text only, whitespace normalized |
| `get_markdown()` | Converted markdown preserving structure |

**Markdown conversion features:**
- Headings (h1-h6)
- Links with URLs
- Lists (ordered/unordered)
- Tables
- Code blocks
- Bold/italic
- Images as `![alt](src)`

### 3. Visual Capture

**Philosophy:** Provide primitives, let LLM compose

| Tool | Description |
|------|-------------|
| `screenshot(options)` | Single screenshot (PNG/JPEG/WebP) |
| `screencast_start(options)` | Begin frame capture |
| `screencast_frame()` | Get next frame |
| `screencast_stop()` | End capture, return frame list |

**Screenshot options:**
- `format`: png, jpeg, webp
- `quality`: 0-100 (for jpeg/webp)
- `full_page`: boolean (viewport or full scroll)
- `selector`: capture specific element
- `clip`: {x, y, width, height}

### 4. PDF Generation

**All CDP options exposed:**

| Option | Type | Description |
|--------|------|-------------|
| `path` | string | Output file path |
| `landscape` | bool | Orientation |
| `paper_width` | number | Inches |
| `paper_height` | number | Inches |
| `margin_top/right/bottom/left` | number | Inches |
| `scale` | number | 0.1-2.0 |
| `header_template` | string | HTML header |
| `footer_template` | string | HTML footer |
| `print_background` | bool | Include backgrounds |
| `page_ranges` | string | e.g., "1-5, 8" |
| `prefer_css_page_size` | bool | Use @page CSS |

### 5. Authentication & Session Management

| Tool | Description |
|------|-------------|
| `cookies_get(domain?)` | Export cookies (all or filtered) |
| `cookies_set(cookies)` | Import cookies array |
| `cookies_save(path)` | Persist to JSON file |
| `cookies_load(path)` | Load from JSON file |
| `cookies_clear(domain?)` | Clear cookies |
| `profile_set(path)` | Use Chrome profile directory |

### 6. JavaScript Execution (All Layers)

**Layer 1: High-level helpers**
```
click(selector)
type(selector, text)
select(selector, value)
wait_for(selector, timeout?)
hover(selector)
scroll_to(selector)
focus(selector)
```

**Layer 2: JavaScript injection**
```
evaluate(js_code)           # Returns result
evaluate_async(js_code)     # For promises
evaluate_on(selector, fn)   # Run function on element
```

**Layer 3: Raw CDP**
```
cdp_send(method, params)    # Any CDP command
cdp_subscribe(event)        # Listen to CDP events
cdp_unsubscribe(event)
```

### 7. Navigation

| Tool | Description |
|------|-------------|
| `navigate(url)` | Go to URL, wait for load |
| `reload(options)` | Refresh page |
| `back()` | Navigate back |
| `forward()` | Navigate forward |
| `current_url()` | Get current URL |
| `wait_for_navigation(options)` | Wait for nav complete |

### 8. Network Interception (Optional Module)

Loaded on demand via `browser_load_module('network')`

| Tool | Description |
|------|-------------|
| `network_enable()` | Start capturing |
| `network_disable()` | Stop capturing |
| `network_requests()` | Get captured requests |
| `network_responses()` | Get captured responses |
| `network_block(patterns)` | Block matching URLs |
| `network_mock(pattern, response)` | Return fake response |
| `network_throttle(profile)` | Simulate slow network |

### 9. Interactive Help System

```
browser_help()              # List all tools
browser_help('screenshot')  # Detailed help for screenshot
browser_help('examples')    # Common usage patterns
browser_help('cdp')         # Raw CDP reference
```

## Plugin Structure

```
chrome-driver/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── browser-automation/
│       ├── SKILL.md                 # Main skill definition
│       ├── examples.md              # Usage examples
│       └── cdp-reference.md         # CDP command reference
├── commands/
│   ├── browser.md                   # /browser - status/control
│   ├── screenshot.md                # /screenshot <url> [file]
│   ├── pdf.md                       # /pdf <url> [file]
│   └── extract.md                   # /extract <url> [format]
├── hooks/
│   └── hooks.json                   # Cleanup on session end
├── lib/
│   ├── ChromeDriver.pm              # Main orchestrator
│   ├── CDP/
│   │   ├── Connection.pm            # WebSocket implementation
│   │   ├── Protocol.pm              # CDP message handling
│   │   └── Events.pm                # Event subscriptions
│   ├── Browser/
│   │   ├── Launcher.pm              # Chrome detection/launch
│   │   ├── Lifecycle.pm             # PID tracking, cleanup
│   │   └── Profile.pm               # User data management
│   ├── Page/
│   │   ├── Navigation.pm            # URL navigation
│   │   ├── Content.pm               # HTML/text extraction
│   │   ├── Screenshot.pm            # Visual capture
│   │   └── PDF.pm                   # Print to PDF
│   ├── DOM/
│   │   ├── Query.pm                 # Selectors, elements
│   │   ├── Actions.pm               # Click, type, etc.
│   │   └── Evaluate.pm              # JS execution
│   ├── Network/
│   │   ├── Monitor.pm               # Request/response capture
│   │   └── Intercept.pm             # Block/mock
│   ├── Session/
│   │   └── Cookies.pm               # Cookie management
│   └── Markdown/
│       └── Converter.pm             # HTML to Markdown
├── bin/
│   ├── chrome-driver                # CLI entry point
│   └── chrome-driver-daemon         # Background process
├── t/                               # Tests
│   ├── 01-websocket.t
│   ├── 02-cdp.t
│   ├── 03-navigation.t
│   └── ...
└── README.md
```

## Standard Perl Modules Used

| Module | Purpose | Since |
|--------|---------|-------|
| `IO::Socket::INET` | TCP for WebSocket | 5.0 |
| `IO::Select` | Non-blocking I/O | 5.0 |
| `HTTP::Tiny` | HTTP for `/json` endpoint | 5.14 |
| `JSON::PP` | JSON encode/decode | 5.14 |
| `Digest::SHA` | WebSocket handshake | 5.10 |
| `MIME::Base64` | Screenshots, handshake | 5.0 |
| `File::Temp` | Temp files | 5.0 |
| `File::Spec` | Cross-platform paths | 5.0 |
| `POSIX` | Process management | 5.0 |
| `Time::HiRes` | Precise timing | 5.8 |

## CDP Communication Flow

```
1. Find/Launch Chrome with --remote-debugging-port=9222
2. HTTP GET http://localhost:9222/json/version
   → Extract webSocketDebuggerUrl
3. Parse WebSocket URL, connect via IO::Socket::INET
4. Perform WebSocket handshake (RFC 6455)
5. Send CDP commands as JSON frames
6. Receive responses and events
7. On shutdown, close socket and kill Chrome
```

## Error Handling

| Error | Behavior |
|-------|----------|
| Chrome not found | Return install instructions for platform |
| Port in use | Try next port (9223, 9224, ...) or connect to existing |
| Connection lost | Attempt reconnect, restart Chrome if needed |
| Command timeout | Configurable timeout, clear error message |
| Invalid selector | Return helpful error with suggestions |

## Configuration

Environment variables:
- `CHROME_DRIVER_PORT` - Debugging port (default: 9222)
- `CHROME_DRIVER_BIN` - Chrome binary path override
- `CHROME_DRIVER_PROFILE` - Default profile directory
- `CHROME_DRIVER_TIMEOUT` - Default timeout in ms (default: 30000)
- `CHROME_DRIVER_HEADLESS` - Run headless (default: true)

## Slash Commands

### /browser
```
/browser              # Show status (running, URL, etc.)
/browser start        # Start Chrome
/browser stop         # Stop Chrome
/browser restart      # Restart Chrome
```

### /screenshot
```
/screenshot https://example.com              # Save to auto-named file
/screenshot https://example.com page.png     # Save to specific file
/screenshot --full-page https://example.com  # Full page capture
```

### /pdf
```
/pdf https://example.com                     # Save to auto-named file
/pdf https://example.com doc.pdf             # Save to specific file
/pdf --landscape https://example.com         # Landscape orientation
```

### /extract
```
/extract https://example.com                 # Extract as markdown
/extract --html https://example.com          # Extract as HTML
/extract --text https://example.com          # Extract as plain text
```

## Hooks

### Session Cleanup
```json
{
  "hooks": [
    {
      "event": "session_end",
      "command": "chrome-driver-daemon stop"
    }
  ]
}
```

## Success Criteria

1. **Zero dependencies** - Works with only Perl 5.14+ standard modules
2. **Cross-platform** - Runs on macOS, Linux, WSL without modification
3. **Self-contained** - No npm, pip, or cpan installation required
4. **LLM-friendly** - Clear tool names, helpful errors, interactive help
5. **Composable** - Small tools that combine for complex workflows
6. **Reliable** - Proper cleanup, no zombie Chrome processes
7. **Documented** - Comprehensive help available to the LLM

## Non-Goals

- Windows native support (use WSL)
- Firefox/Safari support (Chrome/Chromium only)
- GUI interface (CLI and LLM tools only)
- Parallel page handling (single page focus for simplicity)
