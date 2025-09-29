# defmodule ScenicMcp.PortManager do
#   @moduledoc """
#   Utility module for managing scenic_mcp port configuration across multiple apps.

#   This helps prevent port conflicts when running multiple Scenic applications
#   that use scenic_mcp simultaneously.
#   """

#   require Logger

#   # Standard port assignments to prevent conflicts
#   @port_assignments %{
#     flamelex: %{dev: 9999, test: 9998},
#     quillex: %{dev: 9997, test: 9996},
#     memelex: %{dev: 9995, test: 9994}
#   }

#   @doc """
#   Get the recommended port for an application and environment.

#   ## Examples

#       iex> ScenicMcp.PortManager.get_port(:flamelex, :dev)
#       9999

#       iex> ScenicMcp.PortManager.get_port(:quillex, :test)
#       9996
#   """
#   def get_port(app_name, env) when is_atom(app_name) and is_atom(env) do
#     case @port_assignments[app_name] do
#       nil ->
#         Logger.warning("No port assignment found for #{app_name}, using default 9999")
#         9999
#       ports ->
#         Map.get(ports, env, 9999)
#     end
#   end

#   @doc """
#   Get all port assignments as a map.
#   """
#   def all_assignments, do: @port_assignments

#   @doc """
#   Check if a port is available by attempting to bind to it.
#   """
#   def port_available?(port) when is_integer(port) do
#     case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
#       {:ok, socket} ->
#         :gen_tcp.close(socket)
#         true
#       {:error, :eaddrinuse} ->
#         false
#       {:error, _reason} ->
#         false
#     end
#   end

#   @doc """
#   Find the next available port starting from a given port.
#   """
#   def find_available_port(starting_port \\ 9999) do
#     Stream.iterate(starting_port, &(&1 + 1))
#     |> Enum.find(&port_available?/1)
#   end

#   @doc """
#   Validate configuration and suggest corrections if needed.
#   """
#   def validate_config(app_name) do
#     configured_port = Application.get_env(:scenic_mcp, :port)
#     env = Mix.env()
#     recommended_port = get_port(app_name, env)

#     cond do
#       is_nil(configured_port) ->
#         Logger.warning("No scenic_mcp port configured for #{app_name}")
#         Logger.info("💡 Add to config.exs: config :scenic_mcp, port: #{recommended_port}")
#         {:warning, :no_config}

#       configured_port == recommended_port ->
#         Logger.debug("✅ scenic_mcp port correctly configured for #{app_name}: #{configured_port}")
#         :ok

#       true ->
#         Logger.info("ℹ️  scenic_mcp port for #{app_name} is #{configured_port} (recommended: #{recommended_port})")
#         :ok
#     end
#   end

#   @doc """
#   Print port assignment reference for developers.
#   """
#   def print_port_reference do
#     IO.puts("\n🔌 ScenicMCP Port Reference:")
#     IO.puts("=============================")

#     Enum.each(@port_assignments, fn {app, ports} ->
#       IO.puts("#{String.capitalize(to_string(app))}:")
#       Enum.each(ports, fn {env, port} ->
#         IO.puts("  #{env}: #{port}")
#       end)
#     end)

#     IO.puts("\n💡 Add to your app's config.exs:")
#     IO.puts("config :scenic_mcp, port: YOUR_PORT, app_name: \"YourApp\"")
#     IO.puts("\n🚨 Each app must use a unique port to avoid conflicts!")
#   end
# end
