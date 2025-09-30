defmodule ScenicMcp.Tools do
  @moduledoc """
  Tool handlers for MCP server.

  Provides handlers for:
  - Keyboard input
  - Mouse input
  - Screenshot capture
  - Viewport inspection
  """

  require Logger

  # ========================================================================
  # Scenic Process Lookup
  # ========================================================================

  def viewport_pid do
    case Process.whereis(:main_viewport) do
      nil -> raise "Unable to find :main_viewport process"
      pid -> pid
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
        case Process.whereis(:main_viewport) do
          nil ->
            raise "Unable to find the :scenic_driver process"
          vp_pid ->
            state = :sys.get_state(vp_pid, 5000)
            case Map.get(state, :driver_pids, []) do
              [driver | _] -> driver
              [] -> raise "No drivers found in viewport"
            end
        end
    end
  end

  def driver_pid_safe do
    case Process.whereis(:scenic_driver) do
      nil ->
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

  def find_scenic_driver do
    Logger.info("[DEBUG] Starting driver search...")
    driver = driver_pid_safe()
    Logger.info("[DEBUG] Driver search result: #{inspect(driver)}")
    driver
  end

  # ========================================================================
  # Input Handling
  # ========================================================================

  def send_input(input) do
    driver_struct = driver_state()
    Scenic.Driver.send_input(driver_struct, input)
  end

  def char_to_key_event(char) do
    codepoint = char |> String.to_charlist() |> List.first()
    {:codepoint, {codepoint, []}}
  end

  # ========================================================================
  # Tool Handlers (called from server.ex)
  # ========================================================================

  def handle_send_keys(%{"text" => text}) when is_binary(text) do
    driver_struct = driver_state()

    text
    |> String.graphemes()
    |> Enum.each(fn char ->
      codepoint = char |> String.to_charlist() |> List.first()
      Scenic.Driver.send_input(driver_struct, {:codepoint, {codepoint, []}})
    end)

    %{status: "ok", message: "Text sent: #{text}"}
  rescue
    e -> %{error: "No driver found", details: inspect(e)}
  end

  def handle_send_keys(%{"key" => key} = params) when is_binary(key) do
    driver_struct = driver_state()
    modifiers = parse_modifiers(Map.get(params, "modifiers", []))
    key_atom = normalize_key(key)

    Scenic.Driver.send_input(driver_struct, {:key, {key_atom, :press, modifiers}})
    Process.sleep(10)
    Scenic.Driver.send_input(driver_struct, {:key, {key_atom, :release, modifiers}})

    %{status: "ok", message: "Key sent: #{key}"}
  rescue
    e -> %{error: "No driver found", details: inspect(e)}
  end

  def handle_mouse_move(%{"x" => x, "y" => y}) do
    driver_struct = driver_state()
    Scenic.Driver.send_input(driver_struct, {:cursor_pos, {x, y}})
    %{status: "ok", message: "Mouse moved to (#{x}, #{y})"}
  rescue
    e -> %{error: "No driver found", details: inspect(e)}
  end

  def handle_mouse_click(%{"x" => x, "y" => y} = params) do
    driver_struct = driver_state()
    button = parse_button(Map.get(params, "button", "left"))

    # Move to position
    Scenic.Driver.send_input(driver_struct, {:cursor_pos, {x, y}})
    # Click
    Scenic.Driver.send_input(driver_struct, {:cursor_button, {button, :press, 0, {x, y}}})
    Process.sleep(10)
    Scenic.Driver.send_input(driver_struct, {:cursor_button, {button, :release, 0, {x, y}}})

    %{status: "ok", message: "Mouse clicked at (#{x}, #{y})"}
  rescue
    e -> %{error: "No driver found", details: inspect(e)}
  end

  def handle_get_scenic_graph(_args \\ nil) do
    try do
      IO.puts("[DEBUG] Getting viewport state...")
      vp_state = viewport_state()
      IO.puts("[DEBUG] Got viewport state, keys: #{inspect(Map.keys(vp_state))}")

      case vp_state do
        %{script_table: script_table} = state when script_table != nil ->
          IO.puts("[DEBUG] Found script_table: #{inspect(script_table)}")
          IO.puts("[DEBUG] Reading ETS table...")
          scripts = :ets.tab2list(script_table)
          IO.puts("[DEBUG] Got #{length(scripts)} scripts")

          visual_description = build_scene_description(scripts)
          semantic_info = build_semantic_description(Map.get(state, :semantic_table))

          %{
            status: "ok",
            script_count: length(scripts),
            visual_description: visual_description,
            semantic_elements: semantic_info,
            raw_scripts: Enum.map(scripts, fn
              {id, _compiled, _pid} -> id
              {id, _compiled} -> id
            end)
          }

        _ ->
          IO.puts("[DEBUG] No script_table in state")
          %{error: "No script table found in viewport state", state_keys: inspect(Map.keys(vp_state))}
      end
    rescue
      e in [RuntimeError] ->
        IO.puts("[DEBUG] RuntimeError: #{inspect(e)}")
        %{error: "Failed to get scenic graph", details: Exception.message(e), type: "RuntimeError"}
      e ->
        IO.puts("[DEBUG] Other error: #{inspect(e)}")
        IO.puts("[DEBUG] Stacktrace: #{inspect(__STACKTRACE__)}")
        %{error: "Failed to get scenic graph", details: inspect(e), stacktrace: inspect(__STACKTRACE__)}
    end
  end

  def take_screenshot(params) do
    format = Map.get(params, "format", "path")
    filename = Map.get(params, "filename")

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

    case viewport_pid_safe() do
      nil ->
        %{error: "No viewport found"}

      vp_pid ->
        case :sys.get_state(vp_pid) do
          %{driver_pids: [driver_pid | _]} ->
            driver_state = :sys.get_state(driver_pid)

            case Scenic.Driver.Local.screenshot(driver_state, path) do
              :ok ->
                if format == "base64" do
                  case File.read(path) do
                    {:ok, binary} ->
                      encoded = Base.encode64(binary)
                      %{
                        status: "ok",
                        path: path,
                        format: "base64",
                        data: encoded,
                        size: byte_size(binary)
                      }
                    {:error, reason} ->
                      %{error: "Failed to read screenshot file", details: inspect(reason)}
                  end
                else
                  %{status: "ok", path: path, format: "path"}
                end

              {:error, reason} ->
                %{error: "Screenshot failed", details: inspect(reason)}
            end

          _ ->
            %{error: "No driver found in viewport"}
        end
    end
  end

  # ========================================================================
  # Helper Functions
  # ========================================================================

  defp build_scene_description(scripts) do
    scripts
    |> Enum.map(fn
      {id, _compiled_script, _pid} -> {id, nil}
      {id, _compiled_script} -> {id, nil}
      other -> {other, nil}
    end)
    |> Enum.map(fn {id, _} ->
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

  defp build_semantic_description(nil), do: %{count: 0, elements: [], summary: "No semantic DOM available"}

  defp build_semantic_description(semantic_table) do
    try do
      elements = :ets.tab2list(semantic_table)

      summary = elements
        |> Enum.map(fn {_key, data} ->
          data
          |> Map.get(:semantic, %{})
          |> Map.get(:type, :unknown)
          |> to_string()
        end)
        |> Enum.frequencies()
        |> Enum.map(fn {type, count} -> "#{count} #{type}" end)
        |> Enum.join(", ")

      %{
        count: length(elements),
        elements: Enum.map(elements, fn {key, data} -> Map.put(data, :key, key) end),
        summary: summary,
        by_type: Enum.frequencies(Enum.map(elements, fn {_key, data} ->
          Map.get(data, :semantic, %{}) |> Map.get(:type, :unknown)
        end)),
        clickable_count: Enum.count(elements, fn {_key, data} ->
          Map.get(data, :clickable, false)
        end)
      }
    rescue
      _ -> %{count: 0, elements: [], summary: "Error reading semantic table"}
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
      other -> String.to_atom("key_" <> other)
    end
  end

  defp parse_modifiers(modifiers) when is_list(modifiers) do
    modifiers
    |> Enum.filter(&(&1 in ["shift", "ctrl", "alt", "cmd", "meta"]))
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
end
