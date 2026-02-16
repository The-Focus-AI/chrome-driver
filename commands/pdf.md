---
description: Generate a PDF from a web page
allowed-tools: [Bash]
argument-hint: URL [OUTPUT] [--paper=a4|letter] [--landscape]
---

# PDF Generation

Generate a PDF from a web page.

Parse the user's request and run:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/pdf URL [OUTPUT] [OPTIONS]
```

Options:
- `--paper=SIZE` - Paper size: letter (default), a4, legal, a3, a5, tabloid
- `--landscape` - Landscape orientation
- `--margin=INCHES` - All margins (default: 0.4)
- `--scale=FACTOR` - Scale 0.1-2.0 (default: 1.0)
- `--no-background` - Skip background colors/images

If no output path given, file saves to `/tmp/page-TIMESTAMP.pdf`.

Examples:
```bash
${CLAUDE_PLUGIN_ROOT}/bin/pdf https://example.com /tmp/doc.pdf
${CLAUDE_PLUGIN_ROOT}/bin/pdf https://example.com --paper=a4 --landscape
${CLAUDE_PLUGIN_ROOT}/bin/pdf https://example.com --margin=1 --scale=0.8
```
