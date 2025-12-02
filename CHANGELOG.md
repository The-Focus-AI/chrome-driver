# Changelog

All notable changes to chrome-driver will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-02

### Added
- Initial release of chrome-driver
- Core ChromeDriver module with WebSocket and CDP communication
- Browser lifecycle management (auto-start, auto-stop, cleanup)
- Page navigation (goto, back, forward, reload)
- Content extraction (HTML, text, markdown, links, images, metadata)
- Visual capture (screenshots in PNG/JPEG/WebP formats)
- PDF generation with full control over paper size, margins, headers/footers
- DOM interaction (query, click, type, hover, scroll, wait)
- JavaScript execution (sync and async evaluation)
- Session management (cookie save/load, persistence)
- Interactive help system with comprehensive documentation
- Claude Code plugin with skills, slash commands, and hooks
- Pure Perl implementation (no CPAN dependencies, Perl 5.14+)
- Comprehensive test suite (197 tests)
- Full documentation (README, SPEC, TROUBLESHOOTING)

### Features
- **Zero Dependencies**: Works with standard Perl 5.14+ modules only
- **Platform Support**: macOS, Linux, WSL
- **Headless Mode**: Run without UI for automation
- **Auto-cleanup**: Session hooks ensure Chrome processes are terminated
- **Composable API**: Small, focused modules that work together
- **Self-documenting**: Built-in help system for on-demand docs

### Modules
- `ChromeDriver` - Core connection and CDP protocol
- `CDP::Connection` - WebSocket communication (RFC 6455)
- `CDP::Protocol` - CDP command methods
- `CDP::Events` - Event handling and subscriptions
- `CDP::Frame` - Frame management
- `Browser::Launcher` - Chrome detection and startup
- `Browser::Lifecycle` - Process tracking and cleanup
- `Page::Navigation` - Navigation operations
- `Content::Extraction` - Content extraction and conversion
- `Visual::Capture` - Screenshot capabilities
- `Print::PDF` - PDF generation
- `DOM::Elements` - DOM queries and interactions
- `JS::Execute` - JavaScript execution
- `Session::Cookies` - Cookie management
- `Help::Browser` - Interactive documentation

### Claude Code Integration
- Skill: `browser-automation` - Auto-activates for web tasks
- Commands: `/browser`, `/screenshot`, `/pdf`, `/extract`
- Hooks: Session cleanup for Chrome processes

### Documentation
- Complete README with examples and API reference
- SPEC.md with requirements and design philosophy
- IMPLEMENTATION.md with phase-by-phase build plan
- TROUBLESHOOTING.md with solutions for common issues
- Inline POD documentation in all modules
- Interactive help via `browser_help()` function

[0.1.0]: https://github.com/Focus-AI/chrome-driver/releases/tag/v0.1.0
