defmodule Dialectic.LLM.GroundingTest do
  use ExUnit.Case, async: true

  alias Dialectic.LLM.Grounding

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

  test "strips a model-authored sources section from persisted answer content" do
    markdown = """
    # Answer

    Body.

    ## Sources

    - A model-authored source

    ## Follow-up questions

    1. What next?
    """

    result = Grounding.strip_sources(markdown)

    refute result =~ "## Sources"
    refute result =~ "model-authored source"
    assert result =~ "## Follow-up questions"
  end
end
