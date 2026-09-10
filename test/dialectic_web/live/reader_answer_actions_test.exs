defmodule DialecticWeb.ReaderAnswerActionsTest do
  use DialecticWeb.ConnCase, async: false
  use Oban.Testing, repo: Dialectic.Repo

  import Dialectic.AccountsFixtures
  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Graph.GraphActions

  setup do
    nodes =
      for {id, class, content} <- [
            {"1", "origin", "Can we learn better?"},
            {"2", "answer", "## Practice\nExplain it in your own words."},
            {"3", "answer", "## Recall\nTry again tomorrow."}
          ] do
        %{
          "id" => id,
          "class" => class,
          "content" => content,
          "user" => "anonymous",
          "deleted" => false,
          "compound" => false,
          "noted_by" => []
        }
      end

    graph =
      insert_graph(%{
        title: "Reader answer #{System.unique_integer([:positive])}",
        data: %{
          "nodes" => nodes,
          "edges" => [
            %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}},
            %{"data" => %{"id" => "2_3", "source" => "2", "target" => "3"}}
          ]
        }
      })

    %{graph: graph, user: user_fixture()}
  end

  test "a guest posts to the chosen answer, independently of the current reader node", %{
    conn: conn,
    graph: graph
  } do
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=3")
    {:ok, other_reader, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit(view, %{"action" => "comment", "input" => "  My own thinking  "})
    assert_push_event(view, "selection:result", %{request_id: "answer-test", status: "ok"})
    [comment] = created(graph, before_ids)
    assert comment.class == "user"
    assert comment.content == "My own thinking"
    assert comment.source_text == nil
    assert comment.user == "anonymous"
    assert Enum.map(comment.parents, & &1.id) == ["2"]
    assert_patch(view, ~p"/g/#{graph.slug}?node=#{comment.id}")
    assert has_element?(view, "#reading-node-#{comment.id}")
    assert has_element?(other_reader, "#outline-node-#{comment.id}")
    refute has_element?(view, "#reader-view-new-thoughts")
    assert Dialectic.Highlights.list_highlights_with_links(mudg_id: graph.title) == []
    refute_enqueued(worker: Dialectic.Workers.LocalWorker, args: %{graph: graph.title})
  end

  test "asking uses the whole answer and displays completion in the reader", %{
    conn: conn,
    graph: graph
  } do
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit(view, %{"action" => "ask_question", "input" => "How can I test this?"})
    assert_push_event(view, "selection:result", %{status: "ok"})
    nodes = created(graph, before_ids)
    question = Enum.find(nodes, &(&1.class == "question"))
    answer = Enum.find(nodes, &(&1.class == "answer"))
    assert question.content == "How can I test this?"
    assert Enum.map(question.parents, & &1.id) == ["2"]
    assert Enum.map(answer.parents, & &1.id) == [question.id]
    assert Enum.all?(nodes, &is_nil(&1.source_text))
    assert Dialectic.Highlights.list_highlights_with_links(mudg_id: graph.title) == []
    assert_patch(view, ~p"/g/#{graph.slug}?node=#{answer.id}")
    assert has_element?(view, "#reader-generation-#{answer.id}[role='status']")
    refute has_element?(view, "#reader-view-new-thoughts")

    assert has_element?(
             view,
             "#reader-generation-status-#{answer.id}[phx-hook='GenerationStatus']"
           )

    assert_enqueued(
      worker: Dialectic.Workers.LocalWorker,
      args: %{
        graph: graph.title,
        to_node: answer.id,
        live_view_topic: "graph_update:#{graph.title}"
      }
    )

    GraphManager.set_node_content(
      graph.title,
      answer.id,
      "## Starting to write\nA partial response"
    )

    send(view.pid, {:other_user_change, self()})
    assert has_element?(view, "#reader-generation-status-#{answer.id}")
    refute has_element?(view, "#outline-markdown-body-#{answer.id}")

    {:ok, reloaded, _} = live(conn, ~p"/g/#{graph.slug}?node=#{answer.id}")
    assert has_element?(reloaded, "#reader-generation-status-#{answer.id}")

    GraphManager.set_node_content(graph.title, answer.id, "## A test\nTry recalling it tomorrow.")

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      "graph_update:#{graph.title}",
      {:llm_request_complete, answer.id}
    )

    assert has_element?(view, "#reading-node-#{answer.id} h2", "A test")
    refute has_element?(view, "#reader-generation-#{answer.id}")
    refute has_element?(view, "#reader-generation-status-#{answer.id}")
    refute has_element?(reloaded, "#reader-generation-status-#{answer.id}")
    assert has_element?(reloaded, "#outline-markdown-body-#{answer.id}")
  end

  test "branch cards show progress while both sides are being generated", %{
    conn: conn,
    graph: graph
  } do
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit(view, %{"action" => "pros_cons"})
    nodes = created(graph, before_ids)

    for node <- nodes do
      assert has_element?(view, "#next-choice-#{node.id}-loading[role='status']")

      GraphManager.set_node_content(
        graph.title,
        node.id,
        "## A perspective\nA completed response."
      )

      Phoenix.PubSub.broadcast(
        Dialectic.PubSub,
        "graph_update:#{graph.title}",
        {:llm_request_complete, node.id}
      )

      refute has_element?(view, "#next-choice-#{node.id}-loading")
    end
  end

  test "cancelled work does not turn an empty answer into an active loader on reload", %{
    conn: conn,
    graph: graph
  } do
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit(view, %{"action" => "ask_question", "input" => "A follow-up"})
    answer = Enum.find(created(graph, before_ids), &(&1.class == "answer"))

    for job <- all_enqueued(worker: Dialectic.Workers.LocalWorker, args: %{graph: graph.title}) do
      Oban.cancel_job(job.id)
    end

    {:ok, reloaded, _} = live(conn, ~p"/g/#{graph.slug}?node=#{answer.id}")
    refute has_element?(reloaded, "#reader-generation-status-#{answer.id}")
    assert has_element?(reloaded, "#reader-generation-#{answer.id}", "does not have content yet")
  end

  test "signed-in attendees can request a learning plan", %{conn: conn, graph: graph, user: user} do
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}?node=2")
    view |> element("#outline-reading-node-2-ask") |> render_click()
    assert has_element?(view, "#selection-input-form-answer-actions-2-guided-learning")
    before_ids = GraphManager.vertices(graph.title)

    submit(view, %{
      "action" => "ask_question",
      "input" => "Help me practise",
      "guided_learning" => true
    })

    assert_push_event(view, "selection:result", %{status: "ok"})
    assert Enum.any?(created(graph, before_ids), &(&1.class == "learning_plan"))
  end

  test "bookmark toggles the same saved answer without changing reader position", %{
    conn: conn,
    graph: graph,
    user: user
  } do
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit(view, %{"action" => "bookmark"})
    assert_push_event(view, "selection:result", %{status: "ok", bookmarked: true})
    assert "2" in Dialectic.DbActions.Notes.list_noted_node_ids(graph.title, user)
    assert has_element?(view, "#reader-bookmark-node-2[aria-pressed='true']")
    assert has_element?(view, "#outline-detail[data-selected-reader-node-id='2']")
    submit(view, %{"action" => "bookmark"})
    assert_push_event(view, "selection:result", %{status: "ok", bookmarked: false})
    refute "2" in Dialectic.DbActions.Notes.list_noted_node_ids(graph.title, user)
    assert GraphManager.vertices(graph.title) == before_ids
    refute_enqueued(worker: Dialectic.Workers.LocalWorker, args: %{graph: graph.title})
  end

  for {action, classes} <-
        [
          {"explain", ["answer", "question"]},
          {"pros_cons", ["antithesis", "thesis"]},
          {"related_ideas", ["ideas"]}
        ] ++
          Enum.map(
            ~w(clarify assumptions counterexample implications blind_spots says_who who_disagrees steel_man what_if),
            &{&1, [&1]}
          ) do
    test "#{action} uses the answer context without creating passage highlights", %{
      conn: conn,
      graph: graph
    } do
      {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
      before_ids = GraphManager.vertices(graph.title)
      submit(view, %{"action" => unquote(action)})
      assert_push_event(view, "selection:result", %{status: "ok"})
      nodes = created(graph, before_ids)
      assert Enum.sort(Enum.map(nodes, & &1.class)) == unquote(classes)
      assert Enum.all?(nodes, &is_nil(&1.source_text))
      assert Dialectic.Highlights.list_highlights_with_links(mudg_id: graph.title) == []
      refute has_element?(view, "#reader-view-new-thoughts")

      for node <- nodes, node.class != "question" do
        assert_enqueued(
          worker: Dialectic.Workers.LocalWorker,
          args: %{graph: graph.title, to_node: node.id}
        )
      end
    end
  end

  test "asking keeps unread thoughts from other attendees and notifies their reader", %{
    conn: conn,
    graph: graph
  } do
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    {:ok, other_reader, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit(other_reader, %{"action" => "comment", "input" => "Another attendee's thought"})
    [thought] = created(graph, before_ids)
    assert has_element?(view, "#reader-view-new-thoughts", "1 new thought")

    before_ids = GraphManager.vertices(graph.title)
    submit(view, %{"action" => "ask_question", "input" => "How can we test this?"})
    question = Enum.find(created(graph, before_ids), &(&1.class == "question"))
    send(view.pid, {:other_user_change, self()})
    assert has_element?(view, "#reader-view-new-thoughts", "1 new thought")
    assert has_element?(other_reader, "#reader-view-new-thoughts", "1 new thought")

    view |> element("#reader-view-new-thoughts") |> render_click()
    assert_patch(view, ~p"/g/#{graph.slug}?node=#{thought.id}")
    other_reader |> element("#reader-view-new-thoughts") |> render_click()
    assert_patch(other_reader, ~p"/g/#{graph.slug}?node=#{question.id}")
  end

  test "invalid input, roots, missing answers and restricted guest actions are rejected", %{
    conn: conn,
    graph: graph
  } do
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    before_ids = GraphManager.vertices(graph.title)

    for params <- [
          %{"action" => "comment", "input" => "  "},
          %{"action" => "ask_question", "input" => ""},
          %{"action" => "comment", "nodeId" => "1", "input" => "No root comments"},
          %{"action" => "explain", "nodeId" => "missing"},
          %{"action" => "highlight_only"},
          %{"action" => "bookmark"},
          %{"action" => "ask_question", "input" => "A plan", "guided_learning" => true}
        ] do
      submit(view, params)
      assert_push_event(view, "selection:result", %{status: "error"})
    end

    GraphManager.update_vertex_fields(graph.title, "2", %{deleted: true})
    submit(view, %{"action" => "ask_question", "input" => "Deleted answer"})
    assert_push_event(view, "selection:result", %{status: "error"})
    assert GraphManager.vertices(graph.title) == before_ids
    refute_enqueued(worker: Dialectic.Workers.LocalWorker, args: %{graph: graph.title})
  end

  test "locked answers reject crafted submissions", %{conn: conn, graph: graph} do
    graph |> Ecto.Changeset.change(is_locked: true) |> Dialectic.Repo.update!()
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    refute has_element?(view, "#outline-reading-node-2-ask")
    before_ids = GraphManager.vertices(graph.title)

    send(
      view.pid,
      {:answer_action,
       %{
         "nodeId" => "2",
         "request_id" => "answer-test",
         "action" => "comment",
         "input" => "Blocked"
       }}
    )

    render(view)

    assert_push_event(view, "selection:result", %{
      status: "error",
      message: "This graph is locked"
    })

    assert GraphManager.vertices(graph.title) == before_ids
  end

  test "posting preserves private access tokens", %{conn: conn, graph: graph} do
    graph
    |> Ecto.Changeset.change(is_public: false, share_token: "reader-answer-token")
    |> Dialectic.Repo.update!()

    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=2&token=reader-answer-token")
    before_ids = GraphManager.vertices(graph.title)
    submit(view, %{"action" => "comment", "input" => "Private thought"})
    [comment] = created(graph, before_ids)
    assert_patch(view, ~p"/g/#{graph.slug}?node=#{comment.id}&token=reader-answer-token")
  end

  test "only one answer drawer opens, and its disclosure button tracks hiding and switching", %{
    conn: conn,
    graph: graph
  } do
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}?node=2")
    view |> element("#outline-reading-node-2-ask") |> render_click()
    assert has_element?(view, "#reading-node-2 #answer-actions-2[data-presentation='drawer']")
    assert has_element?(view, "#selection-actions-focus-answer-actions-2[role='region']")
    refute has_element?(view, "#answer-actions-2 [phx-hook='Phoenix.FocusWrap']")
    assert has_element?(view, "#selection-actions-focus-selection-actions[aria-modal='true']")
    view |> element("#outline-reading-node-2-ask") |> render_click()
    assert has_element?(view, "#reader-answer-drawer-2[hidden]")
    refute has_element?(view, "#answer-actions-2")
    view |> element("#outline-reading-node-3-ask") |> render_click()
    assert has_element?(view, "#answer-actions-3")
    view |> element("#outline-reading-node-2-ask") |> render_click()
    assert has_element?(view, "#answer-actions-2")
    refute has_element?(view, "#answer-actions-3")
    render_hook(view, "close_answer_drawer", %{"node_id" => "3"})
    assert has_element?(view, "#answer-actions-2")
    render_hook(view, "close_answer_drawer", %{"node_id" => "2"})
    assert has_element?(view, "#outline-reading-node-2-ask[aria-expanded='false']")
  end

  defp submit(view, params) do
    unless has_element?(view, "#answer-actions-2") do
      view |> element("#outline-reading-node-2-ask") |> render_click()
    end

    view
    |> with_target("#answer-actions-2")
    |> render_hook("action", Map.merge(%{"nodeId" => "2", "request_id" => "answer-test"}, params))

    render(view)
  end

  defp created(graph, before_ids),
    do:
      Enum.map(
        GraphManager.vertices(graph.title) -- before_ids,
        &GraphActions.find_node(graph.title, &1)
      )
end
