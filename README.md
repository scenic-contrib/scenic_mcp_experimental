# Scenic MCP - Input Control for Scenic Applications

A Model Context Protocol (MCP) server that enables external keyboard and mouse input injection into Scenic GUI applications.

## Features

- **Keyboard Input**: Send text and special keys to Scenic applications
- **Mouse Control**: Move cursor and click at specific coordinates
- **Visual Feedback**: Get descriptions of what's displayed on screen (v0.2.0)
- **MCP Integration**: Works with any MCP-compatible client (Claude Desktop, etc.)
- **Real-time Communication**: TCP-based connection for low-latency input
- **Scenic Compatible**: Uses proper Scenic ViewPort input routing

## Installation

1. **Add to your Scenic application's `mix.exs`:**
```elixir
defp deps do
  [
    {:scenic_mcp, path: "../scenic_mcp"}
  ]
end
```

2. **Add to your application's supervision tree:**

actually you shouldn't need to do this...

3. **Install Node.js dependencies and build:**
```bash
cd scenic_mcp
npm install
npm run build
```

4. **Configure for Claude Code:**
```bash
# Add the MCP server to Claude Code
claude mcp add scenic-mcp /path/to/scenic_mcp/dist/index.js

# Verify it was added
claude mcp list
```

**Note:** Replace `/path/to/scenic_mcp` with the actual path to your scenic_mcp directory.

## Usage

### Using with Claude Code

Once configured, you can use the MCP tools directly within Claude Code conversations:

1. **Start your Scenic application** (with the ScenicMcp.Server running on port 9999)
2. **Use MCP tools in Claude Code:**
   - `connect_scenic` - Test connection to your Scenic app
   - `get_scenic_status` - Check connection status
   - `send_keys` - Send keyboard input
   - `send_mouse_move` - Move mouse cursor
   - `send_mouse_click` - Click at coordinates
   - `inspect_viewport` - Get visual description of current screen

Example conversation:
```
You: "Use the connect_scenic tool to test connection to my Flamelex app"
Claude: [Uses connect_scenic tool and shows connection status]

You: "Send the text 'hello world' using send_keys"
Claude: [Uses send_keys tool to type text into your app]
```

### MCP Tools

The server provides these MCP tools:

#### `connect_scenic`
Test connection to the Scenic application.

#### `get_scenic_status` 
Check server status and available commands.

#### `send_keys`
Send keyboard input to the Scenic application.

**Parameters:**
- `text` (string): Text to type (each character sent as individual key press)
- `key` (string): Special key name (enter, escape, tab, backspace, delete, up, down, left, right, home, end, page_up, page_down, f1-f12)
- `modifiers` (array): Modifier keys (ctrl, shift, alt, cmd, meta)

#### `send_mouse_move`
Move mouse cursor to specific coordinates.

**Parameters:**
- `x` (number): X coordinate
- `y` (number): Y coordinate

#### `send_mouse_click`
Click mouse at specific coordinates.

**Parameters:**
- `x` (number): X coordinate
- `y` (number): Y coordinate
- `button` (string): Mouse button (left, right, middle) - default: left

#### `get_scenic_graph` (NEW in v0.2.0)
Return the script table for a ViewPort.

### Examples

**Send text:**
```json
{
  "action": "send_keys",
  "text": "hello world"
}
```

**Send special key:**
```json
{
  "action": "send_keys", 
  "key": "enter"
}
```

**Send key with modifiers:**
```json
{
  "action": "send_keys",
  "key": "c",
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

**Click mouse:**
```json
{
  "action": "send_mouse_click",
  "x": 150,
  "y": 250,
  "button": "left"
}
```

**Get visual feedback:**
```json
{
  "action": "get_scenic_graph"
}
```

## Architecture

```
MCP Client (Claude Desktop)
    ↓
TypeScript MCP Server (scenic_mcp)
    ↓ (TCP port 9999)
Elixir GenServer Bridge
    ↓ (Scenic.ViewPort.Input.send/2)
Scenic ViewPort
    ↓
Your Scenic Application
```

## Development

**Start the Elixir server:**
```bash
cd your_scenic_app
mix run --no-halt
```

**Test the MCP server:**
```bash
cd scenic_mcp
node src/index.ts
```

## Requirements

- Elixir/OTP 24+
- Node.js 18+
- Scenic 0.11+

## License

MIT License
