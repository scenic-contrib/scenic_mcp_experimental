# Simple test script to verify the TCP server works
# Run with: elixir test_tcp.exs

# Start the application
{:ok, _} = Application.ensure_all_started(:scenic_mcp)

IO.puts("ScenicMCP TCP server should be running on port 9999")
IO.puts("Testing connection...")

# Give it a moment to start
Process.sleep(1000)

# Test the connection
case :gen_tcp.connect(~c"localhost", 9999, [:binary, packet: :line, active: false]) do
  {:ok, socket} ->
    IO.puts("✓ Connected to TCP server")
    
    # Send hello
    :ok = :gen_tcp.send(socket, "hello\n")
    IO.puts("✓ Sent 'hello' message")
    
    # Receive response
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, data} ->
        IO.puts("✓ Received response:")
        
        # Parse and pretty print JSON
        case Jason.decode(data) do
          {:ok, json} ->
            IO.puts(Jason.encode!(json, pretty: true))
          {:error, _} ->
            IO.puts(data)
        end
        
      {:error, reason} ->
        IO.puts("✗ Failed to receive response: #{inspect(reason)}")
    end
    
    :gen_tcp.close(socket)
    
  {:error, reason} ->
    IO.puts("✗ Failed to connect: #{inspect(reason)}")
end

# Keep the app running for a moment
Process.sleep(1000)
