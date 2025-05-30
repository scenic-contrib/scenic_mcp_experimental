# Scenic MCP

MCP (Model Context Protocol) server for Scenic Elixir applications. This enables AI-driven automation and testing of any Scenic app.

## Architecture

This project consists of two parts:
1. **Elixir Library** - A TCP server that runs inside your Scenic app
2. **MCP Server** - A TypeScript/Node.js server that implements the MCP protocol

```
Your Scenic App (Elixir)
    ↓ adds dependency
scenic_mcp (Elixir TCP Server on port 9999)
    ↓ TCP connection
scenic-mcp (TypeScript MCP Server)
    ↓ MCP protocol
AI Assistant (Claude, Cline, etc.)
```

## Quick Start

### 1. Add to your Scenic app

Add `scenic_mcp` to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:scenic, "~> 0.11"},
    {:scenic_mcp, path: "../scenic_mcp"}  # or from hex/git when published
  ]
end
```

The TCP server will automatically start when your app starts.

### 2. Install the MCP server

For development (from this repo):
```bash
cd scenic_mcp
npm install
npm run build
```

For end users (when published):
```bash
npm install -g @scenic/mcp-server
```

### 3. Configure your MCP client

Add to your MCP client configuration (e.g., Claude Desktop, Cline):

```json
{
  "mcpServers": {
    "scenic": {
      "command": "node",
      "args": ["/path/to/scenic_mcp/dist/index.js"]
    }
  }
}
```

Or if installed globally:
```json
{
  "mcpServers": {
    "scenic": {
      "command": "scenic-mcp"
    }
  }
}
```

## Testing

### Test the Elixir TCP server:

```bash
# Start your Scenic app with scenic_mcp
cd your_scenic_app
iex -S mix

# In another terminal, test the TCP connection
echo "hello" | nc localhost 9999
```

You should see a JSON response with Elixir system info.

### Test the MCP integration:

1. Start your Scenic app
2. Make sure the MCP server is configured in your client
3. Use the `hello_scenic` tool to test the connection

## Development

### Project Structure

```
scenic_mcp/
├── lib/                    # Elixir source
│   ├── scenic_mcp.ex
│   └── scenic_mcp/
│       ├── application.ex
│       └── server.ex
├── src/                    # TypeScript source
│   └── index.ts
├── dist/                   # Compiled JavaScript
├── mix.exs                 # Elixir package
└── package.json            # Node package
```

### Building

```bash
# Install Elixir deps
mix deps.get

# Install Node deps
npm install

# Build TypeScript
npm run build

# Bundle for local dev
npm run bundle
```

## Current Features

- ✅ Basic TCP server in Elixir
- ✅ MCP server in TypeScript
- ✅ Hello world communication test

## Roadmap

- [ ] Viewport discovery and management
- [ ] Input injection (click, type, etc.)
- [ ] Screenshot capture
- [ ] Scene navigation
- [ ] Element inspection
- [ ] Custom app-specific tools

## License

MIT
