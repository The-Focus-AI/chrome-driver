---
description: Navigate to a URL and interact with the page
allowed-tools: [Bash]
argument-hint: URL [--wait-for=SELECTOR] [--click=SELECTOR] [--type=SELECTOR=TEXT]
---

# Navigate

Navigate to a URL and optionally interact with the page.

Parse the user's request and run:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/navigate URL [OPTIONS]
```

Options:
- `--wait-for=SELECTOR` - Wait for element to appear
- `--click=SELECTOR` - Click an element
- `--type=SELECTOR=TEXT` - Type text into input field
- `--eval=JAVASCRIPT` - Execute JavaScript and print result
- `--timeout=SECONDS` - Timeout (default: 30)
- `--no-headless` - Run with visible browser window
- `--user-data=PATH` - Use persistent Chrome profile

Examples:
```bash
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://example.com --wait-for="#content"
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://google.com --type="input[name=q]=hello" --click="input[type=submit]"
${CLAUDE_PLUGIN_ROOT}/bin/navigate https://example.com --eval="document.title"
```
