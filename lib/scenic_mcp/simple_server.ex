defmodule ScenicMcp.SimpleServer do
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
    if viewport == nil do
      viewport = find_scenic_viewport()
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
      
      {:ok, command} ->
        %{error: "Unknown command", command: command}
      
      {:error, _} ->
        %{error: "Invalid JSON"}
    end
  end

  defp handle_get_scenic_graph(args) do
    IO.inspect(args, label: "INSIDE GET SCENIC GRAPH")
    case vp_info = get_viewport_info() do
      %{has_script_table: true, script_table: vp_script_table} ->
        graph = :ets.tab2list(vp_script_table)
        %{status: "ok", description: inspect(graph), script_count: length(graph)}

      _otherwise ->
         %{error: "No viewport found"}
    end
  end

  defp get_visual_feedback(detail_level) do
    Logger.info("[DEBUG] get_visual_feedback called with detail_level: #{detail_level}")
    
    # Try the direct approach first
    viewport = Process.whereis(:main_viewport) || Process.whereis(:viewport)
    Logger.info("[DEBUG] Direct viewport lookup result: #{inspect(viewport)}")
    
    # If direct lookup fails, try the search approach
    if viewport == nil do
      viewport = find_scenic_viewport()
      Logger.info("[DEBUG] Search-based viewport lookup result: #{inspect(viewport)}")
    end
    
    if viewport do
      try do
        Logger.info("[DEBUG] Getting viewport state...")
        # Get the viewport's state
        state = :sys.get_state(viewport, 5000)
        Logger.info("[DEBUG] Viewport state keys: #{inspect(Map.keys(state))}")
        
        # Extract the script table
        script_table = case state do
          %{script_table: table} -> 
            Logger.info("[DEBUG] Found script_table in state: #{inspect(table)}")
            table
          _ -> 
            Logger.warning("[DEBUG] No script_table key in state")
            nil
        end
        
        if script_table do
          # Read scripts from the table
          Logger.info("[DEBUG] Reading scripts from ETS table...")
          scripts = :ets.tab2list(script_table)
          Logger.info("[DEBUG] Found #{length(scripts)} scripts")
          
          # Log first script for debugging
          if length(scripts) > 0 do
            {name, _, _} = hd(scripts)
            Logger.info("[DEBUG] First script name: #{inspect(name)}")
          end
          
          # Build visual description
          description = build_visual_description(scripts, detail_level)
          
          response = %{
            status: "ok",
            description: description,
            script_count: length(scripts),
            detail_level: detail_level
          }
          
          Logger.info("[DEBUG] Returning successful response")
          response
        else
          Logger.error("[DEBUG] No script table found in viewport state")
          %{
            error: "No script table found in viewport state",
            viewport_state_keys: Map.keys(state)
          }
        end
      rescue
        e ->
          Logger.error("[DEBUG] Exception in get_visual_feedback: #{inspect(e)}")
          Logger.error("[DEBUG] Stacktrace: #{inspect(__STACKTRACE__)}")
          %{
            error: "Failed to get scenic graph",
            details: inspect(e),
            stacktrace: inspect(__STACKTRACE__)
          }
      end
    else
      Logger.error("[DEBUG] No Scenic viewport found at all")
      %{error: "No Scenic viewport found"}
    end
  end

  defp build_visual_description(scripts, detail_level) do
    # Parse each script and extract visual elements
    elements = scripts
    |> Enum.map(fn {name, compiled_script, _owner} ->
      {name, decode_script(compiled_script)}
    end)
    |> Enum.reject(fn {_, decoded} -> decoded == nil end)
    
    # Build description
    parts = ["🖼️ Visual Feedback - What's on screen:\n"]
    
    parts = parts ++ Enum.map(elements, fn {name, description} ->
      "• #{humanize_name(name)}: #{description}"
    end)
    
    parts = parts ++ ["\n📊 Total: #{length(scripts)} visual elements"]
    
    Enum.join(parts, "\n")
  end

  defp decode_script(compiled) when is_binary(compiled) do
    try do
      case Scenic.Script.deserialize(compiled) do
        ops when is_list(ops) ->
          analyze_operations(ops)
        _ ->
          nil
      end
    rescue
      _ -> nil
    end
  end
  defp decode_script(_), do: nil

  defp analyze_operations(ops) do
    # Extract meaningful visual elements
    elements = ops
    |> Enum.reduce(%{texts: [], shapes: [], colors: []}, fn op, acc ->
      case op do
        {:draw_text, text} when is_binary(text) ->
          %{acc | texts: [text | acc.texts]}
        {:draw_rect, _} ->
          %{acc | shapes: ["rectangle" | acc.shapes]}
        {:draw_rrect, _} ->
          %{acc | shapes: ["rounded rect" | acc.shapes]}
        {:draw_circle, _} ->
          %{acc | shapes: ["circle" | acc.shapes]}
        {:fill_color, {:color_rgba, {r, g, b, _}}} ->
          color = describe_color(r, g, b)
          %{acc | colors: [color | acc.colors]}
        _ ->
          acc
      end
    end)
    
    # Build description
    parts = []
    
    if length(elements.texts) > 0 do
      texts = elements.texts |> Enum.reverse() |> Enum.uniq() |> Enum.take(3)
      parts ++ ["Text: '#{Enum.join(texts, "', '")}'" ]
    else
      if length(elements.shapes) > 0 do
        shape_counts = elements.shapes |> Enum.frequencies()
        shapes = Enum.map(shape_counts, fn {shape, count} ->
          if count > 1, do: "#{count} #{shape}s", else: shape
        end)
        parts ++ ["Shapes: #{Enum.join(shapes, ", ")}"]
      else
        parts ++ ["#{length(ops)} drawing operations"]
      end
    end
    |> Enum.join(" | ")
  end

  defp describe_color(r, g, b) do
    cond do
      r > 200 && g < 100 && b < 100 -> "red"
      r < 100 && g > 200 && b < 100 -> "green"
      r < 100 && g < 100 && b > 200 -> "blue"
      r == 0 && g == 0 && b == 0 -> "black"
      r == 255 && g == 255 && b == 255 -> "white"
      true -> "color"
    end
  end

  defp humanize_name(name) do
    cond do
      name == "_root_" -> "Root"
      String.contains?(to_string(name), "Layer") -> "Layer"
      String.contains?(to_string(name), "Buffer") -> "Text Buffer"
      true -> to_string(name)
    end
  end

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

  # Find viewport - made public for the API function
  def find_scenic_viewport do
    Logger.info("[DEBUG] Starting viewport search...")
    
    result = Process.list()
    |> Enum.find(fn pid ->
      case Process.info(pid, [:registered_name, :dictionary]) do
        [{:registered_name, name}, {:dictionary, dict}] when is_atom(name) ->
          name_str = Atom.to_string(name)
          is_viewport = String.contains?(name_str, "viewport") or
            Enum.any?(dict, fn {k, _} -> 
              String.contains?(to_string(k), "viewport")
            end)
          
          if is_viewport do
            Logger.info("[DEBUG] Found viewport candidate: #{name} (#{inspect(pid)})")
          end
          
          is_viewport
        _ -> false
      end
    end)
    
    Logger.info("[DEBUG] Viewport search result: #{inspect(result)}")
    result
  end
end
