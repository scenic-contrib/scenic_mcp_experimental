# Scenic MCP - AI Control for Scenic Applications

A Model Context Protocol (MCP) server that enables AI assistants to interact with Scenic GUI applications through keyboard, mouse, and visual feedback.

## Features

- **Keyboard Input**: Send text and special keys with modifier support
- **Mouse Control**: Move cursor and click at specific coordinates
- **Visual Feedback**: Inspect viewport structure and capture screenshots
- **Process Management**: Start, stop, and monitor Scenic applications
- **MCP Integration**: Works with any MCP-compatible client (Claude Desktop, Claude Code, etc.)

## Available Tools

### Connection & Status
1. **`connect_scenic`** - Establish connection to running Scenic app
2. **`get_scenic_status`** - Check connection status and server info
3. **`app_status`** - Get managed app process status

### User Input
4. **`send_keys`** - Send keyboard input (text, special keys, modifiers)
5. **`send_mouse_move`** - Move cursor to coordinates
6. **`send_mouse_click`** - Click at coordinates (left/right/middle button)

### Visual Feedback
7. **`inspect_viewport`** - Get text description of viewport structure
8. **`take_screenshot`** - Capture PNG screenshot (path or base64)

### Process Management
9. **`start_app`** - Launch Scenic app from directory path
10. **`stop_app`** - Stop managed app process

## Installation

### 1. Add to your Scenic app's mix.exs

```elixir
defp deps do
  [
    {:scenic_mcp, path: "../scenic_mcp"}
  ]
end
```

### 2. Configure viewport and driver naming

**CRITICAL**: scenic_mcp requires named viewport and driver processes.

Update your `scenic_config()` function:

```elixir
def scenic_config() do
  [
    name: :main_viewport,  # Required!
    size: {800, 600},
    default_scene: {YourApp.RootScene, []},
    drivers: [
      [
        name: :scenic_driver,  # Required!
        module: Scenic.Driver.Local,
        window: [title: "Your App", resizeable: true],
        on_close: :stop_system
      ]
    ]
  ]
end
```

### 3. Install TypeScript dependencies

```bash
cd scenic_mcp
npm install
npm run build
```

### 4. Configure for Claude Code

**Option A: Using CLI (Recommended)**

```bash
# Add scenic-mcp server
claude mcp add scenic-mcp /path/to/scenic_mcp/dist/index.js

# Verify
claude mcp list
```

**Option B: Manual Configuration**

Edit `~/.claude.json` to add the scenic-mcp server to your project:

```json
{
  "projects": {
    "/path/to/your/project": {
      "mcpServers": {
        "scenic-mcp": {
          "type": "stdio",
          "command": "/path/to/scenic_mcp/dist/index.js",
          "args": [],
          "env": {}
        }
      }
    }
  }
}
```

**Optional: Tidewave MCP Configuration**

Tidewave provides runtime introspection for Elixir/Phoenix apps (logs, SQL queries, code evaluation, docs). If your project includes Tidewave (Flamelex/Quillex do), add this to the same project config:

```json
{
  "projects": {
    "/path/to/your/project": {
      "mcpServers": {
        "scenic-mcp": {
          "type": "stdio",
          "command": "/path/to/scenic_mcp/dist/index.js",
          "args": [],
          "env": {}
        },
        "tidewave": {
          "type": "http",
          "url": "http://localhost:4000/tidewave/mcp"
        }
      }
    }
  }
}
```

**Important:**
- Tidewave requires `"type": "http"` for Phoenix apps (NOT "sse")
- The Tidewave server runs on the same port as your Phoenix app (default 4000)
- Restart Claude Code after configuration changes
- See [Tidewave docs](https://hexdocs.pm/tidewave/mcp.html) for more info

## Usage

### Starting Your Scenic App

Scenic apps with scenic_mcp start the TCP server automatically on port 9999:

```bash
cd your_scenic_app
iex -S mix
# ScenicMCP TCP server listening on port 9999
```

### Tool Examples

**Connect to app:**
```json
{"action": "status"}
```

**Type text:**
```json
{
  "action": "send_keys",
  "text": "hello world"
}
```

**Press special key:**
```json
{
  "action": "send_keys",
  "key": "enter"
}
```

**Key with modifiers:**
```json
{
  "action": "send_keys",
  "key": "s",
  "modifiers": ["ctrl"]
}
```

**Move mouse:**
```json
{
  "action": "send_mouse_move",
  "x": 100,
  "y": 200
}
```

**Click:**
```json
{
  "action": "send_mouse_click",
  "x": 150,
  "y": 250,
  "button": "left"
}
```

**Inspect viewport:**
```json
{"action": "inspect_viewport"}
```

**Take screenshot:**
```json
{
  "action": "take_screenshot",
  "filename": "app_screenshot.png",
  "format": "path"
}
```

## Architecture

```
Claude Desktop / Claude Code
    ↓ (stdio)
TypeScript MCP Server
    ↓ (TCP port 9999)
ScenicMcp.Server (GenServer)
    ↓ (function calls)
ScenicMcp.Tools
    ↓ (Scenic.Driver.send_input/2)
Scenic Driver Process
    ↓
Your Scenic Application
```

## Development

**Build TypeScript:**
```bash
npm run build       # One-time build
npm run dev         # Watch mode
```

**Bundle for distribution:**
```bash
npm run bundle      # Copies dist/* to priv/mcp_server/
```

**Test Elixir server:**
```bash
mix test
```

## Project Structure

```
scenic_mcp/
├── lib/
│   ├── scenic_mcp.ex              # Module documentation
│   └── scenic_mcp/
│       ├── application.ex         # Supervisor setup
│       ├── server.ex              # TCP server (115 lines)
│       └── tools.ex               # Tool handlers (338 lines)
├── src/
│   ├── index.ts                   # MCP server setup (79 lines)
│   ├── connection.ts              # TCP/process management (310 lines)
│   └── tools.ts                   # Tool definitions/handlers (827 lines)
├── test/
│   └── scenic_mcp/
│       └── server_test.exs        # TCP server tests
└── dist/                          # Compiled TypeScript
```

## How It Works

1. **TypeScript MCP Server** (src/index.ts) handles MCP protocol via stdio
2. **TCP Bridge** (src/connection.ts) connects to Elixir server
3. **Elixir GenServer** (lib/scenic_mcp/server.ex) receives JSON commands
4. **Tool Handlers** (lib/scenic_mcp/tools.ex) interact with Scenic viewport/driver
5. **Driver** sends input events to your Scenic app

## License

MIT
