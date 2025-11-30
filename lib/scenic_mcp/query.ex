defmodule ScenicMcp.Query do
  @moduledoc """
  Query utilities for inspecting rendered Scenic content.

  Provides functions to examine what's currently displayed in a Scenic viewport,
  enabling programmatic inspection and testing of GUI applications.

  ## Usage

      # Check if text is visible on screen
      ScenicMcp.Query.text_visible?("Hello World")

      # Get all rendered text as a string
      ScenicMcp.Query.rendered_text()

      # Get text organized by lines
      ScenicMcp.Query.text_by_lines()

      # Check specific line content
      ScenicMcp.Query.text_on_line?(1, "Welcome")

  ## Design

  These functions read directly from Scenic's script table ETS, providing
  a true view of what's actually rendered (not just internal state).
  """

  require Logger

  # ============================================================================
  # Primary Query Functions
  # ============================================================================

  @doc """
  Check if the specified text is visible anywhere on screen.

  Returns `true` if the text is found in any rendered text primitive.

  ## Examples

      iex> ScenicMcp.Query.text_visible?("Save")
      true

      iex> ScenicMcp.Query.text_visible?("NonexistentText")
      false
  """
  @spec text_visible?(String.t()) :: boolean()
  def text_visible?(text) when is_binary(text) do
    rendered_text()
    |> String.contains?(text)
  end

  @doc """
  Get all rendered text content as a single string.

  Extracts text from all text primitives in the script table and
  joins them with spaces.

  ## Examples

      iex> ScenicMcp.Query.rendered_text()
      "File Edit View Help unnamed-1 1 2 3"
  """
  @spec rendered_text() :: String.t()
  def rendered_text do
    get_script_table()
    |> extract_all_text()
    |> Enum.join(" ")
    |> String.trim()
  end

  @doc """
  Get rendered text as a list of individual text items.

  Returns each text primitive's content as a separate list element.

  ## Examples

      iex> ScenicMcp.Query.rendered_text_list()
      ["File", "Edit", "View", "Help", "unnamed-1", "1", "2", "3"]
  """
  @spec rendered_text_list() :: [String.t()]
  def rendered_text_list do
    get_script_table()
    |> extract_all_text()
  end

  @doc """
  Check if the rendered content is empty (no text primitives).

  ## Examples

      iex> ScenicMcp.Query.empty?()
      false
  """
  @spec empty?() :: boolean()
  def empty? do
    rendered_text_list() |> Enum.empty?()
  end

  # ============================================================================
  # Position-Aware Queries
  # ============================================================================

  @doc """
  Get all text primitives with their positions.

  Returns a list of maps containing text content and x/y coordinates,
  sorted by Y (top to bottom) then X (left to right).

  ## Examples

      iex> ScenicMcp.Query.text_with_positions()
      [
        %{text: "File", x: 10, y: 5},
        %{text: "Edit", x: 60, y: 5},
        %{text: "Line 1", x: 10, y: 50}
      ]
  """
  @spec text_with_positions() :: [%{text: String.t(), x: number(), y: number()}]
  def text_with_positions do
    get_script_table()
    |> extract_text_with_positions()
    |> Enum.sort_by(fn %{y: y, x: x} -> {y, x} end)
  end

  @doc """
  Get text content organized by lines (Y-coordinate grouping).

  Groups text primitives that share similar Y-coordinates into lines.
  Returns a list of `{line_y, [text_items]}` tuples, sorted top to bottom.

  ## Parameters
    - `y_tolerance` - Maximum Y-difference to consider text on same line (default: 5)

  ## Examples

      iex> ScenicMcp.Query.text_by_lines()
      [
        {5, ["File", "Edit", "View", "Help"]},
        {50, ["Hello", "World"]},
        {75, ["Line 2"]}
      ]
  """
  @spec text_by_lines(number()) :: [{number(), [String.t()]}]
  def text_by_lines(y_tolerance \\ 5) do
    text_with_positions()
    |> Enum.group_by(fn %{y: y} ->
      round(y / y_tolerance) * y_tolerance
    end)
    |> Enum.map(fn {line_y, items} ->
      sorted_text = items
        |> Enum.sort_by(fn %{x: x} -> x end)
        |> Enum.map(fn %{text: text} -> text end)
      {line_y, sorted_text}
    end)
    |> Enum.sort_by(fn {y, _} -> y end)
  end

  @doc """
  Check if text appears on a specific line number (1-indexed).

  ## Parameters
    - `line_number` - Line number (1 = first line, 2 = second, etc.)
    - `text` - Text to search for on that line

  ## Examples

      iex> ScenicMcp.Query.text_on_line?(1, "File")
      true

      iex> ScenicMcp.Query.text_on_line?(2, "File")
      false
  """
  @spec text_on_line?(pos_integer(), String.t()) :: boolean()
  def text_on_line?(line_number, text) when line_number > 0 and is_binary(text) do
    lines = text_by_lines()

    case Enum.at(lines, line_number - 1) do
      nil -> false
      {_y, text_list} ->
        Enum.any?(text_list, fn item -> String.contains?(item, text) end)
    end
  end

  @doc """
  Get the number of distinct text lines rendered.

  ## Examples

      iex> ScenicMcp.Query.line_count()
      3
  """
  @spec line_count() :: non_neg_integer()
  def line_count do
    text_by_lines() |> length()
  end

  @doc """
  Check if text appears across multiple lines (wrapping detection).

  Useful for testing word wrap functionality.

  ## Examples

      iex> ScenicMcp.Query.text_wraps?("long_content")
      true
  """
  @spec text_wraps?(String.t()) :: boolean()
  def text_wraps?(text_pattern) when is_binary(text_pattern) do
    text_with_positions()
    |> Enum.filter(fn %{text: text} -> String.contains?(text, text_pattern) end)
    |> Enum.map(fn %{y: y} -> y end)
    |> Enum.uniq()
    |> length()
    |> Kernel.>(1)
  end

  # ============================================================================
  # Statistics & Debugging
  # ============================================================================

  @doc """
  Get statistics about the rendered content.

  ## Examples

      iex> ScenicMcp.Query.stats()
      %{
        script_entries: 42,
        text_primitives: 15,
        total_text_length: 234,
        line_count: 8
      }
  """
  @spec stats() :: map()
  def stats do
    script_data = get_script_table()
    text_list = extract_all_text(script_data)

    %{
      script_entries: length(script_data),
      text_primitives: length(text_list),
      total_text_length: text_list |> Enum.join() |> String.length(),
      line_count: line_count()
    }
  end

  @doc """
  Debug dump of the script table contents.

  Prints detailed information about each script entry.
  Useful for debugging rendering issues.
  """
  @spec debug_dump() :: :ok
  def debug_dump do
    script_data = get_script_table()

    IO.puts("\n=== SCENIC SCRIPT TABLE DEBUG ===")
    IO.puts("Total entries: #{length(script_data)}")

    script_data
    |> Enum.with_index()
    |> Enum.each(fn {entry, index} ->
      IO.puts("\nEntry #{index}:")
      IO.inspect(entry, limit: :infinity, printable_limit: 200)
    end)

    IO.puts("\n=== END DEBUG ===\n")
    :ok
  end

  # ============================================================================
  # Private Helpers - Script Table Access
  # ============================================================================

  defp get_script_table do
    case ScenicMcp.Tools.viewport_state() do
      {:ok, %{script_table: script_table}} when not is_nil(script_table) ->
        :ets.tab2list(script_table)

      {:ok, state} ->
        Logger.warning("No script_table in viewport state. Keys: #{inspect(Map.keys(state))}")
        []

      {:error, reason} ->
        Logger.warning("Failed to get viewport state: #{reason}")
        []
    end
  rescue
    error ->
      Logger.warning("Exception getting script table: #{Exception.message(error)}")
      []
  end

  # ============================================================================
  # Private Helpers - Text Extraction
  # ============================================================================

  defp extract_all_text(script_data) do
    script_data
    |> Enum.flat_map(&flatten_commands/1)
    |> Enum.filter(&text_primitive?/1)
    |> Enum.map(&extract_text/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp extract_text_with_positions(script_data) do
    script_data
    |> Enum.flat_map(&flatten_commands/1)
    |> Enum.filter(&text_primitive?/1)
    |> Enum.map(&extract_text_and_position/1)
    |> Enum.reject(&is_nil/1)
  end

  defp flatten_commands({_id, commands, _pid}) when is_list(commands), do: commands
  defp flatten_commands({_id, commands}) when is_list(commands), do: commands
  defp flatten_commands(commands) when is_list(commands), do: commands
  defp flatten_commands(_), do: []

  defp text_primitive?({_id, :text, _data, _opts}), do: true
  defp text_primitive?({:text, _data, _opts}), do: true
  defp text_primitive?(%{type: :text}), do: true
  defp text_primitive?({:draw_text, _text}), do: true
  defp text_primitive?(_), do: false

  defp extract_text({_id, :text, text, _opts}) when is_binary(text), do: text
  defp extract_text({:text, text, _opts}) when is_binary(text), do: text
  defp extract_text(%{type: :text, data: text}) when is_binary(text), do: text
  defp extract_text({:draw_text, text}) when is_binary(text), do: text
  defp extract_text(_), do: nil

  defp extract_text_and_position({_id, :text, text, opts}) when is_binary(text) do
    build_text_position(text, opts)
  end
  defp extract_text_and_position({:text, text, opts}) when is_binary(text) do
    build_text_position(text, opts)
  end
  defp extract_text_and_position(%{type: :text, data: text, opts: opts}) when is_binary(text) do
    build_text_position(text, opts)
  end
  defp extract_text_and_position({:draw_text, text}) when is_binary(text) do
    %{text: text, x: 0, y: 0}
  end
  defp extract_text_and_position(_), do: nil

  defp build_text_position(text, opts) when is_list(opts) do
    {x, y} = Keyword.get(opts, :translate, {0, 0})
    %{text: text, x: x, y: y}
  end
  defp build_text_position(text, _opts) do
    %{text: text, x: 0, y: 0}
  end
end
