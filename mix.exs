defmodule ScenicMcp.MixProject do
  use Mix.Project

  def project do
    [
      app: :scenic_mcp,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "MCP (Model Context Protocol) server for Scenic applications",
      package: package(),

      # Test configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
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
      {:scenic, git: "https://github.com/ScenicFramework/scenic.git", tag: "v0.11.1", override: true},
      # {:scenic_driver_local, path: "../scenic_driver_local"},
      {:scenic_driver_local, git: "https://github.com/JediLuke/scenic_driver_local", branch: "flamelex_vsn"},

      # Test dependencies
      {:excoveralls, "~> 0.17", only: :test},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/yourusername/scenic_mcp"}
    ]
  end
end
