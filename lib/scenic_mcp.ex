defmodule ScenicMcp do
  @moduledoc """
  MCP (Model Context Protocol) server for Scenic applications.

  Add this to your Scenic app to enable AI-driven automation and testing.

  ## Usage

  Add to your dependencies:

      {:scenic_mcp, "~> 0.1.0"}

  The TCP server will automatically start on port 9999 when your application starts.

  ## Configuration

  You can configure the port in your config:

      config :scenic_mcp, port: 9999
  """

  @doc """
  Returns a child spec for adding ScenicMcp to a supervision tree.
  """
  # def child_spec(opts) do
  #   %{
  #     id: __MODULE__,
  #     start: {__MODULE__, :start_link, [opts]},
  #     type: :supervisor
  #   }
  # end

  # @doc """
  # Starts the ScenicMcp supervision tree.
  # """
  # def start_link(opts \\ []) do
  #   ScenicMcp.Application.start(:normal, opts)
  # end

  # @doc """
  # Returns :world for basic testing.
  # """
  # def hello do
  #   :world
  # end
end
