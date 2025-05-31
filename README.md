# Scenic MCP - Keyboard Input for Scenic Applications

A Model Context Protocol (MCP) server that enables external keyboard input injection into Scenic GUI applications.

## Features

- **Keyboard Input**: Send text and special keys to Scenic applications
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
```elixir
# In your application.ex
children = [
  # ... your other children
  {ScenicMcp.Server, port: 9999}
]
```

3. **Install Node.js dependencies:**
```bash
cd scenic_mcp
npm install
```

## Usage

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
