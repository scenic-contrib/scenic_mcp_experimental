# Future Features Archive

This file contains code and functionality that was developed but removed from the initial release to focus on keyboard input only.

## Mouse Functionality

### Elixir Server Mouse Functions (from scenic_mcp/lib/scenic_mcp/server.ex)

```elixir
# Mouse movement handler
defp handle_mouse_move(%{"x" => x, "y" => y}) when is_number(x) and is_number(y) do
  viewport = find_scenic_viewport()
  
  if viewport do
    mouse_event = {:cursor_pos, {x, y}}
    send_input_to_viewport(viewport, mouse_event)
    
    %{status: "ok", message: "Mouse moved to (#{x}, #{y})", viewport: inspect(viewport)}
  else
    %{error: "No Scenic viewport found", available_viewports: list_scenic_viewports()}
  end
end

defp handle_mouse_move(_command) do
  %{error: "Invalid mouse_move command - must provide x and y coordinates"}
end

# Mouse click handler
defp handle_mouse_click(%{"x" => x, "y" => y} = command) when is_number(x) and is_number(y) do
  viewport = find_scenic_viewport()
  
  if viewport do
    button = Map.get(command, "button", "left")
    button_atom = normalize_button_name(button)
    
    # Send mouse move first, then click
    mouse_move = {:cursor_pos, {x, y}}
    mouse_click = {:cursor_button, {button_atom, 1, [], {x, y}}}  # 1 = pressed
    mouse_release = {:cursor_button, {button_atom, 0, [], {x, y}}}  # 0 = released
    
    send_input_to_viewport(viewport, mouse_move)
    Process.sleep(10)
    send_input_to_viewport(viewport, mouse_click)
    Process.sleep(10)
    send_input_to_viewport(viewport, mouse_release)
    
    %{status: "ok", message: "Mouse clicked at (#{x}, #{y}) with #{button} button", viewport: inspect(viewport)}
  else
    %{error: "No Scenic viewport found", available_viewports: list_scenic_viewports()}
  end
end

defp handle_mouse_click(_command) do
  %{error: "Invalid mouse_click command - must provide x and y coordinates"}
end

# Normalize button names
defp normalize_button_name(button) do
  case String.downcase(button) do
    "left" -> :cursor_button_left
    "right" -> :cursor_button_right
    "middle" -> :cursor_button_middle
    other -> String.to_atom("cursor_button_" <> other)
  end
end
```

### TypeScript MCP Tools (from scenic_mcp/src/index.ts)

```typescript
// Mouse movement tool
{
  name: 'send_mouse_move',
  description: 'Move mouse cursor to specific coordinates',
  inputSchema: {
    type: 'object',
    properties: {
      x: {
        type: 'number',
        description: 'X coordinate',
      },
      y: {
        type: 'number',
        description: 'Y coordinate',
      },
    },
    required: ['x', 'y'],
  },
},

// Mouse click tool
{
  name: 'send_mouse_click',
  description: 'Click mouse at specific coordinates',
  inputSchema: {
    type: 'object',
    properties: {
      x: {
        type: 'number',
        description: 'X coordinate',
      },
      y: {
        type: 'number',
        description: 'Y coordinate',
      },
      button: {
        type: 'string',
        enum: ['left', 'right', 'middle'],
        description: 'Mouse button to click (default: left)',
        default: 'left',
      },
    },
    required: ['x', 'y'],
  },
},

// Mouse movement handler
case 'send_mouse_move': {
  try {
    const isRunning = await checkTCPServer();
    if (!isRunning) {
      return {
        content: [
          {
            type: 'text',
            text: 'Cannot send mouse move: Scenic TCP server is not running.',
          },
        ],
        isError: true,
      };
    }

    const { x, y } = request.params.arguments as any;
    
    const command = {
      action: 'send_mouse_move',
      x,
      y,
    };
    
    const response = await sendToElixir(command);
    const data = JSON.parse(response);
    
    if (data.error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error moving mouse: ${data.error}`,
          },
        ],
        isError: true,
      };
    }

    return {
      content: [
        {
          type: 'text',
          text: `Mouse moved to (${x}, ${y})`,
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error moving mouse: ${error instanceof Error ? error.message : 'Unknown error'}`,
        },
      ],
      isError: true,
    };
  }
}

// Mouse click handler
case 'send_mouse_click': {
  try {
    const isRunning = await checkTCPServer();
    if (!isRunning) {
      return {
        content: [
          {
            type: 'text',
            text: 'Cannot send mouse click: Scenic TCP server is not running.',
          },
        ],
        isError: true,
      };
    }

    const { x, y, button = 'left' } = request.params.arguments as any;
    
    const command = {
      action: 'send_mouse_click',
      x,
      y,
      button,
    };
    
    const response = await sendToElixir(command);
    const data = JSON.parse(response);
    
    if (data.error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error clicking mouse: ${data.error}`,
          },
        ],
        isError: true,
      };
    }

    return {
      content: [
        {
          type: 'text',
          text: `Mouse clicked at (${x}, ${y}) with ${button} button`,
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error clicking mouse: ${error instanceof Error ? error.message : 'Unknown error'}`,
        },
      ],
      isError: true,
    };
  }
}
```

## Test Files Archive

The following test files were created during development and contain working examples:

- `test_all_tools.cjs` - Tests all MCP tools including mouse
- `test_b_key_mcp.cjs` - Tests keyboard input via MCP
- `test_b_key.cjs` - Direct keyboard testing
- `test_b_only.cjs` - Minimal keyboard test
- `test_b_simple.cjs` - Simple keyboard test
- `test_generic_scenic.js` - Generic Scenic testing
- `test_send_keys.js` - Key sending tests
- `test_tcp.exs` - TCP connection tests
- `test_visual_feedback.js` - Visual feedback tests
- `reload_server.exs` - Server reload utility

## Root Level Test Files

- `test_b_key_direct.js` - Direct TCP key testing
- `test_complete_mcp_system.js` - End-to-end system test
- `demo_red_box.js` - Red box demo
- `MCP_SUCCESS_SUMMARY.md` - Success documentation

## Development Documentation

- `DEVELOPMENT_SUMMARY.md` - Development process notes
- `WORKING_IMPLEMENTATION_SUMMARY.md` - Implementation details

## Implementation Notes

### Mouse Event Format
Scenic mouse events use the format:
- Movement: `{:cursor_pos, {x, y}}`
- Click: `{:cursor_button, {button_atom, state, modifiers, {x, y}}}`
  - state: 1 = pressed, 0 = released
  - button_atom: `:cursor_button_left`, `:cursor_button_right`, `:cursor_button_middle`

### Mouse Testing Results
Mouse movement was successfully implemented and tested. The system can:
- Move cursor to specific coordinates
- Send mouse click events (left, right, middle buttons)
- Handle mouse button press/release sequences

### Future Integration
To re-enable mouse functionality:
1. Add the mouse functions back to `scenic_mcp/lib/scenic_mcp/server.ex`
2. Add the mouse tools back to `scenic_mcp/src/index.ts`
3. Update the command handler to include mouse actions
4. Test with the archived test files

The mouse functionality was fully working when removed, so re-integration should be straightforward.
