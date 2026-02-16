---
description: Manage browser cookies and sessions
allowed-tools: [Bash]
argument-hint: [save|load|clear] [--file=PATH]
---

# Cookies

Manage browser cookies for session persistence across automation runs.

Parse the user's request and run:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/cookies [COMMAND] [OPTIONS]
```

Commands:
- `save` - Save current cookies to file
- `load` - Load cookies from file
- `clear` - Clear all cookies
- `list` - List current cookies

Options:
- `--file=PATH` - Cookie file path (default: cookies.json)
- `--domain=DOMAIN` - Filter by domain
- `--no-headless` - Run with visible browser window
- `--user-data=PATH` - Use persistent Chrome profile

Examples:
```bash
# Save cookies after logging in
${CLAUDE_PLUGIN_ROOT}/bin/cookies save --file=~/.instacart-cookies.json

# Load cookies for authenticated session
${CLAUDE_PLUGIN_ROOT}/bin/cookies load --file=~/.instacart-cookies.json

# List cookies for a specific domain
${CLAUDE_PLUGIN_ROOT}/bin/cookies list --domain=instacart.com

# Clear all cookies
${CLAUDE_PLUGIN_ROOT}/bin/cookies clear
```

Note: For most use cases, `--user-data=PATH` is preferred over cookie files as it preserves the full browser profile including localStorage and session state.
