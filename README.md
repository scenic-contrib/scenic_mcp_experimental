# Scenic MCP

**Model Context Protocol (MCP) server for Scenic GUI applications**

Version: 1.0.0

Enable AI assistants to interact with [Scenic](https://github.com/ScenicFramework/scenic) GUI applications through keyboard input, mouse control, and visual feedback. Perfect for automated testing, AI-driven development workflows, and accessibility tools.

## Features

- 🎹 **Keyboard Input** - Send text and special keys with modifier support (Ctrl, Shift, Alt, Cmd)
- 🖱️ **Mouse Control** - Move cursor and click at specific coordinates
- 📸 **Visual Feedback** - Inspect viewport structure and capture screenshots
- 🤖 **MCP Integration** - Works with Claude Desktop, Claude Code, and other MCP clients

## Quick Start

### 1. Add to your Scenic app's `mix.exs`

Note this is still not actually published to hex so you need to clone it and add it as a local dep for now.

```elixir
defp deps do
  [
    {:scenic_mcp, "../scenic_mcp"}
  ]
end
```

### 2. Configure your viewport and driver

Scenic MCP requires named viewport and driver processes. Update your supervision tree:

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    {Scenic, scenic_viewport_config()}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end

defp scenic_viewport_config do
  [
    name: :main_viewport,  # Required!
    size: {800, 600},
    default_scene: MyApp.RootScene,
    drivers: [
      [
        name: :scenic_driver,  # Required!
        module: Scenic.Driver.Local,
        window: [title: "My App"],
        on_close: :stop_system
      ]
    ]
  ]
end
```

Note that `name` here defines the atom which will become the registered process name for the ViewPort and Driver processes. We need to know this in order to find the pid of this process in order to interact with the ViewPort, and our solution was to look for this specific name `main_viewport` so you need to set this in your config as above for ScenicMCP to work.

Viewport name: `:main_viewport`
Driver name: `:scenic_driver`

**Optional: Custom process names**

If you need different process names, configure them:

```elixir
# config/config.exs
config :scenic_mcp,
  viewport_name: :my_custom_viewport,
  driver_name: :my_custom_driver,
  port: 9999
```

### 3. Install TypeScript dependencies

```bash
cd scenic_mcp
npm install
npm run build
```

### 4. Configure Claude Code or Claude Desktop

#### Using Claude Code CLI (Recommended)

```bash
claude mcp add scenic-mcp /path/to/scenic_mcp/dist/index.js
claude mcp list  # Verify installation
```

#### Manual Configuration

Edit `~/.claude.json`:

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

### 5. Start your Scenic app

```bash
cd your_scenic_app
iex -S mix
```

You should see:
```
✅ ScenicMCP successfully started on port 9999
```

## Usage

### Available Tools

#### Connection & Status
- **`connect_scenic`** - Establish connection to running Scenic app
- **`get_scenic_status`** - Check connection status and server info

#### User Input
- **`send_keys`** - Send keyboard input (text, special keys, modifiers)
- **`send_mouse_move`** - Move cursor to coordinates
- **`send_mouse_click`** - Click at coordinates (left/right/middle button)

#### Visual Feedback
- **`inspect_viewport`** - Get text description of viewport structure
- **`take_screenshot`** - Capture PNG screenshot (path or base64)

### Examples

#### Text Input
```typescript
send_keys({ text: "Hello, World!" })
```

#### Special Keys
```typescript
send_keys({ key: "enter" })
send_keys({ key: "escape" })
send_keys({ key: "tab" })
```

#### Keyboard Shortcuts
```typescript
send_keys({ key: "s", modifiers: ["ctrl"] })      // Ctrl+S (Save)
send_keys({ key: "c", modifiers: ["cmd"] })       // Cmd+C (Copy on Mac)
send_keys({ key: "z", modifiers: ["ctrl", "shift"] })  // Ctrl+Shift+Z (Redo)
```

#### Mouse Control
```typescript
send_mouse_move({ x: 100, y: 200 })
send_mouse_click({ x: 150, y: 250, button: "left" })
send_mouse_click({ x: 300, y: 100, button: "right" })  // Right-click
```

#### Visual Inspection
```typescript
inspect_viewport()  // Get component structure

take_screenshot({ format: "path" })  // Save to /tmp
take_screenshot({
  filename: "app_state.png",
  format: "base64"  // Get base64 data
})
```

## Architecture

```
AI Agent (Claude Desktop/Code)
    ↓ stdio
TypeScript MCP Server (this package)
    ↓ TCP (port 9999)
Elixir GenServer (ScenicMcp.Server)
    ↓ function calls
Scenic Driver Process
    ↓ input events
Your Scenic Application
```

### How It Works

1. **TypeScript MCP Server** handles MCP protocol via stdio
2. **TCP Bridge** maintains persistent connection to Elixir
3. **Elixir GenServer** receives JSON commands over TCP
4. **Tool Handlers** interact with Scenic viewport and driver
5. **Driver** injects input events into your application

## Configuration

### Available Options

```elixir
# config/config.exs
config :scenic_mcp,
  # TCP port for MCP server (default: 9999)
  port: 9999,

  # Viewport process name (default: :main_viewport)
  viewport_name: :main_viewport,

  # Driver process name (default: :scenic_driver)
  driver_name: :scenic_driver,

  # Application name for logging (default: "Unknown")
  app_name: "MyApp"
```

### Multiple Scenic Apps

If you're running multiple Scenic apps, configure unique ports:

```elixir
# In flamelex/config/config.exs
config :scenic_mcp, port: 9999, app_name: "Flamelex"

# In quillex/config/config.exs
config :scenic_mcp, port: 9997, app_name: "Quillex"

# In your_test/config/test.exs
config :scenic_mcp, port: 9996, app_name: "Test"
```

Connect to specific ports:
```typescript
connect_scenic({ port: 9997 })  // Connect to Quillex
```

## Development

### Build TypeScript

```bash
npm run build       # One-time build
npm run dev         # Watch mode for development
```

### Bundle for Distribution

```bash
npm run bundle      # Copies dist/* to priv/mcp_server/
```

### Run Tests

```bash
# Elixir tests
mix test

# Test specific file
mix test test/scenic_mcp/server_test.exs
```

### Project Structure

```
scenic_mcp/
├── lib/
│   ├── scenic_mcp.ex           # Module documentation
│   └── scenic_mcp/
│       ├── application.ex      # OTP application
│       ├── config.ex           # Configuration management
│       ├── server.ex           # TCP server (GenServer)
│       └── tools.ex            # Tool handlers
├── src/
│   ├── index.ts                # MCP server entry point
│   ├── connection.ts           # TCP connection management
│   └── tools.ts                # Tool definitions
├── test/
│   └── scenic_mcp/
│       └── server_test.exs     # Integration tests
└── dist/                       # Compiled TypeScript
```

## Troubleshooting

### Port Already in Use

**Error:** `Port 9999 is already in use!`

**Solution:** Configure a different port in your config.exs:
```elixir
config :scenic_mcp, port: 9998
```

### Cannot Find Viewport

**Error:** `Unable to find Scenic viewport process ':main_viewport'`

**Solutions:**
1. Ensure your viewport is named: `name: :main_viewport` in your Scenic config
2. Or configure the expected name: `config :scenic_mcp, viewport_name: :your_name`
3. Verify your Scenic app is running: `Process.whereis(:main_viewport)`

### Cannot Find Driver

**Error:** `Unable to find Scenic driver process ':scenic_driver'`

**Solutions:**
1. Ensure your driver is named: `name: :scenic_driver` in your driver config
2. Or configure the expected name: `config :scenic_mcp, driver_name: :your_name`
3. Check driver started: `Process.whereis(:scenic_driver)`

### Connection Timeout

**Error:** `Command timeout after 5000ms`

**Solutions:**
1. Check if Scenic app is running
2. Verify correct port: `connect_scenic({ port: YOUR_PORT })`
3. Check firewall settings (should allow localhost:9999)

### Tests Failing

If tests fail with connection errors:
1. Ensure no other apps are using test ports (9996-9998)
2. Run tests with: `mix test --trace` for detailed output
3. Check that `scenic_driver_local` dependency is properly compiled

## Security Considerations

⚠️ **Important Security Notes:**

- Scenic MCP binds to `localhost` only - not accessible from external networks
- **No authentication** - anyone with local access can control your app
- Intended for **development and testing environments only**
- Do not expose the TCP port (9999) to untrusted networks
- Do not use in production without additional security measures

See [SECURITY.md](SECURITY.md) for detailed security guidelines.

## Integration Guide

See [docs/INTEGRATION.md](docs/INTEGRATION.md) for step-by-step integration instructions, including:

- Adding Scenic MCP to existing applications
- Common patterns and best practices
- Testing strategies
- Example implementations

## API Reference

### Error Handling

All tool functions return consistent error structures:

```json
{
  "error": "Descriptive error message with context and potential solutions"
}
```

Success responses include a `status` field:

```json
{
  "status": "ok",
  "message": "Operation completed successfully",
  ...additional data...
}
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure `mix test` passes
5. Submit a pull request

## Requirements

- Elixir ~> 1.14
- Erlang/OTP 24+
- Node.js >= 18.0
- Scenic ~> 0.11
- Claude Desktop or Claude Code (for MCP client)

## License

MIT License - see [LICENSE](LICENSE) for details

## Related Projects

- [Scenic](https://github.com/ScenicFramework/scenic) - 2D UI framework for Elixir
- [MCP](https://github.com/anthropics/mcp) - Model Context Protocol specification
- [Tidewave](https://hexdocs.pm/tidewave) - Elixir/Phoenix MCP tools

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Support

- Report bugs: [GitHub Issues](https://github.com/your-org/scenic_mcp/issues)
- Documentation: This README and [docs/](docs/)
- Examples: See [examples/](examples/) directory

---

**Made with ❤️ for the Elixir and Scenic communities**
