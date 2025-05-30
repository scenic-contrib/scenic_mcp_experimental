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
        Logger.info("Client connected")
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
        
        # Simple response with Elixir info
        response = %{
          message: "Hello from ScenicMCP!",
          node: Node.self(),
          time: DateTime.utc_now() |> DateTime.to_iso8601(),
          elixir_version: System.version(),
          otp_release: :erlang.system_info(:otp_release) |> List.to_string()
        }
        
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
end
