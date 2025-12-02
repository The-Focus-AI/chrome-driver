# GitHub Copilot Instructions for chrome-driver

## Project Overview

**chrome-driver** is a Claude Code plugin that enables LLMs to interact with web pages via Chrome DevTools Protocol, implemented in pure Perl with zero external dependencies.

**Key Features:**
- Pure Perl implementation (5.14+, no CPAN dependencies)
- WebSocket & CDP communication
- Browser lifecycle management
- Content extraction (HTML, Markdown)
- Visual capture (screenshots, screencasts)
- PDF generation
- JavaScript execution
- Session management (cookies, profiles)

## Tech Stack

- **Language**: Perl 5.14+
- **Protocol**: Chrome DevTools Protocol over WebSocket
- **Standards**: RFC 6455 (WebSocket), JSON-RPC 2.0
- **Target Platforms**: macOS, Linux, WSL

## Coding Guidelines

### Perl Style
- Use strict and warnings
- Avoid CPAN dependencies (core modules only)
- Follow existing patterns in lib/ modules
- Add POD documentation for public functions
- Use Test::More for tests

### Testing
- Run tests with: `prove -Ilib t/`
- For Chrome integration tests: `CHROME_TEST=1 prove t/`
- Always test on clean state (kill orphan Chrome processes)
- Mock CDP responses when possible

### Code Structure
```
lib/
├── ChromeDriver.pm           # Main entry point
├── CDP/                      # Chrome DevTools Protocol
│   ├── Connection.pm         # WebSocket & messaging
│   ├── Protocol.pm           # CDP methods
│   ├── Events.pm             # Event handling
│   └── Frame.pm              # Frame management
├── Browser/                  # Browser lifecycle
│   ├── Launcher.pm           # Chrome detection & launch
│   └── Lifecycle.pm          # PID tracking, cleanup
├── Page/                     # Page operations
│   └── Navigation.pm         # Navigation & waiting
├── Content/                  # Content extraction
│   └── Extraction.pm         # HTML/Markdown
├── Visual/                   # Screenshots & video
│   └── Capture.pm            # Capture operations
├── Print/                    # PDF generation
│   └── PDF.pm                # PDF options
├── DOM/                      # DOM manipulation
│   └── Elements.pm           # Element operations
├── JS/                       # JavaScript execution
│   └── Execute.pm            # Script injection
├── Session/                  # Session management
│   └── Cookies.pm            # Cookie handling
└── Help/                     # Documentation
    └── Browser.pm            # Help system
```

## Issue Tracking with bd

**CRITICAL**: This project uses **bd (beads)** for ALL task tracking. Do NOT create markdown TODO lists.

### Essential Commands

```bash
# Find work
bd ready --json                    # Unblocked issues
bd list --status=open --json       # All open

# Create and manage
bd create "Title" -t bug|feature|task -p 0-4 --json
bd update <id> --status in_progress --json
bd close <id> --reason "Done" --json

# Search
bd show <id> --json
```

### Workflow

1. **Check ready work**: `bd ready --json`
2. **Claim task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** `bd create "Found bug" -p 1 --deps discovered-from:<parent-id> --json`
5. **Complete**: `bd close <id> --reason "Done" --json`
6. **Sync**: Changes auto-sync to `.beads/issues.jsonl`

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

## Development Workflow

### Working with Chrome
```bash
# Launch Chrome manually for testing
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-test

# Check WebSocket endpoint
curl http://localhost:9222/json/version

# Kill orphan Chrome processes
pkill -f 'chrome.*--remote-debugging-port'
```

### Testing
```bash
# Unit tests (no Chrome needed)
prove -Ilib t/unit/

# Integration tests (requires Chrome)
CHROME_TEST=1 prove -Ilib t/integration/

# Specific test
perl -Ilib t/01_connection.t
```

### Common Issues

**WebSocket handshake fails:**
- Check Chrome is running: `curl http://localhost:9222/json`
- Verify port is free: `lsof -i :9222`
- Check logs for SSL/certificate issues

**Module not found:**
- Ensure you're using `-Ilib` flag
- Check module path matches namespace

**Tests hang:**
- Kill orphan Chrome: `pkill -f 'chrome.*--remote-debugging-port'`
- Check for unclosed connections

## CLI Help

Run `bd <command> --help` to see all available flags for any command.
For example: `bd create --help` shows `--parent`, `--deps`, `--assignee`, etc.

## Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic bd commands
- ✅ Run tests before committing
- ✅ Use core Perl modules only (no CPAN)
- ✅ Run `bd <cmd> --help` to discover available flags
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT add CPAN dependencies
- ❌ Do NOT commit test databases or temp files

---

**For detailed workflows and advanced features, see [AGENTS.md](../AGENTS.md)**
