defmodule DialecticWeb.Utils.NodeTitleHelperTest do
  use ExUnit.Case, async: true

  alias DialecticWeb.Utils.NodeTitleHelper

  describe "extract_node_title/2" do
    test "extracts title from content" do
      node = %{content: "Hello World\nMore text here"}
      assert NodeTitleHelper.extract_node_title(node) == "Hello World"
    end

    test "strips markdown headers" do
      node = %{content: "# Hello World\nMore text"}
      assert NodeTitleHelper.extract_node_title(node) == "Hello World"

      node2 = %{content: "## Sub Header\nBody"}
      assert NodeTitleHelper.extract_node_title(node2) == "Sub Header"
    end

    test "strips bold markdown" do
      node = %{content: "**Bold Title**\nContent"}
      assert NodeTitleHelper.extract_node_title(node) == "Bold Title"
    end

    test "truncates long titles" do
      long_text = String.duplicate("a", 100)
      node = %{content: long_text}
      result = NodeTitleHelper.extract_node_title(node, max_length: 80)
      # 80 + "..."
      assert String.length(result) == 83
      assert String.ends_with?(result, "...")
    end

    test "returns node id for empty content" do
      node = %{content: "", id: "test-123"}
      assert NodeTitleHelper.extract_node_title(node) == "test-123"
    end

    test "returns Untitled for empty content and no id" do
      node = %{content: ""}
      assert NodeTitleHelper.extract_node_title(node) == "Untitled"
    end

    test "handles string-keyed maps" do
      node = %{"content" => "String Key Title\nBody"}
      assert NodeTitleHelper.extract_node_title(node) == "String Key Title"
    end

    test "respects max_length: :infinity option" do
      long_text = String.duplicate("a", 200)
      node = %{content: long_text}
      result = NodeTitleHelper.extract_node_title(node, max_length: :infinity)
      assert String.length(result) == 200
    end
  end

  describe "extract_match_preview/3" do
    test "returns tuple with before, match, after text" do
      node = %{content: "Hello world, this is a test"}
      result = NodeTitleHelper.extract_match_preview(node, "world")

      assert result == {"Hello ", "world", ", this is a test"}
    end

    test "is case-insensitive matching" do
      node = %{content: "Hello WORLD, this is a test"}
      result = NodeTitleHelper.extract_match_preview(node, "world")

      assert {_before, matched, _after} = result
      assert matched == "WORLD"
    end

    test "returns nil when no match found" do
      node = %{content: "Hello world"}
      result = NodeTitleHelper.extract_match_preview(node, "missing")

      assert result == nil
    end

    test "adds ellipsis when content is truncated at the start" do
      content = String.duplicate("x", 100) <> " match " <> String.duplicate("y", 20)
      node = %{content: content}
      result = NodeTitleHelper.extract_match_preview(node, "match", context_chars: 20)

      assert {before, "match", _after} = result
      assert String.starts_with?(before, "…")
    end

    test "adds ellipsis when content is truncated at the end" do
      content = "start match " <> String.duplicate("z", 100)
      node = %{content: content}
      result = NodeTitleHelper.extract_match_preview(node, "match", context_chars: 20)

      assert {_before, "match", after_text} = result
      assert String.ends_with?(after_text, "…")
    end

    test "normalizes whitespace and newlines" do
      node = %{content: "Hello\n\nworld   this\n\tis a    test"}
      result = NodeTitleHelper.extract_match_preview(node, "world")

      # Whitespace should be collapsed to single spaces
      assert {before, "world", after_text} = result
      assert before == "Hello "
      assert String.starts_with?(after_text, " this is")
    end

    test "handles match at the beginning of content" do
      node = %{content: "match is at the start"}
      result = NodeTitleHelper.extract_match_preview(node, "match")

      assert {"", "match", _after} = result
    end

    test "handles match at the end of content" do
      node = %{content: "content ends with match"}
      result = NodeTitleHelper.extract_match_preview(node, "match")

      assert {_before, "match", ""} = result
    end

    test "handles empty content" do
      node = %{content: ""}
      result = NodeTitleHelper.extract_match_preview(node, "test")

      assert result == nil
    end

    test "handles nil content" do
      node = %{content: nil}
      result = NodeTitleHelper.extract_match_preview(node, "test")

      assert result == nil
    end

    test "handles string-keyed maps" do
      node = %{"content" => "Hello world test"}
      result = NodeTitleHelper.extract_match_preview(node, "world")

      assert {_before, "world", _after} = result
    end

    test "respects context_chars option" do
      node = %{content: "aaaaa match bbbbb"}
      result = NodeTitleHelper.extract_match_preview(node, "match", context_chars: 3)

      assert {before, "match", after_text} = result
      # 3 chars + possible ellipsis marker
      assert String.length(before) <= 4
      assert String.length(after_text) <= 4
    end
  end
end
