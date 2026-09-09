defmodule DialecticWeb.SharedComposerTest do
  use DialecticWeb.ConnCase, async: false
  use Oban.Testing, repo: Dialectic.Repo

  import Dialectic.AccountsFixtures
  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Graph.GraphActions

  setup do
    user = user_fixture()

    nodes =
      for {id, class, content} <- [
            {"1", "origin", "Can we improve our thinking?"},
            {"2", "answer", "## Practice\nExplain an idea in your own words."}
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
        title: "Shared composer #{System.unique_integer([:positive])}",
        data: %{
          "nodes" => nodes,
          "edges" => [%{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}}]
        }
      })

    %{graph: graph, user: user}
  end

  test "answer and passage use the same composer controls with distinct context and IDs", %{
    conn: conn,
    graph: graph,
    user: user
  } do
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2")

    for {id, context} <- [
          {"global-chat-form", "node"},
          {"selection-input-form-selection-actions", "selection"}
        ] do
      assert has_element?(view, "##{id}[data-composer-context='#{context}']")
      assert has_element?(view, "##{id}-comment[data-shortcut-action='comment']", "Post thought")
      assert has_element?(view, "##{id}-ask[data-shortcut-action='ask']", "Ask AI")
      assert has_element?(view, "##{id} [aria-controls][aria-expanded]")
      assert has_element?(view, "##{id}-sharing-hint")
    end

    assert has_element?(
             view,
             "#selection-input-form-selection-actions #selection-tools-popover-selection-actions[hidden]"
           )

    for action <- ~w(highlight explain) do
      assert has_element?(
               view,
               "#selection-input-form-selection-actions-tools-toolbar #selection-action-#{action}-selection-actions"
             )

      refute has_element?(
               view,
               "#selection-tools-popover-selection-actions #selection-action-#{action}-selection-actions"
             )
    end

    assert has_element?(view, "#global-chat-form-tools-toolbar [phx-click='node_branch']")
    assert has_element?(view, "#global-chat-form-tools-toolbar [phx-click='node_related_ideas']")

    assert has_element?(
             view,
             "#global-chat-form-learning-options #global-chat-form-guided-learning"
           )

    refute has_element?(view, "#global-chat-form details #global-chat-form-guided-learning")
  end

  test "the learning choice survives editing the inquiry and opening tools", %{
    conn: conn,
    graph: graph,
    user: user
  } do
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2")

    view
    |> form("#global-chat-form", %{
      "vertex" => %{"content" => "How can I practise this?"},
      "guided_learning" => "true"
    })
    |> render_change()

    assert has_element?(view, "#global-chat-form-guided-learning:checked")
    view |> element("#global-chat-form [id^='node-tools-more-']") |> render_click()
    assert has_element?(view, "#global-chat-form-guided-learning:checked")

    view
    |> form("#global-chat-form", %{
      "vertex" => %{"content" => "What should I practise first?"},
      "guided_learning" => "true"
    })
    |> render_change()

    assert has_element?(view, "#global-chat-form-guided-learning:checked")

    view
    |> form("#global-chat-form", %{"guided_learning" => "false"})
    |> render_change()

    assert has_element?(view, "#global-chat-form-guided-learning:not(:checked)")
  end

  test "posting a passage thought confirms success after saving and preserves its source", %{
    conn: conn,
    graph: graph,
    user: user
  } do
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit_selection(view, %{"action" => "comment", "input" => "  I would test recall later.  "})
    assert_push_event(view, "selection:result", %{request_id: "selection-test", status: "ok"})
    [id] = GraphManager.vertices(graph.title) -- before_ids
    node = GraphActions.find_node(graph.title, id)
    assert node.class == "user"
    assert node.content == "I would test recall later.\n\nRegarding: \"Explain an idea\""
    assert node.source_text == "Explain an idea"
    assert Enum.map(node.parents, & &1.id) == ["2"]
    assert has_element?(view, "#flash-info", "Your thought was added")
    refute_enqueued(worker: Dialectic.Workers.LocalWorker, args: %{graph: graph.title})
  end

  test "asking about a passage confirms acceptance and queues the contextual AI response", %{
    conn: conn,
    graph: graph,
    user: user
  } do
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit_selection(view, %{"action" => "ask_question", "input" => " How would I test this? "})
    assert_push_event(view, "selection:result", %{request_id: "selection-test", status: "ok"})

    nodes =
      Enum.map(
        GraphManager.vertices(graph.title) -- before_ids,
        &GraphManager.vertex_label(graph.title, &1)
      )

    assert Enum.any?(nodes, &(&1.class == "question" && &1.content == "How would I test this?"))
    answer = Enum.find(nodes, &(&1.class == "answer"))
    assert answer.source_text == "Explain an idea"

    assert_enqueued(
      worker: Dialectic.Workers.LocalWorker,
      args: %{graph: graph.title, to_node: answer.id}
    )
  end

  test "blank passage submissions do not create nodes, highlights, or AI work", %{
    conn: conn,
    graph: graph,
    user: user
  } do
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2")
    before_ids = GraphManager.vertices(graph.title)

    for action <- ["comment", "ask_question"], input <- ["", " \n\t "] do
      submit_selection(view, %{"action" => action, "input" => input})

      assert_push_event(view, "selection:result", %{
        status: "error",
        message: "Write a comment or question first."
      })
    end

    assert GraphManager.vertices(graph.title) == before_ids
    assert Dialectic.Highlights.list_highlights_with_links(mudg_id: graph.title) == []
    refute_enqueued(worker: Dialectic.Workers.LocalWorker, args: %{graph: graph.title})
  end

  test "guest passage actions explain the account requirement without creating content", %{
    conn: conn,
    graph: graph
  } do
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2")
    before_ids = GraphManager.vertices(graph.title)
    assert has_element?(view, "#selection-sign-in-hint a[href='/users/log_in']")
    submit_selection(view, %{"action" => "comment", "input" => "My thought"})

    assert_push_event(view, "selection:result", %{
      status: "error",
      message: "Sign in to use passage actions. Your draft will stay here."
    })

    assert GraphManager.vertices(graph.title) == before_ids
  end

  test "root comments and actions on deleted passages are rejected", %{
    conn: conn,
    graph: graph,
    user: user
  } do
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit_selection(view, %{"action" => "comment", "input" => "My thought", "nodeId" => "1"})

    assert_push_event(view, "selection:result", %{
      status: "error",
      message: "Choose a response to add your comment."
    })

    GraphManager.update_vertex_fields(graph.title, "2", %{deleted: true})

    for action <- ["comment", "ask_question", "explain", "pros_cons"] do
      submit_selection(view, %{"action" => action, "input" => "My thought"})

      assert_push_event(view, "selection:result", %{
        status: "error",
        message: "Choose an existing response to continue."
      })
    end

    assert GraphManager.vertices(graph.title) == before_ids
  end

  test "locked grids reject a crafted passage submission", %{conn: conn, graph: graph, user: user} do
    graph |> Ecto.Changeset.change(is_locked: true) |> Dialectic.Repo.update!()
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2")
    before_ids = GraphManager.vertices(graph.title)
    submit_selection(view, %{"action" => "comment", "input" => "Blocked thought"})

    assert_push_event(view, "selection:result", %{
      status: "error",
      message: "This graph is locked"
    })

    assert GraphManager.vertices(graph.title) == before_ids
  end

  test "a failed highlight save reports an error instead of confirming success", %{
    conn: conn,
    graph: graph,
    user: user
  } do
    {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2")

    send(
      view.pid,
      {:selection_action,
       %{
         action: :highlight_only,
         selected_text: "Explain an idea",
         node_id: "2",
         offsets: %{"start" => -1, "end" => 15},
         highlight: nil,
         request_id: "failed-highlight"
       }}
    )

    render(view)

    assert_push_event(view, "selection:result", %{
      request_id: "failed-highlight",
      status: "error",
      message: "Could not save highlight. Please try again."
    })

    assert Dialectic.Highlights.list_highlights_with_links(mudg_id: graph.title) == []
  end

  defp submit_selection(view, overrides) do
    params =
      Map.merge(
        %{
          "nodeId" => "2",
          "selectedText" => "Explain an idea",
          "offsets" => %{"start" => 0, "end" => 15},
          "request_id" => "selection-test"
        },
        overrides
      )

    view |> with_target("#selection-actions") |> render_hook("action", params)
    render(view)
  end
end
