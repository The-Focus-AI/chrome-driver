# chrome-driver Implementation Plan

## Phase 1: Core WebSocket & CDP Communication

**Goal:** Establish reliable communication with Chrome DevTools Protocol

### Step 1.1: WebSocket Frame Implementation
- [ ] Create `lib/CDP/Frame.pm` with RFC 6455 frame encoding/decoding
- [ ] Implement client-side masking (required for client→server)
- [ ] Handle text frames (opcode 0x01)
- [ ] Handle close/ping/pong frames
- [ ] Support fragmented messages
- [ ] Unit tests for frame encoding/decoding

### Step 1.2: WebSocket Connection
- [ ] Create `lib/CDP/Connection.pm`
- [ ] HTTP upgrade handshake using `IO::Socket::INET`
- [ ] Sec-WebSocket-Key generation with `Digest::SHA`
- [ ] Verify Sec-WebSocket-Accept response
- [ ] Non-blocking read with `IO::Select`
- [ ] Reconnection logic
- [ ] Unit tests with mock server

### Step 1.3: CDP Protocol Handler
- [ ] Create `lib/CDP/Protocol.pm`
- [ ] Message ID tracking for request/response correlation
- [ ] JSON-RPC message formatting
- [ ] Response callback system
- [ ] Error handling and timeouts
- [ ] Unit tests for message flow

### Step 1.4: CDP Event System
- [ ] Create `lib/CDP/Events.pm`
- [ ] Event subscription management
- [ ] Event callback dispatch
- [ ] Common event handlers (page load, console, etc.)
- [ ] Unit tests for event handling

**Deliverable:** Can send CDP commands and receive responses/events

---

## Phase 2: Browser Lifecycle Management

**Goal:** Reliably start, stop, and manage Chrome processes

### Step 2.1: Chrome Detection
- [ ] Create `lib/Browser/Launcher.pm`
- [ ] Detect Chrome on macOS (multiple locations)
- [ ] Detect Chrome/Chromium on Linux (via PATH and common locations)
- [ ] Detect Chrome in WSL (Windows paths)
- [ ] Version detection
- [ ] Return helpful errors if not found

### Step 2.2: Chrome Launch
- [ ] Build command line with required flags
- [ ] `--remote-debugging-port=PORT`
- [ ] `--headless=new` (or `--headless` for older Chrome)
- [ ] `--disable-gpu` (for headless)
- [ ] `--no-first-run`, `--no-default-browser-check`
- [ ] User data directory handling
- [ ] Spawn process, capture PID

### Step 2.3: Lifecycle Management
- [ ] Create `lib/Browser/Lifecycle.pm`
- [ ] PID file for tracking (`/tmp/chrome-driver.pid`)
- [ ] Health check endpoint polling
- [ ] Graceful shutdown (SIGTERM, then SIGKILL)
- [ ] Zombie process cleanup
- [ ] Port conflict resolution

### Step 2.4: Connection Bootstrap
- [ ] HTTP GET to `http://localhost:PORT/json/version`
- [ ] Parse `webSocketDebuggerUrl`
- [ ] Connect via WebSocket
- [ ] Initial page target selection

**Deliverable:** Can auto-start Chrome, connect, and clean up on exit

---

## Phase 3: Navigation & Page Basics

**Goal:** Navigate to URLs and wait for page load

### Step 3.1: Navigation
- [ ] Create `lib/Page/Navigation.pm`
- [ ] `navigate(url)` - go to URL
- [ ] Wait for `Page.loadEventFired`
- [ ] Handle navigation errors (404, timeout, etc.)
- [ ] `reload()`, `back()`, `forward()`
- [ ] `current_url()`

### Step 3.2: Page State
- [ ] `wait_for_navigation(timeout)`
- [ ] `wait_for_selector(selector, timeout)`
- [ ] `wait_for_function(js, timeout)`
- [ ] Network idle detection

**Deliverable:** Can navigate to pages and wait for them to load

---

## Phase 4: Content Extraction

**Goal:** Extract page content in various formats

### Step 4.1: Raw Content
- [ ] Create `lib/Page/Content.pm`
- [ ] `get_html()` - full page HTML via `DOM.getDocument` + `DOM.getOuterHTML`
- [ ] `get_html(selector)` - element HTML
- [ ] Handle iframes (optional)

### Step 4.2: Text Extraction
- [ ] `get_text()` - visible text via JS execution
- [ ] Whitespace normalization
- [ ] Hidden element filtering

### Step 4.3: Markdown Conversion
- [ ] Create `lib/Markdown/Converter.pm`
- [ ] Parse HTML (basic regex or manual parsing, no external deps)
- [ ] Convert headings (h1-h6 → #-######)
- [ ] Convert links (`<a>` → `[text](url)`)
- [ ] Convert lists (ul/ol → -/1.)
- [ ] Convert tables (basic table support)
- [ ] Convert emphasis (b/strong → **, i/em → *)
- [ ] Convert code blocks (pre/code → ```)
- [ ] Convert images (`<img>` → `![alt](src)`)
- [ ] Strip scripts, styles, hidden elements

**Deliverable:** Can extract HTML, text, and markdown from pages

---

## Phase 5: Visual Capture

**Goal:** Take screenshots and capture frame sequences

### Step 5.1: Screenshots
- [ ] Create `lib/Page/Screenshot.pm`
- [ ] `screenshot(options)` via `Page.captureScreenshot`
- [ ] Format support (png, jpeg, webp)
- [ ] Quality setting
- [ ] Full page vs viewport
- [ ] Element screenshot (clip to element bounds)
- [ ] Save to file (MIME::Base64 decode)

### Step 5.2: Screencast
- [ ] `screencast_start(options)` via `Page.startScreencast`
- [ ] Frame event handling (`Page.screencastFrame`)
- [ ] Frame acknowledgment
- [ ] `screencast_frame()` - get next frame
- [ ] `screencast_stop()` - end and return frame list

**Deliverable:** Can capture screenshots and frame sequences

---

## Phase 6: PDF Generation

**Goal:** Print pages to PDF with full option control

### Step 6.1: PDF Printing
- [ ] Create `lib/Page/PDF.pm`
- [ ] `print_pdf(options)` via `Page.printToPDF`
- [ ] All options: paper size, margins, scale, orientation
- [ ] Header/footer templates
- [ ] Background graphics
- [ ] Page ranges
- [ ] Save to file

**Deliverable:** Can generate PDFs with full control over options

---

## Phase 7: DOM Interaction

**Goal:** Click, type, and interact with page elements

### Step 7.1: Element Queries
- [ ] Create `lib/DOM/Query.pm`
- [ ] `query_selector(selector)` - find single element
- [ ] `query_selector_all(selector)` - find all matching
- [ ] Element handle management
- [ ] Selector validation

### Step 7.2: High-Level Actions
- [ ] Create `lib/DOM/Actions.pm`
- [ ] `click(selector)` - click element center
- [ ] `type(selector, text)` - focus and type
- [ ] `select(selector, value)` - select dropdown option
- [ ] `hover(selector)` - mouse over
- [ ] `focus(selector)` - focus element
- [ ] `scroll_to(selector)` - scroll element into view

### Step 7.3: Input Events
- [ ] `Input.dispatchMouseEvent` for clicks
- [ ] `Input.dispatchKeyEvent` for typing
- [ ] Handle special keys (Enter, Tab, etc.)
- [ ] Modifier keys (Shift, Ctrl, etc.)

**Deliverable:** Can interact with page elements naturally

---

## Phase 8: JavaScript Execution

**Goal:** Execute JavaScript and retrieve results

### Step 8.1: JS Evaluation
- [ ] Create `lib/DOM/Evaluate.pm`
- [ ] `evaluate(js)` via `Runtime.evaluate`
- [ ] Return value serialization
- [ ] Error handling (exceptions)
- [ ] `evaluate_async(js)` for promises
- [ ] `evaluate_on(selector, function)` - run on element

### Step 8.2: Raw CDP Access
- [ ] `cdp_send(method, params)` - any CDP command
- [ ] `cdp_subscribe(event)` - listen to events
- [ ] `cdp_unsubscribe(event)` - stop listening

**Deliverable:** Full JavaScript and CDP access

---

## Phase 9: Session Management

**Goal:** Handle cookies and authentication

### Step 9.1: Cookie Management
- [ ] Create `lib/Session/Cookies.pm`
- [ ] `cookies_get(domain?)` via `Network.getCookies`
- [ ] `cookies_set(cookies)` via `Network.setCookies`
- [ ] `cookies_clear(domain?)` via `Network.deleteCookies`
- [ ] `cookies_save(path)` - export to JSON file
- [ ] `cookies_load(path)` - import from JSON file

### Step 9.2: Profile Management
- [ ] Create `lib/Browser/Profile.pm`
- [ ] `profile_set(path)` - use Chrome profile directory
- [ ] Profile directory structure
- [ ] Persistent login handling

**Deliverable:** Can save/restore sessions and use profiles

---

## Phase 10: Network Module (Optional)

**Goal:** Monitor and intercept network traffic

### Step 10.1: Network Monitoring
- [ ] Create `lib/Network/Monitor.pm`
- [ ] `network_enable()` via `Network.enable`
- [ ] Capture `Network.requestWillBeSent`
- [ ] Capture `Network.responseReceived`
- [ ] `network_requests()` - return captured requests
- [ ] `network_responses()` - return captured responses
- [ ] `network_disable()` - stop capturing

### Step 10.2: Network Interception
- [ ] Create `lib/Network/Intercept.pm`
- [ ] `Fetch.enable` for interception
- [ ] `network_block(patterns)` - block matching URLs
- [ ] `network_mock(pattern, response)` - return fake data
- [ ] `network_throttle(profile)` - simulate slow network

**Deliverable:** Can monitor and manipulate network traffic

---

## Phase 11: Help System

**Goal:** Provide interactive documentation to the LLM

### Step 11.1: Help Tool
- [ ] `browser_help()` - list all tools with brief descriptions
- [ ] `browser_help(topic)` - detailed help for specific tool
- [ ] `browser_help('examples')` - common usage patterns
- [ ] `browser_help('cdp')` - raw CDP reference
- [ ] Format output for LLM consumption

**Deliverable:** LLM can get help on any tool

---

## Phase 12: Plugin Packaging

**Goal:** Package as Claude Code plugin

### Step 12.1: Skill Definition
- [ ] Create `skills/browser-automation/SKILL.md`
- [ ] Write clear description with trigger phrases
- [ ] Document all available tools
- [ ] Include usage examples
- [ ] Create `examples.md` with common patterns
- [ ] Create `cdp-reference.md` for advanced use

### Step 12.2: Slash Commands
- [ ] Create `commands/browser.md` - status/control
- [ ] Create `commands/screenshot.md` - quick screenshot
- [ ] Create `commands/pdf.md` - quick PDF
- [ ] Create `commands/extract.md` - quick extraction

### Step 12.3: Hooks
- [ ] Create `hooks/hooks.json`
- [ ] Session end cleanup hook
- [ ] Create cleanup daemon script

### Step 12.4: Plugin Manifest
- [ ] Create `.claude-plugin/plugin.json`
- [ ] README.md with installation instructions

**Deliverable:** Complete, installable Claude Code plugin

---

## Phase 13: Testing & Polish

**Goal:** Ensure reliability and good UX

### Step 13.1: Integration Tests
- [ ] End-to-end navigation tests
- [ ] Screenshot capture tests
- [ ] PDF generation tests
- [ ] Content extraction tests
- [ ] Interaction tests

### Step 13.2: Error Messages
- [ ] Review all error messages for clarity
- [ ] Add suggestions for common issues
- [ ] Platform-specific help

### Step 13.3: Documentation
- [ ] Complete README.md
- [ ] Usage examples
- [ ] Troubleshooting guide

**Deliverable:** Production-ready plugin

---

## Implementation Order

1. **Phases 1-2** (Core) - Must work first, everything depends on this
2. **Phase 3** (Navigation) - Basic functionality
3. **Phase 4** (Content) - Primary use case
4. **Phase 5-6** (Visual/PDF) - Common features
5. **Phase 7-8** (Interaction) - Advanced use
6. **Phase 9** (Session) - Authentication support
7. **Phase 11** (Help) - LLM usability
8. **Phase 12** (Plugin) - Packaging
9. **Phase 10** (Network) - Optional, last
10. **Phase 13** (Polish) - Final pass

## Estimated Complexity

| Phase | Files | Lines (est.) | Complexity |
|-------|-------|--------------|------------|
| 1. CDP Core | 4 | 600-800 | High |
| 2. Lifecycle | 3 | 300-400 | Medium |
| 3. Navigation | 1 | 150-200 | Low |
| 4. Content | 2 | 400-500 | Medium |
| 5. Visual | 1 | 200-250 | Medium |
| 6. PDF | 1 | 100-150 | Low |
| 7. DOM | 3 | 300-400 | Medium |
| 8. JavaScript | 1 | 150-200 | Low |
| 9. Session | 2 | 150-200 | Low |
| 10. Network | 2 | 250-300 | Medium |
| 11. Help | 1 | 200-250 | Low |
| 12. Plugin | 6 | 200-300 | Low |
| 13. Testing | 5 | 400-500 | Medium |

**Total:** ~3,500-4,500 lines of Perl + documentation
