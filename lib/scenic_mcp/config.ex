defmodule ScenicMcp.Config do
  @moduledoc """
  Configuration management for Scenic MCP.

  Configuration MUST be set in your app's config.exs or runtime.exs:

      config :scenic_mcp,
        port: 9992,
        viewport_name: :main_viewport,
        driver_name: :scenic_driver

  ## Configuration Options

  - `:port` - TCP port for the MCP server (REQUIRED — no default, fails loudly if missing)
  - `:viewport_name` - Registered name of the Scenic viewport process (default: :main_viewport)
  - `:driver_name` - Registered name of the Scenic driver process (default: :scenic_driver)
  - `:app_name` - Human-readable name of your application (default: "Unknown")
  """

  @doc """
  Get the TCP port for the MCP server.
  """
  @spec port() :: pos_integer()
  def port do
    case Application.get_env(:scenic_mcp, :port) do
      nil ->
        raise """
        ScenicMcp port not configured!

        Set it in your project's config:

            config :scenic_mcp, port: 9992

        Or in config/runtime.exs via environment variable:

            if port = System.get_env("SCENIC_MCP_PORT") do
              config :scenic_mcp, port: String.to_integer(port)
            end
        """

      port ->
        port
    end
  end

  @doc """
  Get the registered name of the Scenic viewport process.
  """
  @spec viewport_name() :: atom()
  def viewport_name do
    Application.get_env(:scenic_mcp, :viewport_name, :main_viewport)
  end

  @doc """
  Get the registered name of the Scenic driver process.
  """
  @spec driver_name() :: atom()
  def driver_name do
    Application.get_env(:scenic_mcp, :driver_name, :scenic_driver)
  end

  @doc """
  Get the application name.
  """
  @spec app_name() :: String.t()
  def app_name do
    Application.get_env(:scenic_mcp, :app_name, "Unknown")
  end
end
