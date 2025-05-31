# Scenic MCP Server

A Model Context Protocol (MCP) server that enables AI agents to control Scenic applications through keyboard and mouse automation.

## 🎯 Features

- **Connection Management** - Connect to and monitor Scenic applications
- **Keyboard Control** - Send text and special keys with modifier support
- **Mouse Control** - Move cursor and click at specific coordinates
- **Generic Implementation** - Works with any Scenic application (tested with Flamelex)
- **Robust Architecture** - TypeScript MCP server + Elixir TCP backend

## 🚀 Quick Start

### Prerequisites

1. **Node.js** (v18+) and **npm**
2. **Elixir** (v1.14+) and **Mix**
3. A running Scenic application (e.g., Flamelex)

### Installation

```bash
# Clone and setup
cd scenic_mcp

# Install Node.js dependencies
npm install

# Install Elixir dependencies  
mix deps.get

# Build TypeScript
npm run build

# Compile Elixir
mix compile
```

### Usage

1. **Start your Scenic application** (e.g., Flamelex):
   ```bash
   cd flamelex && mix run --no-halt
   ```

2. **Test the MCP server**:
   ```bash
   cd scenic_mcp
   node test_all_tools.cjs
   ```

3. **Configure in Cline** - Add to MCP settings:
   ```json
   {
     "scenic": {
       "command": "node",
       "args": ["/path/to/scenic_mcp/dist/index.js"],
       "disabled": false
     }
   }
   ```

## 🛠️ Available Tools

### `connect_scenic`
Test connection to Scenic application and get server info.

**Parameters:**
- `port` (optional): TCP port number (default: 9999)

**Example:**
```javascript
{
  "port": 9999
}
```

### `get_scenic_status`
Get current connection status and available commands.

**Parameters:** None

### `send_keys`
Send keyboard input to the Scenic application.

**Parameters:**
- `text` (optional): Text to type character by character
- `key` (optional): Special key name (enter, escape, tab, arrows, etc.)
- `modifiers` (optional): Array of modifier keys (ctrl, shift, alt, cmd, meta)

**Examples:**
```javascript
// Send text
{
  "text": "Hello World"
}

// Send special key with modifiers
{
  "key": "enter",
  "modifiers": ["ctrl", "shift"]
}
```

### `send_mouse_move`
Move mouse cursor to specific coordinates.

**Parameters:**
- `x`: X coordinate
- `y`: Y coordinate

**Example:**
```javascript
{
  "x": 100,
  "y": 200
}
```

### `send_mouse_click`
Click mouse at specific coordinates.

**Parameters:**
- `x`: X coordinate
- `y`: Y coordinate  
- `button` (optional): Mouse button - "left", "right", or "middle" (default: "left")

**Example:**
```javascript
{
  "x": 100,
  "y": 200,
  "button": "left"
}
```

## 🏗️ Architecture

```
┌─────────────────┐    stdio    ┌─────────────────┐    TCP     ┌─────────────────┐
│   Cline/MCP     │ ◄────────► │  TypeScript     │ ◄───────► │  Elixir TCP     │
│   Client        │             │  MCP Server     │   :9999    │  Server         │
└─────────────────┘             └─────────────────┘            └─────────────────┘
                                                                        │
                                                                        ▼
                                                               ┌─────────────────┐
                                                               │  Scenic App     │
                                                               │  (Flamelex)     │
                                                               └─────────────────┘
```

### Components

1. **TypeScript MCP Server** (`src/index.ts`)
   - Implements MCP protocol over stdio
   - Handles tool definitions and calls
   - Forwards commands to Elixir TCP server

2. **Elixir TCP Server** (`lib/scenic_mcp/server.ex`)
   - Listens on port 9999
   - Discovers Scenic viewports automatically
   - Injects input events into Scenic applications

3. **Scenic Integration** (`lib/scenic_mcp.ex`)
   - Generic viewport discovery
   - Input event formatting
   - Fluxus integration when available

## 🧪 Testing

Run the comprehensive test suite:

```bash
cd scenic_mcp
node test_all_tools.cjs
```

Expected output:
```
✅ List Tools: SUCCESS
✅ Connect to Scenic: SUCCESS  
✅ Get Scenic Status: SUCCESS
✅ Send Keys (text): SUCCESS
✅ Send Keys (special key): SUCCESS
✅ Move Mouse: SUCCESS
✅ Click Mouse: SUCCESS
```

## 🔧 Development

### Building

```bash
# TypeScript compilation
npm run build

# Elixir compilation  
mix compile

# Watch mode for development
npm run dev
```

### Project Structure

```
scenic_mcp/
├── src/
│   └── index.ts          # TypeScript MCP server
├── lib/
│   ├── scenic_mcp.ex     # Main Elixir module
│   └── scenic_mcp/
│       ├── application.ex # Supervision tree
│       └── server.ex     # TCP server
├── test_all_tools.cjs    # Test suite
├── package.json          # Node.js config
├── mix.exs              # Elixir config
└── tsconfig.json        # TypeScript config
```

## 🐛 Troubleshooting

### "No Scenic viewport found"
- Ensure your Scenic application is running
- Check that the application includes `ScenicMcp.Server` in its supervision tree
- Verify the TCP port (default: 9999) is available

### "Connection timeout"
- Confirm Flamelex or your Scenic app is running
- Check firewall settings for port 9999
- Try restarting the Scenic application

### MCP connection issues
- Verify the compiled JavaScript exists: `ls scenic_mcp/dist/index.js`
- Check Cline's MCP configuration
- Restart VS Code/Cline after configuration changes

## 📝 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 🔗 Related Projects

- [Flamelex](../flamelex/) - Text editor/memex built with Scenic
- [Scenic](https://github.com/ScenicFramework/scenic) - Client application library
- [Model Context Protocol](https://modelcontextprotocol.io/) - Protocol for AI tool integration
