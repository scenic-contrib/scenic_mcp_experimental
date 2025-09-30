defmodule ScenicMcp.Config do
  @moduledoc """
  Configuration management for Scenic MCP.

  Provides centralized access to configuration values with sensible defaults.
  Configuration can be set in your app's config.exs:

      config :scenic_mcp,
        port: 9999,
        viewport_name: :main_viewport,
        driver_name: :scenic_driver

  ## Configuration Options

  - `:port` - TCP port for the MCP server (default: 9999)
  - `:viewport_name` - Registered name of the Scenic viewport process (default: :main_viewport)
  - `:driver_name` - Registered name of the Scenic driver process (default: :scenic_driver)
  - `:app_name` - Human-readable name of your application (default: "Unknown")
  """

  @doc """
  Get the TCP port for the MCP server.
  """
  @spec port() :: pos_integer()
  def port do
    Application.get_env(:scenic_mcp, :port, 9999)
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
