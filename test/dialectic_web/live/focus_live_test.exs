defmodule DialecticWeb.GraphLiveSanitizeTest do
  use DialecticWeb.ConnCase

  alias DialecticWeb.GraphLive

  describe "sanitize_graph_title/1" do
    test "sanitizes graph titles correctly" do
      # Test normal text
      assert GraphLive.sanitize_graph_title("Hello World") == "Hello World"

      # Test text with apostrophes and dashes
      assert GraphLive.sanitize_graph_title("Shakespeare's Macbeth to pass A-Level Exam") ==
               "Shakespeare's Macbeth to pass A-Level Exam"

      # Test specific example with apostrophes and dashes
      assert GraphLive.sanitize_graph_title(
               "Shakespeare's Midsummer night's dream to pass A-Level Exam"
             ) ==
               "Shakespeare's Midsummer night's dream to pass A-Level Exam"

      # Curly quotes and unicode punctuation preserved
      assert GraphLive.sanitize_graph_title("Robert Nozick’s “Anarchy, State, and Utopia”") ==
               "Robert Nozick’s “Anarchy, State, and Utopia”"

      # Test with disallowed characters
      assert GraphLive.sanitize_graph_title("Title with @#$%^&*()!") == "Title with "

      # Test with leading/trailing whitespace
      assert GraphLive.sanitize_graph_title("  Trimmed Title  ") == "Trimmed Title"

      # Test with multiple spaces
      assert GraphLive.sanitize_graph_title("Too   many    spaces") == "Too many spaces"

      # Test with mixed allowed and disallowed characters
      assert GraphLive.sanitize_graph_title("Mix of allowed-chars and (disallowed) {chars}") ==
               "Mix of allowed-chars and disallowed chars"

      # Test with special URL characters
      assert GraphLive.sanitize_graph_title("Title/with\\path:chars?and=query&params") ==
               "Titlewithpathcharsandqueryparams"

      # Test with emojis and Unicode (emoji removed, accented char reduced)
      assert GraphLive.sanitize_graph_title("Title with 🚀 emoji and café") ==
               "Title with emoji and caf"

      # Test with numeric characters
      assert GraphLive.sanitize_graph_title("Title with numbers 123 and 456") ==
               "Title with numbers 123 and 456"

      # Test with a very long title
      long_title = String.duplicate("Very long title ", 10)
      sanitized_long_title = GraphLive.sanitize_graph_title(long_title)
      assert sanitized_long_title == String.trim(long_title)
    end

    test "handles edge cases properly" do
      # Test with empty string
      assert GraphLive.sanitize_graph_title("") == ""

      # Test with only disallowed characters
      assert GraphLive.sanitize_graph_title("@#$%^&*()!") == ""

      # Test with only spaces
      assert GraphLive.sanitize_graph_title("   ") == ""

      # Test with mixed case
      assert GraphLive.sanitize_graph_title("MiXeD cAsE tItLe") == "MiXeD cAsE tItLe"
    end
  end
end
