defmodule DialecticWeb.ReaderContributionsTest do
  use DialecticWeb.ConnCase, async: false
  use Oban.Testing, repo: Dialectic.Repo

  import Dialectic.AccountsFixtures
  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Graph.GraphActions

  setup do
    graph =
      insert_graph(%{
        title: "Mobile inquiry #{System.unique_integer([:positive])}",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Does AI help us think?",
              "class" => "origin",
              "deleted" => false,
              "compound" => false,
              "noted_by" => [],
              "user" => "anonymous"
            },
            %{
              "id" => "2",
              "content" => "Better output can differ from learning.",
              "class" => "answer",
              "deleted" => false,
              "compound" => false,
              "noted_by" => [],
              "user" => "anonymous"
            },
            %{
              "id" => "3",
              "content" => "How could we measure learning?",
              "class" => "question",
              "deleted" => false,
              "compound" => false,
              "noted_by" => [],
              "user" => "anonymous"
            }
          ],
          "edges" => [
            %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}},
            %{"data" => %{"id" => "2_3", "source" => "2", "target" => "3"}}
          ]
        }
      })

    %{graph: graph}
  end

  test "one challenge action opens the shared question interface from the reader", %{
    conn: conn,
    graph: graph
  } do
    {:ok, reader, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    refute has_element?(reader, "#reader-add-thought")
    refute has_element?(reader, "#reader-contribute-2")
    refute has_element?(reader, "#outline-reading-node-1-ask")
    assert has_element?(reader, "#outline-reading-node-2-ask", "Challenge this answer")

    {:ok, inquiry, _} =
      reader |> element("#outline-reading-node-2-ask") |> render_click() |> follow_redirect(conn)

    assert has_element?(inquiry, "#graph-layout[data-mobile-inquiry='true']")
    assert has_element?(inquiry, "#global-chat-form-comment")
    assert has_element?(inquiry, "#global-chat-form-ask")
    assert has_element?(inquiry, "#mobile-inquiry-reader-link[href='/g/#{graph.slug}?node=2']")
    assert has_element?(inquiry, "#node-suggestions-2")
    assert has_element?(inquiry, "#mobile-inquiry-settings")

    inquiry |> element("#global-chat-form [id^='node-tools-more-']") |> render_click()
    assert has_element?(inquiry, "#node-tools-popover-2 button[phx-click='node_counterexample']")
  end

  test "a guest comments without generating an AI answer and can return to the saved comment", %{
    conn: conn,
    graph: graph
  } do
    {:ok, reader, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    {:ok, inquiry, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2&focus=ask")
    before_ids = GraphManager.vertices(graph.title)
    content = "Could I explain it again a week later?"

    inquiry
    |> form("#global-chat-form", vertex: %{content: content})
    |> render_submit(%{"submit_action" => "post"})

    [comment] = new_nodes(graph, before_ids)
    assert comment.class == "user"
    assert comment.content == content
    assert comment.user == "anonymous"
    assert Enum.map(GraphActions.find_node(graph.title, comment.id).parents, & &1.id) == ["2"]

    assert has_element?(
             inquiry,
             "#mobile-inquiry-reader-link[href='/g/#{graph.slug}?node=#{comment.id}']"
           )

    assert has_element?(reader, "#outline-node-#{comment.id}")

    Oban.drain_queue(queue: :db_write)
    saved = Dialectic.DbActions.Graphs.get_graph_by_title(graph.title)
    assert Enum.any?(saved.data["nodes"], &(&1["id"] == comment.id && &1["content"] == content))
  end

  test "Ask creates a contextual question and queues the existing AI response flow", %{
    conn: conn,
    graph: graph
  } do
    {:ok, inquiry, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2&focus=ask")
    before_ids = GraphManager.vertices(graph.title)

    inquiry
    |> form("#global-chat-form", vertex: %{content: "How can we test retention?"})
    |> render_submit()

    created = new_nodes(graph, before_ids)
    question = Enum.find(created, &(&1.class == "question"))
    answer = Enum.find(created, &(&1.class == "answer"))
    assert question.content == "How can we test retention?"
    assert Enum.map(GraphActions.find_node(graph.title, question.id).parents, & &1.id) == ["2"]

    assert Enum.map(GraphActions.find_node(graph.title, answer.id).parents, & &1.id) == [
             question.id
           ]

    assert_enqueued(
      worker: Dialectic.Workers.LocalWorker,
      args: %{graph: graph.title, to_node: answer.id}
    )

    assert has_element?(inquiry, "#generation-status-#{answer.id}")
  end

  test "finished AI responses refresh other attendees' readers", %{conn: conn, graph: graph} do
    {:ok, inquiry, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2&focus=ask")
    before_ids = GraphManager.vertices(graph.title)
    inquiry |> form("#global-chat-form", vertex: %{content: "Test retention"}) |> render_submit()
    answer = Enum.find(new_nodes(graph, before_ids), &(&1.class == "answer"))
    {:ok, reader, _} = live(conn, ~p"/g/#{graph.slug}?node=#{answer.id}")

    GraphManager.set_node_content(
      graph.title,
      answer.id,
      "## Retention test\nExplain it without assistance."
    )

    send(inquiry.pid, {:llm_request_complete, answer.id})
    render(inquiry)
    assert has_element?(reader, "#reading-node-#{answer.id} h2", "Retention test")
  end

  test "learning plans retain the existing account requirement", %{conn: conn, graph: graph} do
    {:ok, guest, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2&focus=ask")
    assert has_element?(guest, "#global-chat-form-guided-learning-signup")
    before_ids = GraphManager.vertices(graph.title)

    render_submit(guest, "reply-and-answer", %{
      "vertex" => %{"content" => "Plan my learning"},
      "guided_learning" => "true"
    })

    assert has_element?(guest, "#login-modal")
    assert new_nodes(graph, before_ids) == []

    user = user_fixture()

    {:ok, signed_in, _} =
      live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2&focus=ask")

    assert has_element?(signed_in, "#global-chat-form-guided-learning")
  end

  test "Connect uses search to select a second idea on mobile", %{conn: conn, graph: graph} do
    {:ok, inquiry, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2&focus=ask")
    inquiry |> element("#node-suggestions-2 button[phx-click*='node_combine']") |> render_click()
    inquiry |> element("#mobile-combine-search") |> render_click()
    assert has_element?(inquiry, "#quick-search-panel")
    render_click(inquiry, "node_clicked", %{"id" => "3", "from_search" => "true"})

    assert has_element?(
             inquiry,
             "#combine-setup button[phx-click*='execute_combine']:not([disabled])"
           )
  end

  test "root comments remain blocked in the shared interface", %{conn: conn, graph: graph} do
    {:ok, inquiry, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=1&focus=ask")
    before_ids = GraphManager.vertices(graph.title)

    render_submit(inquiry, "reply-and-answer", %{
      "vertex" => %{"content" => "Blocked"},
      "submit_action" => "post"
    })

    render_submit(inquiry, "answer", %{"vertex" => %{"content" => "Blocked"}})
    assert new_nodes(graph, before_ids) == []
    assert has_element?(inquiry, "#flash-error", "Choose a response")
  end

  test "a target changed to a root cannot receive comments", %{conn: conn, graph: graph} do
    {:ok, inquiry, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2&focus=ask")
    GraphManager.update_vertex_fields(graph.title, "2", %{class: "origin"})
    before_ids = GraphManager.vertices(graph.title)

    inquiry
    |> form("#global-chat-form", vertex: %{content: "Blocked"})
    |> render_submit(%{"submit_action" => "post"})

    assert new_nodes(graph, before_ids) == []
  end

  test "locked grids block both comment and ask submissions", %{conn: conn, graph: graph} do
    graph |> Ecto.Changeset.change(is_locked: true) |> Dialectic.Repo.update!()
    {:ok, inquiry, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2&focus=ask")
    assert has_element?(inquiry, "#global-chat-form-comment[disabled]")
    assert has_element?(inquiry, "#global-chat-form-ask[disabled]")
    before_ids = GraphManager.vertices(graph.title)

    for action <- ["post", "ask"] do
      render_submit(inquiry, "reply-and-answer", %{
        "vertex" => %{"content" => "Blocked"},
        "submit_action" => action
      })
    end

    assert new_nodes(graph, before_ids) == []
  end

  test "the mobile entry and return links retain private grid access", %{conn: conn, graph: graph} do
    graph =
      graph
      |> Ecto.Changeset.change(is_public: false, share_token: "mobile-token")
      |> Dialectic.Repo.update!()

    {:ok, reader, _} = live(conn, ~p"/g/#{graph.slug}?node=2&token=mobile-token")
    assert has_element?(reader, "#outline-reading-node-2-ask[href*='token=mobile-token']")
    {:ok, inquiry, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2&focus=ask&token=mobile-token")
    assert has_element?(inquiry, "#mobile-inquiry-reader-link[href*='token=mobile-token']")
  end

  defp new_nodes(graph, before_ids) do
    (GraphManager.vertices(graph.title) -- before_ids)
    |> Enum.map(&GraphManager.vertex_label(graph.title, &1))
  end
end
