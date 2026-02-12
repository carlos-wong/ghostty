# Ghostty `+new-tab` CLI Command

## Overview

`ghostty +new-tab` allows external programs and scripts to open a new tab in a running Ghostty terminal instance via IPC (Inter-Process Communication).

- If Ghostty is **already running**, it opens a new tab in the existing window
- If Ghostty is **not running**, macOS will launch Ghostty first, then open the tab

## Usage

```bash
# Open a new tab with default shell
ghostty +new-tab

# Open a new tab and run a command
ghostty +new-tab -e vim

# Open a new tab and run a command with arguments
ghostty +new-tab -e htop

# Open a new tab and run a shell command
ghostty +new-tab -e bash -c "echo hello && sleep 5"
```

## Flags

| Flag | Description |
|------|-------------|
| `-e <command> [args...]` | Execute the given command in the new tab. All arguments after `-e` are treated as the command and its arguments. If omitted, uses the default shell. |
| `--class=<class>` | Connect to a specific Ghostty instance (GTK only, must be a valid GTK application ID). |
| `-h` / `--help` | Show help information. |

## Platform Support

| Platform | IPC Mechanism | Status |
|----------|--------------|--------|
| macOS | URL Scheme (`ghostty://`) | Supported |
| Linux (GTK) | D-Bus | Supported |

## Integration Examples

### Shell Script

```bash
#!/bin/bash
# Open multiple tabs for a development environment
ghostty +new-tab -e nvim .
ghostty +new-tab -e npm run dev
ghostty +new-tab -e tail -f /var/log/app.log
```

### Alfred / Raycast Workflow

```bash
# Use as a custom action to open a terminal tab with a specific command
/Applications/Ghostty.app/Contents/MacOS/ghostty +new-tab -e ssh myserver
```

### Automator / AppleScript

```applescript
do shell script "/Applications/Ghostty.app/Contents/MacOS/ghostty +new-tab -e top"
```

### macOS URL Scheme (Direct)

You can also use the URL scheme directly:

```bash
# Open a new tab
open "ghostty://new-tab"

# Open a new tab with a command
open "ghostty://new-tab?e=vim"

# Open a new window with a command
open "ghostty://new-window?e=htop"
```

### Keyboard Shortcut (Karabiner-Elements / skhd)

```yaml
# skhd example
ctrl + alt - t : ghostty +new-tab
ctrl + alt - n : ghostty +new-window
```

### Python

```python
import subprocess
subprocess.run(["ghostty", "+new-tab", "-e", "python3"])
```

### Node.js

```javascript
const { execSync } = require('child_process');
execSync('ghostty +new-tab -e node');
```

## Related Commands

- `ghostty +new-window` — Open a new window (instead of a tab)
- `ghostty +help` — Show all available CLI actions

## How It Works (macOS)

```
ghostty +new-tab -e vim
  → CLI parses -e arguments
  → Builds URL: ghostty://new-tab?e=vim
  → Executes: open "ghostty://new-tab?e=vim"
  → macOS routes URL to Ghostty.app
  → AppDelegate handles URL → creates new tab
```

The `ghostty://` URL scheme is registered in `Ghostty-Info.plist`. macOS automatically handles both cases:
- **Ghostty running**: sends the URL to the existing instance
- **Ghostty not running**: launches Ghostty, then delivers the URL
