---
description: Extract content from a web page
allowed-tools: [Bash]
argument-hint: URL [--format=markdown|text|html] [--selector=CSS]
---

# Content Extraction

Extract content from a web page in various formats.

Parse the user's request and run:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/extract URL [OPTIONS]
```

Options:
- `--format=FORMAT` - Output: markdown (default), text, html
- `--selector="CSS"` - Extract specific element only
- `--links` - Also list all links found
- `--images` - Also list all images found
- `--metadata` - Also show page metadata

Examples:
```bash
${CLAUDE_PLUGIN_ROOT}/bin/extract https://example.com
${CLAUDE_PLUGIN_ROOT}/bin/extract https://example.com --format=text
${CLAUDE_PLUGIN_ROOT}/bin/extract https://example.com --selector="article.main"
${CLAUDE_PLUGIN_ROOT}/bin/extract https://example.com --links --metadata
```

The extracted content is printed to stdout.
