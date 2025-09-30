# Scenic MCP Integration Guide

Complete guide for integrating Scenic MCP into your Elixir/Scenic applications.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step-by-Step Integration](#step-by-step-integration)
3. [Configuration](#configuration)
4. [Testing](#testing)
5. [Common Patterns](#common-patterns)
6. [Troubleshooting](#troubleshooting)
7. [Example Projects](#example-projects)

## Prerequisites

Before integrating Scenic MCP, ensure you have:

- [ ] Elixir ~> 1.14 installed
- [ ] Erlang/OTP 24+ installed
- [ ] Node.js >= 18.0 installed
- [ ] A working Scenic application
- [ ] Claude Code or Claude Desktop (for MCP client)

## Step-by-Step Integration

### 1. Add Dependency

Add `scenic_mcp` to your `mix.exs`:

```elixir
defp deps do
  [
    {:scenic, "~> 0.11"},
    {:scenic_driver_local, "~> 0.11"},
    {:scenic_mcp, "~> 1.0"},
    # ... your other dependencies
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

### 2. Configure Named Processes

Scenic MCP requires your viewport and driver to be registered with names.

**Update your application.ex:**

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # ... other supervisors
      {Scenic, scenic_config()}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp scenic_config do
    [
      name: :main_viewport,  # REQUIRED for Scenic MCP
      size: {800, 600},
      default_scene: MyApp.Scenes.Root,
      drivers: [
        [
          name: :scenic_driver,  # REQUIRED for Scenic MCP
          module: Scenic.Driver.Local,
          window: [title: "My App", resizeable: true],
          on_close: :stop_system
        ]
      ]
    ]
  end
end
```

### 3. Add Configuration (Optional)

If you need custom process names or ports, add to `config/config.exs`:

```elixir
# config/config.exs
config :scenic_mcp,
  port: 9999,
  viewport_name: :main_viewport,
  driver_name: :scenic_driver,
  app_name: "MyApp"
```

**For different environments:**

```elixir
# config/dev.exs
config :scenic_mcp,
  port: 9999,
  app_name: "MyApp (dev)"

# config/test.exs
config :scenic_mcp,
  port: 9998,  # Different port for tests
  app_name: "MyApp (test)"

# config/prod.exs
# Don't include scenic_mcp in production!
```

### 4. Install TypeScript Dependencies

Navigate to the scenic_mcp directory and build:

```bash
cd deps/scenic_mcp
npm install
npm run build
```

If scenic_mcp is a path dependency:

```bash
cd ../scenic_mcp  # Adjust path as needed
npm install
npm run build
```

### 5. Configure Claude Code

**Using CLI:**

```bash
claude mcp add scenic-mcp /path/to/scenic_mcp/dist/index.js
```

**Manual configuration** in `~/.claude.json`:

```json
{
  "projects": {
    "/Users/you/projects/my_app": {
      "mcpServers": {
        "scenic-mcp": {
          "type": "stdio",
          "command": "/Users/you/projects/my_app/deps/scenic_mcp/dist/index.js",
          "args": [],
          "env": {}
        }
      }
    }
  }
}
```

### 6. Verify Installation

Start your application:

```bash
cd my_app
iex -S mix
```

You should see:
```
✅ ScenicMCP successfully started on port 9999
```

In Claude Code, you should now have access to scenic_mcp tools.

## Configuration

### Multiple Applications

If you have multiple Scenic apps (e.g., main app + demo app), configure unique ports:

```elixir
# In my_app/config/config.exs
config :scenic_mcp, port: 9999, app_name: "MyApp"

# In my_demo/config/config.exs
config :scenic_mcp, port: 9997, app_name: "MyDemo"
```

Then connect to specific apps:

```typescript
connect_scenic({ port: 9999 })  // Connect to MyApp
connect_scenic({ port: 9997 })  // Connect to MyDemo
```

### Custom Process Names

If your app uses different process names:

```elixir
# Your existing viewport config
{Scenic, [
  name: :my_custom_viewport,
  drivers: [[name: :my_custom_driver, ...]]
]}

# Configure scenic_mcp to use your names
config :scenic_mcp,
  viewport_name: :my_custom_viewport,
  driver_name: :my_custom_driver
```

## Testing

### Unit Tests

Test that Scenic MCP starts correctly:

```elixir
defmodule MyApp.ScenicMcpTest do
  use ExUnit.Case

  test "scenic mcp server starts" do
    assert Process.whereis(ScenicMcp.Server) != nil
  end

  test "viewport is registered" do
    assert Process.whereis(:main_viewport) != nil
  end

  test "driver is registered" do
    assert Process.whereis(:scenic_driver) != nil
  end
end
```

### Integration Tests

Test UI interactions through Scenic MCP:

```elixir
defmodule MyApp.IntegrationTest do
  use ExUnit.Case

  @port 9998  # Test port

  setup do
    # Connect to test instance
    client = connect_tcp(@port)
    {:ok, client: client}
  end

  test "can send keyboard input", %{client: client} do
    command = Jason.encode!(%{"action" => "send_keys", "text" => "hello"})
    :ok = :gen_tcp.send(client, command <> "\n")

    assert {:ok, response} = :gen_tcp.recv(client, 0, 1000)
    assert %{"status" => "ok"} = Jason.decode!(response)
  end

  defp connect_tcp(port) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", port, [:binary, packet: :line])
    socket
  end
end
```

### Testing with Claude Code

Create a test script:

```markdown
# Test Plan

1. Start app: `iex -S mix`
2. Connect: `connect_scenic()`
3. Type text: `send_keys({ text: "Hello World" })`
4. Take screenshot: `take_screenshot()`
5. Verify: Check screenshot shows "Hello World"
```

## Common Patterns

### Pattern 1: Automated UI Testing

```elixir
# test/features/ui_workflow_test.exs
defmodule MyApp.UIWorkflowTest do
  use ExUnit.Case

  @moduletag :integration
  @port 9998

  test "complete user workflow" do
    client = connect(@port)

    # Navigate to form
    click(client, {100, 200})

    # Fill form
    send_keys(client, "John Doe")
    send_keys(client, key: "tab")
    send_keys(client, "john@example.com")

    # Submit
    send_keys(client, key: "enter")

    # Verify result
    screenshot = take_screenshot(client)
    assert screenshot_contains?(screenshot, "Success")
  end
end
```

### Pattern 2: AI-Assisted Development

Use Claude Code to interact with your app:

```
User: "Find the save button and click it"
Claude:
1. inspect_viewport()  # Get UI structure
2. # Finds button at coordinates (250, 400)
3. send_mouse_click({ x: 250, y: 400 })
4. take_screenshot()  # Verify action
```

### Pattern 3: Visual Regression Testing

```elixir
defmodule MyApp.VisualRegressionTest do
  use ExUnit.Case

  test "homepage renders correctly" do
    client = connect()

    screenshot = take_screenshot(client, "homepage.png")

    # Compare with baseline
    assert images_match?(screenshot, "test/fixtures/baseline/homepage.png")
  end

  defp images_match?(actual, expected) do
    # Use image comparison library
    ImageCompare.similar?(actual, expected, threshold: 0.95)
  end
end
```

### Pattern 4: Accessibility Testing

```elixir
defmodule MyApp.AccessibilityTest do
  use ExUnit.Case

  test "keyboard navigation works" do
    client = connect()

    # Tab through interactive elements
    Enum.each(1..5, fn _ ->
      send_keys(client, key: "tab")
      Process.sleep(100)
    end)

    # Verify focus indicator visible
    screenshot = take_screenshot(client)
    assert has_focus_indicator?(screenshot)
  end
end
```

## Troubleshooting

### Issue: Port Conflict

**Error:** `Port 9999 is already in use!`

**Solution:**
```elixir
# Use a different port
config :scenic_mcp, port: 9998
```

**Check what's using the port:**
```bash
lsof -i :9999
```

### Issue: Cannot Find Viewport

**Error:** `Unable to find Scenic viewport process ':main_viewport'`

**Diagnosis:**
```elixir
# In IEx
iex> Process.whereis(:main_viewport)
nil  # Problem!

# Check registered processes
iex> Process.registered()
[...]  # Look for your viewport
```

**Solutions:**

1. Add `name: :main_viewport` to your Scenic config
2. Or configure custom name:
   ```elixir
   config :scenic_mcp, viewport_name: :your_viewport_name
   ```

### Issue: Driver Not Found

**Error:** `Unable to find Scenic driver process ':scenic_driver'`

**Diagnosis:**
```elixir
iex> Process.whereis(:scenic_driver)
nil

# Check viewport's drivers
iex> :sys.get_state(:main_viewport) |> Map.get(:driver_pids)
[#PID<0.123.0>]  # Driver exists but not registered
```

**Solution:**
```elixir
# Add name to driver config
drivers: [
  [
    name: :scenic_driver,  # Add this!
    module: Scenic.Driver.Local,
    # ...
  ]
]
```

### Issue: Connection Timeout

**Error:** `Command timeout after 5000ms`

**Diagnosis:**
```bash
# Check if server is running
lsof -i :9999

# Check logs
tail -f log/dev.log | grep ScenicMCP
```

**Solutions:**

1. Ensure app is running: `iex -S mix`
2. Verify port: `connect_scenic({ port: 9999 })`
3. Check firewall allows localhost connections

### Issue: Commands Not Working

**Error:** Commands send but nothing happens

**Diagnosis:**
```elixir
# Check if driver is receiving inputs
iex> :sys.get_state(:scenic_driver) |> IO.inspect()
```

**Solutions:**

1. Verify scene is handling input:
   ```elixir
   def handle_input(input, _context, state) do
     IO.inspect(input, label: "Received input")
     # Your input handling
   end
   ```

2. Check if scene has focus
3. Verify input types are supported by your scene

## Example Projects

### Minimal Example

```elixir
# lib/minimal_app/application.ex
defmodule MinimalApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Scenic, [
        name: :main_viewport,
        size: {400, 400},
        default_scene: MinimalApp.Scene,
        drivers: [[
          name: :scenic_driver,
          module: Scenic.Driver.Local
        ]]
      ]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

# lib/minimal_app/scene.ex
defmodule MinimalApp.Scene do
  use Scenic.Scene
  alias Scenic.Graph
  import Scenic.Primitives

  def init(_args, opts) do
    graph = Graph.build()
      |> text("Hello, Scenic MCP!", translate: {20, 40})

    {:ok, graph, push: graph}
  end

  def handle_input({:codepoint, {char, _}}, _context, graph) do
    # Echo typed character
    IO.puts("Typed: #{<<char::utf8>>}")
    {:noreply, graph}
  end
end

# mix.exs
defp deps do
  [
    {:scenic, "~> 0.11"},
    {:scenic_driver_local, "~> 0.11"},
    {:scenic_mcp, "~> 1.0"}
  ]
end

# config/config.exs
config :scenic_mcp,
  port: 9999,
  app_name: "MinimalApp"
```

### Form Example

See `examples/form_app` directory for a complete form-based application with:
- Text inputs
- Buttons
- Keyboard navigation
- Scenic MCP integration
- Test suite

### Game Example

See `examples/game_app` for:
- Real-time input handling
- Mouse tracking
- Visual feedback
- Automated testing

## Best Practices

### 1. Environment-Specific Config

```elixir
# Don't include in production
if Mix.env() != :prod do
  config :scenic_mcp, port: 9999
end
```

### 2. Unique Ports for Tests

```elixir
# config/test.exs
config :scenic_mcp,
  port: 9996 + System.unique_integer([:positive]) rem 100
```

### 3. Graceful Degradation

```elixir
# Don't fail if scenic_mcp is missing
defp deps do
  base_deps = [
    {:scenic, "~> 0.11"},
    {:scenic_driver_local, "~> 0.11"}
  ]

  dev_deps = [
    {:scenic_mcp, "~> 1.0", only: [:dev, :test]}
  ]

  base_deps ++ dev_deps
end
```

### 4. Document MCP Tools

```elixir
# In your README.md
## Development Tools

This app integrates with Scenic MCP for AI-assisted development.

To use:
1. Start the app: `iex -S mix`
2. In Claude Code: `connect_scenic()`
3. Available commands: send_keys, send_mouse_click, take_screenshot
```

### 5. Test Coverage

Include both unit and integration tests:

```elixir
# Unit tests: test/my_app/scene_test.exs
test "scene handles keyboard input"

# Integration tests: test/integration/scenic_mcp_test.exs
test "can control app via scenic mcp"
```

## Additional Resources

- [Scenic Documentation](https://hexdocs.pm/scenic)
- [MCP Specification](https://github.com/anthropics/mcp)
- [Example Apps](https://github.com/your-org/scenic_mcp/tree/main/examples)
- [Troubleshooting Guide](../README.md#troubleshooting)

## Getting Help

- GitHub Issues: [scenic_mcp/issues](https://github.com/your-org/scenic_mcp/issues)
- Elixir Forum: Tag `scenic-mcp`
- Discord: #scenic-mcp channel

---

**Next Steps:** After integration, see [README.md](../README.md) for usage examples and API reference.
