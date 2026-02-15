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
  Click at specific coordinates.

  Example:
    ScenicMcp.Probes.click(100, 200)
  """
  def click(x, y) when is_number(x) and is_number(y) do
    params = %{"x" => x, "y" => y}

    case ScenicMcp.Tools.handle_mouse_click(params) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to click: #{reason}"
    end
  end

  @doc """
  Click an element by its semantic ID.

  Example:
    ScenicMcp.Probes.click_element("new_button")
  """
  def click_element(element_id) when is_binary(element_id) do
    params = %{"element_id" => element_id}

    case ScenicMcp.Tools.click_element(params) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to click element: #{reason}"
    end
  end

  @doc """
  Press a key without releasing (for holding modifier keys).

  Example:
    ScenicMcp.Probes.key_press("shift")  # Hold shift
    ScenicMcp.Probes.send_scroll(0, -1)  # Scroll while shift held
    ScenicMcp.Probes.key_release("shift") # Release shift
  """
  def key_press(key) when is_binary(key) do
    case ScenicMcp.Tools.handle_key_press(%{"key" => key}) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to press key: #{reason}"
    end
  end

  @doc """
  Release a previously pressed key.
  """
  def key_release(key) when is_binary(key) do
    case ScenicMcp.Tools.handle_key_release(%{"key" => key}) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to release key: #{reason}"
    end
  end

  @doc """
  Send scroll input.

  Examples:
    ScenicMcp.Probes.send_scroll(0, -1)    # Scroll down
    ScenicMcp.Probes.send_scroll(1, 0)     # Scroll right (horizontal)
    ScenicMcp.Probes.send_scroll(0, -1, 400, 300)  # Scroll at specific position
  """
  def send_scroll(dx, dy, x \\ 400, y \\ 300) when is_number(dx) and is_number(dy) do
    params = %{"dx" => dx, "dy" => dy, "x" => x, "y" => y}

    case ScenicMcp.Tools.handle_scroll(params) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to send scroll: #{reason}"
    end
  end

  @doc """
  Move mouse to specific coordinates (without clicking).
  Useful for drag operations and hover effects.

  Example:
    ScenicMcp.Probes.send_mouse_move(100, 200)
  """
  def send_mouse_move(x, y) when is_number(x) and is_number(y) do
    params = %{"x" => x, "y" => y}

    case ScenicMcp.Tools.handle_mouse_move(params) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to move mouse: #{reason}"
    end
  end

  @doc """
  Click at specific coordinates (alias for click/2).

  Example:
    ScenicMcp.Probes.send_mouse_click(100, 200)
  """
  def send_mouse_click(x, y) when is_number(x) and is_number(y) do
    click(x, y)
  end

  @doc """
  Mouse button down (press without release).
  Use with send_mouse_move and mouse_up for drag operations.

  Example:
    ScenicMcp.Probes.mouse_down(100, 200)
    ScenicMcp.Probes.send_mouse_move(100, 400)
    ScenicMcp.Probes.mouse_up(100, 400)
  """
  def mouse_down(x, y) when is_number(x) and is_number(y) do
    params = %{"x" => x, "y" => y}

    case ScenicMcp.Tools.handle_mouse_down(params) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to press mouse: #{reason}"
    end
  end

  @doc """
  Mouse button up (release).
  Use after mouse_down and send_mouse_move for drag operations.

  Example:
    ScenicMcp.Probes.mouse_down(100, 200)
    ScenicMcp.Probes.send_mouse_move(100, 400)
    ScenicMcp.Probes.mouse_up(100, 400)
  """
  def mouse_up(x, y) when is_number(x) and is_number(y) do
    params = %{"x" => x, "y" => y}

    case ScenicMcp.Tools.handle_mouse_up(params) do
      {:ok, _result} -> :ok
      {:error, reason} -> raise "Failed to release mouse: #{reason}"
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
