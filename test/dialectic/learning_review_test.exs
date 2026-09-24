defmodule Dialectic.LearningReviewTest do
  use ExUnit.Case, async: true

  alias Dialectic.Accounts.Graph
  alias Dialectic.LearningReview

  defp note(id, overrides \\ %{}) do
    Map.merge(
      %{
        is_noted: true,
        node_id: id,
        updated_at: ~U[2026-09-24 12:00:00Z],
        graph: %Graph{
          title: "Study grid",
          slug: "study-grid",
          user_id: 1,
          is_public: false,
          data: %{"nodes" => [%{"id" => id, "content" => "# Idea #{id}\nAn explanation."}]}
        }
      },
      overrides
    )
  end

  test "uses at most three recent distinct ideas across bookmarks and highlights" do
    saved = note("1")

    highlight = %{
      mudg: saved.graph,
      node_id: "1",
      selected_text_snapshot: "The specific passage I saved.",
      updated_at: ~U[2026-09-24 13:00:00Z]
    }

    review = LearningReview.build(Enum.map(1..5, &note(to_string(&1))), [highlight], %{id: 1})

    assert LearningReview.count(review) == 3
    assert LearningReview.current(review).passage == highlight.selected_text_snapshot
    assert review.items |> Tuple.to_list() |> Enum.count(&(&1.node_id == "1")) == 1
  end

  test "omits unavailable sources and other people's private grids" do
    saved = note("1")

    invalid = [
      %{saved | graph: %{saved.graph | is_deleted: true}},
      %{saved | graph: %{saved.graph | user_id: 2}},
      %{saved | graph: %{saved.graph | slug: nil}},
      %{saved | node_id: "missing"},
      %{saved | is_noted: false},
      %{saved | graph: %{saved.graph | data: %{"nodes" => [%{"id" => "1", "content" => " "}]}}},
      %{
        saved
        | graph: %{
            saved.graph
            | data: %{"nodes" => [%{"id" => "1", "content" => "Deleted", "deleted" => true}]}
          }
      }
    ]

    assert LearningReview.count(LearningReview.build(invalid, [], %{id: 1})) == 0

    public = %{saved | graph: %{saved.graph | user_id: 2, is_public: true}}
    assert LearningReview.count(LearningReview.build([public], [], %{id: 1})) == 1
  end

  test "supports wrapped node data and bounds source length" do
    saved = note("1")
    node = %{"id" => "1", "content" => String.duplicate("a", 6500)}
    graph = %{saved.graph | data: %{"nodes" => [%{"data" => node}]}}

    card =
      LearningReview.build([%{saved | graph: graph}], [], %{id: 1}) |> LearningReview.current()

    assert String.length(card.passage) == 6000
    assert card.truncated?
  end

  test "requires reveal before rating and counts each idea once" do
    review = LearningReview.build([note("1"), note("2")], [], %{id: 1})
    assert {:error, :invalid} = LearningReview.start(review, "anything")
    assert {:ok, started} = LearningReview.start(review, "independent_practice")
    assert LearningReview.next(started) == started
    assert LearningReview.rate(started, "understood") == started

    rated = started |> LearningReview.reveal() |> LearningReview.rate("understood")
    assert LearningReview.rate(rated, "understood") == rated
    next = LearningReview.next(rated)
    refute next.revealed?
    assert next.index == 1

    complete =
      next |> LearningReview.reveal() |> LearningReview.rate("revisit") |> LearningReview.next()

    assert complete.status == :complete
    assert complete.understood == 1
    assert complete.revisit == 1
    assert LearningReview.current(complete) == nil
    assert LearningReview.next(complete) == complete
  end
end
