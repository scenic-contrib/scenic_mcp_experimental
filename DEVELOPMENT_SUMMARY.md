# Scenic MCP Server Development Summary

## Current Implementation Status ✅

### Working Components

1. **TCP Server Architecture**
   - Elixir TCP server listening on port 9999
   - Node.js MCP server connecting via TCP
   - Bidirectional communication established
   - JSON-RPC protocol for message passing

2. **Input Injection**
   - Keyboard input successfully injected via `Flamelex.Fluxus.user_input/1`
   - Each character sent as individual key press events
   - Events reaching the application layer (RadixUserInputHandler)

3. **MCP Tools Available**
   - `hello_scenic` - Health check and connection verification
   - `send_keys` - Send keyboard input (text or special keys with modifiers)

## Architecture Overview

```
┌─────────────────┐     TCP      ┌──────────────────┐     Fluxus      ┌─────────────┐
│   MCP Client    │ ◄──────────► │  Scenic MCP      │ ──────────────► │  Flamelex   │
│  (Node.js/TS)   │    :9999     │  (Elixir/OTP)    │                 │    GUI      │
└─────────────────┘              └──────────────────┘                 └─────────────┘
```

## Key Insights from Scenic/Flamelex Architecture

1. **Scenic Graph System**
   - Scenic uses a graph-based scene representation
   - Graphs are compiled to scripts (binary format)
   - Scripts are interpreted by drivers (scenic_driver_local)

2. **Input Flow**
   - System events → GLFW → Scenic Driver → ViewPort → Fluxus → Application
   - Direct injection via Fluxus bypasses system event translation

3. **Coordinate System**
   - Scenic uses its own coordinate system
   - Mouse events include floating-point precision coordinates
   - Negative coordinates are valid (viewport can extend beyond window bounds)

## Next Steps for Full MCP Implementation

### 1. Mouse Control
```elixir
# Add to ScenicMCP.Server
def handle_request("send_mouse_move", %{"x" => x, "y" => y}) do
  Flamelex.Fluxus.user_input({:cursor_pos, {x, y}})
  {:ok, %{status: "ok", position: %{x: x, y: y}}}
end

def handle_request("send_mouse_click", %{"x" => x, "y" => y, "button" => button}) do
  button_atom = String.to_atom(button)
  Flamelex.Fluxus.user_input({:cursor_button, {button_atom, :press, [], {x, y}}})
  Process.sleep(50)
  Flamelex.Fluxus.user_input({:cursor_button, {button_atom, :release, [], {x, y}}})
  {:ok, %{status: "ok"}}
end
```

### 2. Visual State Extraction
```elixir
# Integrate with existing introspection tools
def handle_request("get_visual_state", _params) do
  gui_state = Flamelex.API.GUIIntrospector.describe_current_scene()
  script_summary = Flamelex.API.GUIIntrospector.get_latest_script_summary()
  
  {:ok, %{
    gui_state: gui_state,
    script_analysis: script_summary,
    timestamp: DateTime.utc_now()
  }}
end
```

### 3. Screenshot Capability
```elixir
# Would require integration with scenic driver
def handle_request("take_screenshot", _params) do
  # This would need driver-level support
  # Scenic doesn't have built-in screenshot support
  # Would need to implement via:
  # 1. OpenGL framebuffer capture in scenic_driver_local
  # 2. Or external screenshot tool integration
end
```

### 4. Enhanced Tool Set for MCP

```typescript
// Additional tools to implement in index.ts
const tools = [
  // Navigation
  {
    name: "send_mouse_move",
    description: "Move mouse to coordinates",
    inputSchema: {
      type: "object",
      properties: {
        x: { type: "number" },
        y: { type: "number" }
      },
      required: ["x", "y"]
    }
  },
  {
    name: "send_mouse_click",
    description: "Click at coordinates",
    inputSchema: {
      type: "object",
      properties: {
        x: { type: "number" },
        y: { type: "number" },
        button: { 
          type: "string",
          enum: ["left", "right", "middle"],
          default: "left"
        }
      },
      required: ["x", "y"]
    }
  },
  
  // State inspection
  {
    name: "get_visual_state",
    description: "Get current GUI state and visual information",
    inputSchema: {
      type: "object",
      properties: {}
    }
  },
  
  // Text operations
  {
    name: "get_text_at_cursor",
    description: "Get text content at current cursor position",
    inputSchema: {
      type: "object",
      properties: {}
    }
  },
  
  // Window management
  {
    name: "get_window_info",
    description: "Get window dimensions and viewport info",
    inputSchema: {
      type: "object",
      properties: {}
    }
  }
];
```

## Integration Points

### 1. Fluxus Layer
- Primary injection point for all input events
- Already proven to work with keyboard input
- Need to test mouse events

### 2. GUI Introspection
- Existing tools in `Flamelex.API.GUIIntrospector`
- Script analysis provides rendering information
- Can be extended for semantic understanding

### 3. Scenic ViewPort
- Can query viewport for scene graph information
- Access to component tree and state
- Coordinate transformation utilities

## Development Workflow Achieved ✅

1. **MCP Server Running**: Scenic MCP integrated into Flamelex startup
2. **Input Control**: Can send keyboard input to application
3. **Feedback Loop**: Events logged in console for debugging
4. **Tool Interface**: Clean MCP tool interface for AI agents

## Recommended Next Implementation

1. **Mouse Control** (Priority 1)
   - Implement mouse move and click handlers
   - Test coordinate system mapping
   - Verify hover effects work

2. **Visual State** (Priority 2)
   - Enhance state extraction
   - Add component identification
   - Implement element finding by text/type

3. **Action Sequences** (Priority 3)
   - Implement macro recording/playback
   - Add wait/delay mechanisms
   - Create common action patterns

This implementation provides a solid foundation for AI-driven interaction with Scenic applications, enabling automated testing, accessibility tools, and intelligent agents to interact with Elixir desktop applications.
