defmodule Dialectic.SearchTest do
  use Dialectic.DataCase, async: true

  alias Dialectic.GraphFixtures
  alias Dialectic.Search

  test "searches public node content and source text" do
    term = "quasar#{System.unique_integer([:positive])}"

    graph =
      GraphFixtures.insert_graph(%{
        title: "A different grid title #{term |> String.length()}",
        slug: "global-content-search-#{System.unique_integer([:positive])}",
        data: graph_data(term)
      })

    [result] = Search.search_public(term)

    assert result.graph.title == graph.title
    assert Enum.map(result.matches, &(Map.get(&1, :id) || Map.get(&1, "id"))) == ["2", "3"]
    assert Enum.any?(result.matches, &(Map.get(&1, :search_preview_label) == "Content"))
    assert Enum.any?(result.matches, &(Map.get(&1, :search_preview_label) == "Source"))
  end

  test "searches grid titles and topics" do
    term = "heliotrope#{System.unique_integer([:positive])}"

    title_graph =
      GraphFixtures.insert_graph(%{
        title: "#{term} and public reasoning",
        slug: "global-title-search-#{System.unique_integer([:positive])}"
      })

    topic_graph =
      GraphFixtures.insert_graph(%{
        title: "A separate question #{System.unique_integer([:positive])}",
        slug: "global-topic-search-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.change(%{tags: [term]})
      |> Dialectic.Repo.update!()

    results = Search.search_public(term)

    assert Enum.any?(
             results,
             &(&1.graph.title == title_graph.title and &1.match_reason == :title)
           )

    assert Enum.any?(
             results,
             &(&1.graph.title == topic_graph.title and &1.match_reason == :topic)
           )
  end

  test "does not expose private, unpublished, deleted grids or deleted nodes" do
    term = "private-search-#{System.unique_integer([:positive])}"

    for {suffix, attrs} <- [
          {"private", %{is_public: false}},
          {"unpublished", %{is_published: false}},
          {"deleted", %{is_deleted: true}}
        ] do
      GraphFixtures.insert_graph(
        Map.merge(attrs, %{
          title: "Hidden #{suffix} #{System.unique_integer([:positive])}",
          slug: "global-hidden-#{suffix}-#{System.unique_integer([:positive])}",
          data: graph_data(term)
        })
      )
    end

    GraphFixtures.insert_graph(%{
      title: "Visible grid with deleted result #{System.unique_integer([:positive])}",
      slug: "global-deleted-node-#{System.unique_integer([:positive])}",
      data: graph_data(term, deleted: true)
    })

    assert Search.search_public(term) == []
  end

  test "requires at least three characters" do
    assert Search.search_public("ai") == []
  end

  defp graph_data(term, opts \\ []) do
    deleted = Keyword.get(opts, :deleted, false)

    %{
      "nodes" => [
        node("1", "## Opening question"),
        node(
          "2",
          "# A matching explanation\n\nThe #{term} appears in the detailed answer.",
          deleted
        ),
        node("3", "## A source-led question", deleted, "A source passage about #{term}")
      ],
      "edges" => []
    }
  end

  defp node(id, content, deleted \\ false, source_text \\ nil) do
    %{
      "id" => id,
      "content" => content,
      "source_text" => source_text,
      "class" => "answer",
      "user" => "",
      "parent" => nil,
      "noted_by" => [],
      "deleted" => deleted,
      "compound" => false
    }
  end
end
