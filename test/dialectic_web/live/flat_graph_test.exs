defmodule DialecticWeb.FlatGraphTest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.GraphFixtures

  alias Dialectic.Graph.Vertex
  alias Dialectic.Repo

  test "opening an ungrouped grid does not create or persist a Main group", %{conn: conn} do
    graph = insert_graph(%{title: "Flat grid #{System.unique_integer([:positive])}"})
    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/graph?node=1")

    assert has_element?(view, "#graph-title", graph.title)
    assert has_element?(view, "#cy[data-node='1']")
    refute has_element?(view, "[phx-click='open_start_stream_modal']")
    refute has_element?(view, "[phx-click='focus_stream']")
    refute has_element?(view, "[phx-click='toggle_stream']")
    refute has_element?(view, "#start-stream-modal")
    refute "Main" in GraphManager.vertices(graph.title)
    assert Repo.reload!(graph).data == graph.data
  end

  test "legacy grouped nodes retain links, connections, saved membership and AI context", %{
    conn: conn
  } do
    nodes = [
      %Vertex{id: "Main", compound: true},
      %Vertex{id: "Subgroup", compound: true, parent: "Main"},
      %Vertex{id: "1", content: "Saved question", class: "origin", parent: "Subgroup"},
      %Vertex{id: "2", content: "Saved answer", class: "answer", parent: "Subgroup"}
    ]

    data = %{
      nodes: Enum.map(nodes, &Vertex.serialize/1),
      edges: [%{data: %{id: "1_2", source: "1", target: "2"}}]
    }

    graph =
      insert_graph(%{
        title: "Legacy grouped grid #{System.unique_integer([:positive])}",
        data: data |> Jason.encode!() |> Jason.decode!()
      })

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/graph?node=2")
    assert has_element?(view, "#cy[data-node='2']")

    elements = graph.title |> GraphManager.format_graph_json() |> Jason.decode!()
    ideas = Enum.filter(elements, &Map.has_key?(&1, "classes"))
    assert Enum.sort(Enum.map(ideas, & &1["data"]["id"])) == ["1", "2"]
    assert Enum.all?(ideas, &(not Map.has_key?(&1["data"], "parent")))
    assert [%{"data" => %{"source" => "1", "target" => "2"}}] = elements -- ideas

    answer = GraphManager.find_node_by_id(graph.title, "2")
    assert answer.parent == "Subgroup"
    assert GraphManager.build_context(graph.title, answer) == "Saved question"
    GraphManager.save_graph(graph.title)
    saved_nodes = Repo.reload!(graph).data["nodes"]
    assert Enum.find(saved_nodes, &(&1["id"] == "Subgroup"))["compound"]
    assert Enum.find(saved_nodes, &(&1["id"] == "2"))["parent"] == "Subgroup"

    {:ok, legacy_link_view, _html} = live(conn, ~p"/g/#{graph.slug}/graph?node=Subgroup")
    assert has_element?(legacy_link_view, "#cy[data-node='1']")
  end

  test "opening an empty grid does not add placeholder groups or ideas", %{conn: conn} do
    graph =
      insert_graph(%{
        title: "Empty grid #{System.unique_integer([:positive])}",
        data: %{"nodes" => [], "edges" => []}
      })

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/graph")
    assert has_element?(view, "#graph-title", graph.title)
    assert GraphManager.vertices(graph.title) == []
    assert Repo.reload!(graph).data == graph.data
  end
end
