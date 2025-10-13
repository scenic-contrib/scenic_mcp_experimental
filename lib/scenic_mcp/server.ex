defmodule ScenicMcp.Server do
  @moduledoc """
  The server is apart of our Scenic app, it is the bridge which our Typescript ScenicMCP server talks to.
  This server recieves JSON from that typescript server and convert it to actions, send back responses
  also as JSON back over the same channel.

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
        Logger.error("❌ Port #{port} is already in use for #{app_name}!")
        Logger.error("💡 Configure a unique port in config.exs: config :scenic_mcp, port: UNIQUE_PORT")
        Logger.error("📋 Suggested ports: Flamelex=9999, Quillex=9997, Tests=9996/9998")
        {:stop, :eaddrinuse}

      {:error, reason} ->
        Logger.error("Failed to start TCP server on port #{port} for #{app_name}: #{inspect(reason)}")
        {:stop, "Failed to start TCP server"}
    end
  end

  def handle_continue(:accept, %{listen_socket: listen_socket} = state) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client} ->
        {:noreply, Map.put(state, :client, client), {:continue, :loop}}

      {:error, reason} ->
        Logger.error("Failed to accept connection: #{inspect(reason)}")
        {:noreply, state, {:continue, :accept}}
    end
  end

  def handle_continue(:loop, %{client: client} = state) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} ->
        # Parse the incoming data
        response = parse_message(String.trim(data))

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

  def parse_message("hello") do
    # Special case for "hello" command used by TypeScript for connection testing
    %{status: "ok", message: "Hello from Scenic MCP Server"}
  end

  def parse_message(json_string) do
    case Jason.decode(json_string) do

      {:ok, %{"action" => "status"}} ->
        # Handle status command
        %{status: "ok", message: "Scenic MCP Server is running"}

      {:ok, %{"action" => all_other_actions} = actn} when is_binary(all_other_actions) ->
        # Handle tool calls
        ScenicMcp.Tools.handle_action(actn)
        |> handle_tool_result()

      {:ok, command} ->
        Logger.error("#{__MODULE__} received unknown command: #{inspect(command)}")
        %{error: "Unknown command", command: command}

      {:error, _} ->
        Logger.error("#{__MODULE__} received invalid JSON: #{inspect(json_string)}")
        %{error: "Invalid JSON"}
    end
  end

  # Convert {:ok, result} | {:error, reason} tuples to maps for JSON encoding
  defp handle_tool_result({:ok, result}), do: result
  defp handle_tool_result({:error, reason}), do: %{error: reason}
end
