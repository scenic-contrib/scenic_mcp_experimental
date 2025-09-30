defmodule ScenicMcp.ServerTest do
  use ExUnit.Case, async: false
  require Logger

  @moduletag timeout: 10_000

  setup do
    # Start the server on a test port with a unique name
    port = 9998 + :rand.uniform(100)  # Random port to avoid conflicts
    server_name = :"test_server_#{:rand.uniform(10000)}"

    {:ok, server_pid} = GenServer.start_link(ScenicMcp.Server, [port: port], name: server_name)

    # Give the server time to start
    Process.sleep(200)

    # Cleanup function
    on_exit(fn ->
      if Process.alive?(server_pid) do
        GenServer.stop(server_pid)
      end
    end)

    %{server_pid: server_pid, port: port, server_name: server_name}
  end

  describe "TCP server" do
    test "server starts and listens on specified port", %{port: port} do
      # Test that we can connect to the server
      assert can_connect_to_port?(port)
    end

    test "server handles JSON commands", %{port: port} do
      command = %{"action" => "inspect_viewport"}
      response = send_tcp_command(port, command)

      # Should get a JSON response (even if it's an error about no viewport)
      assert is_map(response)
      assert Map.has_key?(response, "error") or Map.has_key?(response, "status")
    end

    test "server handles invalid JSON gracefully", %{port: port} do
      response = send_raw_tcp_command(port, "invalid json{")
      
      assert is_map(response)
      assert response["error"] == "Invalid JSON"
    end

    test "server handles unknown commands", %{port: port} do
      command = %{"action" => "unknown_command"}
      response = send_tcp_command(port, command)
      
      assert is_map(response)
      assert response["error"] == "Unknown command"
    end
  end

  describe "command handling" do
    test "inspect_viewport returns error when no viewport available", %{port: port} do
      command = %{"action" => "inspect_viewport"}
      response = send_tcp_command(port, command)

      assert is_map(response)
      assert String.contains?(response["error"], "Failed to get scenic graph")
    end

    test "send_keys returns error when no driver available", %{port: port} do
      command = %{"action" => "send_keys", "text" => "hello"}
      response = send_tcp_command(port, command)
      
      assert is_map(response)
      assert response["error"] == "No driver found"
    end

    test "send_mouse_move returns error when no driver available", %{port: port} do
      command = %{"action" => "send_mouse_move", "x" => 100, "y" => 200}
      response = send_tcp_command(port, command)
      
      assert is_map(response)
      assert response["error"] == "No driver found"
    end

    test "take_screenshot returns error when no viewport available", %{port: port} do
      command = %{"action" => "take_screenshot"}
      response = send_tcp_command(port, command)
      
      assert is_map(response)
      assert response["error"] == "No viewport found"
    end
  end

  describe "driver detection" do
    test "find_scenic_driver returns nil when no driver exists" do
      result = ScenicMcp.Tools.find_scenic_driver()
      assert result == nil
    end
  end

  # Helper functions
  defp can_connect_to_port?(port) do
    case :gen_tcp.connect(~c"localhost", port, [:binary, packet: :line, active: false]) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true
      {:error, _} ->
        false
    end
  end

  defp send_tcp_command(port, command) do
    json_command = Jason.encode!(command)
    send_raw_tcp_command(port, json_command)
  end

  defp send_raw_tcp_command(port, raw_command) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", port, [:binary, packet: :line, active: false])
    
    :ok = :gen_tcp.send(socket, raw_command <> "\n")
    
    {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
    :gen_tcp.close(socket)
    
    case Jason.decode(String.trim(response)) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{"error" => "Failed to decode response", "raw" => String.trim(response)}
    end
  end
end