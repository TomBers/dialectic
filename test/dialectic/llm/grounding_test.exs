defmodule Dialectic.LLM.GroundingTest do
  use ExUnit.Case, async: true

  alias Dialectic.LLM.Grounding

  test "source status counts distinct usable links, not search requests or malformed chunks" do
    assert Grounding.sources(nil) == []
    assert Grounding.sources(%{"google" => %{"webSearchQueries" => ["evidence"]}}) == []
    assert Grounding.sources(%{google: %{groundingChunks: "invalid"}}) == []

    metadata = %{
      google: %{
        groundingChunks: [
          %{web: %{uri: "https://example.org/paper", title: "Paper"}},
          %{"web" => %{"uri" => "https://example.org/paper", "title" => "Duplicate"}},
          %{web: %{uri: "javascript:alert(1)"}},
          %{web: %{uri: "/relative"}},
          nil
        ]
      }
    }

    assert Grounding.sources(metadata) == [%{url: "https://example.org/paper", title: "Paper"}]
  end

  test "retains and merges the complete provider grounding metadata" do
    first =
      Grounding.merge(nil, %{
        provider_meta: %{
          "google" => %{
            "grounding_metadata" => %{
              "webSearchQueries" => ["first query"],
              "groundingChunks" => [
                %{"web" => %{"title" => "First", "uri" => "https://example.com/first"}}
              ]
            }
          }
        }
      })

    merged =
      Grounding.merge(first, %{
        provider_meta: %{
          "google" => %{
            "grounding_metadata" => %{
              "webSearchQueries" => ["second query"],
              "groundingSupports" => [
                %{
                  "groundingChunkIndices" => [0],
                  "confidenceScores" => [0.97],
                  "segment" => %{
                    "startIndex" => 10,
                    "endIndex" => 74,
                    "text" =>
                      "A complete support passage that is not shortened or otherwise rewritten."
                  }
                }
              ],
              "searchEntryPoint" => %{"renderedContent" => "<div>Search</div>"}
            }
          }
        }
      })

    assert get_in(merged, ["google", "webSearchQueries"]) == [
             "first query",
             "second query"
           ]

    assert [support] = get_in(merged, ["google", "groundingSupports"])
    assert support["segment"]["startIndex"] == 10
    assert support["segment"]["endIndex"] == 74
    assert support["confidenceScores"] == [0.97]

    assert get_in(merged, ["google", "searchEntryPoint", "renderedContent"]) ==
             "<div>Search</div>"
  end

  test "strips model-authored sources and references sections from persisted answer content" do
    for heading <- ["Sources", "References"] do
      markdown = """
      # Answer

      Body.

      ## #{heading}

      - A model-authored source

      ## Follow-up questions

      1. What next?
      """

      result = Grounding.strip_sources(markdown)

      refute result =~ "## #{heading}"
      refute result =~ "model-authored source"
      assert result =~ "## Follow-up questions"
    end
  end
end
