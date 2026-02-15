defmodule ScenicMcp.Tools do
  @moduledoc """
  Tool handlers for MCP server.

  Provides handlers for:
  - Keyboard input
  - Mouse input
  - Screenshot capture
  - Viewport inspection

  All functions return either `{:ok, result}` or `{:error, reason}` tuples
  for consistent error handling.
  """

  require Logger

  # ========================================================================
  # Scenic Process Lookup
  # ========================================================================

  @doc """
  Get the PID of the configured viewport process.

  Returns `{:ok, pid}` if found, or `{:error, reason}` if not found.
  """
  @spec viewport_pid() :: {:ok, pid()} | {:error, String.t()}
  def viewport_pid do
    viewport_name = ScenicMcp.Config.viewport_name()

    case Process.whereis(viewport_name) do
      nil ->
        {:error,
         "Unable to find Scenic viewport process ':#{viewport_name}'. " <>
           "Ensure your Scenic application is running and the viewport is registered with this name. " <>
           "You can configure a different name with: config :scenic_mcp, viewport_name: :your_name"}

      pid ->
        {:ok, pid}
    end
  end

  @doc """
  Get the viewport state.

  Returns `{:ok, state}` if successful, or `{:error, reason}` if the viewport
  cannot be found or the state cannot be retrieved.
  """
  @spec viewport_state() :: {:ok, map()} | {:error, String.t()}
  def viewport_state do
    with {:ok, pid} <- viewport_pid() do
      state = :sys.get_state(pid, 5000)
      {:ok, state}
    end
  catch
    :exit, reason ->
      {:error, "Failed to get viewport state: #{inspect(reason)}"}
  end

  @doc """
  Get the PID of the configured driver process.

  Returns `{:ok, pid}` if found, or `{:error, reason}` if not found.
  """
  @spec driver_pid() :: {:ok, pid()} | {:error, String.t()}
  def driver_pid do
    driver_name = ScenicMcp.Config.driver_name()

    case Process.whereis(driver_name) do
      pid when is_pid(pid) ->
        {:ok, pid}

      _otherwise ->
        {:error, "Unable to find Scenic driver process ':#{driver_name}'"}
    end
  catch
    :exit, reason ->
      {:error, "Failed to find driver process: #{inspect(reason)}"}
  end

  @doc """
  Get the driver state.

  Returns `{:ok, state}` if successful, or `{:error, reason}` if the driver
  cannot be found or the state cannot be retrieved.
  """
  @spec driver_state() :: {:ok, any()} | {:error, String.t()}
  def driver_state do
    with {:ok, pid} <- driver_pid() do
      state = :sys.get_state(pid, 5000)
      {:ok, state}
    end
  catch
    :exit, reason ->
      {:error, "Failed to get driver state: #{inspect(reason)}"}
  end

  # ========================================================================
  # Input Handling
  # ========================================================================

  @doc """
  Send input to the Scenic driver.

  Returns `{:ok, :sent}` if successful, or `{:error, reason}` if the driver
  cannot be found or the input cannot be sent.
  """
  @spec send_input(any()) :: {:ok, :sent} | {:error, String.t()}
  def send_input(input) do
    with {:ok, driver_struct} <- driver_state() do
      Scenic.Driver.send_input(driver_struct, input)
      {:ok, :sent}
    end
  catch
    :exit, reason ->
      {:error, "Failed to send input: #{inspect(reason)}"}
  end

  # ========================================================================
  # Tool Handlers (called from server.ex)
  # ========================================================================

  @doc """
  Handle keyboard input.

  Accepts either:
  - `%{"text" => string}` - Type text character by character
  - `%{"key" => string, "modifiers" => list}` - Press special key with optional modifiers

  Returns `{:ok, result_map}` or `{:error, reason}`.
  """
  @spec handle_send_keys(map()) :: {:ok, map()} | {:error, String.t()}
  def handle_send_keys(%{"text" => text}) when is_binary(text) do
    with {:ok, driver_struct} <- driver_state() do
      text
      |> String.graphemes()
      |> Enum.each(fn char ->
        # Scenic components expect :codepoint events for character input
        # The format is {:codepoint, {char_string, modifiers}}
        # where char_string is a single UTF-8 character and modifiers is a list

        # Send the codepoint event (this is what TextField listens for)
        Scenic.Driver.send_input(driver_struct, {:codepoint, {char, []}})
        Process.sleep(10)
      end)

      {:ok, %{status: "ok", message: "Text sent: #{text}"}}
    end
  end

  def handle_send_keys(%{"key" => key} = params) when is_binary(key) do
    with {:ok, driver_struct} <- driver_state() do
      modifiers = parse_modifiers(Map.get(params, "modifiers", []))
      key_atom = normalize_key(key)

      # Key state: 1 = press, 0 = release
      Scenic.Driver.send_input(driver_struct, {:key, {key_atom, 1, modifiers}})
      Process.sleep(10)
      Scenic.Driver.send_input(driver_struct, {:key, {key_atom, 0, modifiers}})

      {:ok, %{status: "ok", message: "Key sent: #{key}"}}
    end
  end

  def handle_send_keys(_params) do
    {:error, "Invalid parameters: must provide either 'text' or 'key' parameter"}
  end

  @doc """
  Handle mouse movement.

  Accepts `%{"x" => number, "y" => number}`.

  Returns `{:ok, result_map}` or `{:error, reason}`.
  """
  @spec handle_mouse_move(map()) :: {:ok, map()} | {:error, String.t()}
  def handle_mouse_move(%{"x" => x, "y" => y}) do
    with {:ok, driver_struct} <- driver_state() do
      Scenic.Driver.send_input(driver_struct, {:cursor_pos, {x, y}})
      {:ok, %{status: "ok", message: "Mouse moved to (#{x}, #{y})"}}
    end
  end

  def handle_mouse_move(_params) do
    {:error, "Invalid parameters: must provide 'x' and 'y' coordinates"}
  end

  @doc """
  Handle mouse clicks.

  Accepts `%{"x" => number, "y" => number, "button" => string}`.
  Button is optional and defaults to "left".

  Returns `{:ok, result_map}` or `{:error, reason}`.
  """
  @spec handle_mouse_click(map()) :: {:ok, map()} | {:error, String.t()}
  def handle_mouse_click(%{"x" => x, "y" => y} = params) do
    with {:ok, driver_struct} <- driver_state() do
      button = parse_button(Map.get(params, "button", "left"))

      # Move to position
      Scenic.Driver.send_input(driver_struct, {:cursor_pos, {x, y}})
      # Click - Scenic format: {:cursor_button, {button, state, modifiers, coords}}
      # state: 1 = press, 0 = release
      Scenic.Driver.send_input(driver_struct, {:cursor_button, {button, 1, [], {x, y}}})
      Process.sleep(10)
      Scenic.Driver.send_input(driver_struct, {:cursor_button, {button, 0, [], {x, y}}})

      {:ok, %{status: "ok", message: "Mouse clicked at (#{x}, #{y})"}}
    end
  end

  def handle_mouse_click(_params) do
    {:error, "Invalid parameters: must provide 'x' and 'y' coordinates"}
  end

  @doc """
  Send mouse button down (press without release).
  Useful for drag operations.

  Params: `%{"x" => number, "y" => number, "button" => string}`
  """
  @spec handle_mouse_down(map()) :: {:ok, map()} | {:error, String.t()}
  def handle_mouse_down(%{"x" => x, "y" => y} = params) do
    with {:ok, driver_struct} <- driver_state() do
      button = parse_button(Map.get(params, "button", "left"))
      Scenic.Driver.send_input(driver_struct, {:cursor_pos, {x, y}})
      Scenic.Driver.send_input(driver_struct, {:cursor_button, {button, 1, [], {x, y}}})
      {:ok, %{status: "ok", message: "Mouse down at (#{x}, #{y})"}}
    end
  end

  def handle_mouse_down(_params) do
    {:error, "Invalid parameters: must provide 'x' and 'y' coordinates"}
  end

  @doc """
  Send mouse button up (release).
  Useful for ending drag operations.

  Params: `%{"x" => number, "y" => number, "button" => string}`
  """
  @spec handle_mouse_up(map()) :: {:ok, map()} | {:error, String.t()}
  def handle_mouse_up(%{"x" => x, "y" => y} = params) do
    with {:ok, driver_struct} <- driver_state() do
      button = parse_button(Map.get(params, "button", "left"))
      Scenic.Driver.send_input(driver_struct, {:cursor_pos, {x, y}})
      Scenic.Driver.send_input(driver_struct, {:cursor_button, {button, 0, [], {x, y}}})
      {:ok, %{status: "ok", message: "Mouse up at (#{x}, #{y})"}}
    end
  end

  def handle_mouse_up(_params) do
    {:error, "Invalid parameters: must provide 'x' and 'y' coordinates"}
  end

  @doc """
  Send scroll wheel input.

  Params:
    - dx: horizontal scroll delta
    - dy: vertical scroll delta
    - x, y: cursor position (optional, defaults to center of viewport)

  Example:
    handle_scroll(%{"dx" => 0, "dy" => -1})  # Scroll down
    handle_scroll(%{"dx" => 1, "dy" => 0})   # Scroll right
  """
  @spec handle_scroll(map()) :: {:ok, map()} | {:error, String.t()}
  def handle_scroll(%{"dx" => dx, "dy" => dy} = params) do
    x = Map.get(params, "x", 400)
    y = Map.get(params, "y", 300)

    with {:ok, driver_struct} <- driver_state() do
      # Scenic cursor_scroll format: {:cursor_scroll, {{dx, dy}, {x, y}}}
      Scenic.Driver.send_input(driver_struct, {:cursor_scroll, {{dx, dy}, {x, y}}})
      {:ok, %{status: "ok", message: "Scroll sent: dx=#{dx}, dy=#{dy} at (#{x}, #{y})"}}
    end
  end

  def handle_scroll(_params) do
    {:error, "Invalid parameters: must provide 'dx' and 'dy' scroll deltas"}
  end

  def inspect_viewport(args \\ nil) do
    handle_get_scenic_graph(args)
  end

  @doc """
  Get viewport graph information.

  Returns `{:ok, result_map}` with viewport structure information,
  or `{:error, reason}` if the viewport cannot be inspected.
  """
  @spec handle_get_scenic_graph(any()) :: {:ok, map()} | {:error, String.t()}
  def handle_get_scenic_graph(_args \\ nil) do
    with {:ok, vp_state} <- viewport_state() do
      case vp_state do
        %{script_table: script_table} = state when script_table != nil ->
          scripts = :ets.tab2list(script_table)

          visual_description = build_scene_description(scripts)
          semantic_info = build_semantic_description(Map.get(state, :semantic_table))

          {:ok,
           %{
             status: "ok",
             script_count: length(scripts),
             visual_description: visual_description,
             semantic_elements: semantic_info,
             raw_scripts:
               Enum.map(scripts, fn
                 {id, _compiled, _pid} -> id
                 {id, _compiled} -> id
               end)
           }}

        _ ->
          {:error,
           "No script table found in viewport state. The viewport may not be fully initialized. State keys: #{inspect(Map.keys(vp_state))}"}
      end
    end
  end

  @doc """
  Find clickable elements in the current viewport.

  Returns `{:ok, result_map}` with a list of clickable elements and their center coordinates,
  or `{:error, reason}` if elements cannot be found.

  Optional params:
  - `filter`: Filter by element ID (matches against atom keys)
  """
  @spec find_clickable_elements(map()) :: {:ok, map()} | {:error, String.t()}
  def find_clickable_elements(params) do
    with {:ok, vp_state} <- viewport_state() do
      case Map.get(vp_state, :semantic_table) do
        nil ->
          {:error, "No semantic table found - the viewport may not have semantic DOM enabled"}

        semantic_table ->
          # Phase 1 Semantic Registration Format
          # ETS stores: {{scene_name, entry_id}, %Entry{}}
          # where Entry has: id, type, clickable, screen_bounds, local_bounds, etc.
          #
          # Alternative format (some Scenic versions):
          # {graph_key, %{elements: %{}, by_type: %{}, ...}}

          raw_entries = :ets.tab2list(semantic_table)

          all_entries = raw_entries
            |> Enum.flat_map(fn
              # Standard Phase 1 format: {{scene_name, entry_id}, entry_struct}
              {{scene_name, _entry_id}, entry} when is_map(entry) and is_map_key(entry, :id) ->
                [{entry.id, entry, scene_name}]

              # Alternative format: {graph_key, %{elements: %{id => entry}, ...}}
              {graph_key, %{elements: elements}} when is_map(elements) ->
                Enum.map(elements, fn {id, entry} ->
                  {id, entry, graph_key}
                end)

              # Fallback: skip unknown formats
              _other ->
                []
            end)

          # Group by ID (in case multiple scenes have same ID)
          # Prefer :_root_ scene, otherwise use first one found
          flat_elements = all_entries
            |> Enum.group_by(fn {id, _entry, _scene_name} -> id end)
            |> Enum.map(fn {_id, versions} ->
              # Prefer entries from :_root_ scene
              best_version = Enum.max_by(versions, fn {_id, _entry, scene_name} ->
                if scene_name in [:_root_, "_root_"], do: 1_000_000, else: 0
              end)
              {id, entry, _scene_name} = best_version
              {id, entry}
            end)

          filter = Map.get(params, "filter")

          clickable_elements =
            flat_elements
            |> Enum.filter(fn {_id, entry} ->
              # Phase 1: clickable flag is directly on the Entry struct
              Map.get(entry, :clickable, false)
            end)
            |> maybe_filter_by_id(filter)
            |> Enum.map(fn {id, entry} ->
              # Phase 1: Use screen_bounds (will fall back to local_bounds in Phase 1)
              # Bounds format: %{left: x, top: y, width: w, height: h}
              bounds = entry.screen_bounds

              # Calculate center from bounds
              center = if bounds do
                %{
                  "x" => bounds.left + bounds.width / 2,
                  "y" => bounds.top + bounds.height / 2
                }
              else
                nil
              end

              # Convert bounds to old format for compatibility
              bounds_map = if bounds do
                %{
                  "left" => bounds.left,
                  "top" => bounds.top,
                  "width" => bounds.width,
                  "height" => bounds.height
                }
              else
                nil
              end

              %{
                id: inspect(id),
                raw_id: id,
                type: entry.type,
                bounds: bounds_map,
                center: center,
                clickable: entry.clickable,
                label: entry.label,
                role: entry.role,
                z_index: entry.z_index
              }
              |> sanitize_for_json()
            end)

          {:ok,
           %{
             status: "ok",
             count: length(clickable_elements),
             elements: clickable_elements
           }}
      end
    end
  end

  @doc """
  Click on an element by its semantic ID.

  This is a high-level convenience function similar to Playwright's `page.click(selector)`.
  It finds the element, calculates its center, and clicks it automatically.

  Params:
  - `element_id`: The semantic ID to click (string or atom, e.g., ":load_component_button")

  Returns `{:ok, result_map}` with click details, or `{:error, reason}` if element not found.
  """
  @spec click_element(map()) :: {:ok, map()} | {:error, String.t()}
  def click_element(%{"element_id" => element_id}) when is_binary(element_id) do
    with {:ok, result} <- find_clickable_elements(%{"filter" => element_id}),
         element <- List.first(result.elements) do
      if element do
        # Handle both atom and string keys (after sanitization)
        center = get_in_sanitized(element, [:center]) || get_in_sanitized(element, ["center"])

        case center do
          %{"x" => x, "y" => y} when is_number(x) and is_number(y) ->
            # Click at the element's center
            case handle_mouse_click(%{"x" => x, "y" => y}) do
              {:ok, _click_result} ->
                {:ok,
                 %{
                   status: "ok",
                   message: "Clicked element #{element_id}",
                   element: element,
                   clicked_at: %{x: x, y: y}
                 }}

              {:error, reason} ->
                {:error, "Failed to click element: #{reason}"}
            end

          _ ->
            {:error, "Element found but has no valid center coordinates: #{inspect(center)}"}
        end
      else
        {:error, "Element '#{element_id}' not found or not clickable"}
      end
    end
  end

  def click_element(_params) do
    {:error, "Invalid parameters: must provide 'element_id' parameter"}
  end

  @doc """
  Move mouse to hover over an element by its semantic ID.

  Similar to Playwright's hover functionality - finds the element and moves the mouse
  to its center without clicking.

  Params:
  - `element_id`: The semantic ID to hover over (string or atom)

  Returns `{:ok, result_map}` with hover details, or `{:error, reason}` if element not found.
  """
  @spec hover_element(map()) :: {:ok, map()} | {:error, String.t()}
  def hover_element(%{"element_id" => element_id}) when is_binary(element_id) do
    with {:ok, result} <- find_clickable_elements(%{"filter" => element_id}),
         element <- List.first(result.elements) do
      if element do
        # Handle both atom and string keys (after sanitization)
        center = get_in_sanitized(element, [:center]) || get_in_sanitized(element, ["center"])

        case center do
          %{"x" => x, "y" => y} when is_number(x) and is_number(y) ->
            case handle_mouse_move(%{"x" => x, "y" => y}) do
              {:ok, _move_result} ->
                {:ok,
                 %{
                   status: "ok",
                   message: "Hovering over element #{element_id}",
                   element: element,
                   position: %{x: x, y: y}
                 }}

              {:error, reason} ->
                {:error, "Failed to move mouse to element: #{reason}"}
            end

          _ ->
            {:error, "Element found but has no valid center coordinates: #{inspect(center)}"}
        end
      else
        {:error, "Element '#{element_id}' not found"}
      end
    end
  end

  def hover_element(_params) do
    {:error, "Invalid parameters: must provide 'element_id' parameter"}
  end

  @doc """
  Capture a screenshot of the Scenic application.

  Accepts `%{"format" => "path" | "base64", "filename" => string}`.
  Both parameters are optional.

  Returns `{:ok, result_map}` with screenshot information,
  or `{:error, reason}` if the screenshot cannot be captured.
  """
  @spec take_screenshot(map()) :: {:ok, map()} | {:error, String.t()}
  def take_screenshot(params) do
    format = Map.get(params, "format", "path")
    filename = Map.get(params, "filename")

    path =
      if filename do
        if String.ends_with?(filename, ".png") do
          filename
        else
          filename <> ".png"
        end
      else
        timestamp =
          DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[:\s]/, "_")

        "/tmp/scenic_screenshot_#{timestamp}.png"
      end

    with {:ok, vp_pid} <- viewport_pid(),
         {:ok, driver_pid} <- get_driver_from_viewport(vp_pid),
         driver_state <- :sys.get_state(driver_pid),
         :ok <- Scenic.Driver.Local.screenshot(driver_state, path) do
      if format == "base64" do
        case File.read(path) do
          {:ok, binary} ->
            encoded = Base.encode64(binary)

            {:ok,
             %{
               status: "ok",
               path: path,
               format: "base64",
               data: encoded,
               size: byte_size(binary)
             }}

          {:error, reason} ->
            {:error, "Failed to read screenshot file: #{inspect(reason)}"}
        end
      else
        {:ok, %{status: "ok", path: path, format: "path"}}
      end
    else
      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, "Screenshot failed: #{inspect(other)}"}
    end
  end

  # ========================================================================
  # Helper Functions
  # ========================================================================

  defp get_driver_from_viewport(vp_pid) do
    case :sys.get_state(vp_pid) do
      %{driver_pids: [driver_pid | _]} ->
        {:ok, driver_pid}

      _ ->
        {:error,
         "No driver found in viewport state. Ensure your Scenic driver is properly configured."}
    end
  catch
    :exit, reason ->
      {:error, "Failed to get driver from viewport: #{inspect(reason)}"}
  end

  defp build_scene_description(scripts) do
    scripts
    |> Enum.map(fn
      {id, _compiled_script, _pid} -> {id, nil}
      {id, _compiled_script} -> {id, nil}
      other -> {other, nil}
    end)
    |> Enum.map(fn {id, _} ->
      component_name =
        case id do
          {name, _uid} when is_atom(name) -> Atom.to_string(name)
          name when is_atom(name) -> Atom.to_string(name)
          _ -> inspect(id)
        end

      %{
        id: inspect(id),
        component: component_name
      }
    end)
    |> Enum.group_by(& &1.component)
    |> Enum.map(fn {component, items} ->
      "#{component} (#{length(items)} instances)"
    end)
    |> Enum.join(", ")
  end

  defp build_semantic_description(nil),
    do: %{count: 0, elements: [], summary: "No semantic DOM available"}

  defp build_semantic_description(semantic_table) do
    try do
      # Each entry in semantic_table is {graph_key, %{elements: %{id => element_info}, timestamp: ...}}
      # We need to flatten the nested elements map
      # IMPORTANT: Keep only the LATEST version of each element ID (by timestamp)
      raw_table = :ets.tab2list(semantic_table)
      IO.inspect(raw_table |> Enum.map(fn {key, data} ->
        {key, Map.keys(Map.get(data, :elements, %{})), Map.get(data, :timestamp)}
      end), label: "DEBUG: Raw semantic table entries")

      flat_elements = raw_table
        |> Enum.flat_map(fn {graph_key, data} ->
          timestamp = Map.get(data, :timestamp, 0)
          # Extract the nested elements map
          case Map.get(data, :elements) do
            elements when is_map(elements) ->
              Enum.map(elements, fn {id, element_info} ->
                {id, element_info, timestamp, graph_key}
              end)
            _ -> []
          end
        end)
        # Keep the best version of each ID
        # Prefer entries from :_root_ graph, otherwise take the latest by timestamp
        |> Enum.group_by(fn {id, _element_info, _timestamp, _graph_key} -> id end)
        |> Enum.map(fn {_id, versions} ->
          # Prefer _root_ entries, otherwise take latest timestamp
          best_version = Enum.max_by(versions, fn {_id, _info, ts, graph_key} ->
            root_priority = if graph_key in [:_root_, "_root_"], do: 1_000_000_000_000, else: 0
            root_priority + ts
          end)
          {id, element_info, _timestamp, _graph_key} = best_version
          {id, element_info}
        end)

      summary =
        flat_elements
        |> Enum.map(fn {_id, element_info} ->
          element_info
          |> Map.get(:semantic, %{})
          |> Map.get(:type, :unknown)
          |> to_string()
        end)
        |> Enum.frequencies()
        |> Enum.map(fn {type, count} -> "#{count} #{type}" end)
        |> Enum.join(", ")

      %{
        count: length(flat_elements),
        elements: Enum.map(flat_elements, fn {id, element_info} ->
          element_info
          |> Map.put(:key, inspect(id))
          |> sanitize_for_json()
        end),
        summary: summary,
        by_type:
          Enum.frequencies(
            Enum.map(flat_elements, fn {_id, element_info} ->
              Map.get(element_info, :semantic, %{}) |> Map.get(:type, :unknown)
            end)
          ),
        clickable_count:
          Enum.count(flat_elements, fn {_id, element_info} ->
            element_info
            |> Map.get(:semantic, %{})
            |> Map.get(:clickable, false)
          end)
      }
    rescue
      _ -> %{count: 0, elements: [], summary: "Error reading semantic table"}
    end
  end

  # Convert a character to a key event that applications can understand.
  # Returns {:ok, key_event} for supported characters, :error otherwise.
  defp char_to_key_event(char) do
    case char do
      # Lowercase letters
      "a" -> {:ok, {:key, {:key_a, 1, []}}}
      "b" -> {:ok, {:key, {:key_b, 1, []}}}
      "c" -> {:ok, {:key, {:key_c, 1, []}}}
      "d" -> {:ok, {:key, {:key_d, 1, []}}}
      "e" -> {:ok, {:key, {:key_e, 1, []}}}
      "f" -> {:ok, {:key, {:key_f, 1, []}}}
      "g" -> {:ok, {:key, {:key_g, 1, []}}}
      "h" -> {:ok, {:key, {:key_h, 1, []}}}
      "i" -> {:ok, {:key, {:key_i, 1, []}}}
      "j" -> {:ok, {:key, {:key_j, 1, []}}}
      "k" -> {:ok, {:key, {:key_k, 1, []}}}
      "l" -> {:ok, {:key, {:key_l, 1, []}}}
      "m" -> {:ok, {:key, {:key_m, 1, []}}}
      "n" -> {:ok, {:key, {:key_n, 1, []}}}
      "o" -> {:ok, {:key, {:key_o, 1, []}}}
      "p" -> {:ok, {:key, {:key_p, 1, []}}}
      "q" -> {:ok, {:key, {:key_q, 1, []}}}
      "r" -> {:ok, {:key, {:key_r, 1, []}}}
      "s" -> {:ok, {:key, {:key_s, 1, []}}}
      "t" -> {:ok, {:key, {:key_t, 1, []}}}
      "u" -> {:ok, {:key, {:key_u, 1, []}}}
      "v" -> {:ok, {:key, {:key_v, 1, []}}}
      "w" -> {:ok, {:key, {:key_w, 1, []}}}
      "x" -> {:ok, {:key, {:key_x, 1, []}}}
      "y" -> {:ok, {:key, {:key_y, 1, []}}}
      "z" -> {:ok, {:key, {:key_z, 1, []}}}

      # Uppercase letters (with shift modifier)
      "A" -> {:ok, {:key, {:key_a, 1, ["shift"]}}}
      "B" -> {:ok, {:key, {:key_b, 1, ["shift"]}}}
      "C" -> {:ok, {:key, {:key_c, 1, ["shift"]}}}
      "D" -> {:ok, {:key, {:key_d, 1, ["shift"]}}}
      "E" -> {:ok, {:key, {:key_e, 1, ["shift"]}}}
      "F" -> {:ok, {:key, {:key_f, 1, ["shift"]}}}
      "G" -> {:ok, {:key, {:key_g, 1, ["shift"]}}}
      "H" -> {:ok, {:key, {:key_h, 1, ["shift"]}}}
      "I" -> {:ok, {:key, {:key_i, 1, ["shift"]}}}
      "J" -> {:ok, {:key, {:key_j, 1, ["shift"]}}}
      "K" -> {:ok, {:key, {:key_k, 1, ["shift"]}}}
      "L" -> {:ok, {:key, {:key_l, 1, ["shift"]}}}
      "M" -> {:ok, {:key, {:key_m, 1, ["shift"]}}}
      "N" -> {:ok, {:key, {:key_n, 1, ["shift"]}}}
      "O" -> {:ok, {:key, {:key_o, 1, ["shift"]}}}
      "P" -> {:ok, {:key, {:key_p, 1, ["shift"]}}}
      "Q" -> {:ok, {:key, {:key_q, 1, ["shift"]}}}
      "R" -> {:ok, {:key, {:key_r, 1, ["shift"]}}}
      "S" -> {:ok, {:key, {:key_s, 1, ["shift"]}}}
      "T" -> {:ok, {:key, {:key_t, 1, ["shift"]}}}
      "U" -> {:ok, {:key, {:key_u, 1, ["shift"]}}}
      "V" -> {:ok, {:key, {:key_v, 1, ["shift"]}}}
      "W" -> {:ok, {:key, {:key_w, 1, ["shift"]}}}
      "X" -> {:ok, {:key, {:key_x, 1, ["shift"]}}}
      "Y" -> {:ok, {:key, {:key_y, 1, ["shift"]}}}
      "Z" -> {:ok, {:key, {:key_z, 1, ["shift"]}}}

      # Numbers
      "0" -> {:ok, {:key, {:key_0, 1, []}}}
      "1" -> {:ok, {:key, {:key_1, 1, []}}}
      "2" -> {:ok, {:key, {:key_2, 1, []}}}
      "3" -> {:ok, {:key, {:key_3, 1, []}}}
      "4" -> {:ok, {:key, {:key_4, 1, []}}}
      "5" -> {:ok, {:key, {:key_5, 1, []}}}
      "6" -> {:ok, {:key, {:key_6, 1, []}}}
      "7" -> {:ok, {:key, {:key_7, 1, []}}}
      "8" -> {:ok, {:key, {:key_8, 1, []}}}
      "9" -> {:ok, {:key, {:key_9, 1, []}}}

      # Common symbols
      " " -> {:ok, {:key, {:key_space, 1, []}}}
      "!" -> {:ok, {:key, {:key_1, 1, ["shift"]}}}
      "\"" -> {:ok, {:key, {:key_apostrophe, 1, ["shift"]}}}
      "#" -> {:ok, {:key, {:key_3, 1, ["shift"]}}}
      "$" -> {:ok, {:key, {:key_4, 1, ["shift"]}}}
      "%" -> {:ok, {:key, {:key_5, 1, ["shift"]}}}
      "&" -> {:ok, {:key, {:key_7, 1, ["shift"]}}}
      "'" -> {:ok, {:key, {:key_apostrophe, 1, []}}}
      "(" -> {:ok, {:key, {:key_9, 1, ["shift"]}}}
      ")" -> {:ok, {:key, {:key_0, 1, ["shift"]}}}
      "*" -> {:ok, {:key, {:key_8, 1, ["shift"]}}}
      "+" -> {:ok, {:key, {:key_equal, 1, ["shift"]}}}
      "," -> {:ok, {:key, {:key_comma, 1, []}}}
      "-" -> {:ok, {:key, {:key_minus, 1, []}}}
      "." -> {:ok, {:key, {:key_period, 1, []}}}
      "/" -> {:ok, {:key, {:key_slash, 1, []}}}
      ":" -> {:ok, {:key, {:key_semicolon, 1, ["shift"]}}}
      ";" -> {:ok, {:key, {:key_semicolon, 1, []}}}
      "<" -> {:ok, {:key, {:key_comma, 1, ["shift"]}}}
      "=" -> {:ok, {:key, {:key_equal, 1, []}}}
      ">" -> {:ok, {:key, {:key_period, 1, ["shift"]}}}
      "?" -> {:ok, {:key, {:key_slash, 1, ["shift"]}}}
      "@" -> {:ok, {:key, {:key_2, 1, ["shift"]}}}
      "[" -> {:ok, {:key, {:key_left_bracket, 1, []}}}
      "\\" -> {:ok, {:key, {:key_backslash, 1, []}}}
      "]" -> {:ok, {:key, {:key_right_bracket, 1, []}}}
      "^" -> {:ok, {:key, {:key_6, 1, ["shift"]}}}
      "_" -> {:ok, {:key, {:key_minus, 1, ["shift"]}}}
      "`" -> {:ok, {:key, {:key_grave_accent, 1, []}}}
      "{" -> {:ok, {:key, {:key_left_bracket, 1, ["shift"]}}}
      "|" -> {:ok, {:key, {:key_backslash, 1, ["shift"]}}}
      "}" -> {:ok, {:key, {:key_right_bracket, 1, ["shift"]}}}
      "~" -> {:ok, {:key, {:key_grave_accent, 1, ["shift"]}}}

      # Unsupported character
      _ -> :error
    end
  end

  defp normalize_key(key) do
    case String.downcase(key) do
      "enter" -> :key_enter
      "escape" -> :key_escape
      "tab" -> :key_tab
      "backspace" -> :key_backspace
      "delete" -> :key_delete
      "space" -> :key_space
      "up" -> :key_up
      "down" -> :key_down
      "left" -> :key_left
      "right" -> :key_right
      "home" -> :key_home
      "end" -> :key_end
      "page_up" -> :key_pageup
      "page_down" -> :key_pagedown
      "f1" -> :key_f1
      "f2" -> :key_f2
      "f3" -> :key_f3
      "f4" -> :key_f4
      "f5" -> :key_f5
      "f6" -> :key_f6
      "f7" -> :key_f7
      "f8" -> :key_f8
      "f9" -> :key_f9
      "f10" -> :key_f10
      "f11" -> :key_f11
      "f12" -> :key_f12
      "shift" -> :key_leftshift
      "leftshift" -> :key_leftshift
      "rightshift" -> :key_rightshift
      "ctrl" -> :key_leftctrl
      "leftctrl" -> :key_leftctrl
      "rightctrl" -> :key_rightctrl
      "alt" -> :key_leftalt
      "leftalt" -> :key_leftalt
      "rightalt" -> :key_rightalt
      other -> String.to_atom("key_" <> other)
    end
  end

  @doc """
  Send a key press event (without release).

  This is useful for holding modifier keys like shift while performing other actions.
  """
  @spec handle_key_press(map()) :: {:ok, map()} | {:error, String.t()}
  def handle_key_press(%{"key" => key}) do
    with {:ok, driver_struct} <- driver_state() do
      key_atom = normalize_key(key)
      Scenic.Driver.send_input(driver_struct, {:key, {key_atom, 1, []}})
      {:ok, %{status: "ok", message: "Key pressed: #{key}"}}
    end
  end

  @doc """
  Send a key release event.
  """
  @spec handle_key_release(map()) :: {:ok, map()} | {:error, String.t()}
  def handle_key_release(%{"key" => key}) do
    with {:ok, driver_struct} <- driver_state() do
      key_atom = normalize_key(key)
      Scenic.Driver.send_input(driver_struct, {:key, {key_atom, 0, []}})
      {:ok, %{status: "ok", message: "Key released: #{key}"}}
    end
  end

  defp parse_modifiers(modifiers) when is_list(modifiers) do
    modifiers
    |> Enum.filter(&(&1 in ["shift", "ctrl", "alt", "cmd", "meta"]))
    |> Enum.map(&String.to_atom/1)  # Convert to atoms for Scenic
  end

  defp parse_modifiers(_), do: []

  defp parse_button(button) when is_binary(button) do
    case String.downcase(button) do
      "left" -> :btn_left
      "right" -> :btn_right
      "middle" -> :btn_middle
      _ -> :btn_left
    end
  end

  defp parse_button(_), do: :btn_left

  # Convert Unicode codepoint to Scenic key atom with modifiers
  # Returns {key_atom, modifiers} tuple
  # Letters and numbers get :key_<char> format (e.g., :key_a, :key_1)
  # Special characters get their own key atoms, uppercase/symbols include shift
  defp codepoint_to_key_with_mods(codepoint) when is_integer(codepoint) do
    case codepoint do
      # Lowercase letters a-z (no shift)
      c when c >= ?a and c <= ?z -> {String.to_atom("key_#{<<c>>}"), []}
      # Uppercase letters A-Z (need shift)
      c when c >= ?A and c <= ?Z -> {String.to_atom("key_#{<<c + 32>>}"), [:shift]}
      # Numbers 0-9 (no shift)
      c when c >= ?0 and c <= ?9 -> {String.to_atom("key_#{<<c>>}"), []}
      # Space
      32 -> {:key_space, []}
      # Common punctuation requiring shift
      ?! -> {:key_1, [:shift]}
      ?@ -> {:key_2, [:shift]}
      ?# -> {:key_3, [:shift]}
      ?$ -> {:key_4, [:shift]}
      ?% -> {:key_5, [:shift]}
      ?^ -> {:key_6, [:shift]}
      ?& -> {:key_7, [:shift]}
      ?* -> {:key_8, [:shift]}
      ?( -> {:key_9, [:shift]}
      ?) -> {:key_0, [:shift]}
      ?_ -> {:key_minus, [:shift]}
      ?+ -> {:key_equal, [:shift]}
      ?{ -> {:key_open_bracket, [:shift]}
      ?} -> {:key_close_bracket, [:shift]}
      ?| -> {:key_backslash, [:shift]}
      ?: -> {:key_semicolon, [:shift]}
      ?" -> {:key_apostrophe, [:shift]}
      ?< -> {:key_comma, [:shift]}
      ?> -> {:key_period, [:shift]}
      ?? -> {:key_slash, [:shift]}
      ?~ -> {:key_grave, [:shift]}
      # Common punctuation without shift
      ?- -> {:key_minus, []}
      ?= -> {:key_equal, []}
      ?[ -> {:key_open_bracket, []}
      ?] -> {:key_close_bracket, []}
      ?\\ -> {:key_backslash, []}
      ?\; -> {:key_semicolon, []}
      ?' -> {:key_apostrophe, []}
      ?, -> {:key_comma, []}
      ?. -> {:key_period, []}
      ?/ -> {:key_slash, []}
      ?` -> {:key_grave, []}
      # Fallback for unknown characters - use generic key name
      _ -> {:key_unknown, []}
    end
  end

  defp calculate_center(bounds) when is_map(bounds) do
    # Bounds format: %{left: x, top: y, width: w, height: h}
    left = Map.get(bounds, :left, 0)
    top = Map.get(bounds, :top, 0)
    width = Map.get(bounds, :width, 0)
    height = Map.get(bounds, :height, 0)

    %{
      x: left + width / 2,
      y: top + height / 2
    }
  end

  defp calculate_center(_), do: %{x: 0, y: 0}

  defp calculate_center_with_transforms(bounds, transforms, graph_key, vp_state) when is_map(bounds) do
    # Calculate local center
    local_center = calculate_center(bounds)

    # DEBUG: See what transforms we're getting
    IO.inspect(transforms, label: "DEBUG: Element transforms")

    # Apply element's own translate transform if present
    # Transforms can be in format: %{translate: {x, y}} or %{pin: ..., translate: ...}
    element_translate = case Map.get(transforms, :translate) do
      {tx, ty} when is_number(tx) and is_number(ty) -> {tx, ty}
      _ -> {0, 0}
    end

    {elem_tx, elem_ty} = element_translate
    IO.inspect({elem_tx, elem_ty}, label: "DEBUG: Element translate")

    # NEW: Traverse the graph hierarchy and accumulate all parent transforms
    hierarchy_translate = get_hierarchy_transforms(graph_key, vp_state)
    {hier_tx, hier_ty} = hierarchy_translate
    IO.inspect({hier_tx, hier_ty}, label: "DEBUG: Hierarchy translate for #{inspect(graph_key)}")

    # Accumulate all transforms
    %{
      x: local_center.x + elem_tx + hier_tx,
      y: local_center.y + elem_ty + hier_ty
    }
  end

  defp calculate_center_with_transforms(bounds, _transforms, _graph_key, _vp_state) do
    calculate_center(bounds)
  end

  @doc """
  Traverse the graph hierarchy and accumulate transforms from all parent graphs.

  Uses scene_script_table which contains parent-child relationships between graphs.

  ## Algorithm

  1. Build a parent map from scene_script_table (child -> parent)
  2. Walk up the chain from element's graph_key to :_root_
  3. For each graph in the chain, extract and accumulate its transforms
  4. Return the total accumulated translate offset

  ## Example

  Button in scrolled modal:
  - Button graph_key: "xyz123" (transforms: translate {20, 630})
  - Parent scroll group: "abc456" (transforms: translate {0, -495})
  - Parent modal container: "def789" (transforms: translate {300, 100})
  - Root: :_root_

  Accumulated: {20, 630} + {0, -495} + {300, 100} = {320, 235}
  """
  defp get_hierarchy_transforms(nil, _vp_state), do: {0, 0}
  defp get_hierarchy_transforms(_graph_key, nil), do: {0, 0}

  defp get_hierarchy_transforms(graph_key, vp_state) when graph_key in [:_root_, "_root_"] do
    # Root graph has no parent, no accumulated transform
    {0, 0}
  end

  defp get_hierarchy_transforms(graph_key, vp_state) do
    scene_script_table = Map.get(vp_state, :scene_script_table)

    if scene_script_table == nil do
      IO.puts("DEBUG: No scene_script_table in viewport state")
      {0, 0}
    else
      # Build parent map from scene_script_table
      parent_map = build_parent_map(scene_script_table)
      IO.inspect(Map.keys(parent_map), label: "DEBUG: Parent map keys", limit: 10)

      # Walk up the hierarchy and accumulate transforms
      accumulate_parent_transforms(graph_key, parent_map, scene_script_table, {0, 0}, 0)
    end
  end

  @doc """
  Build a child -> parent map from scene_script_table.

  scene_script_table entries have format:
  {graph_key, %{children: [child_key1, child_key2, ...], transforms: [...], ...}}

  We invert this to create: %{child_key => parent_key}
  """
  defp build_parent_map(scene_script_table) do
    :ets.tab2list(scene_script_table)
    |> Enum.reduce(%{}, fn {parent_key, script_info}, acc ->
      children = Map.get(script_info, :children, [])

      Enum.reduce(children, acc, fn child_key, acc2 ->
        Map.put(acc2, child_key, parent_key)
      end)
    end)
  end

  @doc """
  Recursively walk up the parent chain and accumulate transforms.

  Stops at :_root_ or when no parent is found (max depth 10 for safety).
  """
  defp accumulate_parent_transforms(_graph_key, _parent_map, _scene_script_table, acc, depth) when depth > 10 do
    IO.puts("DEBUG: Max hierarchy depth (10) reached, stopping")
    acc
  end

  defp accumulate_parent_transforms(graph_key, parent_map, scene_script_table, {acc_x, acc_y}, depth) do
    # Look up this graph's parent
    case Map.get(parent_map, graph_key) do
      nil ->
        # No parent found, we're at the top
        IO.puts("DEBUG: No parent for #{inspect(graph_key)}, stopping at depth #{depth}")
        {acc_x, acc_y}

      parent_key when parent_key in [:_root_, "_root_"] ->
        # Reached root, stop here
        IO.puts("DEBUG: Reached root from #{inspect(graph_key)} at depth #{depth}")
        {acc_x, acc_y}

      parent_key ->
        # Get parent's transforms from scene_script_table
        parent_transform = get_graph_transform_from_scene_script(parent_key, scene_script_table)
        {parent_tx, parent_ty} = parent_transform
        IO.puts("DEBUG: Parent #{inspect(parent_key)} has transform {#{parent_tx}, #{parent_ty}}")

        # Accumulate and recurse
        new_acc = {acc_x + parent_tx, acc_y + parent_ty}
        accumulate_parent_transforms(parent_key, parent_map, scene_script_table, new_acc, depth + 1)
    end
  end

  @doc """
  Extract translate transform from a scene_script_table entry.

  scene_script_table has format:
  {graph_key, %{transforms: [{:translate, {x, y}}, ...], ...}}
  """
  defp get_graph_transform_from_scene_script(graph_key, scene_script_table) do
    case :ets.lookup(scene_script_table, graph_key) do
      [] ->
        IO.puts("DEBUG: Graph #{inspect(graph_key)} not found in scene_script_table")
        {0, 0}

      [{^graph_key, script_info}] ->
        # Extract transforms list
        transforms_list = Map.get(script_info, :transforms, [])

        # Find translate transform
        translate = Enum.find_value(transforms_list, {0, 0}, fn
          {:translate, {x, y}} when is_number(x) and is_number(y) -> {x, y}
          _ -> false
        end)

        translate

      other ->
        IO.puts("DEBUG: Unexpected scene_script_table format: #{inspect(other)}")
        {0, 0}
    end
  end

  @doc """
  DEPRECATED: Old function that only looked at immediate graph transform.
  Replaced by get_hierarchy_transforms which traverses the full parent chain.
  """
  defp get_graph_transform(nil, _vp_state), do: {0, 0}
  defp get_graph_transform(_graph_key, nil), do: {0, 0}

  defp get_graph_transform(graph_key, vp_state) when graph_key in [:_root_, "_root_"] do
    # Root graph has no transform
    {0, 0}
  end

  defp get_graph_transform(graph_key, vp_state) do
    # Look up the graph's script in the script_table
    case Map.get(vp_state, :script_table) do
      nil ->
        IO.puts("DEBUG: No script_table in viewport state")
        {0, 0}

      script_table ->
        case :ets.lookup(script_table, graph_key) do
          [] ->
            IO.puts("DEBUG: Graph key #{inspect(graph_key)} not found in script_table")
            {0, 0}

          [{^graph_key, compiled_script} | _] ->
            extract_translate_from_script(compiled_script, graph_key)

          [{^graph_key, compiled_script, _pid} | _] ->
            extract_translate_from_script(compiled_script, graph_key)

          other ->
            IO.puts("DEBUG: Unexpected script_table format for #{inspect(graph_key)}: #{inspect(other)}")
            {0, 0}
        end
    end
  end

  @doc """
  Extract the translate transform from a compiled Scenic script.

  A compiled script is a binary containing drawing commands. The transform
  is embedded in the script's metadata/commands.

  For now, we use a simple approach: inspect the script structure for
  translate transforms. This may need refinement based on Scenic's internal
  script format.
  """
  defp extract_translate_from_script(compiled_script, graph_key) do
    # Compiled scripts are complex binary structures. We need to access
    # the transform that was applied when the graph was compiled.
    #
    # The script contains a :tx (transform matrix) in its metadata.
    # For translate transforms, this is typically a simple {dx, dy} offset.

    try do
      # Scenic scripts have a specific structure - they're Erlang terms
      # Try to pattern match common structures
      case compiled_script do
        # Some scripts might have transform info accessible
        %{tx: tx_matrix} ->
          extract_translate_from_matrix(tx_matrix)

        # Compiled script might be a tuple with transform data
        {_commands, _opts, tx_matrix} ->
          extract_translate_from_matrix(tx_matrix)

        # Binary format - harder to parse
        binary when is_binary(binary) ->
          # For binary scripts, we'd need to parse Scenic's internal format
          # This is complex, so for now return {0, 0} and log
          IO.puts("DEBUG: Binary script for #{inspect(graph_key)} - cannot easily extract transform")
          IO.puts("       Script size: #{byte_size(binary)} bytes")
          {0, 0}

        other ->
          IO.inspect(other, label: "DEBUG: Unexpected script structure for #{inspect(graph_key)}", limit: 5)
          {0, 0}
      end
    rescue
      error ->
        IO.puts("DEBUG: Error extracting transform for #{inspect(graph_key)}: #{inspect(error)}")
        {0, 0}
    end
  end

  defp extract_translate_from_matrix({dx, dy}), do: {dx, dy}
  defp extract_translate_from_matrix([1, 0, 0, 1, dx, dy]), do: {dx, dy}
  defp extract_translate_from_matrix(_), do: {0, 0}

  defp maybe_filter_by_id(elements, nil), do: elements

  defp maybe_filter_by_id(elements, filter) when is_binary(filter) do
    # Try to match the filter against the element key
    # Support both ":atom_name" and "atom_name" formats
    filter_clean = String.trim_leading(filter, ":")
    filter_atom = String.to_atom(filter_clean)

    # Use exact matching - the key must equal the filter atom
    # or the stringified key must equal the filter string
    # Handle tuple IDs like {:hypercard, uuid} by converting to string
    Enum.filter(elements, fn {key, _data} ->
      key == filter_atom or key_to_string(key) == filter_clean
    end)
  end

  defp key_to_string(key) when is_atom(key), do: Atom.to_string(key)
  defp key_to_string(key) when is_tuple(key), do: inspect(key)
  defp key_to_string(key), do: to_string(key)

  defp maybe_filter_by_id(elements, _), do: elements

  # Helper to get values from maps that may have atom or string keys
  defp get_in_sanitized(map, [key | rest]) when is_map(map) do
    value = Map.get(map, key) || Map.get(map, to_string(key))
    if rest == [] do
      value
    else
      get_in_sanitized(value, rest)
    end
  end

  defp get_in_sanitized(_, _), do: nil

  # Recursively sanitize data structures to be JSON-encodable
  # Converts tuples, atoms, and other non-JSON types to strings/basic types
  defp sanitize_for_json(data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {sanitize_for_json(k), sanitize_for_json(v)} end)
    |> Enum.into(%{})
  end

  defp sanitize_for_json(data) when is_list(data) do
    Enum.map(data, &sanitize_for_json/1)
  end

  defp sanitize_for_json(data) when is_tuple(data) do
    # Convert tuples to string representation
    inspect(data)
  end

  defp sanitize_for_json(data) when is_atom(data) and data != nil and data != true and data != false do
    # Convert atoms (except nil, true, false) to strings
    Atom.to_string(data)
  end

  defp sanitize_for_json(data) when is_binary(data) or is_number(data) or is_boolean(data) or is_nil(data) do
    # These types are already JSON-safe
    data
  end

  defp sanitize_for_json(data) do
    # Fallback for any other types (PIDs, refs, etc.)
    inspect(data)
  end

  # This one here is the real milk in the tea! Here we map what actions we receive to tool calls
  def handle_action(%{"action" => "inspect_viewport"} = _actn) do
    ScenicMcp.Tools.handle_get_scenic_graph()
  end

  def handle_action(%{"action" => "send_keys"} = actn) do
    ScenicMcp.Tools.handle_send_keys(actn)
  end

  def handle_action(%{"action" => "send_mouse_move"} = actn) do
    ScenicMcp.Tools.handle_mouse_move(actn)
  end

  def handle_action(%{"action" => "send_mouse_click"} = actn) do
    ScenicMcp.Tools.handle_mouse_click(actn)
  end

  def handle_action(%{"action" => "take_screenshot"} = actn) do
    ScenicMcp.Tools.take_screenshot(actn)
  end

  def handle_action(%{"action" => "find_clickable"} = actn) do
    ScenicMcp.Tools.find_clickable_elements(actn)
  end

  def handle_action(%{"action" => "click_element"} = actn) do
    ScenicMcp.Tools.click_element(actn)
  end

  def handle_action(%{"action" => "hover_element"} = actn) do
    ScenicMcp.Tools.hover_element(actn)
  end

  def handle_action(%{"action" => _action}) do
    {:error, "Unknown command"}
  end

  def handle_action(_) do
    {:error, "Invalid action format - must include 'action' key"}
  end
end
