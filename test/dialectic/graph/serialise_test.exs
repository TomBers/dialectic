defmodule Dialectic.Graph.SerialiseTest do
  use ExUnit.Case, async: true

  alias Dialectic.Graph.Serialise

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
