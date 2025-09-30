defmodule ScenicMcp.Tools do
  @moduledoc """
  Tool handlers and Scenic interaction helpers for MCP server.

  Provides both low-level Scenic interaction helpers and high-level semantic
  DOM queries for AI-driven automation and testing.

  ## Low-level Scenic API

      ScenicMcp.Tools.viewport_pid()
      ScenicMcp.Tools.script_table()
      ScenicMcp.Tools.send_text("Hello")

  ## Semantic DOM API

      {:ok, dom} = ScenicMcp.Tools.get_semantic_dom()
      {:ok, buffers} = ScenicMcp.Tools.query(:text_buffer)
      ScenicMcp.Tools.inspect_dom()
  """

  require Logger

  alias Scenic.ViewPort


  # ========================================================================
  # Low-level Scenic interaction functions (existing API)
  # ========================================================================

  def viewport_pid do
    case Process.whereis(:main_viewport) do
      p when is_pid(p) ->
        p
      _otherwise ->
        raise "Unable to find the :main_viewport process. The Scenic supervision tree may not be running, or the viewport may be registered under a different name."
    end
  end

  def viewport_pid_safe do
    Process.whereis(:main_viewport)
  end

  def viewport_state do
    :sys.get_state(viewport_pid(), 5000)
  end

  def driver_pid do
    case Process.whereis(:scenic_driver) do
      p when is_pid(p) ->
        p
      _otherwise ->
        # Fallback: try to get it from the viewport if app hasn't updated to use :scenic_driver name yet
        case Process.whereis(:main_viewport) do
          nil ->
            raise "Unable to find the :scenic_driver process. Make sure your driver is registered with name: :scenic_driver"
          vp_pid ->
            # Get the driver from the viewport state
            state = :sys.get_state(vp_pid, 5000)
            case Map.get(state, :driver_pids, []) do
              [driver | _] ->
                IO.puts("Warning: Found driver via viewport. Please update your driver config to use name: :scenic_driver")
                driver
              [] ->
                raise "No drivers found in viewport"
            end
        end
    end
  end

  def driver_pid_safe do
    case Process.whereis(:scenic_driver) do
      nil ->
        # Fallback for apps that haven't updated yet
        case Process.whereis(:main_viewport) do
          nil -> nil
          vp_pid ->
            state = :sys.get_state(vp_pid, 5000)
            case Map.get(state, :driver_pids, []) do
              [driver | _] -> driver
              [] -> nil
            end
        end
      pid -> pid
    end
  end

  def driver_state do
    driver = driver_pid()
    :sys.get_state(driver, 5000)
  end

  def script_table do
    :ets.tab2list(viewport_state().script_table)
  end

  def send_input(input) do
    driver_struct = driver_state()
    Scenic.Driver.send_input(driver_struct, input)
  end

  @doc """
  Send text input to the application. Each character is sent as a codepoint event.
  """
  def send_text(text) when is_binary(text) do
    driver_struct = driver_state()

    text
    |> String.graphemes()
    |> Enum.each(fn char ->
      case char_to_key_event(char) do
        {:ok, key_event} ->
          Scenic.Driver.send_input(driver_struct, key_event)
        :error ->
          # For unsupported characters, still try codepoint
          codepoint = char |> String.to_charlist() |> List.first()
          Scenic.Driver.send_input(driver_struct, {:codepoint, {codepoint, []}})
      end
    end)

    :ok
  end

  # Convert a character to a key event that Quillex can understand.
  # Returns {:ok, key_event} for supported characters, :error otherwise.
  def char_to_key_event(char) do
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

      # Uppercase letters (same key with shift modifier)
      "A" -> {:ok, {:key, {:key_a, 1, [:shift]}}}
      "B" -> {:ok, {:key, {:key_b, 1, [:shift]}}}
      "C" -> {:ok, {:key, {:key_c, 1, [:shift]}}}
      "D" -> {:ok, {:key, {:key_d, 1, [:shift]}}}
      "E" -> {:ok, {:key, {:key_e, 1, [:shift]}}}
      "F" -> {:ok, {:key, {:key_f, 1, [:shift]}}}
      "G" -> {:ok, {:key, {:key_g, 1, [:shift]}}}
      "H" -> {:ok, {:key, {:key_h, 1, [:shift]}}}
      "I" -> {:ok, {:key, {:key_i, 1, [:shift]}}}
      "J" -> {:ok, {:key, {:key_j, 1, [:shift]}}}
      "K" -> {:ok, {:key, {:key_k, 1, [:shift]}}}
      "L" -> {:ok, {:key, {:key_l, 1, [:shift]}}}
      "M" -> {:ok, {:key, {:key_m, 1, [:shift]}}}
      "N" -> {:ok, {:key, {:key_n, 1, [:shift]}}}
      "O" -> {:ok, {:key, {:key_o, 1, [:shift]}}}
      "P" -> {:ok, {:key, {:key_p, 1, [:shift]}}}
      "Q" -> {:ok, {:key, {:key_q, 1, [:shift]}}}
      "R" -> {:ok, {:key, {:key_r, 1, [:shift]}}}
      "S" -> {:ok, {:key, {:key_s, 1, [:shift]}}}
      "T" -> {:ok, {:key, {:key_t, 1, [:shift]}}}
      "U" -> {:ok, {:key, {:key_u, 1, [:shift]}}}
      "V" -> {:ok, {:key, {:key_v, 1, [:shift]}}}
      "W" -> {:ok, {:key, {:key_w, 1, [:shift]}}}
      "X" -> {:ok, {:key, {:key_x, 1, [:shift]}}}
      "Y" -> {:ok, {:key, {:key_y, 1, [:shift]}}}
      "Z" -> {:ok, {:key, {:key_z, 1, [:shift]}}}

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

      # Common punctuation
      " " -> {:ok, {:key, {:key_space, 1, []}}}
      "!" -> {:ok, {:key, {:key_1, 1, [:shift]}}}
      "." -> {:ok, {:key, {:key_period, 1, []}}}
      "," -> {:ok, {:key, {:key_comma, 1, []}}}
      "?" -> {:ok, {:key, {:key_slash, 1, [:shift]}}}
      "-" -> {:ok, {:key, {:key_minus, 1, []}}}

      # Fall back to codepoint for unsupported characters
      _ -> :error
    end
  end

  @doc """
  Send key input to the application. Supports special keys and modifiers.
  """
  def send_keys(key, modifiers \\ []) when is_binary(key) and is_list(modifiers) do
    driver_struct = driver_state()
    key_atom = normalize_key(key)

    # Send key press
    Scenic.Driver.send_input(driver_struct, {:key, {key_atom, 1, modifiers}})

    # Send key release
    Scenic.Driver.send_input(driver_struct, {:key, {key_atom, 0, modifiers}})

    :ok
  end

  @doc """
  Send mouse move event to move the cursor to specified coordinates.
  """
  def send_mouse_move(x, y) when is_number(x) and is_number(y) do
    driver_struct = driver_state()
    Scenic.Driver.send_input(driver_struct, {:cursor_pos, {round(x), round(y)}})
    :ok
  end

  @doc """
  Send mouse click event at specified coordinates.

  Options:
  - button: :left (default), :right, or :middle
  - action: :press (default), :release, or :click (does press then release)
  """
  def send_mouse_click(x, y, opts \\ []) when is_number(x) and is_number(y) do
    driver_struct = driver_state()
    button = Keyword.get(opts, :button, :left)
    action = Keyword.get(opts, :action, :click)

    button_atom = case button do
      :left -> :btn_left
      :right -> :btn_right
      :middle -> :btn_middle
      b when is_atom(b) -> b
      _ -> :btn_left
    end

    # Ensure coordinates are integers
    int_x = round(x)
    int_y = round(y)

    case action do
      :press ->
        Scenic.Driver.send_input(driver_struct, {:cursor_button, {button_atom, 1, [], {int_x, int_y}}})
      :release ->
        Scenic.Driver.send_input(driver_struct, {:cursor_button, {button_atom, 0, [], {int_x, int_y}}})
      :click ->
        # Send both press and release for a complete click
        Scenic.Driver.send_input(driver_struct, {:cursor_button, {button_atom, 1, [], {int_x, int_y}}})
        Process.sleep(10)  # Small delay between press and release
        Scenic.Driver.send_input(driver_struct, {:cursor_button, {button_atom, 0, [], {int_x, int_y}}})
    end

    :ok
  end

  # ========================================================================
  # Semantic DOM API - High-level semantic queries
  # ========================================================================

  @doc """
  Get the complete semantic DOM structure.

  Returns a hierarchical, DOM-like structure representing all semantic
  elements in the viewport.

  ## Examples

      {:ok, dom} = ScenicMcp.Probes.get_semantic_dom()
      IO.inspect(dom.summary)
  """
  def get_semantic_dom(viewport_name \\ :main_viewport) do
    case get_viewport_info(viewport_name) do
      {:ok, viewport} ->
        {:ok, build_semantic_dom(viewport)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get only visible components in DOM structure.
  """
  def get_visible_dom(viewport_name \\ :main_viewport) do
    case get_semantic_dom(viewport_name) do
      {:error, reason} -> {:error, reason}
      {:ok, dom} ->
        visible_components = Enum.filter(dom.components, & &1.visible)

        {:ok, %{dom |
          components: visible_components,
          summary: recalculate_summary(visible_components)
        }}
    end
  end

  @doc """
  Query elements by semantic type.

  ## Examples

      {:ok, buffers} = ScenicMcp.Probes.query(:text_buffer)
      {:ok, buttons} = ScenicMcp.Probes.query(:button)
      {:ok, editable} = ScenicMcp.Probes.query(:editable)
  """
  def query(type, viewport_name \\ :main_viewport) do
    case get_semantic_dom(viewport_name) do
      {:error, reason} -> {:error, reason}
      {:ok, dom} ->
        elements = dom.components
        |> Enum.flat_map(& &1.elements)
        |> filter_by_type(type)

        {:ok, elements}
    end
  end

  @doc """
  Get content from all text buffers.

  Returns a map of buffer_id -> content for easy access.
  """
  def get_all_buffer_content(viewport_name \\ :main_viewport) do
    case query(:text_buffer, viewport_name) do
      {:ok, buffers} ->
        content_map = buffers
        |> Enum.filter(& &1.semantic.type == :text_buffer)
        |> Enum.into(%{}, fn buf ->
          {buf.semantic.buffer_id, buf.content}
        end)

        {:ok, content_map}

      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get a pretty-printed representation of the semantic DOM.
  """
  def inspect_dom(viewport_name \\ :main_viewport) do
    case get_semantic_dom(viewport_name) do
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        :error

      {:ok, dom} ->
        IO.puts("=== Semantic DOM Structure ===")
        IO.puts("Viewport: #{dom.viewport.name} (#{elem(dom.viewport.size, 0)}x#{elem(dom.viewport.size, 1)})")
        IO.puts("Components: #{dom.summary.total_components}")
        IO.puts("Total Elements: #{dom.summary.total_elements}")

        IO.puts("\nBy Type:")
        Enum.each(dom.summary.by_type, fn {type, count} ->
          IO.puts("  #{type}: #{count}")
        end)

        IO.puts("\nComponents:")
        Enum.each(dom.components, fn comp ->
          visibility = if comp.visible, do: "visible", else: "hidden"
          IO.puts("  [#{comp.id}] (#{visibility}) - #{length(comp.elements)} elements")

          Enum.each(comp.elements, fn elem ->
            case elem.type do
              :text_buffer ->
                content_preview = String.slice(elem.content, 0, 30)
                content_preview = if String.length(elem.content) > 30, do: content_preview <> "...", else: content_preview
                IO.puts("    └─ Buffer #{elem.semantic.buffer_id}: #{inspect(content_preview)}")

              :button ->
                IO.puts("    └─ Button: #{elem.semantic.label}")

              _ ->
                IO.puts("    └─ #{elem.type}: #{inspect(elem.id)}")
            end
          end)
        end)

        :ok
    end
  end

  # Private helper functions for semantic DOM

  def get_viewport_info(viewport_name) do
    case Process.whereis(viewport_name) do
      nil -> {:error, "ViewPort #{viewport_name} not found"}
      pid -> ViewPort.info(pid)
    end
  end

  def build_semantic_dom(viewport) do
    # Get all semantic data
    semantic_entries = :ets.tab2list(viewport.semantic_table)

    # Build components list
    components = semantic_entries
    |> Enum.filter(fn {_key, data} -> map_size(data.elements) > 0 end)
    |> Enum.map(fn {graph_key, data} -> build_component(graph_key, data, viewport) end)

    # Calculate summary
    summary = calculate_summary(components)

    %{
      viewport: %{
        name: viewport.name,
        size: viewport.size
      },
      timestamp: :os.system_time(:millisecond),
      components: components,
      summary: summary
    }
  end

  def build_component(graph_key, data, viewport) do
    # Try to determine if component is visible
    visible = determine_visibility(graph_key, viewport)

    # Build elements list
    elements = data.elements
    |> Map.values()
    |> Enum.map(&build_element/1)

    %{
      id: graph_key,
      type: :component,
      visible: visible,
      timestamp: data[:timestamp],
      elements: elements
    }
  end

  def build_element(elem) do
    %{
      id: elem.id,
      type: elem.semantic.type,
      semantic: elem.semantic,
      content: elem.content || "",
      properties: extract_properties(elem)
    }
  end

  def extract_properties(elem) do
    properties = %{}

    # Extract common properties from semantic data
    properties = if elem.semantic[:editable] do
      Map.put(properties, :editable, elem.semantic.editable)
    else
      properties
    end

    properties = if elem.semantic[:role] do
      Map.put(properties, :role, elem.semantic.role)
    else
      properties
    end

    properties = if elem.semantic[:label] do
      Map.put(properties, :label, elem.semantic.label)
    else
      properties
    end

    properties
  end

  def determine_visibility(graph_key, viewport) do
    # Simple heuristic: if it's in the script table, it's probably visible
    case :ets.lookup(viewport.script_table, graph_key) do
      [] -> false  # No script = not being rendered
      [{^graph_key, _script}] -> true
    end
  end

  def calculate_summary(components) do
    total_elements = components
    |> Enum.map(fn comp -> length(comp.elements) end)
    |> Enum.sum()

    by_type = components
    |> Enum.flat_map(fn comp -> comp.elements end)
    |> Enum.group_by(fn elem -> elem.type end)
    |> Enum.into(%{}, fn {type, elements} -> {type, length(elements)} end)

    %{
      total_components: length(components),
      total_elements: total_elements,
      by_type: by_type
    }
  end

  def recalculate_summary(components) do
    calculate_summary(components)
  end

  def filter_by_type(elements, :editable) do
    Enum.filter(elements, fn elem ->
      elem.properties[:editable] == true
    end)
  end

  def filter_by_type(elements, type) do
    Enum.filter(elements, fn elem ->
      elem.type == type
    end)
  end

  def take_screenshot(params) do
    # Handling screenshot request

    # Get optional parameters
    format = Map.get(params, "format", "path")  # "path" or "base64"
    filename = Map.get(params, "filename")

    # Generate filename if not provided
    path = if filename do
      if String.ends_with?(filename, ".png") do
        filename
      else
        filename <> ".png"
      end
    else
      timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[:\s]/, "_")
      "/tmp/scenic_screenshot_#{timestamp}.png"
    end

    # Find viewport and get driver
    viewport = viewport_pid_safe()

    if viewport do
      try do
        # Get the viewport's state to find drivers
        state = :sys.get_state(viewport, 5000)
        # Getting driver_pids from viewport state

        # Get driver pids from the viewport state
        driver_pids = Map.get(state, :driver_pids, [])

        # Got driver_pids

        if length(driver_pids) > 0 do
          driver_pid = hd(driver_pids)
          # Using driver_pid for screenshot

          # Take the screenshot using the driver
          Scenic.Driver.Local.screenshot(driver_pid, path)
          # Screenshot saved

          # Return response based on format
          case format do
            "base64" ->
              # Read file and encode to base64
              case File.read(path) do
                {:ok, data} ->
                  base64_data = Base.encode64(data)
                  %{
                    status: "ok",
                    format: "base64",
                    data: base64_data,
                    path: path,
                    size: byte_size(data)
                  }
                {:error, reason} ->
                  %{error: "Failed to read screenshot file", reason: inspect(reason)}
              end

            _ ->
              # Just return the path
              %{
                status: "ok",
                format: "path",
                path: path
              }
          end
        else
          Logger.error("No driver PIDs found in viewport state")

          # Try waiting a bit for drivers to register, then retry once
          Logger.info("Waiting 2 seconds for drivers to register...")
          :timer.sleep(2000)

          updated_state = :sys.get_state(viewport, 5000)
          updated_driver_pids = Map.get(updated_state, :driver_pids, [])
          Logger.info("After waiting, found driver_pids: #{inspect(updated_driver_pids)}")

          if length(updated_driver_pids) > 0 do
            driver_pid = hd(updated_driver_pids)
            # Using driver_pid after wait

            # Take the screenshot using the driver
            Scenic.Driver.Local.screenshot(driver_pid, path)
            # Screenshot saved

            # Return response based on format
            case format do
              "base64" ->
                # Read file and encode to base64
                case File.read(path) do
                  {:ok, data} ->
                    base64_data = Base.encode64(data)
                    %{
                      status: "ok",
                      format: "base64",
                      data: base64_data,
                      path: path,
                      size: byte_size(data)
                    }
                  {:error, reason} ->
                    %{error: "Failed to read screenshot file", reason: inspect(reason)}
                end

              _ ->
                # Just return the path
                %{
                  status: "ok",
                  format: "path",
                  path: path
                }
            end
          else
            %{error: "No driver found in viewport after waiting", viewport_keys: Map.keys(updated_state)}
          end
        end
      rescue
        e ->
          error_msg = try do
            case e do
              %KeyError{key: key} ->
                "KeyError - missing key: #{inspect(key)}"
              _ ->
                "#{Exception.format(:error, e)}"
            end
          rescue
            _ -> "Unknown error occurred"
          end
          Logger.error("Screenshot failed: #{error_msg}")
          %{error: "Screenshot failed", details: error_msg}
      end
    else
      %{error: "No viewport found"}
    end
  end


  def handle_get_scenic_graph(args \\ nil) do
    try do
      # Get viewport state to access script table
      vp_state = viewport_state()

      case vp_state do
        %{script_table: script_table} = state when script_table != nil ->
          # Read all scripts from the ETS table
          scripts = :ets.tab2list(script_table)

          # Build a visual description of the scene
          visual_description = build_scene_description(scripts)

          # Get semantic DOM information if available
          semantic_info = build_semantic_description(Map.get(state, :semantic_table))

          %{
            status: "ok",
            script_count: length(scripts),
            visual_description: visual_description,
            semantic_elements: semantic_info,
            raw_scripts: Enum.map(scripts, fn {id, _compiled} -> id end)
          }

        _ ->
          %{error: "No script table found in viewport state"}
      end
    rescue
      e ->
        %{error: "Failed to get scenic graph", details: inspect(e)}
    end
  end

  def build_scene_description(scripts) do
    scripts
    |> Enum.map(fn {id, _compiled_script} ->
      # Extract component name from ID
      component_name = case id do
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

  def build_semantic_description(nil), do: %{count: 0, elements: [], summary: "No semantic DOM available"}

  def build_semantic_description(semantic_table) do
    semantic_entries = :ets.tab2list(semantic_table)

    elements = Enum.flat_map(semantic_entries, fn {_key, info} ->
      if is_map(info) && Map.has_key?(info, :elements) do
        info.elements
        |> Map.values()
        |> Enum.map(fn elem ->
          semantic = elem[:semantic] || %{}

          %{
            type: semantic[:type],
            role: semantic[:role],
            label: semantic[:label],
            description: semantic[:description],
            clickable: semantic[:clickable] || false,
            state: semantic[:state],
            path: semantic[:path],
            menu_index: semantic[:menu_index],
            position: extract_position(elem),
            id: elem[:id]
          }
        end)
      else
        []
      end
    end)

    # Group by type for summary
    by_type = elements
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, items} -> {type, length(items)} end)
    |> Map.new()

    # Build human-readable summary
    summary = build_semantic_summary(elements, by_type)

    %{
      count: length(elements),
      by_type: by_type,
      clickable_count: Enum.count(elements, & &1.clickable),
      elements: elements,
      summary: summary
    }
  end

  def extract_position(elem) do
    cond do
      frame = elem[:frame] -> %{x: frame.pin.x, y: frame.pin.y, width: frame.size.width, height: frame.size.height}
      translate = elem[:translate] -> %{x: elem(translate, 0), y: elem(translate, 1)}
      true -> nil
    end
  end

  def build_semantic_summary(elements, by_type) do
    clickable = Enum.filter(elements, & &1.clickable)
    menu_items = Enum.filter(elements, & &1.type == :menu_item)

    parts = [
      "Found #{length(elements)} semantic elements",
      if(length(clickable) > 0, do: "#{length(clickable)} clickable"),
      if(length(menu_items) > 0, do: "#{length(menu_items)} menu items"),
      if(map_size(by_type) > 0, do: "Types: #{by_type |> Map.keys() |> Enum.join(", ")}")
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")

    parts
  end

  # Visual feedback functions commented out to avoid warnings
  # These will be re-enabled when visual feedback is implemented

  # def get_visual_feedback(detail_level) do
  #   # Implementation commented out
  # end

  # def build_visual_description(scripts, detail_level) do
  #   # Implementation commented out
  # end

  # def decode_script(compiled) when is_binary(compiled) do
  #   # Implementation commented out
  # end

  # def analyze_operations(ops) do
  #   # Implementation commented out
  # end

  # def describe_color(r, g, b) do
  #   # Implementation commented out
  # end

  # def humanize_name(name) do
  #   # Implementation commented out
  # end

  # Input handling
  def handle_send_keys(%{"text" => text}) when is_binary(text) do
    try do
      driver_state = driver_state()

      String.graphemes(text)
      |> Enum.each(fn char ->
        # Use codepoint for text input instead of key events
        # Convert string to codepoint integer
        codepoint = char |> String.to_charlist() |> List.first()
        event = {:codepoint, {codepoint, []}}
        Scenic.Driver.send_input(driver_state, event)
        Process.sleep(10)
      end)

      %{status: "ok", message: "Sent text: #{text}"}
    rescue
      _ -> %{error: "No driver found"}
    end
  end

  def handle_send_keys(%{"key" => key} = params) when is_binary(key) do
    try do
      driver_state = driver_state()
      key_atom = normalize_key(key)
      modifiers = parse_modifiers(Map.get(params, "modifiers", []))

      # Send key press
      Scenic.Driver.send_input(driver_state, {:key, {key_atom, 1, modifiers}})
      Process.sleep(10)
      # Send key release
      Scenic.Driver.send_input(driver_state, {:key, {key_atom, 0, modifiers}})

      %{status: "ok", message: "Sent key: #{key} with modifiers: #{inspect(modifiers)}"}
    rescue
      _ -> %{error: "No driver found"}
    end
  end

  def handle_mouse_move(%{"x" => x, "y" => y}) do
    try do
      driver_state = driver_state()
      Scenic.Driver.send_input(driver_state, {:cursor_pos, {x, y}})
      %{status: "ok", message: "Mouse moved to (#{x}, #{y})"}
    rescue
      _ -> %{error: "No driver found"}
    end
  end

  def handle_mouse_click(%{"x" => x, "y" => y} = params) do
    try do
      driver_state = driver_state()
      button = parse_button(Map.get(params, "button", "left"))

      # Move to position first
      Scenic.Driver.send_input(driver_state, {:cursor_pos, {x, y}})
      Process.sleep(10)

      # Press and release
      Scenic.Driver.send_input(driver_state, {:cursor_button, {button, 1, [], {x, y}}})
      Process.sleep(10)
      Scenic.Driver.send_input(driver_state, {:cursor_button, {button, 0, [], {x, y}}})

      %{status: "ok", message: "Clicked #{button} at (#{x}, #{y})"}
    rescue
      _ -> %{error: "No driver found"}
    end
  end

  def normalize_key(key) do
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
      other -> String.to_atom("key_" <> other)
    end
  end

  def parse_modifiers(modifiers) when is_list(modifiers) do
    modifiers
    |> Enum.filter(&(&1 in ["shift", "ctrl", "alt", "cmd", "meta"]))
  end

  def parse_modifiers(_), do: []

  def parse_button(button) when is_binary(button) do
    case String.downcase(button) do
      "left" -> :btn_left
      "right" -> :btn_right
      "middle" -> :btn_middle
      _ -> :btn_left
    end
  end

  def parse_button(_), do: :btn_left

  # Screenshot functionality
  # def handle_take_screenshot(params) do
  #   Logger.info("Handling screenshot request: #{inspect(params)}")

  #   # Get optional parameters
  #   format = Map.get(params, "format", "path")  # "path" or "base64"
  #   filename = Map.get(params, "filename")

  #   # Generate filename if not provided
  #   path = if filename do
  #     if String.ends_with?(filename, ".png") do
  #       filename
  #     else
  #       filename <> ".png"
  #     end
  #   else
  #     timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[:\s]/, "_")
  #     "/tmp/scenic_screenshot_#{timestamp}.png"
  #   end

  #   # Find viewport and get driver
  #   viewport = viewport_pid_safe()

  #   if viewport do
  #     try do
  #       # Get the viewport's state to find drivers
  #       state = :sys.get_state(viewport, 5000)
  #       Logger.info("Getting driver_pids from viewport state...")

  #       # Get driver pids from the viewport state
  #       driver_pids = Map.get(state, :driver_pids, [])

  #       Logger.info("Final driver_pids: #{inspect(driver_pids)}")

  #       if length(driver_pids) > 0 do
  #         driver_pid = hd(driver_pids)
  #         Logger.info("Using driver_pid: #{inspect(driver_pid)}")

  #         # Take the screenshot using the driver
  #         Scenic.Driver.Local.screenshot(driver_pid, path)
  #         Logger.info("Screenshot saved to: #{path}")

  #         # Return response based on format
  #         case format do
  #           "base64" ->
  #             # Read file and encode to base64
  #             case File.read(path) do
  #               {:ok, data} ->
  #                 base64_data = Base.encode64(data)
  #                 %{
  #                   status: "ok",
  #                   format: "base64",
  #                   data: base64_data,
  #                   path: path,
  #                   size: byte_size(data)
  #                 }
  #               {:error, reason} ->
  #                 %{error: "Failed to read screenshot file", reason: inspect(reason)}
  #             end

  #           _ ->
  #             # Just return the path
  #             %{
  #               status: "ok",
  #               format: "path",
  #               path: path
  #             }
  #         end
  #       else
  #         Logger.error("No driver PIDs found in viewport state")

  #         # Try waiting a bit for drivers to register, then retry once
  #         Logger.info("Waiting 2 seconds for drivers to register...")
  #         :timer.sleep(2000)

  #         updated_state = :sys.get_state(viewport, 5000)
  #         updated_driver_pids = Map.get(updated_state, :driver_pids, [])
  #         Logger.info("After waiting, found driver_pids: #{inspect(updated_driver_pids)}")

  #         if length(updated_driver_pids) > 0 do
  #           driver_pid = hd(updated_driver_pids)
  #           Logger.info("Using driver_pid after wait: #{inspect(driver_pid)}")

  #           # Take the screenshot using the driver
  #           Scenic.Driver.Local.screenshot(driver_pid, path)
  #           Logger.info("Screenshot saved to: #{path}")

  #           # Return response based on format
  #           case format do
  #             "base64" ->
  #               # Read file and encode to base64
  #               case File.read(path) do
  #                 {:ok, data} ->
  #                   base64_data = Base.encode64(data)
  #                   %{
  #                     status: "ok",
  #                     format: "base64",
  #                     data: base64_data,
  #                     path: path,
  #                     size: byte_size(data)
  #                   }
  #                 {:error, reason} ->
  #                   %{error: "Failed to read screenshot file", reason: inspect(reason)}
  #               end

  #             _ ->
  #               # Just return the path
  #               %{
  #                 status: "ok",
  #                 format: "path",
  #                 path: path
  #               }
  #           end
  #         else
  #           %{error: "No driver found in viewport after waiting", viewport_keys: Map.keys(updated_state)}
  #         end
  #       end
  #     rescue
  #       e ->
  #         error_msg = try do
  #           case e do
  #             %KeyError{key: key} ->
  #               "KeyError - missing key: #{inspect(key)}"
  #             _ ->
  #               "#{Exception.format(:error, e)}"
  #           end
  #         rescue
  #           _ -> "Unknown error occurred"
  #         end
  #         Logger.error("Screenshot failed: #{error_msg}")
  #         %{error: "Screenshot failed", details: error_msg}
  #     end
  #   else
  #     %{error: "No viewport found"}
  #   end
  # end

  # Find viewport - made public for the API function
  def find_scenic_driver do
    Logger.info("[DEBUG] Starting driver search...")

    # Look for the scenic driver process
    result = Process.list()
    |> Enum.find(fn pid ->
      case Process.info(pid, [:registered_name]) do
        [{:registered_name, :scenic}] -> true
        _ -> false
      end
    end)

    Logger.info("[DEBUG] Driver search result: #{inspect(result)}")
    result
  end

end
