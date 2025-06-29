# defmodule ScenicMcp.ProcessManager do
#   @moduledoc """
#   Manages Elixir application processes for Scenic MCP.
#   Allows starting, stopping, and monitoring Scenic applications.
#   """

#   use GenServer
#   require Logger

#   @doc """
#   Starts the process manager
#   """
#   def start_link(opts \\ []) do
#     GenServer.start_link(__MODULE__, opts, name: __MODULE__)
#   end

#   @doc """
#   Start an application with the given parameters
#   """
#   def start_app(app_path, args \\ []) do
#     GenServer.call(__MODULE__, {:start_app, app_path, args}, 30_000)
#   end

#   @doc """
#   Stop the currently running application
#   """
#   def stop_app do
#     GenServer.call(__MODULE__, :stop_app)
#   end

#   @doc """
#   Get the status of the managed application
#   """
#   def status do
#     GenServer.call(__MODULE__, :status)
#   end

#   @doc """
#   Get recent logs from the application
#   """
#   def get_logs(lines \\ 100) do
#     GenServer.call(__MODULE__, {:get_logs, lines})
#   end

#   ## Callbacks

#   def init(_opts) do
#     {:ok, %{
#       port: nil,
#       app_path: nil,
#       logs: [],
#       max_log_lines: 1000
#     }}
#   end

#   def handle_call({:start_app, app_path, args}, _from, state) do
#     # Stop any existing app first
#     state = stop_port(state)

#     # Prepare the command
#     cmd = "cd #{app_path} && elixir --erl \"-noinput\" -S mix run --no-halt"

#     # Start the port
#     port_opts = [
#       :binary,
#       :exit_status,
#       :stderr_to_stdout,
#       :use_stdio,
#       {:line, 1024},
#       {:env, [{"MIX_ENV", "dev"}]}
#     ]

#     try do
#       port = Port.open({:spawn, cmd}, port_opts)

#       new_state = %{state |
#         port: port,
#         app_path: app_path,
#         logs: []
#       }

#       Logger.info("Started Scenic app at #{app_path} with port #{inspect(port)}")

#       {:reply, {:ok, %{status: "started", path: app_path, port: inspect(port)}}, new_state}
#     rescue
#       e ->
#         Logger.error("Failed to start app: #{inspect(e)}")
#         {:reply, {:error, "Failed to start app: #{inspect(e)}"}, state}
#     end
#   end

#   def handle_call(:stop_app, _from, state) do
#     new_state = stop_port(state)
#     {:reply, {:ok, %{status: "stopped"}}, new_state}
#   end

#   def handle_call(:status, _from, state) do
#     status = case state.port do
#       nil ->
#         %{status: "stopped", app_path: nil}
#       port ->
#         info = Port.info(port)
#         if info do
#           %{
#             status: "running",
#             app_path: state.app_path,
#             port_info: %{
#               id: info[:id],
#               connected: info[:connected],
#               links: length(info[:links] || []),
#               memory: info[:memory]
#             }
#           }
#         else
#           %{status: "crashed", app_path: state.app_path}
#         end
#     end

#     {:reply, status, state}
#   end

#   def handle_call({:get_logs, lines}, _from, state) do
#     logs = Enum.take(state.logs, -lines)
#     {:reply, {:ok, logs}, state}
#   end

#   def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
#     # Store the log line
#     log_entry = %{
#       timestamp: DateTime.utc_now(),
#       message: line
#     }

#     # Also log it locally
#     Logger.debug("[App Output] #{line}")

#     # Keep only the last max_log_lines
#     logs = [log_entry | state.logs]
#     logs = if length(logs) > state.max_log_lines do
#       Enum.take(logs, state.max_log_lines)
#     else
#       logs
#     end

#     {:noreply, %{state | logs: logs}}
#   end

#   def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
#     Logger.info("Scenic app exited with status: #{status}")
#     {:noreply, %{state | port: nil}}
#   end

#   def handle_info(_msg, state) do
#     {:noreply, state}
#   end

#   ## Private functions

#   defp stop_port(%{port: nil} = state), do: state
#   defp stop_port(%{port: port} = state) do
#     try do
#       Port.close(port)
#     catch
#       _, _ -> :ok
#     end

#     %{state | port: nil, app_path: nil}
#   end
# end
