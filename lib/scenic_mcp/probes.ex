defmodule ScenicMcp.Probes do
  @moduledoc """
  Compatibility shim for the old ScenicMcp.Probes API.

  This module wraps the new ScenicMcp.Tools API to provide backward compatibility
  with existing spex tests.
  """

  @doc """
  Send keyboard input - either text or special keys.

  Examples:
    ScenicMcp.Probes.send_keys("a", [:ctrl])  # Ctrl+A
    ScenicMcp.Probes.send_keys("enter", [])   # Enter key
  """
  def send_keys(key, modifiers) when is_binary(key) and is_list(modifiers) do
    # Check if it's a special key or a single character
    params = if is_special_key?(key) do
      # Special key (enter, escape, etc.)
      %{"key" => key, "modifiers" => Enum.map(modifiers, &to_string/1)}
    else
      # Regular character with modifiers
      %{"key" => key, "modifiers" => Enum.map(modifiers, &to_string/1)}
    end

    case ScenicMcp.Tools.handle_send_keys(params) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to send keys: #{reason}"
    end
  end

  @doc """
  Send text input character by character.

  Example:
    ScenicMcp.Probes.send_text("Hello World")
  """
  def send_text(text) when is_binary(text) do
    params = %{"text" => text}

    case ScenicMcp.Tools.handle_send_keys(params) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to send text: #{reason}"
    end
  end

  @doc """
  Take a screenshot.

  Example:
    ScenicMcp.Probes.take_screenshot("my_screenshot")
  """
  def take_screenshot(filename) when is_binary(filename) do
    # Ensure test/spex/screenshots directory exists
    screenshots_dir = "test/spex/screenshots"
    File.mkdir_p!(screenshots_dir)

    # Build full path
    full_path = Path.join(screenshots_dir, filename)
    full_path = if String.ends_with?(full_path, ".png"), do: full_path, else: full_path <> ".png"

    params = %{"filename" => full_path, "format" => "path"}

    case ScenicMcp.Tools.take_screenshot(params) do
      {:ok, result} ->
        Map.get(result, :path) || Map.get(result, "path")
      {:error, reason} ->
        raise "Failed to take screenshot: #{reason}"
    end
  end

  # Helper to determine if a key is a special key
  defp is_special_key?(key) do
    key in [
      "enter", "escape", "tab", "backspace", "delete", "space",
      "up", "down", "left", "right", "home", "end",
      "page_up", "page_down",
      "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12"
    ] or String.length(key) > 1
  end
end
