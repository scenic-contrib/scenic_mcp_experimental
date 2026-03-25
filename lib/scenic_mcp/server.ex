defmodule ScenicMcp.Server do
  @moduledoc """
  TCP server that bridges TypeScript MCP wrappers to the Scenic app.

  Supports multiple concurrent connections — each client gets its own
  handler process so the acceptor loop is never blocked.

  MCP Server (TypeScript) → TCP Bridge (stdIO) → Elixir Server (this module) → Scenic ViewPort → Scenic App
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    app_name = Keyword.get(opts, :app_name, "Unknown")

    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      {:ok, listen_socket} ->
        Logger.info("ScenicMCP TCP server listening for #{app_name} on port #{port}")
        {:ok, %{listen_socket: listen_socket, port: port, app_name: app_name}, {:continue, :accept}}

      {:error, :eaddrinuse} ->
        Logger.error("Port #{port} is already in use for #{app_name}!")
        Logger.error("Configure a unique port in config.exs: config :scenic_mcp, port: UNIQUE_PORT")
        {:stop, :eaddrinuse}

      {:error, reason} ->
        Logger.error("Failed to start TCP server on port #{port} for #{app_name}: #{inspect(reason)}")
        {:stop, "Failed to start TCP server"}
    end
  end

  # Accept loop — spawns a handler per client, immediately loops back
  def handle_continue(:accept, %{listen_socket: listen_socket} = state) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client} ->
        pid = spawn_link(fn -> client_loop(client) end)
        :gen_tcp.controlling_process(client, pid)
        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("Failed to accept connection: #{inspect(reason)}")
        {:noreply, state, {:continue, :accept}}
    end
  end

  def handle_info(msg, state) do
    Logger.warning("#{__MODULE__} - Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Per-client handler loop — runs in its own process
  defp client_loop(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} ->
        response = parse_message(String.trim(data))
        json_response = Jason.encode!(response) <> "\n"
        :gen_tcp.send(client, json_response)
        client_loop(client)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        Logger.error("Client error: #{inspect(reason)}")
        :gen_tcp.close(client)
    end
  end

  def parse_message("hello") do
    %{status: "ok", message: "Hello from Scenic MCP Server"}
  end

  def parse_message(json_string) do
    case Jason.decode(json_string) do
      {:ok, %{"action" => "status"}} ->
        %{status: "ok", message: "Scenic MCP Server is running"}

      {:ok, %{"action" => _} = actn} ->
        ScenicMcp.Tools.handle_action(actn)
        |> handle_tool_result()

      # No catch-all for unknown actions — crash with MatchError.
      # But invalid JSON is external input — handle gracefully.
      {:error, _} ->
        %{error: "Invalid JSON"}
    end
  end

  defp handle_tool_result({:ok, result}), do: result
  defp handle_tool_result({:error, reason}), do: %{error: reason}
end
