defmodule Dialectic.Responses.Utils.SSEParserTest do
  use ExUnit.Case, async: true

  alias Dialectic.Responses.Utils

  describe "Utils.parse_chunk/1 - SSE parsing" do
    test "parses a single frame with a single data line" do
      input = "data: {\"a\":1}\n\n"

      assert {:ok, [decoded]} = Utils.parse_chunk(input)
      assert decoded == %{"a" => 1}
    end

    test "parses multiple frames in one input" do
      input =
        "data: {\"a\":1}\n\n" <>
          "data: {\"b\":2}\n\n"

      assert {:ok, [d1, d2]} = Utils.parse_chunk(input)
      assert d1 == %{"a" => 1}
      assert d2 == %{"b" => 2}
    end

    test "concatenates multi-line data that form a single JSON document" do
      input =
        Enum.join(
          [
            "data: {",
            "data:   \"a\": 1,",
            "data:   \"b\": [1, 2, 3]",
            "data: }",
            ""
          ],
          "\n"
        )

      assert {:ok, [decoded]} = Utils.parse_chunk(input)
      assert decoded == %{"a" => 1, "b" => [1, 2, 3]}
    end

    test "supports NDJSON within a single frame (multiple JSON objects across data lines)" do
      input =
        Enum.join(
          [
            "data: {\"part\":1}",
            "data: {\"part\":2}",
            ""
          ],
          "\n"
        )

      assert {:ok, [d1, d2]} = Utils.parse_chunk(input)
      assert d1 == %{"part" => 1}
      assert d2 == %{"part" => 2}
    end

    test "ignores non-data SSE fields like event:, id:, retry:" do
      input =
        Enum.join(
          [
            "event: message",
            "id: 42",
            "retry: 10000",
            "data: {\"ok\":true}",
            ""
          ],
          "\n"
        )

      assert {:ok, [decoded]} = Utils.parse_chunk(input)
      assert decoded == %{"ok" => true}
    end

    test "ignores [DONE] control payloads" do
      assert {:ok, []} = Utils.parse_chunk("data: [DONE]\n\n")
    end

    test "empty data payloads are ignored" do
      # A frame with a data: line but no content
      assert {:ok, []} = Utils.parse_chunk("data:\n\n")
    end

    test "normalizes CRLF line endings" do
      input = "data: {\"x\": 7}\r\n\r\n"

      assert {:ok, [decoded]} = Utils.parse_chunk(input)
      assert decoded == %{"x" => 7}
    end
  end
end
