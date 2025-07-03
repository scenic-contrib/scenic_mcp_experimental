# Reload the ScenicMcp.Server module
IO.puts("Reloading ScenicMcp.Server...")

# Find and stop the current server
case Process.whereis(ScenicMcp.Server) do
  nil -> 
    IO.puts("Server not running")
  pid ->
    IO.puts("Stopping server at #{inspect(pid)}")
    GenServer.stop(pid)
    Process.sleep(100)
end

# Also check for old server
case Process.whereis(ScenicMcp.Server) do
  nil -> 
    :ok
  pid ->
    IO.puts("Stopping old server at #{inspect(pid)}")
    GenServer.stop(pid)
    Process.sleep(100)
end

# Recompile the module
Code.compile_file("lib/scenic_mcp/server.ex")
IO.puts("Module recompiled")

# Start the server again
case ScenicMcp.Server.start_link(port: 9999) do
  {:ok, pid} ->
    IO.puts("Server restarted at #{inspect(pid)}")
  {:error, reason} ->
    IO.puts("Failed to start server: #{inspect(reason)}")
end
