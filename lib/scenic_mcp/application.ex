defmodule ScenicMcp.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting ScenicMCP Application...")

    port = ScenicMcp.Config.port()
    app_name = Application.get_env(:scenic_mcp, :app_name, "Unknown")
    children = [{ScenicMcp.Server, port: port, app_name: app_name}]

    boot_result = Supervisor.start_link(children,
      name: ScenicMcp.Supervisor,
      strategy: :one_for_one
    )

    case boot_result do
      {:ok, pid} when is_pid(pid) ->
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
