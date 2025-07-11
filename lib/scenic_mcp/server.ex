defmodule ScenicMcp.Server do
  use GenServer
  require Logger
  #TODO dont use this import, use module directly
  import ScenicMcp.Probes

  @tcp_port 9999

  def start_link(opts) do
    port = Keyword.get(opts, :port, @tcp_port)
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      {:ok, listen_socket} ->
        Logger.info("ScenicMCP TCP server listening on port #{port}")
        {:ok, %{listen_socket: listen_socket, port: port}, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("Failed to start TCP server on port #{port}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  def handle_continue(:accept, %{listen_socket: listen_socket} = state) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client} ->
        Logger.info("Client connected to ScenicMCP")
        {:noreply, Map.put(state, :client, client), {:continue, :loop}}

      {:error, reason} ->
        Logger.error("Failed to accept connection: #{inspect(reason)}")
        {:noreply, state, {:continue, :accept}}
    end
  end

  def handle_continue(:loop, %{client: client} = state) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} ->
        Logger.debug("Received: #{inspect(data)}")

        # Parse the incoming data
        response = handle_command(String.trim(data))

        json_response = Jason.encode!(response) <> "\n"
        :gen_tcp.send(client, json_response)

        {:noreply, state, {:continue, :loop}}

      {:error, :closed} ->
        Logger.info("Client disconnected")
        {:noreply, Map.delete(state, :client), {:continue, :accept}}

      {:error, reason} ->
        Logger.error("Error receiving data: #{inspect(reason)}")
        :gen_tcp.close(client)
        {:noreply, Map.delete(state, :client), {:continue, :accept}}
    end
  end

  def handle_info(msg, state) do
    Logger.warning("#{__MODULE__} - Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Handle different commands
  defp handle_command(json_string) do
    case Jason.decode(json_string) do
      {:ok, %{"action" => "get_scenic_graph"} = command} ->
        handle_get_scenic_graph(command)

      {:ok, %{"action" => "send_keys"} = command} ->
        handle_send_keys(command)

      {:ok, %{"action" => "send_mouse_move"} = command} ->
        handle_mouse_move(command)

      {:ok, %{"action" => "send_mouse_click"} = command} ->
        handle_mouse_click(command)

      {:ok, %{"action" => "take_screenshot"} = command} ->
        # handle_take_screenshot(command)
        ScenicMcp.Tools.take_screenshot(command)

      {:ok, command} ->
        Logger.error "#{__MODULE__} recv'd an unknown command: #{inspect command}"
        %{error: "Unknown command", command: command}

      {:error, _} ->
        Logger.error "#{__MODULE__} recv'd some invalid JSON"
        %{error: "Invalid JSON"}
    end
  end

  defp handle_get_scenic_graph(_args) do
    try do
      # Get viewport state to access script table
      vp_state = viewport_state()

      case vp_state do
        %{script_table: script_table} when script_table != nil ->
          # Read all scripts from the ETS table
          scripts = :ets.tab2list(script_table)

          # Build a visual description of the scene
          visual_description = build_scene_description(scripts)

          %{
            status: "ok",
            script_count: length(scripts),
            visual_description: visual_description,
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

  defp build_scene_description(scripts) do
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

  # Visual feedback functions commented out to avoid warnings
  # These will be re-enabled when visual feedback is implemented

  # defp get_visual_feedback(detail_level) do
  #   # Implementation commented out
  # end

  # defp build_visual_description(scripts, detail_level) do
  #   # Implementation commented out
  # end

  # defp decode_script(compiled) when is_binary(compiled) do
  #   # Implementation commented out
  # end

  # defp analyze_operations(ops) do
  #   # Implementation commented out
  # end

  # defp describe_color(r, g, b) do
  #   # Implementation commented out
  # end

  # defp humanize_name(name) do
  #   # Implementation commented out
  # end

  # Input handling
  defp handle_send_keys(%{"text" => text}) when is_binary(text) do
    try do
      driver_state = driver_state()

      String.graphemes(text)
      |> Enum.each(fn char ->
        # Use codepoint for text input instead of key events
        event = {:codepoint, {char, []}}
        Scenic.Driver.send_input(driver_state, event)
        Process.sleep(10)
      end)

      %{status: "ok", message: "Sent text: #{text}"}
    rescue
      _ -> %{error: "No driver found"}
    end
  end

  defp handle_send_keys(%{"key" => key} = params) when is_binary(key) do
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

  defp handle_mouse_move(%{"x" => x, "y" => y}) do
    try do
      driver_state = driver_state()
      Scenic.Driver.send_input(driver_state, {:cursor_pos, {x, y}})
      %{status: "ok", message: "Mouse moved to (#{x}, #{y})"}
    rescue
      _ -> %{error: "No driver found"}
    end
  end

  defp handle_mouse_click(%{"x" => x, "y" => y} = params) do
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
    |> Enum.map(&String.to_atom/1)
    |> Enum.filter(&(&1 in [:shift, :ctrl, :alt, :cmd, :meta]))
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

  # Screenshot functionality
  # defp handle_take_screenshot(params) do
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
