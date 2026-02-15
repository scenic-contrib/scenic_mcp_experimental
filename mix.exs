defmodule ScenicMcp.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :scenic_mcp,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "MCP (Model Context Protocol) server for Scenic applications"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ScenicMcp.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:scenic, git: "https://github.com/JediLuke/scenic.git", branch: "main", override: true},
      {:scenic_driver_local, git: "https://github.com/JediLuke/scenic_driver_local.git", branch: "main", override: true},
    ]
  end
end
