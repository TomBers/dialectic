defmodule Dialectic.Responses.GuidedLearningTargetTest do
  use ExUnit.Case, async: true
  alias Dialectic.Responses.GuidedLearningTarget

  defp nodes do
    %{
      "answer" => %{
        id: "answer",
        class: "answer",
        content: "# Evidence\nA study measured practice performance.",
        parents: []
      },
      "question" => %{
        id: "question",
        class: "question",
        content: "Make a learning plan.",
        parents: [%{id: "answer"}]
      },
      "plan" => %{
        id: "plan",
        class: "learning_plan",
        content: "Previous plan",
        parents: [%{id: "question"}]
      }
    }
  end

  test "targets the substantive answer through request and plan wrappers" do
    nodes = nodes()
    target = GuidedLearningTarget.select(nodes["plan"], &nodes[&1])
    assert target.node_id == "answer"
    assert target.title == "Evidence"
    assert target.content == nodes["answer"].content
    assert {:ok, _} = GuidedLearningTarget.resolve(target, &nodes[&1])
  end

  test "preserves the exact selected passage through serialization" do
    nodes = nodes()
    question = Map.put(nodes["question"], :source_text, "practice performance")

    target =
      GuidedLearningTarget.select(question, &nodes[&1]) |> Jason.encode!() |> Jason.decode!()

    assert {:ok, resolved} = GuidedLearningTarget.resolve(target, &nodes[&1])
    assert resolved.id == "answer"
    assert resolved.content == "practice performance"
  end

  test "an answer's generation context is not mistaken for a new selected passage" do
    answer = Map.put(nodes()["answer"], :source_text, "An earlier claim this answer examined")
    target = GuidedLearningTarget.select(answer, fn _ -> nil end)
    assert target.content == answer.content
    assert target.title == "Evidence"
  end

  test "edited, removed, deleted and foreign targets do not silently retarget" do
    nodes = nodes()
    target = GuidedLearningTarget.select(nodes["question"], &nodes[&1])

    for replacement <- [
          nil,
          %{nodes["answer"] | content: "Changed answer"},
          Map.put(nodes["answer"], :deleted, true)
        ] do
      assert {:error, :target_changed} =
               GuidedLearningTarget.resolve(target, fn _id -> replacement end)
    end
  end

  test "topic-only plans and cycles terminate with their original topic" do
    question = %{id: "q", class: "question", content: "What is knowledge?", parents: [%{id: "q"}]}
    target = GuidedLearningTarget.select(question, fn _id -> question end)
    assert target.node_id == "q"
    assert target.content == question.content
  end
end
