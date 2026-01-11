---
description: Fill out and submit web forms
allowed-tools: [Bash]
argument-hint: URL [--fill=SELECTOR=VALUE] [--submit=SELECTOR]
---

# Form

Fill out and submit web forms.

Parse the user's request and run:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/form URL [OPTIONS]
```

Options:
- `--fill=SELECTOR=VALUE` - Fill input field (can repeat)
- `--select=SELECTOR=VALUE` - Select dropdown option (can repeat)
- `--fill-json='{"sel":"val"}'` - Fill multiple fields from JSON
- `--submit=SELECTOR` - Click submit button after filling
- `--wait-for=SELECTOR` - Wait for element before filling
- `--wait-after=SELECTOR` - Wait for element after submit
- `--screenshot=PATH` - Take screenshot after completion
- `--no-headless` - Run with visible browser window
- `--user-data=PATH` - Use persistent Chrome profile

Examples:
```bash
# Login form
${CLAUDE_PLUGIN_ROOT}/bin/form https://example.com/login \
  --fill='#username=john' \
  --fill='#password=secret' \
  --submit='button[type=submit]'

# Form with dropdowns
${CLAUDE_PLUGIN_ROOT}/bin/form https://example.com/register \
  --fill='#name=John Doe' \
  --select='#country=US' \
  --submit='#register-btn'

# Using JSON for multiple fields
${CLAUDE_PLUGIN_ROOT}/bin/form https://example.com/contact \
  --fill-json='{"#name":"John","#email":"john@test.com"}' \
  --submit='button.send'
```
