defmodule Dialectic.LLM.GroundedSourcesTest do
  use ExUnit.Case, async: true

  alias Dialectic.LLM.GroundedSources

  test "replaces model-authored source URLs with Google grounding metadata" do
    markdown = """
    # The Asian Financial Crisis

    Answer body.

    ## Sources

    * [Globalization and Its Discontents](https://vertexaisearch.cloud.google.com/grounding-api-redirect/invented-token) - Model-authored description.

    ## Follow-up questions

    1. What happened next?
    """

    metadata = %{
      provider_meta: %{
        "google" => %{
          "sources" => [
            %{
              "title" => "Joseph E. Stiglitz | Britannica",
              "uri" =>
                "https://vertexaisearch.cloud.google.com/grounding-api-redirect/verified-token"
            }
          ],
          "grounding_metadata" => %{
            "groundingSupports" => [
              %{
                "groundingChunkIndices" => [0],
                "segment" => %{
                  "text" =>
                    "Stiglitz argued that the IMF's response worsened social and economic harm."
                }
              }
            ]
          }
        }
      }
    }

    sources = GroundedSources.merge_metadata([], metadata)
    result = GroundedSources.reconcile_markdown(markdown, sources)

    assert result =~
             "1. [Joseph E. Stiglitz | Britannica](<https://vertexaisearch.cloud.google.com/grounding-api-redirect/verified-token>)"

    assert result =~
             "Supports: “Stiglitz argued that the IMF's response worsened social and economic harm.”"

    refute result =~ "invented-token"
    refute result =~ "Web source"
    assert result =~ "## Follow-up questions"
  end

  test "deduplicates valid URLs and rejects malformed source records" do
    metadata = %{
      "provider_meta" => %{
        "google" => %{
          "sources" => [
            %{"title" => "First", "uri" => "https://example.com/research"},
            %{"title" => "Duplicate", "uri" => "https://example.com/research"},
            %{"title" => "Invalid", "uri" => "javascript:alert(1)"},
            %{"title" => "Missing URL"}
          ]
        }
      }
    }

    assert GroundedSources.merge_metadata([], metadata) == [
             %{
               title: "First",
               url: "https://example.com/research",
               grounding_indices: [0, 1],
               supports: []
             }
           ]
  end

  test "attaches support metadata that arrives after its source" do
    url = "https://vertexaisearch.cloud.google.com/grounding-api-redirect/source"

    sources =
      GroundedSources.merge_metadata([], %{
        provider_meta: %{"google" => %{"sources" => [%{"title" => "arxiv.org", "uri" => url}]}}
      })

    sources =
      GroundedSources.merge_metadata(sources, %{
        provider_meta: %{
          "google" => %{
            "grounding_metadata" => %{
              "groundingSupports" => [
                %{
                  "groundingChunkIndices" => [0],
                  "segment" => %{"text" => "The system is capable of universal computation."}
                }
              ]
            }
          }
        }
      })

    assert [%{supports: ["The system is capable of universal computation."]}] = sources
  end

  test "keeps global grounding indices across streamed source batches" do
    first =
      GroundedSources.merge_metadata([], %{
        provider_meta: %{
          "google" => %{
            "sources" => [%{"title" => "First", "uri" => "https://example.com/first"}]
          }
        }
      })

    sources =
      GroundedSources.merge_metadata(first, %{
        provider_meta: %{
          "google" => %{
            "sources" => [%{"title" => "Second", "uri" => "https://example.com/second"}],
            "grounding_metadata" => %{
              "groundingSupports" => [
                %{
                  "groundingChunkIndices" => [1],
                  "segment" => %{"text" => "This supports the second source."}
                }
              ]
            }
          }
        }
      })

    assert [first_source, second_source] = sources
    assert first_source.supports == []
    assert second_source.supports == ["This supports the second source."]
  end

  test "removes a source section when grounding returned no sources" do
    markdown = """
    # Answer

    Body.

    ## Sources

    * [Invented](https://example.invalid/invented)

    ## Next section

    More.
    """

    result = GroundedSources.reconcile_markdown(markdown, [])

    refute result =~ "## Sources"
    refute result =~ "example.invalid"
    assert result =~ "## Next section"
  end

  test "does not add a source section the model did not request" do
    markdown = "# Answer\n\nBody only."

    assert GroundedSources.reconcile_markdown(markdown, [
             %{title: "Unused", url: "https://example.com"}
           ]) == markdown
  end
end
