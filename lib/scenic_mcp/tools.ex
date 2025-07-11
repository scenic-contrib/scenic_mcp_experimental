defmodule ScenicMcp.Tools do
  import ScenicMcp.Probes
  require Logger

  def take_screenshot(params) do
    Logger.info("Handling screenshot request: #{inspect(params)}")

    # Get optional parameters
    format = Map.get(params, "format", "path")  # "path" or "base64"
    filename = Map.get(params, "filename")

    # Generate filename if not provided
    path = if filename do
      if String.ends_with?(filename, ".png") do
        filename
      else
        filename <> ".png"
      end
    else
      timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[:\s]/, "_")
      "/tmp/scenic_screenshot_#{timestamp}.png"
    end

    # Find viewport and get driver
    viewport = viewport_pid_safe()

    if viewport do
      try do
        # Get the viewport's state to find drivers
        state = :sys.get_state(viewport, 5000)
        Logger.info("Getting driver_pids from viewport state...")

        # Get driver pids from the viewport state
        driver_pids = Map.get(state, :driver_pids, [])

        Logger.info("Final driver_pids: #{inspect(driver_pids)}")

        if length(driver_pids) > 0 do
          driver_pid = hd(driver_pids)
          Logger.info("Using driver_pid: #{inspect(driver_pid)}")

          # Take the screenshot using the driver
          Scenic.Driver.Local.screenshot(driver_pid, path)
          Logger.info("Screenshot saved to: #{path}")

          # Return response based on format
          case format do
            "base64" ->
              # Read file and encode to base64
              case File.read(path) do
                {:ok, data} ->
                  base64_data = Base.encode64(data)
                  %{
                    status: "ok",
                    format: "base64",
                    data: base64_data,
                    path: path,
                    size: byte_size(data)
                  }
                {:error, reason} ->
                  %{error: "Failed to read screenshot file", reason: inspect(reason)}
              end

            _ ->
              # Just return the path
              %{
                status: "ok",
                format: "path",
                path: path
              }
          end
        else
          Logger.error("No driver PIDs found in viewport state")

          # Try waiting a bit for drivers to register, then retry once
          Logger.info("Waiting 2 seconds for drivers to register...")
          :timer.sleep(2000)

          updated_state = :sys.get_state(viewport, 5000)
          updated_driver_pids = Map.get(updated_state, :driver_pids, [])
          Logger.info("After waiting, found driver_pids: #{inspect(updated_driver_pids)}")

          if length(updated_driver_pids) > 0 do
            driver_pid = hd(updated_driver_pids)
            Logger.info("Using driver_pid after wait: #{inspect(driver_pid)}")

            # Take the screenshot using the driver
            Scenic.Driver.Local.screenshot(driver_pid, path)
            Logger.info("Screenshot saved to: #{path}")

            # Return response based on format
            case format do
              "base64" ->
                # Read file and encode to base64
                case File.read(path) do
                  {:ok, data} ->
                    base64_data = Base.encode64(data)
                    %{
                      status: "ok",
                      format: "base64",
                      data: base64_data,
                      path: path,
                      size: byte_size(data)
                    }
                  {:error, reason} ->
                    %{error: "Failed to read screenshot file", reason: inspect(reason)}
                end

              _ ->
                # Just return the path
                %{
                  status: "ok",
                  format: "path",
                  path: path
                }
            end
          else
            %{error: "No driver found in viewport after waiting", viewport_keys: Map.keys(updated_state)}
          end
        end
      rescue
        e ->
          error_msg = try do
            case e do
              %KeyError{key: key} ->
                "KeyError - missing key: #{inspect(key)}"
              _ ->
                "#{Exception.format(:error, e)}"
            end
          rescue
            _ -> "Unknown error occurred"
          end
          Logger.error("Screenshot failed: #{error_msg}")
          %{error: "Screenshot failed", details: error_msg}
      end
    else
      %{error: "No viewport found"}
    end
  end
end
