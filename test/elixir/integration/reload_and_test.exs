# Reload the ScenicMcp.Server module
IO.puts("Reloading ScenicMcp.Server...")

# First stop the current server if running
if Process.whereis(ScenicMcp.Server) do
  GenServer.stop(ScenicMcp.Server)
  Process.sleep(100)
end

# Reload the module
:code.purge(ScenicMcp.Server)
:code.load_file(ScenicMcp.Server)

# Restart the server
{:ok, _pid} = ScenicMcp.Server.start_link(port: 9999)

IO.puts("Server reloaded and restarted on port 9999")
IO.puts("You can now run the test scripts to see debug output")
