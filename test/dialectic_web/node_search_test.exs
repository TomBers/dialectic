defmodule DialecticWeb.NodeSearchTest do
  use ExUnit.Case, async: true

  alias DialecticWeb.NodeSearch

  test "matches words in any order and across titles, content and sources" do
    node = %{
      id: "1",
      content: "# Desire\n\nSocial production shapes experience.",
      source_text: "Guattari describes machines."
    }

    assert NodeSearch.annotate_result(node, "production desire")
    assert NodeSearch.annotate_result(node, "Guattari desire")
    refute NodeSearch.annotate_result(node, "desire astronomy")
    assert NodeSearch.annotate_result(node, "What is social production?")
  end

  test "ranks title and phrase matches ahead of scattered keywords" do
    exact = NodeSearch.annotate_result(%{content: "# Social production"}, "social production")

    body =
      NodeSearch.annotate_result(
        %{content: "# Desire\nSocial production matters."},
        "social production"
      )

    scattered =
      NodeSearch.annotate_result(
        %{content: "# Production and the social world"},
        "social production"
      )

    assert exact.search_rank < body.search_rank
    assert body.search_rank < scattered.search_rank
  end

  test "ignores accents and keeps original spelling in a matching preview" do
    node = %{
      content:
        "# Reading\n" <> String.duplicate("Context. ", 30) <> "Désir and Guattari appear here."
    }

    result = NodeSearch.annotate_result(node, "DESIR")
    assert result.search_preview_label == "Content"
    assert result.search_preview =~ "Désir"
    assert String.starts_with?(result.search_preview, "…")
  end

  test "previews the relevant keyword when query words are reordered" do
    node = %{
      content:
        "# Reading\n" <>
          String.duplicate("Context. ", 30) <> "Production shapes the social world."
    }

    result = NodeSearch.annotate_result(node, "social production")
    assert result.search_preview =~ "Production"
    assert String.length(result.search_preview) <= 152
  end

  test "short terms do not match inside unrelated words" do
    refute NodeSearch.annotate_result(%{content: "# Railway"}, "AI")
    assert NodeSearch.annotate_result(%{content: "# AI systems"}, "AI")
    refute NodeSearch.annotate_result(%{content: "# Any topic"}, "  ")
  end

  test "short terms keep word boundaries inside multiword queries" do
    refute NodeSearch.annotate_result(%{content: "# Thai systems"}, "AI systems")

    refute NodeSearch.annotate_result(
             %{content: "# Planning\nThai systems are useful."},
             "AI systems"
           )

    assert NodeSearch.annotate_result(%{content: "# AI systems"}, "AI systems")
    assert NodeSearch.annotate_result(%{content: "# Systems using AI"}, "AI systems")
  end

  test "long literal queries produce bounded previews" do
    query = String.duplicate("word ", 100) |> String.trim()
    result = NodeSearch.annotate_result(%{content: "# " <> query}, query)
    assert String.length(result.search_preview) <= 152
  end
end
