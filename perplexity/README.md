# Perplexity MCP Server Plugin

Real-time web search, reasoning, and research capabilities through Perplexity's API via Model Context Protocol.

## What This Plugin Does

Adds Perplexity AI's search and reasoning capabilities to Claude Code through an MCP server. Enables real-time web searches and research using Perplexity's API.

## Features

- **Real-time web search** - Access current information from the web
- **Advanced reasoning** - Leverage Perplexity's AI for complex queries
- **Research capabilities** - Deep dive into topics with comprehensive search
- **MCP integration** - Seamless integration through Model Context Protocol

## Requirements

- **Node.js** - Required for npx
- **Perplexity API Key** - Get one from [Perplexity AI](https://docs.perplexity.ai)

## Installation

### 1. Set Your API Key

```bash
# Set your Perplexity API key as an environment variable
export PERPLEXITY_API_KEY="pplx-xxxxxxxxxxxxx"

# Optional: Set custom timeout (default is 600000ms = 10 minutes)
export PERPLEXITY_TIMEOUT_MS="300000"
```

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) to persist across sessions.

### 2. Install the Plugin

```bash
# Add the marketplace
/plugin marketplace add dkmaker/my-claude-plugins

# Install the Perplexity plugin
/plugin install my-claude-plugins/perplexity
```

Restart Claude Code after installation.

## Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PERPLEXITY_API_KEY` | Yes | - | Your Perplexity API key |
| `PERPLEXITY_TIMEOUT_MS` | No | 600000 | Request timeout in milliseconds |

## Usage

Once installed, Claude Code automatically has access to Perplexity's search capabilities through the MCP server.

Example prompts:
```
"Search the web for the latest information on..."
"Research recent developments in..."
"What are the current trends in..."
```

## MCP Server Details

- **Server Type:** stdio
- **Command:** `npx -y @perplexity-ai/mcp-server`
- **Package:** `@perplexity-ai/mcp-server`

The plugin uses npx to automatically download and run the latest version of the Perplexity MCP server.

## Troubleshooting

### Plugin Not Working

1. **Check API key is set:**
   ```bash
   echo $PERPLEXITY_API_KEY
   ```

2. **Verify Node.js is installed:**
   ```bash
   node --version
   npx --version
   ```

3. **Test the MCP server directly:**
   ```bash
   npx -y @perplexity-ai/mcp-server
   ```

### Timeout Issues

If searches are timing out, increase the timeout:

```bash
export PERPLEXITY_TIMEOUT_MS="900000"  # 15 minutes
```

## Documentation

- [Perplexity API Docs](https://docs.perplexity.ai)
- [MCP Server Guide](https://docs.perplexity.ai/guides/mcp-server)
- [GitHub Repository](https://github.com/perplexityai/modelcontextprotocol)

## Version

**0.5.0**

## License

MIT - See [Perplexity's repository](https://github.com/perplexityai/modelcontextprotocol) for details.
