# Context7 MCP Server - Expansion Guide

Context7 is a Model Context Protocol (MCP) server designed to provide up-to-date documentation and context for the libraries and frameworks used in the Story Weaver project.

## How to Add New Documentation Sources

To add a new library or framework to Context7, follow these steps:

1.  **Open `context7-server.js`** in the project root.
2.  Locate the `documentationSources` object at the top of the file.
3.  Add a new entry with a unique key, descriptive name, clear description, and the official documentation URL.

Example:
```javascript
  'flutter_animate': {
    name: 'flutter_animate',
    description: 'Documentation for the Flutter Animate library for beautiful animations.',
    url: 'https://pub.dev/packages/flutter_animate',
  },
```

## How the MCP Protocol Works here

- **`tools/list`**: This method iterates over the `documentationSources` keys and presents them as available tools to the AI.
- **`tools/call`**: When a tool is called (e.g., `google_generative_ai_dart`), the server returns the corresponding URL from the mapping.

## Advanced Expansions

### 1. Keyword-based Search
You can modify the `inputSchema` in `tools/list` to accept a `query` parameter and update `tools/call` to append that query to the documentation URL (if the source supports search parameters).

### 2. Deep Link Mapping
Instead of just a root URL, you can create a nested mapping for common sub-topics (e.g., `riverpod_providers`, `riverpod_hooks`) to provide even more precise context.

### 3. Dynamic Scraping (Future)
If integrated with a library like `playwright` or `cheerio`, the server could theoretically scrape the documentation pages and return relevant snippets directly as text, further reducing token usage for the AI.

## Deploying Changes

Since this is a local MCP server:
1. Save `context7-server.js`.
2. Ensure your MCP client (like Gemini CLI or Claude Desktop) is configured to point to this file.
3. Restart your MCP session to pick up the new tools.

---
*Maintained by the Story Weaver Development Team.*
