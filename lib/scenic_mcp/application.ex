defmodule ScenicMcp.Application do
  @moduledoc false

  use Application
  require Logger

  # HERE update the docs Claude
  @port 9999

  @impl true
  def start(_type, _args) do
    Logger.info("Starting ScenicMCP Application...")

    children = [{ScenicMcp.Server, port: @port}]

    opts = [strategy: :one_for_one, name: ScenicMcp.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
