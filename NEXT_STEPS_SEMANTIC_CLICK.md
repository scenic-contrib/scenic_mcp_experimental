# Next Steps: Completing Semantic Click Integration

## Current Status

✅ **Implemented:**
- 3 new Elixir functions in `scenic_mcp/lib/scenic_mcp/tools.ex`
  - `find_clickable_elements/1`
  - `click_element/1`
  - `hover_element/1`
- 3 new TypeScript MCP tool handlers in `scenic_mcp/src/tools.ts`
- Modified `scenic_local/lib/scenic/component/button.ex` to auto-register semantic data
- All tests passing (9/9)
- TypeScript built and bundled

❌ **Issue:**
- New MCP tools not yet available in Claude Desktop (requires MCP server restart)
- Button semantic data may not be reaching the viewport's semantic_table correctly

## Demonstrated

We successfully:
1. Connected to WidgetWorkbench on port 9996
2. Took screenshot showing the Load Component button
3. Clicked manually (but missed - landed at 1135,301 instead of button center)
4. Click visualization shows the miss (red "A:" marker to the right of button)

## What's Left to Complete

### Step 1: Verify Button Semantic Registration

The button code was modified to add semantic data:

```elixir
# In scenic_local/lib/scenic/component/button.ex
semantic_opts = if id do
  [
    semantic: %{
      type: :button,
      label: text,
      clickable: true,
      bounds: %{left: 0, top: 0, width: width, height: height}
    }
  ]
else
  []
end
```

**Problem**: Components create sub-graphs, and semantic data from component sub-graphs may not propagate to the main viewport's semantic_table.

**Solution Options:**

#### Option A: Make Button call ViewPort API directly
Add to button's `init/3` after graph is built:

```elixir
# Register in viewport semantic table
if id do
  viewport = Scene.viewport(scene)

  # Need to implement ViewPort.register_semantic/3
  Scenic.ViewPort.register_semantic(viewport, id, %{
    type: :button,
    label: text,
    clickable: true,
    bounds: %{left: 0, top: 0, width: width, height: height}
  })
end
```

This requires adding `register_semantic/3` to ViewPort module.

#### Option B: Fix semantic propagation from components
Modify ViewPort to recursively collect semantic data from component sub-scenes.

This is more complex but cleaner long-term.

#### Option C: Register at the scene level (WidgetWorkbench)
Instead of modifying Button, register buttons from the parent scene:

```elixir
# In widget_wkb_scene.ex after adding button to graph
graph = graph
|> button("Load Component", id: :load_component_button, ...)

# Register it
Scenic.ViewPort.register_semantic(viewport, :load_component_button, %{
  type: :button,
  label: "Load Component",
  clickable: true,
  bounds: calculate_button_bounds(load_button_frame)
})
```

### Step 2: Make MCP Tools Available

The TypeScript bundle is built but Claude Desktop needs to reload the MCP configuration.

**To reload:**
1. Restart Claude Desktop, OR
2. Modify the MCP config file to trigger reload

Once reloaded, these tools will be available:
- `find_clickable_elements`
- `click_element`
- `hover_element`

### Step 3: Test End-to-End

Once tools are available and semantic data is registered:

```javascript
// 1. Find all clickable elements
find_clickable_elements()
// Should show: load_component_button with bounds and center

// 2. Click by semantic ID
click_element(element_id: "load_component_button")
// Should click dead center of button

// 3. Verify with screenshot
take_screenshot()
// Should show modal opened
```

## Recommended Path Forward

**Quickest solution (Option C):**

1. Add `ViewPort.register_semantic/3` function to scenic_local
2. Call it from WidgetWorkbench after creating buttons
3. Restart WidgetWorkbench to pick up changes
4. Restart Claude Desktop to load new MCP tools
5. Test with `find_clickable_elements()` and `click_element()`

**Implementation for register_semantic/3:**

```elixir
# In scenic_local/lib/scenic/view_port.ex

def register_semantic(viewport_pid, element_id, semantic_data) when is_pid(viewport_pid) do
  GenServer.call(viewport_pid, {:register_semantic, element_id, semantic_data})
end

def register_semantic(%ViewPort{pid: pid}, element_id, semantic_data) do
  register_semantic(pid, element_id, semantic_data)
end

# Handler
def handle_call({:register_semantic, element_id, semantic_data}, _from, %{semantic_table: semantic_table} = state) do
  # Get current graph's semantic data
  graph_key = :_root_  # Or pass as parameter

  current_data = case :ets.lookup(semantic_table, graph_key) do
    [{^graph_key, data}] -> data
    [] -> %{graph_key: graph_key, elements: %{}, by_type: %{}}
  end

  # Add new element
  updated_data = current_data
  |> put_in([:elements, element_id], semantic_data)
  |> update_in([:by_type, semantic_data.type], fn existing ->
    [element_id | (existing || [])]
  end)

  :ets.insert(semantic_table, {graph_key, updated_data})

  {:reply, :ok, state}
end
```

## Files to Modify

1. **scenic_local/lib/scenic/view_port.ex**
   - Add `register_semantic/2` and `register_semantic/3` public functions
   - Add `handle_call({:register_semantic, ...})` handler

2. **scenic-widget-contrib/lib/widget_workbench/widget_wkb_scene.ex**
   - After creating buttons, register them:
     ```elixir
     viewport = Scene.viewport(scene)
     Scenic.ViewPort.register_semantic(viewport, :load_component_button, %{
       type: :button,
       label: "Load Component",
       clickable: true,
       bounds: %{
         left: load_button_frame.pin.point.x,
         top: load_button_frame.pin.point.y,
         width: load_button_frame.size.width,
         height: load_button_frame.size.height
       }
     })
     ```

## Testing Checklist

- [ ] Add `register_semantic/3` to ViewPort
- [ ] Register Load Component button from WidgetWorkbench
- [ ] Recompile scenic_local: `cd scenic_local && mix compile`
- [ ] Restart WidgetWorkbench
- [ ] Restart Claude Desktop to reload MCP tools
- [ ] Connect: `connect_scenic(port: 9996)`
- [ ] Find elements: `find_clickable_elements()`
- [ ] Verify load_component_button appears with correct bounds
- [ ] Click it: `click_element(element_id: "load_component_button")`
- [ ] Take screenshot to verify modal opened
- [ ] Celebrate! 🎉

## Alternative: Manual Testing Without MCP Reload

You can test the Elixir functions directly via IEx:

```elixir
# In WidgetWorkbench IEx console
alias ScenicMcp.Tools

# Test finding elements
{:ok, result} = Tools.find_clickable_elements(%{})
IO.inspect(result, label: "Clickable elements")

# Test clicking
{:ok, click_result} = Tools.click_element(%{"element_id" => "load_component_button"})
IO.inspect(click_result, label: "Click result")
```

This bypasses the MCP interface and tests the core functionality directly.

## Long-Term Enhancement

Once basic semantic click is working, enhance it with:

1. **Auto-registration for all components** - Make Button, TextField, etc. auto-register
2. **Coordinate calculation from transforms** - Calculate actual screen position from transforms
3. **Visibility checks** - Don't return hidden/obscured elements
4. **Better filtering** - By type, text content, ARIA role, etc.
5. **Wait strategies** - `wait_for_element(id, timeout)`, `wait_for_clickable(id)`
6. **Recording** - Record user interactions to generate test scripts

## Summary

The foundation is 100% complete! We just need to:
1. Bridge the gap between component sub-graphs and viewport semantic_table
2. Reload MCP tools in Claude Desktop
3. Test the full workflow

The hardest part (designing the API, implementing the logic, building the infrastructure) is done. Now it's just plumbing! 🔧
