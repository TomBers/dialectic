defmodule DialecticWeb.GraphAccessTest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  alias Dialectic.DbActions.{Graphs, Sharing}
  alias Dialectic.Repo

  setup do
    owner = user_fixture()
    {:ok, graph} = Graphs.create_new_graph("Access #{System.unique_integer([:positive])}", owner)
    %{owner: owner, graph: graph}
  end

  test "guests can read and share both views but cannot submit grid changes", %{
    conn: conn,
    graph: graph
  } do
    GraphManager.get_graph(graph.title)

    response =
      GraphManager.add_node(graph.title, %Dialectic.Graph.Vertex{
        class: "answer",
        content: "A response anyone can read"
      })

    GraphManager.add_edges(graph.title, response, [GraphManager.find_node_by_id(graph.title, "1")])

    GraphManager.save_graph(graph.title)
    before_ids = GraphManager.vertices(graph.title)

    for {path, prefix, prompt_id} <- [
          {~p"/g/#{graph.slug}?node=#{response.id}", "reader", "reader-contribution-sign-in"},
          {~p"/g/#{graph.slug}/graph?node=#{response.id}", "graph",
           "node-inquiry-actions-#{response.id}-sign-in"}
        ] do
      {:ok, view, _} = live(conn, path)
      assert has_element?(view, "##{prefix}-workspace-bar-share")
      assert has_element?(view, "##{prompt_id}-register[href='/users/register']")
      refute has_element?(view, "#global-chat-form")

      for {event, params} <-
            [
              {"answer", %{"vertex" => %{"content" => "A guest thought"}}},
              {"reply-and-answer", %{"vertex" => %{"content" => "A guest question"}}},
              {"node:join_group", %{"node" => response.id, "parent" => "forged-group"}},
              {"node:leave_group", %{"node" => response.id}},
              {"start_stream", %{"title" => "Guest stream"}},
              {"node_regenerate", %{"id" => response.id}},
              {"set_prompt_mode", %{"prompt_mode" => "high_school"}}
            ] ++
              Enum.map(
                ~w(branch_list submit_guided_paths apply_guided_next_action submit_explore_modal
                 node_branch node_combine node_related_ideas node_clarify node_assumptions
                 node_counterexample node_implications node_blind_spots node_says_who
                 node_who_disagrees node_steel_man node_what_if delete_node node_move
                 delete_stream execute_combine),
                &{&1, %{}}
              ) do
        render_click(view, event, params)
        assert has_element?(view, "#flash-error", "Sign in or create an account")
        assert GraphManager.vertices(graph.title) == before_ids
        assert GraphManager.vertex_label(graph.title, response.id).parent == response.parent
        assert Repo.reload!(graph).prompt_mode == graph.prompt_mode
      end
    end
  end

  test "a private share link grants viewing without granting guest editing", %{
    conn: conn,
    graph: graph,
    owner: owner
  } do
    {:ok, graph} = Graphs.toggle_graph_public(graph, owner)
    contributor = user_fixture()

    refute Sharing.can_access?(nil, graph, nil)
    refute Sharing.can_access?(nil, graph, "wrong-token")
    assert Sharing.can_access?(nil, graph, graph.share_token)
    refute Sharing.can_edit?(nil, graph, graph.share_token)
    assert Sharing.can_edit?(contributor, graph, graph.share_token)
    refute Sharing.can_edit?(contributor, graph)

    for path <- [~p"/g/#{graph.slug}", ~p"/g/#{graph.slug}/graph"] do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, path)
      {:ok, view, _} = live(conn, path <> "?token=#{graph.share_token}")
      render_click(view, "node:join_group", %{"node" => "1", "parent" => "forged-group"})
      assert has_element?(view, "#flash-error", "Sign in or create an account")
      assert GraphManager.vertex_label(graph.title, "1").parent == nil
    end

    deleted = %{graph | is_deleted: true}
    refute Sharing.can_access?(owner, deleted, graph.share_token)
    refute Sharing.can_edit?(owner, deleted, graph.share_token)
  end

  test "reader and grid headers keep the same controls and layout", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    conn = log_in_user(conn, owner)
    {:ok, reader, _html} = live(conn, ~p"/g/#{graph.slug}")
    {:ok, grid, _html} = live(conn, ~p"/g/#{graph.slug}/graph")

    for {view, prefix} <- [{reader, "reader"}, {grid, "graph"}] do
      assert has_element?(view, "##{prefix}-header ##{prefix}-more[aria-controls='right-panel']")
      assert has_element?(view, "##{prefix}-header ##{prefix}-byline", "Public")
      assert has_element?(view, "##{prefix}-creator[href='/u/#{owner.username}']")

      assert has_element?(
               view,
               "##{prefix}-header ##{prefix}-grid-history[aria-controls='grid-history-panel']"
             )

      assert has_element?(view, "##{prefix}-workspace-bar-share")
      assert has_element?(view, "##{prefix}-workspace-bar-outline-desktop[data-explore-toggle]")
      assert has_element?(view, "##{prefix}-workspace-bar-outline-desktop [data-explore-label]")

      assert has_element?(
               view,
               "##{prefix}-workspace-bar-outline-desktop [data-explore-hide-icon]"
             )

      assert has_element?(
               view,
               "##{prefix}-workspace-bar-outline-desktop [data-explore-show-icon]"
             )

      assert has_element?(view, "##{prefix}-workspace-bar-graph[aria-label='Grid view']", "Grid")
      refute has_element?(view, "##{prefix}-header [popovertarget]")
      refute has_element?(view, "##{prefix}-header #graph-help-button")
    end

    assert has_element?(reader, "#reader-workspace-bar-reader[aria-current='page']")
    assert has_element?(grid, "#graph-workspace-bar-graph[aria-current='page']")
    assert has_element?(grid, "#graph-workspace-bar-outline-desktop[aria-controls='side-drawer']")
    assert has_element?(grid, "#graph-mobile-explore[aria-controls='side-drawer']")
    refute has_element?(grid, "#grid-tools-reading-style")
    assert has_element?(grid, "#details-reading-style #reader-style-screen")
    assert has_element?(reader, "#reader-style-book", "Serif")
    assert has_element?(reader, "#right-panel.fixed.top-10")
    assert has_element?(reader, "#right-panel .tools-drawer-header #right-panel-close")
    assert has_element?(reader, "#right-panel .tools-drawer-header + .tools-drawer-content")
    assert has_element?(reader, "#right-panel[class~='lg:absolute']")
    assert has_element?(grid, "#right-panel.absolute")
    refute has_element?(grid, "#right-panel.fixed")

    render_patch(reader, ~p"/g/#{graph.slug}?tools=reading-style")
    assert_push_event(reader, "open_reader_tools", %{})
  end

  test "mobile tool links open in an accessible workspace with a route back to reader", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    {:ok, view, _html} =
      live(log_in_user(conn, owner), ~p"/g/#{graph.slug}/graph?tools=configure")

    assert_push_event(view, "open_grid_tool", %{section: "configure"})
    assert has_element?(view, "#graph-keyboard-workspace.flex #right-panel")
    refute has_element?(view, "#graph-keyboard-workspace.hidden")
    assert has_element?(view, "#graph-workspace-bar-reader[href^='/g/#{graph.slug}?node=']")
    assert has_element?(view, "#graph-more[aria-controls='right-panel']")
    assert has_element?(view, "#graph-layout[data-mobile-map-enabled='true']")
    refute has_element?(view, "#cy.hidden")
  end

  test "grid history opens directly from both headers and refreshes contributions", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    for {path, prefix} <- [
          {~p"/g/#{graph.slug}/graph", "graph"},
          {~p"/g/#{graph.slug}", "reader"}
        ] do
      {:ok, view, _html} = live(conn, path)
      refute has_element?(view, "#right-panel #grid-activity-log")

      {:ok, log} =
        Dialectic.GridActivity.record_node_comment_created(graph.title, owner, "1")

      view |> element("##{prefix}-grid-history") |> render_click()

      assert has_element?(view, "#grid-history-panel-title", "Grid history")
      assert has_element?(view, "#grid-history-description")
      assert has_element?(view, "#grid-activity-log-#{log.id}")

      assert has_element?(
               view,
               "#grid-activity-actor-#{log.id}[href='/u/#{owner.username}']"
             )

      view |> element("##{prefix}-grid-history") |> render_click()
      assert has_element?(view, "#grid-history-origin")
      assert has_element?(view, "#grid-activity-log-#{log.id}")
    end
  end

  test "history pages through older events without dropping loaded entries", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    events =
      for _ <- 1..52 do
        {:ok, event} = Dialectic.GridActivity.record_node_comment_created(graph.title, owner, "1")
        event
      end

    oldest = hd(events)
    newest = List.last(events)
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}")
    view |> element("#reader-grid-history") |> render_click()
    assert has_element?(view, "#grid-activity-log-#{newest.id}")
    refute has_element?(view, "#grid-activity-log-#{oldest.id}")
    view |> element("#grid-history-load-earlier") |> render_click()
    assert has_element?(view, "#grid-activity-log-#{newest.id}")
    view |> element("#grid-history-load-earlier") |> render_click()
    assert has_element?(view, "#grid-activity-log-#{oldest.id}")
    refute has_element?(view, "#grid-history-load-earlier")
    view |> element("#reader-grid-history") |> render_click()
    assert has_element?(view, "#grid-activity-log-#{newest.id}")
    refute has_element?(view, "#grid-activity-log-#{oldest.id}")
  end

  test "owner manages visibility and contributions from Share", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    for {path, prefix} <- [
          {~p"/g/#{graph.slug}/graph", "graph"},
          {~p"/g/#{graph.slug}", "reader"}
        ] do
      {:ok, view, _html} = live(log_in_user(conn, owner), path)
      view |> element("##{prefix}-workspace-bar-share") |> render_click()
      assert has_element?(view, "#share-access-settings #share-visibility-public")
      assert has_element?(view, "#share-access-settings #toggle_lock_graph")
      refute has_element?(view, "#right-panel #toggle_lock_graph")

      view |> element("#share-visibility-private") |> render_click()
      refute Repo.reload!(graph).is_public
      assert has_element?(view, "##{prefix}-byline", "Private")
      assert has_element?(view, "#share-visibility-private[aria-pressed='true']")
      view |> element("#share-visibility-public") |> render_click()
      assert Repo.reload!(graph).is_public
      view |> element("#toggle_lock_graph") |> render_click()
      assert Repo.reload!(graph).is_locked
      refute has_element?(view, "#toggle_lock_graph[checked]")
      view |> element("#toggle_lock_graph") |> render_click()
      refute Repo.reload!(graph).is_locked
      assert has_element?(view, "#toggle_lock_graph[checked]")
    end
  end

  test "More groups reading and grid actions without repeating history and access settings", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    for path <- [~p"/g/#{graph.slug}/graph", ~p"/g/#{graph.slug}"] do
      {:ok, view, _html} = live(log_in_user(conn, owner), path)
      assert has_element?(view, "#right-panel-title", "More")
      assert has_element?(view, "#right-panel #details-reading-style")
      refute has_element?(view, "#details-reading-style[open]")
      assert has_element?(view, "#right-panel #more-saved-highlights")
      assert has_element?(view, "#right-panel #reader-tools-follow")
      assert has_element?(view, "#right-panel #details-export")
      refute has_element?(view, "#right-panel #details-activity")
      refute has_element?(view, "#right-panel #toggle_lock_graph")
      refute has_element?(view, "#tools-mobile-actions")

      if has_element?(view, "#graph-layout"),
        do: assert(has_element?(view, "#grid-tools-presentation"))
    end
  end

  test "forged access-setting events cannot change another user's grid", %{
    conn: conn,
    graph: graph
  } do
    for user <- [nil, user_fixture()] do
      visitor_conn = if user, do: log_in_user(conn, user), else: conn

      for path <- [~p"/g/#{graph.slug}/graph", ~p"/g/#{graph.slug}"] do
        {:ok, view, _html} = live(visitor_conn, path)
        refute has_element?(view, "#graph-access-settings-private")
        refute has_element?(view, "#reader-access-settings-private")
        render_click(view, "set_graph_visibility", %{"visibility" => "private"})
        assert has_element?(view, "#flash-error", "Only the grid owner")
        assert Repo.reload!(graph).is_public
        refute has_element?(view, "#toggle_public_graph")
        refute has_element?(view, "#toggle_lock_graph")

        for event <- ["toggle_lock_graph", "toggle_public_graph"] do
          render_click(view, event)
          assert has_element?(view, "#flash-error", "Only the grid owner")
          assert Repo.reload!(graph).is_public
          refute Repo.reload!(graph).is_locked
        end
      end
    end
  end

  test "owner locking a grid prevents contributions from an already open editor", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    {:ok, visitor, _html} = live(log_in_user(conn, user_fixture()), ~p"/g/#{graph.slug}/graph")
    {:ok, owner_view, _html} = live(log_in_user(conn, owner), ~p"/g/#{graph.slug}/graph")

    response =
      GraphManager.add_node(graph.title, %Dialectic.Graph.Vertex{
        class: "answer",
        content: "A response open for discussion"
      })

    GraphManager.add_edges(graph.title, response, [GraphManager.find_node_by_id(graph.title, "1")])

    render_click(visitor, "node_clicked", %{"id" => response.id})
    render_click(owner_view, "node_clicked", %{"id" => response.id})
    count = length(GraphManager.vertices(graph.title))

    render_click(owner_view, "toggle_lock_graph")
    assert Repo.reload!(graph).is_locked

    assert has_element?(
             owner_view,
             "#node-tools-popover-#{response.id}[phx-hook='ToolsMenu']:not([phx-update])"
           )

    assert has_element?(
             owner_view,
             "#node-tools-popover-#{response.id} [id^='node-tool-pros-cons-'][disabled]"
           )

    render_click(visitor, "answer", %{"vertex" => %{"content" => "A blocked contribution"}})

    assert has_element?(visitor, "#flash-error", "locked")
    assert length(GraphManager.vertices(graph.title)) == count

    render_click(visitor, "node:join_group", %{"node" => response.id, "parent" => "forged-group"})
    assert has_element?(visitor, "#flash-error", "locked")
    assert GraphManager.vertex_label(graph.title, response.id).parent == response.parent

    render_click(owner_view, "toggle_lock_graph")
    refute Repo.reload!(graph).is_locked

    assert has_element?(
             owner_view,
             "#node-tools-popover-#{response.id} [id^='node-tool-pros-cons-']:not([disabled])"
           )

    render_click(visitor, "answer", %{"vertex" => %{"content" => "An allowed contribution"}})
    assert length(GraphManager.vertices(graph.title)) == count + 1
  end

  test "making a grid private removes existing public reader and editor sessions", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    {:ok, reader, _html} = live(conn, ~p"/g/#{graph.slug}")
    {:ok, editor, _html} = live(conn, ~p"/g/#{graph.slug}/graph")
    {:ok, owner_view, _html} = live(log_in_user(conn, owner), ~p"/g/#{graph.slug}/graph")

    render_click(owner_view, "toggle_public_graph")

    assert_redirect(reader, "/")
    assert_redirect(editor, "/")
    refute Repo.reload!(graph).is_public
    assert has_element?(owner_view, "#graph-layout")
  end

  test "invited and token-authorized readers retain access when visibility changes", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    invited = user_fixture()
    {:ok, _share} = Sharing.invite_user(graph, invited.email)
    {:ok, reader, _html} = live(log_in_user(conn, invited), ~p"/g/#{graph.slug}")
    {:ok, token_reader, _html} = live(conn, ~p"/g/#{graph.slug}?token=#{graph.share_token}")

    assert {:ok, _graph} = Graphs.toggle_graph_public(graph, owner)

    assert has_element?(reader, "#outline-layout")
    assert has_element?(token_reader, "#outline-layout")
    assert {:error, :forbidden} = Sharing.remove_invite(graph, invited.email, invited)
    assert length(Sharing.list_shares(graph)) == 1

    assert :ok = Sharing.remove_invite(graph, invited.email, owner)
    assert_redirect(reader, "/")
    assert has_element?(token_reader, "#outline-layout")
  end
end
