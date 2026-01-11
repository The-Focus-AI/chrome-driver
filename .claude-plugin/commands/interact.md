---
description: Interact with current page without reloading (for multi-step workflows)
allowed-tools: [Bash]
argument-hint: [--click=SELECTOR] [--type=SELECTOR=TEXT] [--eval=JS]
---

# Interact

Interact with the current browser page WITHOUT navigating away. Essential for multi-step workflows on SPAs.

**Key difference from navigate**: This command works on the already-open tab without reloading the page, preserving state between actions.

Parse the user's request and run:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/interact [OPTIONS]
```

Options:
- `--click=SELECTOR` - Click element matching CSS selector
- `--type=SELECTOR=TEXT` - Type text into input field
- `--eval=JAVASCRIPT` - Execute JavaScript and print result
- `--wait-for=SELECTOR` - Wait for element to appear
- `--select=SELECTOR=VALUE` - Select dropdown option
- `--focus=SELECTOR` - Focus an element
- `--text=SELECTOR` - Get text content of element
- `--timeout=SECONDS` - Timeout (default: 30)
- `--no-headless` - Run with visible browser window
- `--user-data=PATH` - Use persistent Chrome profile (required for session continuity)

Examples:
```bash
# Execute JavaScript on current page
${CLAUDE_PLUGIN_ROOT}/bin/interact --eval="document.title" --user-data=~/.chrome-session

# Click a button without navigating
${CLAUDE_PLUGIN_ROOT}/bin/interact --click="#submit-btn" --user-data=~/.chrome-session

# Chain actions: type then click
${CLAUDE_PLUGIN_ROOT}/bin/interact --type="#search=query" --click="#search-btn" --user-data=~/.chrome-session

# Get text from an element
${CLAUDE_PLUGIN_ROOT}/bin/interact --text="h1.title" --user-data=~/.chrome-session
```
