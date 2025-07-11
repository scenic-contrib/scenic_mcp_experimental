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
  
  def viewport_pid_safe do
    Process.whereis(:main_viewport)
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
  
  def driver_pid_safe do
    Process.whereis(:scenic_driver)
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

  @doc """
  Send text input to the application. Each character is sent as a codepoint event.
  """
  def send_text(text) when is_binary(text) do
    driver_state = driver_state()
    
    text
    |> String.graphemes()
    |> Enum.each(fn char ->
      case char_to_key_event(char) do
        {:ok, key_event} ->
          Scenic.Driver.send_input(driver_state, key_event)
        :error ->
          # For unsupported characters, still try codepoint
          codepoint = char |> String.to_charlist() |> List.first()
          Scenic.Driver.send_input(driver_state, {:codepoint, {codepoint, []}})
      end
    end)
    
    :ok
  end

  # Convert a character to a key event that Quillex can understand.
  # Returns {:ok, key_event} for supported characters, :error otherwise.
  defp char_to_key_event(char) do
    case char do
      # Lowercase letters
      "a" -> {:ok, {:key, {:key_a, 1, []}}}
      "b" -> {:ok, {:key, {:key_b, 1, []}}}
      "c" -> {:ok, {:key, {:key_c, 1, []}}}
      "d" -> {:ok, {:key, {:key_d, 1, []}}}
      "e" -> {:ok, {:key, {:key_e, 1, []}}}
      "f" -> {:ok, {:key, {:key_f, 1, []}}}
      "g" -> {:ok, {:key, {:key_g, 1, []}}}
      "h" -> {:ok, {:key, {:key_h, 1, []}}}
      "i" -> {:ok, {:key, {:key_i, 1, []}}}
      "j" -> {:ok, {:key, {:key_j, 1, []}}}
      "k" -> {:ok, {:key, {:key_k, 1, []}}}
      "l" -> {:ok, {:key, {:key_l, 1, []}}}
      "m" -> {:ok, {:key, {:key_m, 1, []}}}
      "n" -> {:ok, {:key, {:key_n, 1, []}}}
      "o" -> {:ok, {:key, {:key_o, 1, []}}}
      "p" -> {:ok, {:key, {:key_p, 1, []}}}
      "q" -> {:ok, {:key, {:key_q, 1, []}}}
      "r" -> {:ok, {:key, {:key_r, 1, []}}}
      "s" -> {:ok, {:key, {:key_s, 1, []}}}
      "t" -> {:ok, {:key, {:key_t, 1, []}}}
      "u" -> {:ok, {:key, {:key_u, 1, []}}}
      "v" -> {:ok, {:key, {:key_v, 1, []}}}
      "w" -> {:ok, {:key, {:key_w, 1, []}}}
      "x" -> {:ok, {:key, {:key_x, 1, []}}}
      "y" -> {:ok, {:key, {:key_y, 1, []}}}
      "z" -> {:ok, {:key, {:key_z, 1, []}}}
      
      # Uppercase letters (same key with shift modifier)
      "A" -> {:ok, {:key, {:key_a, 1, [:shift]}}}
      "B" -> {:ok, {:key, {:key_b, 1, [:shift]}}}
      "C" -> {:ok, {:key, {:key_c, 1, [:shift]}}}
      "D" -> {:ok, {:key, {:key_d, 1, [:shift]}}}
      "E" -> {:ok, {:key, {:key_e, 1, [:shift]}}}
      "F" -> {:ok, {:key, {:key_f, 1, [:shift]}}}
      "G" -> {:ok, {:key, {:key_g, 1, [:shift]}}}
      "H" -> {:ok, {:key, {:key_h, 1, [:shift]}}}
      "I" -> {:ok, {:key, {:key_i, 1, [:shift]}}}
      "J" -> {:ok, {:key, {:key_j, 1, [:shift]}}}
      "K" -> {:ok, {:key, {:key_k, 1, [:shift]}}}
      "L" -> {:ok, {:key, {:key_l, 1, [:shift]}}}
      "M" -> {:ok, {:key, {:key_m, 1, [:shift]}}}
      "N" -> {:ok, {:key, {:key_n, 1, [:shift]}}}
      "O" -> {:ok, {:key, {:key_o, 1, [:shift]}}}
      "P" -> {:ok, {:key, {:key_p, 1, [:shift]}}}
      "Q" -> {:ok, {:key, {:key_q, 1, [:shift]}}}
      "R" -> {:ok, {:key, {:key_r, 1, [:shift]}}}
      "S" -> {:ok, {:key, {:key_s, 1, [:shift]}}}
      "T" -> {:ok, {:key, {:key_t, 1, [:shift]}}}
      "U" -> {:ok, {:key, {:key_u, 1, [:shift]}}}
      "V" -> {:ok, {:key, {:key_v, 1, [:shift]}}}
      "W" -> {:ok, {:key, {:key_w, 1, [:shift]}}}
      "X" -> {:ok, {:key, {:key_x, 1, [:shift]}}}
      "Y" -> {:ok, {:key, {:key_y, 1, [:shift]}}}
      "Z" -> {:ok, {:key, {:key_z, 1, [:shift]}}}
      
      # Numbers
      "0" -> {:ok, {:key, {:key_0, 1, []}}}
      "1" -> {:ok, {:key, {:key_1, 1, []}}}
      "2" -> {:ok, {:key, {:key_2, 1, []}}}
      "3" -> {:ok, {:key, {:key_3, 1, []}}}
      "4" -> {:ok, {:key, {:key_4, 1, []}}}
      "5" -> {:ok, {:key, {:key_5, 1, []}}}
      "6" -> {:ok, {:key, {:key_6, 1, []}}}
      "7" -> {:ok, {:key, {:key_7, 1, []}}}
      "8" -> {:ok, {:key, {:key_8, 1, []}}}
      "9" -> {:ok, {:key, {:key_9, 1, []}}}
      
      # Common punctuation
      " " -> {:ok, {:key, {:key_space, 1, []}}}
      "!" -> {:ok, {:key, {:key_1, 1, [:shift]}}}
      "." -> {:ok, {:key, {:key_period, 1, []}}}
      "," -> {:ok, {:key, {:key_comma, 1, []}}}
      "?" -> {:ok, {:key, {:key_slash, 1, [:shift]}}}
      
      # Fall back to codepoint for unsupported characters
      _ -> :error
    end
  end

  @doc """
  Send key input to the application. Supports special keys and modifiers.
  """
  def send_keys(key, modifiers \\ []) when is_binary(key) and is_list(modifiers) do
    driver_state = driver_state()
    key_atom = normalize_key(key)
    
    # Send key press
    Scenic.Driver.send_input(driver_state, {:key, {key_atom, 1, modifiers}})
    
    # Send key release  
    Scenic.Driver.send_input(driver_state, {:key, {key_atom, 0, modifiers}})
    
    :ok
  end

  @doc """
  Take a screenshot and save it to the specified filename or generate one.
  Returns the path to the saved screenshot.
  """
  def take_screenshot(filename \\ nil) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    final_filename = filename || "screenshot_#{timestamp}.png"
    
    # Use the Tools module to take the screenshot
    case ScenicMcp.Tools.take_screenshot(%{"filename" => final_filename}) do
      %{status: "ok", path: path} -> path
      %{error: _reason} -> nil
      _other -> nil
    end
  end

  # Helper function to normalize key names to atoms
  defp normalize_key(key) when is_binary(key) do
    case String.downcase(key) do
      "enter" -> :key_enter
      "escape" -> :key_escape
      "esc" -> :key_escape
      "backspace" -> :key_backspace
      "delete" -> :key_delete
      "tab" -> :key_tab
      "space" -> :key_space
      "up" -> :key_up
      "down" -> :key_down
      "left" -> :key_left
      "right" -> :key_right
      "home" -> :key_home
      "end" -> :key_end
      "page_up" -> :key_page_up
      "page_down" -> :key_page_down
      "a" -> :key_a
      "s" -> :key_s
      "ctrl" -> :key_left_ctrl
      "shift" -> :key_left_shift
      "alt" -> :key_left_alt
      other -> 
        # Try to convert single character keys
        if String.length(other) == 1 do
          char = other |> String.to_charlist() |> List.first()
          case char do
            c when c >= ?a and c <= ?z -> String.to_atom("key_#{other}")
            c when c >= ?A and c <= ?Z -> String.to_atom("key_#{String.downcase(other)}")
            _ -> :key_unknown
          end
        else
          :key_unknown
        end
    end
  end
end
