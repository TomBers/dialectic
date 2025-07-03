defmodule DialecticWeb.TestApostrophe do
  @moduledoc """
  A module for testing and debugging apostrophe handling issues.

  This file is intended to isolate and diagnose issues with apostrophes
  in graph titles, particularly with titles like "Shakespeare's Macbeth".
  """

  require Logger

  @doc """
  Test sanitization function with different apostrophe patterns.
  Especially focused on the "Shakespeare's" case where the apostrophe
  is disappearing.
  """
  def test_sanitize do
    test_titles = [
      "Shakespeare's Macbeth to pass A-Level Exam",
      "Shakespeare's Midsummer night's dream to pass A-Level Exam",
      "King's Cross is London's famous station",
      "It's a test of apostrophes",
      "Testing apostrophe's in the middle"
    ]

    IO.puts("========== APOSTROPHE TEST ==========")
    IO.puts("Testing sanitize_graph_title function with different apostrophe patterns")

    Enum.each(test_titles, fn title ->
      IO.puts("\nOriginal: #{inspect(title)}")

      # Test the sanitize function directly
      sanitized = sanitize_graph_title(title)
      IO.puts("Sanitized: #{inspect(sanitized)}")
      IO.puts("Equal? #{title == sanitized}")

      # Check for specific apostrophe patterns
      if String.contains?(title, "'") do
        original_apostrophes = count_apostrophes(title)
        sanitized_apostrophes = count_apostrophes(sanitized)

        IO.puts(
          "Apostrophes: Original=#{original_apostrophes}, Sanitized=#{sanitized_apostrophes}"
        )

        if original_apostrophes != sanitized_apostrophes do
          IO.puts("WARNING: Apostrophes were lost during sanitization!")

          # Find the first missing apostrophe
          find_missing_apostrophe(title, sanitized)
        end
      end

      # Special test for Shakespeare's case
      if String.contains?(title, "Shakespeare's") do
        IO.puts("Testing specific patterns for 'Shakespeare's':")

        # Test replacing just 'e's' with 'es'
        test_es = String.replace(title, "e's", "es")
        IO.puts("After replacing 'e's' with 'es': #{test_es}")
        IO.puts("Matches issue? #{test_es == sanitized}")

        # Test replacing just "re's" with "res"
        test_res = String.replace(title, "re's", "res")
        IO.puts("After replacing 're's' with 'res': #{test_res}")
        IO.puts("Matches issue? #{test_res == sanitized}")

        # Test replacing Shakespeare's directly
        test_direct = String.replace(title, "Shakespeare's", "Shakespeares")
        IO.puts("After replacing 'Shakespeare's' with 'Shakespeares': #{test_direct}")
        IO.puts("Matches issue? #{test_direct == sanitized}")
      end
    end)

    IO.puts("\n========== END TEST ==========")
  end

  @doc """
  Test the process of encoding and decoding titles for URLs.
  """
  def test_url_encoding do
    test_titles = [
      "Shakespeare's Macbeth to pass A-Level Exam",
      "Shakespeare's Midsummer night's dream to pass A-Level Exam"
    ]

    IO.puts("========== URL ENCODING TEST ==========")

    Enum.each(test_titles, fn title ->
      IO.puts("\nOriginal: #{inspect(title)}")

      # Test URL encoding
      encoded = URI.encode(title)
      IO.puts("URL encoded: #{encoded}")

      # Test URL decoding
      decoded = URI.decode(encoded)
      IO.puts("URL decoded: #{decoded}")
      IO.puts("Equal after encode/decode? #{title == decoded}")

      # Check apostrophes
      if String.contains?(title, "'") do
        IO.puts("Original has apostrophes? #{String.contains?(title, "'")}")
        IO.puts("Encoded has %27? #{String.contains?(encoded, "%27")}")
        IO.puts("Decoded has apostrophes? #{String.contains?(decoded, "'")}")
      end
    end)

    IO.puts("\n========== END TEST ==========")
  end

  @doc """
  Test database operations with apostrophes in titles.
  Creates a test graph, checks the title, then deletes it.

  Requires running in a context with database access.
  """
  def test_database do
    test_title = "Shakespeare's Macbeth to pass A-Level Exam"

    IO.puts("========== DATABASE TEST ==========")
    IO.puts("Testing database operations with apostrophe in title")
    IO.puts("Title: #{inspect(test_title)}")

    # Try creating a graph with this title
    alias Dialectic.DbActions.Graphs
    alias Dialectic.Repo

    case Graphs.create_new_graph(test_title) do
      {:ok, graph} ->
        IO.puts("Graph created successfully")
        IO.puts("Title in database: #{inspect(graph.title)}")
        IO.puts("Equal to original? #{test_title == graph.title}")

        # Check first node content
        first_node = get_in(graph.data, ["nodes", Access.at(0), "content"])
        IO.puts("First node content: #{inspect(first_node)}")
        IO.puts("Node content equal to title? #{test_title == first_node}")

        # Clean up
        Repo.delete(graph)
        IO.puts("Test graph deleted")

      {:error, changeset} ->
        IO.puts("Error creating graph: #{inspect(changeset.errors)}")
    end

    IO.puts("========== END TEST ==========")
  end

  @doc """
  Test the complete flow from input to display.
  """
  def test_complete_flow do
    test_title = "Shakespeare's Macbeth to pass A-Level Exam"

    IO.puts("========== COMPLETE FLOW TEST ==========")
    IO.puts("Testing complete flow from input to display")
    IO.puts("Original title: #{inspect(test_title)}")

    # 1. Sanitize
    sanitized = sanitize_graph_title(test_title)
    IO.puts("1. Sanitized: #{inspect(sanitized)}")
    IO.puts("1. Equal? #{test_title == sanitized}")

    # 2. URL encode for path
    url_encoded = URI.encode(sanitized)
    IO.puts("2. URL encoded: #{url_encoded}")

    # 3. URL decode (simulating mount)
    url_decoded = URI.decode(url_encoded)
    IO.puts("3. URL decoded: #{url_decoded}")
    IO.puts("3. Equal to sanitized? #{sanitized == url_decoded}")

    # 4. HTML escape (for display)
    html_escaped = Phoenix.HTML.html_escape(url_decoded) |> Phoenix.HTML.safe_to_string()
    IO.puts("4. HTML escaped: #{html_escaped}")

    # 5. Try with problematic pattern
    if String.contains?(test_title, "Shakespeare's") do
      IO.puts("\nTesting problematic 'Shakespeare's' pattern:")

      test_es = String.replace(test_title, "e's", "es")
      IO.puts("After replacing 'e's' with 'es': #{test_es}")

      test_es_sanitized = sanitize_graph_title(test_es)
      IO.puts("Sanitized after replacement: #{test_es_sanitized}")
      IO.puts("Equal? #{test_es == test_es_sanitized}")
    end

    IO.puts("========== END TEST ==========")
  end

  # Implementation of sanitize_graph_title for testing
  defp sanitize_graph_title(title) do
    title
    |> String.trim()
    # Only allow letters, numbers, spaces, dashes and apostrophes
    |> String.replace(~r/[^a-zA-Z0-9\s'-]/, "")
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
  end

  # Helper to count apostrophes
  defp count_apostrophes(str) do
    str |> String.graphemes() |> Enum.count(&(&1 == "'"))
  end

  # Helper to find missing apostrophe
  defp find_missing_apostrophe(original, sanitized) do
    original_chars = String.graphemes(original)
    sanitized_chars = String.graphemes(sanitized)

    # Find differences
    {_, diffs} =
      Enum.reduce(Enum.zip(0..1000, original_chars), {0, []}, fn {i, char}, {index, diffs} ->
        sanitized_char = Enum.at(sanitized_chars, index, nil)

        cond do
          sanitized_char == nil ->
            {index, diffs ++ [{i, char, "missing"}]}

          char == sanitized_char ->
            {index + 1, diffs}

          char == "'" ->
            # Apostrophe in original but not in sanitized
            {index, diffs ++ [{i, char, "removed apostrophe"}]}

          true ->
            # Other difference
            {index + 1, diffs ++ [{i, char, sanitized_char}]}
        end
      end)

    if length(diffs) > 0 do
      IO.puts("Differences found:")

      Enum.each(diffs, fn {pos, orig_char, status} ->
        IO.puts("  Position #{pos}: Original='#{orig_char}', Status=#{status}")

        # Show context around difference
        start = max(0, pos - 10)
        length = min(20, String.length(original) - start)
        context = String.slice(original, start, length)
        IO.puts("  Context: ...#{context}...")
      end)
    else
      IO.puts("No character differences found, but apostrophes are missing!")
    end
  end
end
