# Playwright MCP Server Plugin

Browser automation and testing with Playwright via Model Context Protocol.

## What This Plugin Does

Adds Playwright browser automation capabilities to Claude Code through an MCP server. Enables automated browser testing, web scraping, and interaction with web applications.

## Features

- **Browser automation** - Control Chrome, Firefox, and WebKit browsers
- **End-to-end testing** - Automate testing workflows
- **Web scraping** - Extract data from web pages
- **Screenshots and PDFs** - Capture page content
- **Cross-browser support** - Test across multiple browsers

## Requirements

- **Node.js** - Required for npx
- **Browsers** - Playwright will download required browsers on first use

## Installation

### Install the Plugin

```bash
# Add the marketplace
/plugin marketplace add dkmaker/my-claude-plugins

# Install the Playwright plugin
/plugin install my-claude-plugins/playwright
```

Restart Claude Code after installation.

## Usage

Once installed, Claude Code can use Playwright for browser automation tasks.

Example prompts:
```
"Test if the login flow works on example.com"
"Take a screenshot of the homepage"
"Check if the search feature returns results"
"Verify that the checkout process completes successfully"
```

## MCP Server Details

- **Server Type:** stdio
- **Command:** `npx -y @playwright/mcp@latest`
- **Package:** `@playwright/mcp`

The plugin uses npx to automatically download and run the latest version of the Playwright MCP server.

## Troubleshooting

### Plugin Not Working

1. **Verify Node.js is installed:**
   ```bash
   node --version
   npx --version
   ```

2. **Test the MCP server directly:**
   ```bash
   npx -y @playwright/mcp@latest
   ```

3. **Check browser installation:**
   On first use, Playwright will download required browsers automatically.

### Browser Issues

If browsers aren't working:

```bash
# Install browsers manually
npx playwright install
```

## Documentation

- [Playwright Documentation](https://playwright.dev)
- [Playwright GitHub](https://github.com/microsoft/playwright)
- [MCP Server Package](https://www.npmjs.com/package/@playwright/mcp)

## Version

**1.0.0**

## License

Apache-2.0 - See [Playwright's repository](https://github.com/microsoft/playwright) for details.
