---
description: Take a screenshot of a web page
allowed-tools: [Bash]
argument-hint: URL [OUTPUT] [--full-page] [--selector=CSS] [--format=png|jpeg]
---

# Screenshot

Take a screenshot of a web page.

Parse the user's request and run:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/screenshot URL [OUTPUT] [OPTIONS]
```

Options:
- `--full-page` - Capture entire scrollable page
- `--selector="CSS"` - Capture specific element
- `--format=png|jpeg|webp` - Output format (default: png)
- `--quality=N` - JPEG/WebP quality 0-100 (default: 80)
- `--width=N --height=N` - Set viewport size

If no output path given, file saves to `/tmp/screenshot-TIMESTAMP.png`.

Examples:
```bash
${CLAUDE_PLUGIN_ROOT}/bin/screenshot https://example.com /tmp/page.png
${CLAUDE_PLUGIN_ROOT}/bin/screenshot https://example.com --full-page --format=jpeg
${CLAUDE_PLUGIN_ROOT}/bin/screenshot https://example.com --selector="article.main"
```
