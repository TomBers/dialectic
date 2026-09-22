defmodule Dialectic.Graph.SerialiseTest do
  use ExUnit.Case, async: true

  alias Dialectic.Graph.Serialise
  alias Dialectic.Graph.Vertex

  test "flat rendering preserves legacy groups and context through a save and reload" do
    nodes = [
      %Vertex{id: "Main", compound: true},
      %Vertex{id: "Other", compound: true, parent: "Main"},
      %Vertex{id: "1", content: "Original context", class: "origin", parent: "Main"},
      %Vertex{id: "2", content: "Other context", class: "origin", parent: "Other"},
      %Vertex{id: "3", content: "Answer", class: "answer", parent: "Main"}
    ]

    data = %{
      nodes: Enum.map(nodes, &Vertex.serialize/1),
      edges: [
        %{data: %{source: "1", target: "3"}},
        %{data: %{source: "2", target: "3"}}
      ]
    }

    graph = data |> Jason.encode!() |> Jason.decode!() |> Serialise.json_to_graph()
    {"3", answer} = :digraph.vertex(graph, "3")
    assert Vertex.build_context(answer, graph, 5_000) == "Original context"

    rendered = Vertex.to_cytoscape_format(graph)
    rendered_nodes = Enum.filter(rendered, &Map.has_key?(&1, :classes))
    assert length(rendered_nodes) == 3
    assert Enum.all?(rendered_nodes, &(not Map.has_key?(&1.data, :parent)))

    saved = Serialise.graph_to_json(graph)
    assert Enum.sort_by(saved.nodes, & &1.id) == Enum.sort_by(data.nodes, & &1.id)
    restored = saved |> Jason.encode!() |> Jason.decode!() |> Serialise.json_to_graph()
    {"3", restored_answer} = :digraph.vertex(restored, "3")
    assert Vertex.build_context(restored_answer, restored, 5_000) == "Original context"
    assert Enum.sort(:digraph.in_neighbours(restored, "3")) == ["1", "2"]

    :digraph.delete(graph)
    :digraph.delete(restored)
  end

  test "json_to_graph skips edges that would introduce cycles" do
    graph =
      Serialise.json_to_graph(%{
        "nodes" => [
          %{
            "id" => "1",
            "content" => "Root",
            "class" => "origin",
            "user" => nil,
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          },
          %{
            "id" => "2",
            "content" => "Middle",
            "class" => "answer",
            "user" => nil,
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          },
          %{
            "id" => "3",
            "content" => "Leaf",
            "class" => "answer",
            "user" => nil,
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          }
        ],
        "edges" => [
          %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}},
          %{"data" => %{"id" => "2_3", "source" => "2", "target" => "3"}},
          %{"data" => %{"id" => "3_2", "source" => "3", "target" => "2"}}
        ]
      })

    assert :digraph.get_cycle(graph, "2") == false
    assert :digraph.out_neighbours(graph, "3") == []
    assert :digraph.out_neighbours(graph, "2") == ["3"]
  end
end
