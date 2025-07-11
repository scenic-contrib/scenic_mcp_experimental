# Scenic MCP Development Log

## Project Overview
Scenic MCP is a Model Context Protocol server that enables external keyboard and mouse input injection into Scenic GUI applications. It acts as the "browser automation equivalent" for native Scenic applications.

## Current Status: v0.2.0

### ✅ Completed Features
- **Core MCP Server**: TypeScript implementation with 5 working tools
- **TCP Bridge**: Elixir GenServer for reliable communication
- **Input Injection**: Keyboard (text + special keys) and mouse (movement + clicking)
- **Connection Management**: Robust TCP connection with retry logic
- **Scenic Integration**: Proper ViewPort input routing via `Scenic.ViewPort.Input.send/2`

### 🏗️ Architecture
```
MCP Client (Claude Desktop)
    ↓ (stdio)
TypeScript MCP Server (scenic_mcp/src/index.ts)
    ↓ (TCP port 9999)
Elixir GenServer Bridge (scenic_mcp/lib/scenic_mcp/server.ex)
    ↓ (Scenic.ViewPort.Input.send/2)
Scenic ViewPort
    ↓
Target Scenic Application
```

### 🛠️ Available Tools
1. `connect_scenic` - Test connection to Scenic application
2. `get_scenic_status` - Check server status and connection
3. `send_keys` - Send keyboard input (text, special keys, modifiers)
4. `send_mouse_move` - Move mouse cursor to coordinates
5. `send_mouse_click` - Click mouse at coordinates with button selection
6. `get_scenic_graph` - Get visual description of what's on screen (NEW in v0.2.0)

### 📁 Project Structure
```
scenic_mcp/
├── src/index.ts              # TypeScript MCP server
├── lib/scenic_mcp/
│   ├── application.ex        # Elixir application
│   └── server.ex            # TCP bridge GenServer
├── test/                    # Elixir tests
├── package.json             # Node.js dependencies
├── mix.exs                  # Elixir dependencies
└── README.md               # Documentation
```

## Development Sessions

### Session 2025-05-31: Visual Feedback Implementation
**Goal**: Implement "eyes" for AI - ability to see what's on screen
**Status**: Enhanced Implementation Complete

**Tasks Completed**:
- ✅ Added `get_scenic_graph` tool to TypeScript MCP server
- ✅ Implemented Elixir handler for graph inspection
- ✅ Created test script `test_get_graph.js`
- ✅ Discovered Scenic's graph storage architecture
- ✅ Modified local Scenic library to add default `:get_graph` handler
- ✅ Enhanced MCP server to query scenes for their graphs
- ✅ Created `test_enhanced_graph.js` for testing

**Key Findings**:
- Scenic stores graphs in individual Scene processes, not centrally
- ViewPort compiles graphs to scripts for rendering
- Need to query scenes directly for full graph content
- Successfully added default handler to all Scenic scenes

**Architecture Insights**:
```
ViewPort (maintains scene hierarchy)
    ↓
Scene Processes (each holds its own graph)
    ↓ (via handle_call(:get_graph, ...))
Graph Data (module, id, assigns, graph primitives)
```

**Technical Implementation**:
- Modified `scenic_local/lib/scenic/scene.ex` to add default handler:
  ```elixir
  def handle_call(:get_graph, _from, scene) do
    graph_info = %{
      module: __MODULE__,
      id: scene.id,
      assigns: scene.assigns,
      graph: Scenic.Graph.to_list(scene.assigns.graph)
    }
    {:reply, graph_info, scene}
  end
  ```
- Enhanced `ScenicMcp.Server` to query scenes and aggregate graph data
- Now provides both summary and detailed graph descriptions

### Session 2025-05-30: v0.2 Cleanup & Organization
**Goal**: Clean up codebase and prepare for v0.2 release
**Status**: Completed

**Tasks Completed**:
- ✅ Analyzed current project structure
- ✅ Identified scattered development artifacts
- ✅ Created development log system
- ✅ Standardized version numbers to 0.2.0
- ✅ Added initial visual feedback capability

## Future Roadmap

### v0.3: Enhanced Scene Graph Inspection
- ✅ `get_scene_graph` - Basic implementation complete, needs enhancement
- `find_elements` - Query UI components by type/ID/properties
- `get_element_bounds` - Get clickable areas for smart targeting
- `take_screenshot` - Visual state capture

**Enhancement Plan for get_scene_graph**:
1. Modify application scenes to expose their graphs via `handle_call(:get_graph, ...)`
2. Query ViewPort's internal scene registry for hierarchy
3. Parse graph primitives into human-readable descriptions
4. Support element identification for targeted interactions

### v0.4: Smart Interactions
- `click_element` - Click by element ID instead of coordinates
- `type_into_field` - Smart text input with field detection
- `wait_for_element` - Wait for UI state changes
- `scroll_to_element` - Navigate to specific components

### v1.0: Production Ready
- Hex package publication
- NPM package publication
- Comprehensive documentation
- Example integrations
- CI/CD pipeline

## Technical Notes

### Scenic ViewPort Discovery
The system uses multiple strategies to find Scenic viewports:
1. Common registered names (`:main_viewport`, `:viewport`, `:scenic_viewport`)
2. Process dictionary scanning for viewport-related processes
3. Scenic supervisor tree inspection

### Input Event Format
- Keyboard: `{:key, {key_atom, 1, modifiers}}`
- Mouse Move: `{:cursor_pos, {x, y}}`
- Mouse Click: `{:cursor_button, {button_atom, 1, []}}`

### Error Handling
- TCP connection retry logic (3 attempts with 500ms delay)
- Graceful viewport discovery fallbacks
- Comprehensive error reporting to MCP client

## Development Guidelines

### Code Style
- TypeScript: Follow standard conventions, use proper typing
- Elixir: Follow community conventions, use `mix format`
- Logging: Use appropriate log levels, include context

### Testing Strategy
- Integration tests for end-to-end functionality
- Unit tests for individual components
- Manual testing with Flamelex as reference application

### Version Management
- Semantic versioning (MAJOR.MINOR.PATCH)
- Update version in both `package.json` and `mix.exs`
- Tag releases in git

## Troubleshooting

### Common Issues
1. **TCP Connection Failed**: Ensure Scenic app includes `ScenicMcp.Server` in supervision tree
2. **No Viewport Found**: Check viewport registration and naming conventions
3. **Input Not Working**: Verify Scenic ViewPort input validation and routing

### Debug Commands
```bash
# Test TCP connection
telnet localhost 9999

# Check Elixir processes
iex> Process.registered() |> Enum.filter(&String.contains?(Atom.to_string(&1), "viewport"))

# Test MCP server
node src/index.ts
