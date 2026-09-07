defmodule DialecticWeb.HomeCreationTest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  alias Dialectic.DbActions.Graphs
  alias Dialectic.Repo

  test "a separate exploration retains its owner, original question, and selected depth", %{
    conn: conn
  } do
    original_owner = user_fixture()
    learner = user_fixture()
    question = "A repeated question #{System.unique_integer([:positive])}"
    {:ok, original} = Graphs.create_new_graph(question, original_owner)
    {:ok, view, _html} = live(log_in_user(conn, learner), ~p"/")

    render_submit(view, "reply-and-answer", %{
      "vertex" => %{"content" => question},
      "mode" => "expert"
    })

    assert has_element?(view, "#existing-grid-choice")
    view |> element("#create-separate-grid") |> render_click()
    {path, _flash} = assert_redirect(view, 2_000)

    graph = graph_from_path(path)
    assert graph.title != original.title
    assert graph.slug != original.slug
    assert graph.user_id == learner.id
    assert graph.prompt_mode == "expert"
    assert GraphManager.find_node_by_id(graph.title, "1").content == "## " <> question
    assert GraphManager.find_node_by_id(graph.title, "2").response_level == "expert"
    assert Repo.reload!(original).data == original.data
  end

  test "a private matching question is never offered or opened for another visitor", %{conn: conn} do
    owner = user_fixture()
    question = "Private collision #{System.unique_integer([:positive])}"
    {:ok, original} = Graphs.create_new_graph(question, owner)
    original = original |> Ecto.Changeset.change(is_public: false) |> Repo.update!()

    {:ok, view, _html} = live(conn, ~p"/")
    render_submit(view, "reply-and-answer", %{"vertex" => %{"content" => question}})
    {path, _flash} = assert_redirect(view, 2_000)

    graph = graph_from_path(path)
    assert graph.title != original.title
    assert graph.is_public
    assert graph.user_id == nil
    refute Repo.reload!(original).is_public
    assert Repo.reload!(original).data == original.data
  end

  test "simultaneous creations of the same question produce distinct grids" do
    title = "Concurrent creation #{System.unique_integer([:positive])}"
    owner = user_fixture()

    graphs =
      1..4
      |> Task.async_stream(fn _ -> Graphs.create_unique_graph(title, owner, "expert") end,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, {:ok, graph}} -> graph end)

    assert length(Enum.uniq_by(graphs, & &1.title)) == 4
    assert length(Enum.uniq_by(graphs, & &1.slug)) == 4
    assert Enum.all?(graphs, &(&1.user_id == owner.id && &1.prompt_mode == "expert"))
  end

  defp graph_from_path(path) do
    slug = String.replace_prefix(path, "/g/", "")
    Graphs.get_graph_by_slug_or_title(slug)
  end
end
