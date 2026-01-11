---
description: Record screencast frames from a web page
allowed-tools: [Bash]
argument-hint: URL OUTPUT_DIR [--duration=SECONDS] [--count=N]
---

# Record

Record screencast frames from a web page for video generation.

Parse the user's request and run:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/record URL OUTPUT_DIR [OPTIONS]
```

Options:
- `--duration=SECONDS` - Recording duration (default: 5)
- `--count=N` - Exact number of frames to capture
- `--format=jpeg|png` - Frame format (default: jpeg)
- `--quality=N` - JPEG quality 0-100 (default: 80)
- `--max-width=N` - Maximum frame width
- `--max-height=N` - Maximum frame height
- `--fps=N` - Approximate frames per second (default: 10)
- `--no-headless` - Run with visible browser window
- `--user-data=PATH` - Use persistent Chrome profile

Examples:
```bash
# Record 5 seconds
${CLAUDE_PLUGIN_ROOT}/bin/record https://example.com /tmp/frames

# Record 30 PNG frames
${CLAUDE_PLUGIN_ROOT}/bin/record https://example.com /tmp/frames --count=30 --format=png

# High quality recording
${CLAUDE_PLUGIN_ROOT}/bin/record https://example.com /tmp/frames --duration=10 --quality=95

# Convert to video with ffmpeg
ffmpeg -framerate 10 -i /tmp/frames/frame-%04d.jpg -c:v libx264 output.mp4
```
