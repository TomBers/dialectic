defmodule Dialectic.Responses.ExtractTextTest do
  use ExUnit.Case, async: true

  alias Dialectic.Workers.{OpenAIWorker, ClaudeWorker, DeepSeekWorker, GeminiWorker}

  describe "OpenAIWorker.extract_text/1" do
    test "returns concatenated content across choices" do
      resp = %{
        "choices" => [
          %{"message" => %{"content" => "Hello "}},
          %{"message" => %{"content" => "world!"}}
        ]
      }

      assert OpenAIWorker.extract_text(resp) == "Hello world!"
    end

    test "returns nil when content is missing or empty" do
      assert OpenAIWorker.extract_text(%{"choices" => []}) == nil

      assert OpenAIWorker.extract_text(%{"choices" => [%{"message" => %{"content" => ""}}]}) ==
               nil

      assert OpenAIWorker.extract_text(%{"choices" => [%{}]}) == nil
      assert OpenAIWorker.extract_text(%{}) == nil
    end
  end

  describe "ClaudeWorker.extract_text/1" do
    test "joins text parts and ignores non-text parts" do
      resp = %{
        "content" => [
          %{"type" => "text", "text" => "Part A. "},
          %{"type" => "tool_use", "name" => "search", "input" => %{}},
          %{"type" => "text", "text" => "Part B."}
        ]
      }

      assert ClaudeWorker.extract_text(resp) == "Part A. Part B."
    end

    test "returns nil when no text parts are present" do
      resp = %{"content" => [%{"type" => "tool_use", "name" => "search"}]}
      assert ClaudeWorker.extract_text(resp) == nil
      assert ClaudeWorker.extract_text(%{}) == nil
    end
  end

  describe "DeepSeekWorker.extract_text/1" do
    test "returns concatenated content across choices" do
      resp = %{
        "choices" => [
          %{"message" => %{"content" => "Alpha "}},
          %{"message" => %{"content" => "Beta"}}
        ]
      }

      assert DeepSeekWorker.extract_text(resp) == "Alpha Beta"
    end

    test "returns nil when no content is present" do
      assert DeepSeekWorker.extract_text(%{"choices" => [%{}]}) == nil
      assert DeepSeekWorker.extract_text(%{"choices" => []}) == nil
      assert DeepSeekWorker.extract_text(%{}) == nil
    end
  end

  describe "GeminiWorker.extract_text/1" do
    test "joins text across parts and candidates" do
      resp = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{"text" => "One "},
                %{"text" => "Two "},
                %{"non_text" => "ignored"}
              ]
            }
          },
          %{"content" => %{"parts" => [%{"text" => "Three"}]}}
        ]
      }

      assert GeminiWorker.extract_text(resp) == "One Two Three"
    end

    test "returns nil when no text parts are present" do
      resp = %{"candidates" => [%{"content" => %{"parts" => [%{"inline_data" => %{}}]}}]}
      assert GeminiWorker.extract_text(resp) == nil
      assert GeminiWorker.extract_text(%{}) == nil
    end
  end
end
