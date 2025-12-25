# Setting Up Browser Automation MCP Server

This guide shows you how to set up an MCP server that allows me to control a browser for testing your Pick-A-Path Adventures app.

## Prerequisites

1. **Install Node.js** (if not already installed)
   ```bash
   node --version  # Should be v18 or higher
   ```

2. **Install Playwright**
   ```bash
   npm install playwright
   npx playwright install chromium
   ```

## Setup Steps

### Step 1: Install Dependencies

```bash
cd C:\dev\story-weaver-app
npm install playwright
npx playwright install chromium
```

### Step 2: Update MCP Configuration

I've created two MCP configuration files. Choose one based on your setup:

#### Option A: For Cursor/Claude Desktop (`.claude/mcp.json`)

The file already exists. Add the browser server:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "chrome-devtools-mcp@latest",
        "--headless"
      ]
    },
    "browser-automation": {
      "command": "node",
      "args": ["C:\\dev\\story-weaver-app\\mcp-browser-server.js"]
    }
  }
}
```

#### Option B: For OpenCode (`opencode.json`)

Add to your `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "browser-automation": {
      "type": "local",
      "command": ["node", "mcp-browser-server.js"],
      "enabled": true
    }
  },
  "tools": {
    "browser-automation": true
  }
}
```

### Step 3: Restart Your IDE

After updating the MCP configuration:
1. **Restart Cursor** (or your IDE)
2. The MCP server should automatically start

### Step 4: Verify Setup

Once restarted, I should have access to browser automation tools. You can verify by asking me to:
- "Launch a browser and navigate to google.com"
- "Take a screenshot of the current page"

## What I Can Do With This MCP Server

Once set up, I'll be able to:

1. **Launch Browsers**
   - Chrome, Firefox, or WebKit
   - Headless or visible mode

2. **Navigate & Interact**
   - Navigate to URLs
   - Click elements
   - Fill forms
   - Wait for elements

3. **Test Your Flutter App**
   - Start Flutter app in browser
   - Navigate through wizard
   - Enable Interactive Mode
   - Make choices in Pick-A-Path
   - Take screenshots
   - Verify UI elements

4. **Automated Testing**
   - Run full test suites
   - Generate test reports
   - Take screenshots for documentation

## Example Usage

Once set up, I can run commands like:

```
"Launch Chrome, navigate to localhost:8080, click the 'Create Story' button, 
fill in character name 'TestHero', enable Interactive Mode, and take a screenshot"
```

## Troubleshooting

### MCP Server Not Starting

1. **Check Node.js is installed:**
   ```bash
   node --version
   ```

2. **Check Playwright is installed:**
   ```bash
   npx playwright --version
   ```

3. **Check file permissions:**
   - Ensure `mcp-browser-server.js` is executable
   - On Windows, you may need to run: `chmod +x mcp-browser-server.js`

### Browser Won't Launch

1. **Install browser binaries:**
   ```bash
   npx playwright install chromium
   ```

2. **Check firewall settings** - Playwright may need network access

### MCP Tools Not Appearing

1. **Restart your IDE** after updating MCP config
2. **Check MCP server logs** in your IDE's output panel
3. **Verify the path** to `mcp-browser-server.js` is correct

## Alternative: Simpler Setup

If the MCP server setup is complex, I can also:

1. **Use Flutter integration tests** (already created)
2. **Generate test scripts** you can run manually
3. **Use existing chrome-devtools MCP** (already configured)

Let me know which approach you prefer!

