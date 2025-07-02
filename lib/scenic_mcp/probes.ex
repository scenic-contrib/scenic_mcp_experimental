defmodule ScenicMcp.Probes do
  @moduledoc """
  Helper functions that let us interact with Scenic.
  """

  def viewport_pid do
    case Process.whereis(:main_viewport) do
      p when is_pid(p) ->
        p
      _otherwise ->
        raise "Unable to find the :main_viewport process. The Scenic supervision tree may not be running, or the viewport may be registered under a different name."
    end
  end

  def viewport_state do
    :sys.get_state(viewport_pid(), 5000)
  end

  def driver_pid do
    case Process.whereis(:scenic_driver) do
      p when is_pid(p) ->
        p
      _otherwise ->
        raise "Unable to find the :scenic_driver process. The Scenic supervision tree may not be running, or the viewport may be registered under a different name."
    end
  end

  def driver_state do
    :sys.get_state(driver_pid(), 5000)
  end

  def script_table do
    :ets.tab2list(viewport_state().script_table)
  end

  def send_input(input) do
    Scenic.Driver.send_input(driver_state(), input)
  end
end
