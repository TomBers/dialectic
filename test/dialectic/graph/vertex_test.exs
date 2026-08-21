defmodule Dialectic.Graph.VertexTest do
  use ExUnit.Case, async: true

  alias Dialectic.Graph.Vertex

  setup do
    {:ok, graph: :digraph.new()}
  end

  describe "prompt provenance serialization" do
    test "round-trips prompt provenance and remains compatible with older nodes" do
      vertex = %Vertex{
        id: "1",
        class: "answer",
        prompt_kind: "initial_explainer",
        response_level: "expert",
        grounding_metadata: %{
          "google" => %{"webSearchQueries" => ["grounded query"]}
        }
      }

      assert %Vertex{
               prompt_kind: "initial_explainer",
               response_level: "expert",
               grounding_metadata: %{
                 "google" => %{"webSearchQueries" => ["grounded query"]}
               }
             } =
               vertex |> Vertex.serialize() |> stringify_keys() |> Vertex.deserialize()

      legacy_data =
        vertex
        |> Vertex.serialize()
        |> Map.drop([:prompt_kind, :response_level, :grounding_metadata])
        |> stringify_keys()

      assert %Vertex{prompt_kind: nil, response_level: nil, grounding_metadata: nil} =
               Vertex.deserialize(legacy_data)

      in_memory_legacy_vertex = Map.delete(vertex, :response_level)
      assert Vertex.serialize(in_memory_legacy_vertex).response_level == nil
    end
  end

  test "round-trips structured learning-plan data" do
    guided_plan = %{
      version: 1,
      title: "Test topic",
      actions: [%{key: "clarify", reason: "Define the topic."}],
      paths: [
        %{
          id: "path-1",
          label: "Foundation",
          question: "What comes first?",
          reason: "It establishes context."
        }
      ]
    }

    vertex = %Vertex{
      id: "plan-1",
      class: "learning_plan",
      guided_plan: guided_plan,
      guided_submissions: ["action:clarify"]
    }

    serialized = Vertex.serialize(vertex)

    assert serialized.guided_plan == guided_plan
    assert serialized.guided_submissions == ["action:clarify"]

    deserialized = serialized |> Jason.encode!() |> Jason.decode!() |> Vertex.deserialize()
    assert deserialized.guided_plan["version"] == 1
    assert hd(deserialized.guided_plan["actions"])["key"] == "clarify"
    assert deserialized.guided_submissions == ["action:clarify"]
  end

  describe "to_cytoscape_format/1" do
    test "serializes active vertices and edges while excluding deleted graph elements", %{
      graph: graph
    } do
      parent = %Vertex{
        id: "parent",
        class: "origin",
        content: "Parent",
        compound: true
      }

      child = %Vertex{
        id: "child",
        class: "answer",
        content: "Child",
        parent: parent.id,
        prompt_kind: "selection_explain"
      }

      deleted = %Vertex{id: "deleted", class: "answer", content: "Deleted", deleted: true}

      :digraph.add_vertex(graph, parent.id, parent)
      :digraph.add_vertex(graph, child.id, child)
      :digraph.add_vertex(graph, deleted.id, deleted)
      :digraph.add_edge(graph, parent.id, child.id)
      :digraph.add_edge(graph, parent.id, deleted.id)

      elements = Vertex.to_cytoscape_format(graph)
      nodes = Enum.filter(elements, &Map.has_key?(&1, :classes))
      edges = Enum.reject(elements, &Map.has_key?(&1, :classes))

      assert Enum.sort_by(nodes, & &1.data.id) == [
               %{classes: "answer", data: %{content: "Child", id: "child", parent: "parent"}},
               %{
                 classes: "origin",
                 data: %{compound: true, content: "Parent", id: "parent", parent: nil}
               }
             ]

      assert edges == [
               %{
                 data: %{
                   id: "parent_child",
                   relation: "selection_explain",
                   source: "parent",
                   target: "child"
                 }
               }
             ]
    end

    test "falls back to the child class for legacy relation data", %{graph: graph} do
      parent = %Vertex{id: "parent", class: "origin", content: "Parent"}
      child = %Vertex{id: "child", class: "clarify", content: "Child"}

      :digraph.add_vertex(graph, parent.id, parent)
      :digraph.add_vertex(graph, child.id, child)
      :digraph.add_edge(graph, parent.id, child.id)

      assert [%{data: %{relation: "clarify"}}] =
               graph
               |> Vertex.to_cytoscape_format()
               |> Enum.reject(&Map.has_key?(&1, :classes))
    end
  end

  describe "build_context/3 question traversal" do
    test "keeps origin history through an omitted question", %{graph: graph} do
      origin = add_vertex(graph, "origin", "Initial framing", "origin")
      question = add_vertex(graph, "question", "What should be clarified?", "question")
      later_answer = add_vertex(graph, "later-answer", "Later answer", "answer")

      add_edges(graph, [
        {origin.id, question.id},
        {question.id, later_answer.id}
      ])

      context = Vertex.build_context(later_answer, graph, 5_000)

      assert context == origin.content
      refute context =~ question.content
    end

    test "keeps ordered origin and answer history through an omitted question", %{graph: graph} do
      origin = add_vertex(graph, "origin", "Initial framing", "origin")
      earlier_answer = add_vertex(graph, "earlier-answer", "Earlier answer", "answer")
      question = add_vertex(graph, "question", "What comes next?", "question")
      later_answer = add_vertex(graph, "later-answer", "Later answer", "answer")

      add_edges(graph, [
        {origin.id, earlier_answer.id},
        {earlier_answer.id, question.id},
        {question.id, later_answer.id}
      ])

      context = Vertex.build_context(later_answer, graph, 5_000)

      assert context == Enum.join([origin.content, earlier_answer.content], "\n\n")
      refute context =~ question.content
    end

    test "orders shortcut DAG ancestors before their descendants", %{graph: graph} do
      oldest = add_vertex(graph, "a", "Aaaa", "origin")
      middle = add_vertex(graph, "c", "Cccc", "answer")
      recent = add_vertex(graph, "d", "Dddd", "answer")
      target = add_vertex(graph, "t", "Target", "answer")

      add_edges(graph, [
        {oldest.id, middle.id},
        {middle.id, recent.id},
        {recent.id, target.id},
        {oldest.id, target.id}
      ])

      assert Vertex.build_context(target, graph, 5_000) == "Aaaa\n\nCccc\n\nDddd"
      assert Vertex.build_context(target, graph, 2) == "Cccc\n\nDddd"
    end

    test "sorts numeric vertex IDs numerically at every traversal depth", %{graph: graph} do
      two = add_vertex(graph, "2", "Second", "answer")
      ten = add_vertex(graph, "10", "Tenth", "answer")
      nested = add_vertex(graph, "20", "Nested", "answer")
      nested_target = add_vertex(graph, "30", "Nested target", "answer")
      direct_target = add_vertex(graph, "40", "Direct target", "answer")

      add_edges(graph, [
        {ten.id, nested.id},
        {two.id, nested.id},
        {nested.id, nested_target.id},
        {ten.id, direct_target.id},
        {two.id, direct_target.id}
      ])

      assert Vertex.build_context(nested_target, graph, 5_000) ==
               "Second\n\nTenth\n\nNested"

      assert Vertex.build_context(direct_target, graph, 5_000) == "Second\n\nTenth"
    end

    test "deduplicates shared history reached through a question", %{graph: graph} do
      origin = add_vertex(graph, "origin", "Shared framing", "origin")
      first_answer = add_vertex(graph, "first-answer", "First answer", "answer")
      second_answer = add_vertex(graph, "second-answer", "Second answer", "answer")
      question = add_vertex(graph, "question", "Compare these answers?", "question")
      later_answer = add_vertex(graph, "later-answer", "Later answer", "answer")

      add_edges(graph, [
        {origin.id, first_answer.id},
        {origin.id, second_answer.id},
        {first_answer.id, question.id},
        {second_answer.id, question.id},
        {question.id, later_answer.id}
      ])

      context_items =
        later_answer
        |> Vertex.build_context(graph, 5_000)
        |> String.split("\n\n")

      assert List.first(context_items) == origin.content
      assert Enum.count(context_items, &(&1 == origin.content)) == 1

      assert Enum.sort(context_items) ==
               Enum.sort([origin.content, first_answer.content, second_answer.content])

      refute question.content in context_items
    end
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp add_vertex(graph, id, content, class) do
    vertex = %Vertex{id: id, content: content, class: class}
    :digraph.add_vertex(graph, id, vertex)
    vertex
  end

  defp add_edges(graph, edges) do
    Enum.each(edges, fn {parent_id, child_id} ->
      :digraph.add_edge(graph, parent_id, child_id)
    end)
  end
end
