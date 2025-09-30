# Scenic MCP - Input Control for Scenic Applications

A Model Context Protocol (MCP) server that enables LLMs to interact with Scenic GUI applications.

## Features

- **Keyboard Input**: Proper ViewPort input routing via `Scenic.ViewPort.Input.send/2`
- **Mouse Control**: Move cursor and click at specific coordinates
- **Visual Feedback**: Get descriptions of what's displayed on screen, let the LLM "see" the Scenic app
- **MCP Integration**: Works with any MCP-compatible client (Claude Desktop, etc.)

Although the MCP server was clearly written to give Scenic tools to LLMs, it does provide an API that mimics user interactions,
this can be very useful for scripting user input and writing tests for actual user input scenarios.

### 🛠️ Available Tools
1. `connect_scenic` - Test connection to Scenic application
2. `get_scenic_status` - Check server status and connection
3. `send_keys` - Send keyboard input (text, special keys, modifiers)
4. `send_mouse_move` - Move mouse cursor to coordinates
5. `send_mouse_click` - Click mouse at coordinates with button selection
6. `get_scenic_graph` - Get visual description of what's on screen

## Installation

1. **Add to your Scenic application's `mix.exs`:**
```elixir
defp deps do
  [
    {:scenic_mcp, path: "../scenic_mcp"}
  ]
end
```

2. **Configure your Scenic viewport with proper naming:**

**IMPORTANT**: For scenic_mcp to work correctly, your Scenic application MUST name both the viewport and driver. Update your `scenic_config()` function:

```elixir
def scenic_config() do
  [
    name: :main_viewport,  # Required for viewport lookup
    size: @default_resolution,
    default_scene: {YourApp.RootScene, []},
    drivers: [
      [
        name: :scenic_driver,  # Required for driver lookup
        module: Scenic.Driver.Local,
        window: [
          title: "Your App",
          resizeable: true
        ],
        on_close: :stop_system
      ]
    ]
  ]
end
```

3. **Install Node.js dependencies:**
```bash
cd scenic_mcp
npm install
```

4. **Configure for Claude Code (optional):**

```
# Add the MCP server to Claude Code
claude mcp add scenic-mcp /path/to/scenic_mcp/dist/index.js

# Verify it was added
claude mcp list
```

Note: Replace /path/to/scenic_mcp with the actual path to your scenic_mcp directory (wherever you cloned this repo).

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
Return the script table for a ViewPort, providing a visual description of the scene.

#### `take_screenshot`
Capture a screenshot of the current Scenic display.

**Parameters:**
- `filename` (string, optional): Custom filename for the screenshot
- `format` (string, optional): Output format - "path" (default) or "base64"

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
  "modifiers": [:ctrl]
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
Elixir GenServer Bridge (ScenicMcp.Server)
    ↓ (ScenicMcp.Probes)
Scenic.Driver.send_input/2
    ↓
Scenic Driver Process (:scenic_driver)
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

## Testing

This project includes comprehensive testing to ensure reliability and guide improvements.

### Test Suites

1. **Elixir Unit Tests** - Core server functionality
   ```bash
   mix test
   mix test --cover  # With coverage reporting
   ```

2. **TypeScript Tests** - MCP integration testing
   ```bash
   npm test
   npm run test:coverage  # With coverage
   npm run test:watch     # Watch mode
   ```

3. **LLM Tool Testing** - Validates tool descriptions and usability
   ```bash
   npm run test:llm-tools
   ```

### Testing Innovation: LLM-Driven Tool Enhancement

One of the unique aspects of this project is how we use LLM testing to improve the tool descriptions:

1. **Tool Usage Analysis**: We run scenarios through LLMs to see which tools they discover and use
2. **Description Enhancement**: Based on usage patterns, we automatically enhance tool descriptions
3. **Real-World Validation**: The enhanced descriptions are tested against real development scenarios

This approach has led to significant improvements in tool discoverability and correct usage by AI assistants.

### Running All Tests
```bash
npm run test:all  # Runs both Elixir and TypeScript tests
```

## License

MIT License
