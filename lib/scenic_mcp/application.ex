defmodule ScenicMcp.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting ScenicMCP Application...")

    children = case should_start_server?() do
      true ->
        port = Application.get_env(:scenic_mcp, :port, 9999)
        [{ScenicMcp.Server, port: port}]
      false ->
        []
    end

    opts = [strategy: :one_for_one, name: ScenicMcp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp should_start_server? do
    case Mix.env() do
      :test -> Application.get_env(:scenic_mcp, :auto_start, false)
      _ -> true
    end
  end
end
