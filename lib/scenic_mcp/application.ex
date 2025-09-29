defmodule ScenicMcp.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting ScenicMCP Application...")

    # Get port from configuration, default to 9999
    port = Application.get_env(:scenic_mcp, :port, 9999)
    app_name = Application.get_env(:scenic_mcp, :app_name, "Unknown")
    env = Application.get_env(:scenic_mcp, :environment, :prod)
    
    Logger.info("ScenicMCP starting for #{app_name} (env: #{env}) on port #{port}")

    children = [{ScenicMcp.Server, port: port}]

    opts = [strategy: :one_for_one, name: ScenicMcp.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("✅ ScenicMCP successfully started on port #{port}")
        {:ok, pid}
      {:error, {:shutdown, {:failed_to_start_child, ScenicMcp.Server, {:shutdown, :eaddrinuse}}}} ->
        Logger.error("❌ Port #{port} is already in use! Please configure a different port for #{app_name}")
        Logger.error("💡 Add to your config: config :scenic_mcp, port: YOUR_UNIQUE_PORT")
        {:error, :port_in_use}
      {:error, reason} ->
        Logger.error("❌ Failed to start ScenicMCP: #{inspect(reason)}")
        {:error, reason}
    end
  end

end
