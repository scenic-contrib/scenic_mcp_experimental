defmodule ScenicMcp do
  @moduledoc """
  MCP (Model Context Protocol) server for Scenic applications.

  Provides AI control over Scenic apps via TCP bridge.

  ## Usage

  Add to your Scenic app's `application.ex`:

      children = [
        {ScenicMcp.Server, [port: 9999, app_name: "MyApp"]}
      ]

  The MCP TypeScript server connects via stdio, bridges to this TCP server.
  """
end
