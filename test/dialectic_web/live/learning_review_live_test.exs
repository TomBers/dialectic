defmodule DialecticWeb.LearningReviewLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  alias Dialectic.Accounts
  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Notes

  setup do
    user = user_fixture()
    username = "learner#{System.unique_integer([:positive])}"
    {:ok, user} = Accounts.update_user_profile(user, %{username: username})
    %{user: user, path: ~p"/u/#{username}"}
  end

  defp saved_idea(user) do
    suffix = System.unique_integer([:positive])

    graph =
      Dialectic.Repo.insert!(%Graph{
        title: "Practice grid #{suffix}",
        slug: "practice-grid-#{suffix}",
        user_id: user.id,
        is_public: false,
        is_published: true,
        is_deleted: false,
        data: %{
          "nodes" => [%{"id" => "idea", "content" => "# A useful idea\nThe source explanation."}]
        }
      })

    {:ok, _} = Notes.add_note(graph.title, "idea", user)
    graph
  end

  test "guides new learners to save their first idea", %{conn: conn, user: user, path: path} do
    {:ok, view, _} = live(log_in_user(conn, user), path)
    assert has_element?(view, "#learning-review-empty")
    assert has_element?(view, "#learning-review-explore[href='/community']")
    refute has_element?(view, "#learning-review-start")
  end

  test "keeps the review private, including when events are forged", %{
    conn: conn,
    user: user,
    path: path
  } do
    saved_idea(user)
    {:ok, view, _} = live(conn, path)
    refute has_element?(view, "#learning-review")

    render_submit(view, "start_learning_review", %{
      "learning_review" => %{"reason" => "tutor_request"}
    })

    render_submit(view, "reveal_learning_review", %{"practice" => %{"answer" => "Forged answer"}})
    render_click(view, "rate_learning_review", %{"rating" => "understood"})
    render_click(view, "next_learning_review")
    refute has_element?(view, "#learning-review")
    refute_push_event(view, "analytics", %{})
  end

  test "requires an explanation, reveals its source and completes a self-check", %{
    conn: conn,
    user: user,
    path: path
  } do
    graph = saved_idea(user)
    {:ok, view, _} = live(log_in_user(conn, user), path)
    assert has_element?(view, "#learning-review-continue[href='/g/#{graph.slug}?node=idea']")

    view
    |> form("#learning-review-start-form", learning_review: %{reason: "independent_practice"})
    |> render_submit()

    assert_push_event(view, "analytics", %{
      event: "learning_review_started",
      params: %{reason: "independent_practice", item_count: 1}
    })

    refute has_element?(view, "#learning-review-source")

    render_click(view, "rate_learning_review", %{"rating" => "understood"})
    render_click(view, "next_learning_review")
    refute has_element?(view, "#learning-review-complete")

    view |> form("#learning-review-answer-form", practice: %{answer: " "}) |> render_submit()
    refute has_element?(view, "#learning-review-source")

    view
    |> form("#learning-review-answer-form", practice: %{answer: String.duplicate("a", 2001)})
    |> render_submit()

    refute has_element?(view, "#learning-review-source")

    view
    |> form("#learning-review-answer-form", practice: %{answer: "My private explanation"})
    |> render_submit()

    assert has_element?(view, "#learning-review-source", "The source explanation.")
    assert has_element?(view, "#learning-review-source-link[href='/g/#{graph.slug}?node=idea']")

    assert_push_event(view, "analytics", %{
      event: "learning_source_compared",
      params: %{reason: "independent_practice"}
    })

    view |> element("#learning-review-revisit") |> render_click()

    assert_push_event(view, "analytics", %{
      event: "learning_idea_reviewed",
      params: %{reason: "independent_practice", self_check: "revisit"}
    })

    render_click(view, "rate_learning_review", %{"rating" => "understood"})
    view |> element("#learning-review-next") |> render_click()
    assert has_element?(view, "#learning-review-complete")

    assert_push_event(view, "analytics", %{
      event: "learning_review_completed",
      params: %{reason: "independent_practice", understood: 0, revisit: 1}
    })

    {:ok, reloaded, _} = live(log_in_user(build_conn(), user), path)
    assert has_element?(reloaded, "#learning-review-start")
    refute has_element?(reloaded, "#learning-review-source")
  end
end
