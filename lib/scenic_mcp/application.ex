defmodule ScenicMcp.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting ScenicMCP Application...")

    # Get port from configuration, default to 9999
    port = Application.get_env(:scenic_mcp, :port, 9999)
    Logger.info("ScenicMCP starting on port #{port}")

    children = [{ScenicMcp.Server, port: port}]

    opts = [strategy: :one_for_one, name: ScenicMcp.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
