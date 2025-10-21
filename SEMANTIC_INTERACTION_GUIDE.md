# Semantic Interaction Guide

## Overview

scenic_mcp now provides Playwright/Puppeteer-like semantic interaction for Scenic applications! Instead of manually calculating coordinates, you can click and interact with elements by their semantic IDs.

## New MCP Tools

### 1. `find_clickable_elements` - Discover Interactive Elements

Find all clickable elements in the viewport with their IDs, bounds, and center coordinates.

```javascript
// Find all clickable elements
find_clickable_elements()

// Filter by element ID
find_clickable_elements(filter: "load_component_button")
```

**Returns:**
```json
{
  "status": "ok",
  "count": 3,
  "elements": [
    {
      "id": ":load_component_button",
      "type": "button",
      "bounds": {
        "left": 100,
        "top": 200,
        "width": 150,
        "height": 40
      },
      "center": {
        "x": 175,
        "y": 220
      }
    }
  ]
}
```

### 2. `click_element` - Click by Semantic ID

High-level convenience function that finds an element and clicks its center automatically.

```javascript
// Click a button by ID
click_element(element_id: "load_component_button")

// Also accepts with or without colon prefix
click_element(element_id: ":save_button")
```

**Returns:**
```json
{
  "status": "ok",
  "message": "Clicked element load_component_button",
  "clicked_at": {
    "x": 175,
    "y": 220
  }
}
```

### 3. `hover_element` - Hover by Semantic ID

Move the mouse to an element's center without clicking.

```javascript
// Hover over an element to show tooltip
hover_element(element_id: "info_button")
```

**Returns:**
```json
{
  "status": "ok",
  "message": "Hovering over element info_button",
  "position": {
    "x": 175,
    "y": 220
  }
}
```

## Usage Examples

### Example 1: Playwright-Style Test

```javascript
// 1. Connect to the app
connect_scenic(port: 9999)

// 2. Discover available elements
find_clickable_elements()

// 3. Click a button by ID
click_element(element_id: "open_modal_button")

// 4. Verify the modal opened
inspect_viewport()  // Should show modal elements

// 5. Take a screenshot for visual verification
take_screenshot(filename: "modal_opened.png")
```

### Example 2: Testing Form Interaction

```javascript
// Click into a text field
click_element(element_id: "username_field")

// Type some text
send_keys(text: "john_doe")

// Click the submit button
click_element(element_id: "submit_button")

// Verify success
inspect_viewport()
```

### Example 3: Hover Testing

```javascript
// Hover over an element
hover_element(element_id: "help_icon")

// Wait a moment for tooltip
// (add sleep/wait if needed)

// Take screenshot showing tooltip
take_screenshot(filename: "tooltip_visible.png")
```

## How It Works

### Architecture

```
MCP Tool Call
    ↓
TypeScript Handler (tools.ts)
    ↓
TCP Bridge to Elixir
    ↓
Elixir Handler (tools.ex)
    ↓
1. Query semantic_table in ViewPort
2. Find element by ID
3. Calculate center coordinates
4. Send mouse/click events
```

### Semantic Table

Scenic components register themselves in the `:semantic_table` ETS table:

```elixir
# In your Scenic component:
Scenic.ViewPort.set_semantic(viewport, :my_button, %{
  type: :button,
  clickable: true,
  bounds: %{left: x, top: y, width: w, height: h}
})
```

### Element Matching

The filter supports both formats:
- `"load_component_button"` - without colon
- `":load_component_button"` - with colon

Matching is done against the atom key in the semantic table.

## Writing Automated Tests

### Test Structure

```elixir
# In your test file
test "user can click button to open modal" do
  # 1. Start app (with scenic_mcp)
  {:ok, _app} = start_app()

  # 2. Connect MCP
  {:ok, _} = connect_scenic()

  # 3. Find and click button
  {:ok, result} = click_element(%{"element_id" => "open_modal_button"})

  # 4. Verify modal is visible
  {:ok, viewport} = inspect_viewport()
  assert viewport.semantic_elements.by_type[:modal] == 1
end
```

### Integration with SexySpex

```elixir
# In your spex file
scenario "Open component modal" do
  given "the app is running"

  when_ "I click the load component button", fn ->
    click_element(%{"element_id" => "load_component_button"})
  end

  then_ "the modal is visible", fn ->
    {:ok, viewport} = inspect_viewport()
    assert viewport.semantic_elements.by_type[:modal] > 0
  end
end
```

## Error Handling

All functions return `{:ok, result}` or `{:error, reason}`:

```elixir
case click_element(%{"element_id" => "nonexistent"}) do
  {:ok, result} ->
    IO.puts("Clicked successfully!")

  {:error, "Element 'nonexistent' not found or not clickable"} ->
    IO.puts("Element not found")
end
```

## Comparison to Manual Clicking

### Before (Manual Coordinates)

```javascript
// ❌ Fragile - breaks if layout changes
send_mouse_click(x: 1135, y: 301)  // Where is this? What does it click?
```

### After (Semantic ID)

```javascript
// ✅ Robust - works regardless of position
click_element(element_id: "load_component_button")  // Clear intent!
```

## Best Practices

### 1. Use Descriptive IDs

```elixir
# ✅ Good
:save_button
:delete_confirmation_modal
:user_profile_menu

# ❌ Bad
:btn1
:modal
:menu
```

### 2. Register All Interactive Elements

```elixir
# Make sure all buttons, inputs, etc. are in semantic_table
Scenic.ViewPort.set_semantic(viewport, :my_button, %{
  type: :button,
  clickable: true,
  bounds: calculate_bounds(...)
})
```

### 3. Use `find_clickable_elements` for Discovery

```javascript
// When writing tests, first discover what's available
find_clickable_elements()
// Then use the IDs you find
click_element(element_id: "discovered_id")
```

### 4. Combine with Visual Verification

```javascript
// Click something
click_element(element_id: "toggle_theme")

// Verify visually
take_screenshot(filename: "dark_theme.png")
```

## Advanced Usage

### Waiting for Elements

```elixir
# Poll until element appears
def wait_for_element(element_id, timeout \\ 5000) do
  deadline = System.monotonic_time(:millisecond) + timeout

  Stream.repeatedly(fn ->
    case find_clickable_elements(%{"filter" => element_id}) do
      {:ok, %{count: count}} when count > 0 -> {:ok, :found}
      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(100)
          :continue
        else
          {:error, :timeout}
        end
    end
  end)
  |> Enum.find(fn
    {:ok, :found} -> true
    {:error, :timeout} -> true
    _ -> false
  end)
end
```

### Chaining Actions

```elixir
# Build test helpers
def open_and_fill_form(username, password) do
  with {:ok, _} <- click_element(%{"element_id" => "username_field"}),
       {:ok, _} <- send_keys(%{"text" => username}),
       {:ok, _} <- click_element(%{"element_id" => "password_field"}),
       {:ok, _} <- send_keys(%{"text" => password}),
       {:ok, _} <- click_element(%{"element_id" => "submit_button"}) do
    {:ok, :submitted}
  end
end
```

## Troubleshooting

### Element Not Found

**Error:** `Element 'my_button' not found or not clickable`

**Solutions:**
1. Check element is registered: `find_clickable_elements()`
2. Verify ID matches exactly (case-sensitive)
3. Ensure `clickable: true` in semantic data
4. Check element has valid bounds

### No Semantic Table

**Error:** `No semantic table found`

**Solutions:**
1. Ensure your Scenic app has semantic DOM enabled
2. Check components are registering with `ViewPort.set_semantic/3`
3. Verify viewport is fully initialized

### Click Not Working

**Solutions:**
1. Use `take_screenshot()` to see where click landed
2. Verify bounds are correct with `find_clickable_elements()`
3. Check element is not obscured by another element
4. Ensure element is actually clickable in the UI

## Next Steps

- Add element visibility checks (similar to Playwright's actionability)
- Add waiting strategies (wait for element, wait for clickable)
- Add screenshot-based element finding (AI vision)
- Add recording/playback for test generation

## Related Documentation

- [scenic_mcp README](README.md) - Main documentation
- [SEMANTIC_CLICK_HANDOVER.md](../scenic-widget-contrib/docs/SEMANTIC_CLICK_HANDOVER.md) - Implementation details
- [Playwright Actions](https://playwright.dev/docs/input) - Inspiration for this API
