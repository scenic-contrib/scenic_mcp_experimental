defmodule ScenicMcp.Probes do
  @moduledoc """
  Semantic DOM-like probes for Scenic applications.
  
  Provides both low-level Scenic interaction helpers and high-level semantic
  DOM queries for AI-driven automation and testing.
  
  ## Low-level Scenic API
  
      ScenicMcp.Probes.viewport_pid()
      ScenicMcp.Probes.script_table()
      ScenicMcp.Probes.send_text("Hello")
      
  ## Semantic DOM API
  
      {:ok, dom} = ScenicMcp.Probes.get_semantic_dom()
      {:ok, buffers} = ScenicMcp.Probes.query(:text_buffer)
      ScenicMcp.Probes.inspect_dom()
  """
  
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
  Take a screenshot and save it to the specified filename or generate one.
  Returns the path to the saved screenshot.
  """
  def take_screenshot(filename \\ nil) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    final_filename = filename || "screenshot_#{timestamp}.png"
    
    # Use the Tools module to take the screenshot
    case ScenicMcp.Tools.take_screenshot(%{"filename" => final_filename}) do
      %{status: "ok", path: path} -> path
      %{error: _reason} -> nil
      _other -> nil
    end
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

  # Helper function to normalize key names to atoms
  defp normalize_key(key) when is_binary(key) do
    case String.downcase(key) do
      "enter" -> :key_enter
      "escape" -> :key_escape
      "esc" -> :key_escape
      "backspace" -> :key_backspace
      "delete" -> :key_delete
      "tab" -> :key_tab
      "space" -> :key_space
      "up" -> :key_up
      "down" -> :key_down
      "left" -> :key_left
      "right" -> :key_right
      "home" -> :key_home
      "end" -> :key_end
      "page_up" -> :key_page_up
      "page_down" -> :key_page_down
      "a" -> :key_a
      "s" -> :key_s
      "ctrl" -> :key_left_ctrl
      "shift" -> :key_left_shift
      "alt" -> :key_left_alt
      other -> 
        # Try to convert single character keys
        if String.length(other) == 1 do
          char = other |> String.to_charlist() |> List.first()
          case char do
            c when c >= ?a and c <= ?z -> String.to_atom("key_#{other}")
            c when c >= ?A and c <= ?Z -> String.to_atom("key_#{String.downcase(other)}")
            _ -> :key_unknown
          end
        else
          :key_unknown
        end
    end
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
  
  defp get_viewport_info(viewport_name) do
    case Process.whereis(viewport_name) do
      nil -> {:error, "ViewPort #{viewport_name} not found"}
      pid -> ViewPort.info(pid)
    end
  end
  
  defp build_semantic_dom(viewport) do
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
  
  defp build_component(graph_key, data, viewport) do
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
  
  defp build_element(elem) do
    %{
      id: elem.id,
      type: elem.semantic.type,
      semantic: elem.semantic,
      content: elem.content || "",
      properties: extract_properties(elem)
    }
  end
  
  defp extract_properties(elem) do
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
  
  defp determine_visibility(graph_key, viewport) do
    # Simple heuristic: if it's in the script table, it's probably visible
    case :ets.lookup(viewport.script_table, graph_key) do
      [] -> false  # No script = not being rendered
      [{^graph_key, _script}] -> true
    end
  end
  
  defp calculate_summary(components) do
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
  
  defp recalculate_summary(components) do
    calculate_summary(components)
  end
  
  defp filter_by_type(elements, :editable) do
    Enum.filter(elements, fn elem ->
      elem.properties[:editable] == true
    end)
  end
  
  defp filter_by_type(elements, type) do
    Enum.filter(elements, fn elem ->
      elem.type == type
    end)
  end
end
