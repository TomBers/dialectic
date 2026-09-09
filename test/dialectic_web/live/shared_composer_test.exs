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

    for action <- ~w(highlight explain pros-cons related) do
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
    assert has_element?(view, "#global-chat-form-tools-toolbar [phx-click*='node_combine']")

    assert has_element?(
             view,
             "#global-chat-form-more-tools-row [aria-controls='node-tools-popover-2']"
           )

    assert has_element?(view, "#global-chat-form-tools-toolbar [phx-click='node_related_ideas']")

    assert has_element?(
             view,
             "#global-chat-form-tools-toolbar [data-reader-shortcut='a'] [data-shortcut-label='mac']",
             "⌘ A"
           )

    assert has_element?(
             view,
             "#global-chat-form-tools-toolbar [data-reader-shortcut='r'] [data-shortcut-label='other']",
             "Ctrl+R"
           )

    assert has_element?(view, "#global-chat-form-comment [data-shortcut-label='mac']", "⌘ ⇧ ↵")

    assert has_element?(
             view,
             "#global-chat-form-learning-options #global-chat-form-guided-learning"
           )

    refute has_element?(view, "#global-chat-form details #global-chat-form-guided-learning")
  end

  for locked? <- [false, true] do
    test "the tool group saves and removes bookmarks without submitting the draft (locked: #{locked?})",
         %{
           conn: conn,
           graph: graph,
           user: user
         } do
      graph =
        graph
        |> Ecto.Changeset.change(is_locked: unquote(locked?))
        |> Dialectic.Repo.update!()

      {:ok, view, _} = live(log_in_user(conn, user), ~p"/g/#{graph.slug}/graph?node=2")
      before_ids = GraphManager.vertices(graph.title)
      button = "#global-chat-form-tools-toolbar #graph-bookmark-node-2"

      assert has_element?(
               view,
               "#{button}[type='button'][data-reader-shortcut='b'][aria-pressed='false']:not([disabled])"
             )

      refute has_element?(view, "#node-title-header-2 #graph-bookmark-node-2")

      unless unquote(locked?) do
        view
        |> form("#global-chat-form", %{"vertex" => %{"content" => "Keep this question"}})
        |> render_change()
      end

      view |> element(button) |> render_click()
      assert has_element?(view, "#{button}[aria-pressed='true']", "Bookmarked")
      assert has_element?(view, "#{button} .hero-bookmark-solid")
      assert has_element?(view, "#{button} [data-shortcut-label='mac']", "⌘ B")
      assert has_element?(view, "#{button} [data-shortcut-label='other']", "Ctrl+B")
      assert Dialectic.DbActions.Notes.list_noted_node_ids(graph.title, user) == ["2"]
      refute_push_event(view, "scroll_to_top", %{})

      view |> element(button) |> render_click()
      assert has_element?(view, "#{button}[aria-pressed='false']", "Bookmark")
      assert Dialectic.DbActions.Notes.list_noted_node_ids(graph.title, user) == []
      refute_push_event(view, "scroll_to_top", %{})

      unless unquote(locked?) do
        assert has_element?(view, "#global-chat-input", "Keep this question")
      end

      assert GraphManager.vertices(graph.title) == before_ids
      refute_enqueued(worker: Dialectic.Workers.LocalWorker, args: %{graph: graph.title})
    end
  end

  test "bookmark in the tool group prompts guests to sign in", %{conn: conn, graph: graph} do
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}/graph?node=2")
    refute has_element?(view, "#login-modal")

    view |> element("#global-chat-form-tools-toolbar #graph-bookmark-node-2") |> render_click()

    assert has_element?(view, "#login-modal")
    assert has_element?(view, "#graph-bookmark-node-2[aria-pressed='false']")
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

  for mode <- [:grid, :reader] do
    test "the full passage form and common tools are available (#{mode})", %{
      conn: conn,
      graph: graph,
      user: user
    } do
      {:ok, view, _} = live(log_in_user(conn, user), selection_path(graph, unquote(mode)))
      assert has_element?(view, "#selection-input-form-selection-actions-ask")
      assert has_element?(view, "#selection-input-form-selection-actions-comment")

      assert has_element?(
               view,
               "#selection-advanced-tools-toggle-selection-actions[aria-haspopup='dialog']"
             )

      for action <- ~w(highlight explain pros-cons related) do
        assert has_element?(
                 view,
                 "#selection-input-form-selection-actions-tools-toolbar #selection-action-#{action}-selection-actions"
               )
      end
    end

    for {action, classes, link_types} <-
          [
            {"explain", ["answer", "question"], ["explain"]},
            {"pros_cons", ["antithesis", "thesis"], ["con", "pro"]},
            {"related_ideas", ["ideas"], ["related_idea"]}
          ] ++
            Enum.map(
              ~w(clarify assumptions counterexample implications blind_spots says_who who_disagrees steel_man what_if),
              &{&1, [&1], [&1]}
            ) do
      test "#{action} creates linked responses for the selected passage (#{mode})", %{
        conn: conn,
        graph: graph,
        user: user
      } do
        {:ok, view, _} = live(log_in_user(conn, user), selection_path(graph, unquote(mode)))
        before_ids = GraphManager.vertices(graph.title)
        submit_selection(view, %{"action" => unquote(action)})
        assert_push_event(view, "selection:result", %{request_id: "selection-test", status: "ok"})

        nodes =
          Enum.map(
            GraphManager.vertices(graph.title) -- before_ids,
            &GraphActions.find_node(graph.title, &1)
          )

        assert Enum.sort(Enum.map(nodes, & &1.class)) == unquote(classes)
        assert Enum.all?(nodes, &(&1.source_text == "Explain an idea"))
        [highlight] = Dialectic.Highlights.list_highlights_with_links(mudg_id: graph.title)
        assert Enum.sort(Enum.map(highlight.links, & &1.link_type)) == unquote(link_types)

        for node <- nodes, node.class != "question" do
          assert_enqueued(
            worker: Dialectic.Workers.LocalWorker,
            args: %{graph: graph.title, to_node: node.id}
          )
        end
      end
    end

    test "posting a passage thought confirms success after saving and preserves its source (#{mode})",
         %{
           conn: conn,
           graph: graph,
           user: user
         } do
      {:ok, view, _} = live(log_in_user(conn, user), selection_path(graph, unquote(mode)))
      {:ok, other_reader, _} = live(conn, selection_path(graph, :reader))
      before_ids = GraphManager.vertices(graph.title)

      submit_selection(view, %{"action" => "comment", "input" => "  I would test recall later.  "})

      assert_push_event(view, "selection:result", %{request_id: "selection-test", status: "ok"})
      [id] = GraphManager.vertices(graph.title) -- before_ids
      node = GraphActions.find_node(graph.title, id)
      assert has_element?(other_reader, "#outline-node-#{id}")
      assert node.class == "user"
      assert node.content == "I would test recall later.\n\nRegarding: \"Explain an idea\""
      assert node.source_text == "Explain an idea"
      assert Enum.map(node.parents, & &1.id) == ["2"]
      assert has_element?(view, "#flash-info", "Your thought was added")
      refute_enqueued(worker: Dialectic.Workers.LocalWorker, args: %{graph: graph.title})
    end

    test "asking about a passage confirms acceptance and queues the contextual AI response (#{mode})",
         %{
           conn: conn,
           graph: graph,
           user: user
         } do
      {:ok, view, _} = live(log_in_user(conn, user), selection_path(graph, unquote(mode)))
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

      if unquote(mode) == :reader do
        assert_patch(view, selection_path_for_node(graph, answer.id))
        assert has_element?(view, "#reader-generation-#{answer.id}", "Generating an AI response")

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
          "## A recall test\nExplain it tomorrow."
        )

        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          "graph_update:#{graph.title}",
          {:llm_request_complete, answer.id}
        )

        assert has_element?(view, "#reading-node-#{answer.id} h2", "A recall test")
        refute has_element?(view, "#reader-generation-#{answer.id}")
      end
    end

    test "blank passage submissions do not create nodes, highlights, or AI work (#{mode})", %{
      conn: conn,
      graph: graph,
      user: user
    } do
      {:ok, view, _} = live(log_in_user(conn, user), selection_path(graph, unquote(mode)))
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

    test "guest passage actions explain the account requirement without creating content (#{mode})",
         %{
           conn: conn,
           graph: graph
         } do
      {:ok, view, _} = live(conn, selection_path(graph, unquote(mode)))
      before_ids = GraphManager.vertices(graph.title)
      assert has_element?(view, "#selection-sign-in-hint a[href='/users/log_in']")
      submit_selection(view, %{"action" => "comment", "input" => "My thought"})

      assert_push_event(view, "selection:result", %{
        status: "error",
        message: "Sign in to use passage actions. Your draft will stay here."
      })

      assert GraphManager.vertices(graph.title) == before_ids
    end

    test "root comments and actions on deleted passages are rejected (#{mode})", %{
      conn: conn,
      graph: graph,
      user: user
    } do
      {:ok, view, _} = live(log_in_user(conn, user), selection_path(graph, unquote(mode)))
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

    test "locked grids reject a crafted passage submission (#{mode})", %{
      conn: conn,
      graph: graph,
      user: user
    } do
      graph |> Ecto.Changeset.change(is_locked: true) |> Dialectic.Repo.update!()
      {:ok, view, _} = live(log_in_user(conn, user), selection_path(graph, unquote(mode)))
      before_ids = GraphManager.vertices(graph.title)
      submit_selection(view, %{"action" => "comment", "input" => "Blocked thought"})

      assert_push_event(view, "selection:result", %{
        status: "error",
        message: "This graph is locked"
      })

      assert GraphManager.vertices(graph.title) == before_ids
    end

    test "a failed highlight save reports an error instead of confirming success (#{mode})", %{
      conn: conn,
      graph: graph,
      user: user
    } do
      {:ok, view, _} = live(log_in_user(conn, user), selection_path(graph, unquote(mode)))

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
  end

  defp selection_path(graph, :grid), do: ~p"/g/#{graph.slug}/graph?node=2"
  defp selection_path(graph, :reader), do: ~p"/g/#{graph.slug}?node=2"
  defp selection_path_for_node(graph, node_id), do: ~p"/g/#{graph.slug}?node=#{node_id}"

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
