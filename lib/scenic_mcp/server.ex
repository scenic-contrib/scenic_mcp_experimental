defmodule ScenicMcp.Server do
  use GenServer
  require Logger

  def start_link(opts) do
    port = Keyword.get(opts, :port, 9999)
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
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Handle different commands
  defp handle_command("hello") do
    %{
      message: "Hello from ScenicMCP!",
      node: Node.self(),
      time: DateTime.utc_now() |> DateTime.to_iso8601(),
      elixir_version: System.version(),
      otp_release: :erlang.system_info(:otp_release) |> List.to_string(),
      scenic_viewports: list_scenic_viewports()
    }
  end

  defp handle_command(json_string) do
    case Jason.decode(json_string) do
      {:ok, %{"action" => "status"}} ->
        handle_status()
      
      {:ok, %{"action" => "send_keys"} = command} ->
        handle_send_keys(command)
      
      {:ok, %{"action" => "send_mouse_move"} = command} ->
        handle_mouse_move(command)
      
      {:ok, %{"action" => "send_mouse_click"} = command} ->
        handle_mouse_click(command)
      
      {:ok, command} ->
        %{error: "Unknown command", command: command}
      
      {:error, _} ->
        # Fallback to hello response for non-JSON
        handle_command("hello")
    end
  end

  defp handle_status do
    %{
      status: "active",
      scenic_viewports: list_scenic_viewports(),
      available_commands: ["send_keys", "send_mouse_move", "send_mouse_click"],
      time: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp handle_send_keys(%{"text" => text} = command) when is_binary(text) do
    viewport = find_scenic_viewport()
    
    if viewport do
      modifiers = parse_modifiers(command["modifiers"] || [])
      
      # Send each character as a key event
      String.graphemes(text)
      |> Enum.each(fn char ->
        key_atom = normalize_key_name(char)
        key_event = {:key, {key_atom, 1, modifiers}}  # 1 = key_pressed
        send_input_to_viewport(viewport, key_event)
        
        # Small delay between keystrokes for better reliability
        Process.sleep(10)
      end)
      
      %{status: "ok", message: "Sent text: #{text}", viewport: inspect(viewport)}
    else
      %{error: "No Scenic viewport found", available_viewports: list_scenic_viewports()}
    end
  end

  defp handle_send_keys(%{"key" => key} = command) when is_binary(key) do
    viewport = find_scenic_viewport()
    
    if viewport do
      modifiers = parse_modifiers(command["modifiers"] || [])
      key_atom = normalize_key_name(key)
      
      key_event = {:key, {key_atom, 1, modifiers}}  # 1 = key_pressed
      send_input_to_viewport(viewport, key_event)
      
      %{status: "ok", message: "Sent key: #{key}", key_atom: key_atom, viewport: inspect(viewport)}
    else
      %{error: "No Scenic viewport found", available_viewports: list_scenic_viewports()}
    end
  end

  defp handle_send_keys(_command) do
    %{error: "Invalid send_keys command - must provide either 'text' or 'key'"}
  end

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

  # Normalize key names to match Scenic's expectations
  defp normalize_key_name(key) do
    case String.downcase(key) do
      "enter" -> :key_enter
      "return" -> :key_enter
      "escape" -> :key_escape
      "esc" -> :key_escape
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
      "page_up" -> :key_page_up
      "pageup" -> :key_page_up
      "page_down" -> :key_page_down
      "pagedown" -> :key_page_down
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
      # For any other key, try to convert to atom
      other -> String.to_atom("key_" <> other)
    end
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

  defp parse_modifiers(modifiers) when is_list(modifiers) do
    Enum.map(modifiers, fn mod ->
      case String.downcase(mod) do
        "ctrl" -> :ctrl
        "shift" -> :shift
        "alt" -> :alt
        "cmd" -> :cmd
        "meta" -> :meta
        other -> String.to_atom(other)
      end
    end)
  end

  defp parse_modifiers(_), do: []

  # Generic Scenic viewport discovery
  defp find_scenic_viewport do
    # Try multiple strategies to find a Scenic viewport
    find_by_registered_name() ||
    find_by_process_dictionary() ||
    find_by_scenic_supervisor()
  end

  # Strategy 1: Look for common viewport names
  defp find_by_registered_name do
    common_names = [
      :main_viewport,
      :viewport,
      :scenic_viewport
    ]
    
    Enum.find_value(common_names, fn name ->
      case Process.whereis(name) do
        nil -> nil
        pid -> pid
      end
    end)
  end

  # Strategy 2: Look through process dictionary for Scenic-related processes
  defp find_by_process_dictionary do
    Process.list()
    |> Enum.find(fn pid ->
      case Process.info(pid, :registered_name) do
        {:registered_name, name} when is_atom(name) ->
          name_str = Atom.to_string(name)
          String.contains?(name_str, "viewport") or String.contains?(name_str, "Viewport")
        _ ->
          false
      end
    end)
  end

  # Strategy 3: Look for processes under Scenic supervisor
  defp find_by_scenic_supervisor do
    try do
      # Look for any process that might be a Scenic viewport
      Process.list()
      |> Enum.find(fn pid ->
        case Process.info(pid, :dictionary) do
          {:dictionary, dict} ->
            Enum.any?(dict, fn {key, _value} ->
              key_str = inspect(key)
              String.contains?(key_str, "scenic") or String.contains?(key_str, "viewport")
            end)
          _ ->
            false
        end
      end)
    rescue
      _ -> nil
    end
  end

  # List all potential Scenic viewports for debugging
  defp list_scenic_viewports do
    registered_processes = Process.registered()
    |> Enum.filter(fn name ->
      name_str = Atom.to_string(name)
      String.contains?(name_str, "viewport") or 
      String.contains?(name_str, "Viewport") or
      String.contains?(name_str, "scenic") or
      String.contains?(name_str, "Scenic")
    end)

    %{
      registered_scenic_processes: registered_processes,
      total_processes: length(Process.list()),
      found_viewport: find_scenic_viewport() != nil
    }
  end

  # Generic input sending that works with any Scenic viewport
  defp send_input_to_viewport(viewport_pid, event) when is_pid(viewport_pid) do
    Logger.info("🎯 Injecting input event via ViewPort: #{inspect(event)}")
    
    # Use proper Scenic ViewPort input routing
    send_via_viewport(viewport_pid, event)
  end
  
  defp send_input_to_viewport(nil, event) do
    Logger.error("❌ No viewport found for event: #{inspect(event)}")
    {:error, :no_viewport}
  end
  
  # Send event via Scenic.ViewPort.Input.send/2 - the proper Scenic input channel
  defp send_via_viewport(viewport_pid, event) do
    try do
      # Create a ViewPort struct
      viewport = %Scenic.ViewPort{pid: viewport_pid}
      
      case Scenic.ViewPort.Input.send(viewport, event) do
        :ok ->
          Logger.info("✅ Sent event via ViewPort.Input.send: #{inspect(event)}")
          :ok
        {:error, reason} ->
          Logger.error("❌ ViewPort rejected input: #{inspect(reason)} for event: #{inspect(event)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("❌ Failed to send input via ViewPort: #{inspect(e)}")
        {:error, e}
    end
  end
end
