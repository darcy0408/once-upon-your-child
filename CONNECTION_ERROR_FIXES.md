# Connection Error Troubleshooting Guide

## Issues Identified

### 1. **MCP Server Connection Errors**
Your `opencode.json` has remote MCP servers that may be failing:
- `context7` (https://mcp.context7.com/mcp) - Requires `CONTEXT7_API_KEY`
- `gh_grep` (https://mcp.grep.app) - May require authentication

### 2. **Python Jedi Language Server Crashes**
The Python language server is crashing repeatedly, which can cause IDE connection issues.

### 3. **Chrome DevTools MCP**
The chrome-devtools MCP server may be trying to connect when Chrome isn't available.

## Quick Fixes

### Fix 1: Disable Problematic MCP Servers (Temporary)
Edit `opencode.json` and disable remote servers:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": false,  // ← Change to false
      "headers": {
        "CONTEXT7_API_KEY": "{env:CONTEXT7_API_KEY}"
      }
    },
    "gh_grep": {
      "type": "remote", 
      "url": "https://mcp.grep.app",
      "enabled": false  // ← Change to false
    }
  }
}
```

### Fix 2: Restart Python Language Server
1. In VS Code/Cursor: `Ctrl+Shift+P` → "Python: Restart Language Server"
2. Or reload window: `Ctrl+Shift+P` → "Developer: Reload Window"

### Fix 3: Check Backend Connection
Ensure your Flask backend is running:
```bash
# Check if backend is running
curl http://127.0.0.1:5000/health
```

### Fix 4: Verify MCP Server Requirements
If you need the MCP servers:
- Set `CONTEXT7_API_KEY` environment variable (if using context7)
- Ensure you have internet connectivity
- Check firewall/VPN settings

## Recommended Action
Disable remote MCP servers you're not actively using to reduce connection attempts.




