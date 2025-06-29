defmodule ScenicMcp.Server do
  use GenServer
  require Logger

  def start_link(opts) do
    port = Keyword.get(opts, :port, 9999)
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  # Public API function to get viewport info for debugging
  def get_viewport_info do
    # Try the direct approach first
    viewport = Process.whereis(:main_viewport) || Process.whereis(:viewport)
    
    # If direct lookup fails, try the search approach
    viewport = if viewport == nil do
      find_scenic_viewport()
    else
      viewport
    end
    
    if viewport do
      try do
        state = :sys.get_state(viewport, 5000)
        %{
          viewport_pid: viewport,
          viewport_alive: Process.alive?(viewport),
          state_keys: Map.keys(state),
          has_script_table: Map.has_key?(state, :script_table),
          script_table: Map.get(state, :script_table)
        }
      rescue
        e ->
          %{
            viewport_pid: viewport,
            error: "Failed to get viewport state",
            details: inspect(e)
          }
      end
    else
      %{error: "No viewport found"}
    end
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
        handle_take_screenshot(command)
      
      # Process management now handled by TypeScript MCP server
      
      {:ok, command} ->
        %{error: "Unknown command", command: command}
      
      {:error, _} ->
        %{error: "Invalid JSON"}
    end
  end

  defp handle_get_scenic_graph(args) do
    IO.inspect(args, label: "INSIDE GET SCENIC GRAPH")
    case get_viewport_info() do
      %{has_script_table: true, script_table: vp_script_table} ->
        graph = :ets.tab2list(vp_script_table)
        %{status: "ok", description: inspect(graph), script_count: length(graph)}

      _otherwise ->
         %{error: "No viewport found"}
    end
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
    viewport = find_scenic_viewport()
    
    if viewport do
      String.graphemes(text)
      |> Enum.each(fn char ->
        key = String.to_atom("key_" <> char)
        event = {:key, {key, 1, []}}
        send(viewport, {:input, event})
        Process.sleep(10)
      end)
      
      %{status: "ok", message: "Sent text: #{text}"}
    else
      %{error: "No viewport found"}
    end
  end

  defp handle_send_keys(%{"key" => key}) when is_binary(key) do
    viewport = find_scenic_viewport()
    
    if viewport do
      key_atom = normalize_key(key)
      event = {:key, {key_atom, 1, []}}
      send(viewport, {:input, event})
      
      %{status: "ok", message: "Sent key: #{key}"}
    else
      %{error: "No viewport found"}
    end
  end

  defp handle_mouse_move(%{"x" => x, "y" => y}) do
    viewport = find_scenic_viewport()
    
    if viewport do
      event = {:cursor_pos, {x, y}}
      send(viewport, {:input, event})
      
      %{status: "ok", message: "Mouse moved to (#{x}, #{y})"}
    else
      %{error: "No viewport found"}
    end
  end

  defp handle_mouse_click(%{"x" => x, "y" => y}) do
    viewport = find_scenic_viewport()
    
    if viewport do
      send(viewport, {:input, {:cursor_pos, {x, y}}})
      Process.sleep(10)
      send(viewport, {:input, {:cursor_button, {:cursor_button_left, 1, []}}})
      
      %{status: "ok", message: "Clicked at (#{x}, #{y})"}
    else
      %{error: "No viewport found"}
    end
  end

  defp normalize_key(key) do
    case String.downcase(key) do
      "enter" -> :key_enter
      "escape" -> :key_escape
      "tab" -> :key_tab
      "backspace" -> :key_backspace
      "space" -> :key_space
      other -> String.to_atom("key_" <> other)
    end
  end

  # Screenshot functionality
  defp handle_take_screenshot(params) do
    Logger.info("Handling screenshot request: #{inspect(params)}")
    
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
    viewport = find_scenic_viewport()
    
    if viewport do
      try do
        # Get the viewport's state to find drivers
        state = :sys.get_state(viewport, 5000)
        Logger.info("Getting driver_pids from viewport state...")
        
        # Get driver pids from the viewport state
        driver_pids = Map.get(state, :driver_pids, [])
        
        Logger.info("Final driver_pids: #{inspect(driver_pids)}")
        
        if length(driver_pids) > 0 do
          driver_pid = hd(driver_pids)
          Logger.info("Using driver_pid: #{inspect(driver_pid)}")
          
          # Take the screenshot using the driver
          Scenic.Driver.Local.screenshot(driver_pid, path)
          Logger.info("Screenshot saved to: #{path}")
          
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
            Logger.info("Using driver_pid after wait: #{inspect(driver_pid)}")
            
            # Take the screenshot using the driver
            Scenic.Driver.Local.screenshot(driver_pid, path)
            Logger.info("Screenshot saved to: #{path}")
            
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

  # Process management now handled by TypeScript MCP server directly

  # Find viewport - made public for the API function
  def find_scenic_viewport do
    Logger.info("[DEBUG] Starting viewport search...")
    
    # First try to find by registered name
    viewport_candidates = Process.list()
    |> Enum.filter(fn pid ->
      case Process.info(pid, [:registered_name, :dictionary, :current_function]) do
        [{:registered_name, name}, {:dictionary, dict}, {:current_function, {mod, _fun, _arity}}] when is_atom(name) ->
          name_str = Atom.to_string(name)
          module_str = Atom.to_string(mod)
          
          is_viewport = 
            String.contains?(name_str, "viewport") or
            String.contains?(module_str, "ViewPort") or
            Enum.any?(dict, fn {k, _} -> 
              String.contains?(to_string(k), "viewport")
            end)
          
          if is_viewport do
            Logger.info("[DEBUG] Found viewport candidate: #{name} (#{inspect(pid)}) - module: #{module_str}")
          end
          
          is_viewport
        
        [{:registered_name, name}, _dict] when is_atom(name) ->
          name_str = Atom.to_string(name)
          is_viewport = String.contains?(name_str, "viewport")
          
          if is_viewport do
            Logger.info("[DEBUG] Found viewport candidate: #{name} (#{inspect(pid)})")
          end
          
          is_viewport
        _ -> 
          false
      end
    end)
    
    Logger.info("[DEBUG] Found #{length(viewport_candidates)} viewport candidates")
    
    # Try to find the main viewport specifically
    main_viewport = Enum.find(viewport_candidates, fn pid ->
      case Process.info(pid, [:registered_name]) do
        [{:registered_name, :main_viewport}] -> true
        _ -> false
      end
    end)
    
    result = main_viewport || List.first(viewport_candidates)
    
    Logger.info("[DEBUG] Viewport search result: #{inspect(result)}")
    result
  end
end
