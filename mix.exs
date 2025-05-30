defmodule ScenicMcp.MixProject do
  use Mix.Project

  def project do
    [
      app: :scenic_mcp,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "MCP (Model Context Protocol) server for Scenic applications",
      package: package()
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
      {:jason, "~> 1.4"}
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
