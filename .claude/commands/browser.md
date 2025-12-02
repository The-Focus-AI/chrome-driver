# Browser Control

Check browser status, start/stop Chrome, and manage connections.

## Usage

When the user types `/browser`, perform these actions:

1. **Check if Chrome is running:**
   ```bash
   curl -s http://localhost:9222/json/version
   ```

2. **If Chrome is not running, ask if they want to start it:**
   - If yes, start Chrome:
     ```bash
     google-chrome --remote-debugging-port=9222 --headless --user-data-dir=/tmp/chrome-profile &
     ```
   - Wait 2 seconds for Chrome to start
   - Verify it started successfully

3. **Display browser status:**
   - Chrome process ID (if available)
   - WebSocket debugging URL
   - Number of open pages/targets
   - User data directory

4. **Show available actions:**
   - Start Chrome (if not running)
   - Stop Chrome (if running)
   - Connect to a specific page
   - List all open tabs

## Example Output

```
Chrome Browser Status:

✓ Chrome is running
  Process ID: 12345
  Debugging Port: 9222
  WebSocket URL: ws://localhost:9222/devtools/browser/abc-123

Open Targets:
  1. https://example.com (page)
  2. about:blank (page)

Actions:
  - Use ChromeDriver->new() to connect
  - Use /screenshot for quick screenshot
  - Use /extract to get page content
  - Use /pdf to generate PDF

To stop Chrome: pkill -f 'chrome.*--remote-debugging-port'
```

## Notes

- Chrome must be running with `--remote-debugging-port=9222` for automation to work
- The browser will persist between commands unless explicitly stopped
- Use the browser-automation skill for complex interactions
