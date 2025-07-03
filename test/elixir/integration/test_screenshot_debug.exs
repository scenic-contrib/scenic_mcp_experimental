#!/usr/bin/env elixir

# Debug script to test screenshot functionality
require Logger

defmodule ScreenshotDebug do
  def test_screenshot do
    Logger.info("Starting screenshot debug test...")
    
    # Find the viewport
    viewport = find_scenic_viewport()
    
    if viewport do
      Logger.info("Found viewport: #{inspect(viewport)}")
      
      # Get viewport state
      try do
        state = :sys.get_state(viewport, 5000)
        Logger.info("Viewport state type: #{inspect(state.__struct__)}")
        Logger.info("Viewport state keys: #{inspect(Map.keys(state))}")
        
        # Try different ways to get driver_pids
        driver_pids = case state do
          %{driver_pids: pids} -> 
            Logger.info("Found driver_pids directly: #{inspect(pids)}")
            pids
          %{drivers: drivers} -> 
            Logger.info("Found drivers field: #{inspect(drivers)}")
            drivers
          _ ->
            Logger.info("No driver_pids or drivers field found")
            []
        end
        
        # Check if we have any processes that look like drivers
        all_processes = Process.list()
        driver_processes = Enum.filter(all_processes, fn pid ->
          case Process.info(pid, [:registered_name, :dictionary]) do
            [{:registered_name, name}, {:dictionary, dict}] when is_atom(name) ->
              name_str = Atom.to_string(name)
              is_driver = String.contains?(name_str, "driver") or
                String.contains?(name_str, "Driver") or
                Enum.any?(dict, fn {k, _} -> 
                  String.contains?(to_string(k), "driver")
                end)
              
              if is_driver do
                Logger.info("Found potential driver process: #{name} (#{inspect(pid)})")
              end
              
              is_driver
            _ -> false
          end
        end)
        
        Logger.info("Found #{length(driver_processes)} potential driver processes")
        
        # Try to find Scenic.Driver.Local processes specifically
        scenic_drivers = Enum.filter(all_processes, fn pid ->
          case :sys.get_state(pid, 1000) do
            %{module: Scenic.Driver.Local} -> 
              Logger.info("Found Scenic.Driver.Local process: #{inspect(pid)}")
              true
            _ -> false
          rescue
            _ -> false
          end
        end)
        
        Logger.info("Found #{length(scenic_drivers)} Scenic.Driver.Local processes")
        
        # Log the full state for debugging
        Logger.info("Full viewport state: #{inspect(state, limit: :infinity, pretty: true)}")
        
      rescue
        e ->
          Logger.error("Error getting viewport state: #{inspect(e)}")
      end
    else
      Logger.error("No viewport found!")
    end
  end
  
  def find_scenic_viewport do
    Logger.info("Searching for viewport...")
    
    result = Process.list()
    |> Enum.find(fn pid ->
      case Process.info(pid, [:registered_name, :dictionary]) do
        [{:registered_name, name}, {:dictionary, dict}] when is_atom(name) ->
          name_str = Atom.to_string(name)
          is_viewport = String.contains?(name_str, "viewport") or
            Enum.any?(dict, fn {k, _} -> 
              String.contains?(to_string(k), "viewport")
            end)
          
          if is_viewport do
            Logger.info("Found viewport candidate: #{name} (#{inspect(pid)})")
          end
          
          is_viewport
        _ -> false
      end
    end)
    
    Logger.info("Viewport search result: #{inspect(result)}")
    result
  end
end

# Run the test
ScreenshotDebug.test_screenshot()