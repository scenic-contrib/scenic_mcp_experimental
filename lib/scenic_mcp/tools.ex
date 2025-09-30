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
  alias ScenicMcp.Config

  # ========================================================================
  # Scenic Process Lookup
  # ========================================================================

  @doc """
  Get the PID of the configured viewport process.

  Returns `{:ok, pid}` if found, or `{:error, reason}` if not found.
  """
  @spec viewport_pid() :: {:ok, pid()} | {:error, String.t()}
  def viewport_pid do
    viewport_name = Config.viewport_name()

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
    driver_name = Config.driver_name()

    case Process.whereis(driver_name) do
      pid when is_pid(pid) ->
        {:ok, pid}

      _otherwise ->
        # Fallback: try to find driver through viewport
        case viewport_pid() do
          {:error, reason} ->
            {:error,
             "Unable to find Scenic driver process ':#{driver_name}' and viewport lookup also failed: #{reason}"}

          {:ok, vp_pid} ->
            state = :sys.get_state(vp_pid, 5000)

            case Map.get(state, :driver_pids, []) do
              [driver | _] ->
                {:ok, driver}

              [] ->
                {:error,
                 "No drivers found in viewport state. Ensure your Scenic driver is properly configured and started."}
            end
        end
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
        codepoint = char |> String.to_charlist() |> List.first()
        Scenic.Driver.send_input(driver_struct, {:codepoint, {codepoint, []}})
      end)

      {:ok, %{status: "ok", message: "Text sent: #{text}"}}
    end
  end

  def handle_send_keys(%{"key" => key} = params) when is_binary(key) do
    with {:ok, driver_struct} <- driver_state() do
      modifiers = parse_modifiers(Map.get(params, "modifiers", []))
      key_atom = normalize_key(key)

      Scenic.Driver.send_input(driver_struct, {:key, {key_atom, :press, modifiers}})
      Process.sleep(10)
      Scenic.Driver.send_input(driver_struct, {:key, {key_atom, :release, modifiers}})

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
      # Click
      Scenic.Driver.send_input(driver_struct, {:cursor_button, {button, :press, 0, {x, y}}})
      Process.sleep(10)
      Scenic.Driver.send_input(driver_struct, {:cursor_button, {button, :release, 0, {x, y}}})

      {:ok, %{status: "ok", message: "Mouse clicked at (#{x}, #{y})"}}
    end
  end

  def handle_mouse_click(_params) do
    {:error, "Invalid parameters: must provide 'x' and 'y' coordinates"}
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
      elements = :ets.tab2list(semantic_table)

      summary =
        elements
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
        by_type:
          Enum.frequencies(
            Enum.map(elements, fn {_key, data} ->
              Map.get(data, :semantic, %{}) |> Map.get(:type, :unknown)
            end)
          ),
        clickable_count:
          Enum.count(elements, fn {_key, data} ->
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
