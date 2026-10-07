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

  test "reader and grid headers keep the same controls and layout", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    conn = log_in_user(conn, owner)
    {:ok, reader, _html} = live(conn, ~p"/g/#{graph.slug}")
    {:ok, grid, _html} = live(conn, ~p"/g/#{graph.slug}/graph")

    for {view, prefix} <- [{reader, "reader"}, {grid, "graph"}] do
      assert has_element?(view, "##{prefix}-header #document-menu-settings-document-menu")
      assert has_element?(view, "##{prefix}-header ##{prefix}-access-settings", "Public")
      assert has_element?(view, "##{prefix}-header ##{prefix}-workspace-bar-level", "Expanded")
      assert has_element?(view, "##{prefix}-workspace-bar-level .hero-square-3-stack-3d")
      refute has_element?(view, "##{prefix}-header #graph-help-button")
      refute has_element?(view, "##{prefix}-header #reader-workspace-bar-outline-desktop")
    end

    controls = fn view, prefix ->
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.filter("##{prefix}-header button")
      |> LazyHTML.to_tree()
      |> Enum.map(fn {tag, attrs, _children} ->
        attrs = Map.new(attrs)
        {tag, String.replace_prefix(attrs["id"], prefix, "workspace"), attrs["class"]}
      end)
    end

    assert controls.(reader, "reader") == controls.(grid, "graph")
    assert has_element?(reader, "#reader-workspace-bar-reader[aria-current='page']")
    assert has_element?(grid, "#graph-workspace-bar-graph[aria-current='page']")
    assert has_element?(grid, "#grid-tools-reading-style[href*='tools=reading-style']")
    assert has_element?(reader, "#reader-style-book", "Serif")
    assert has_element?(reader, "#right-panel.fixed")
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
    assert has_element?(view, "#graph-mobile-back-to-reader[href^='/g/#{graph.slug}?node=']")

    assert has_element?(
             view,
             "#document-menu-settings-mobile-document-menu[aria-controls='right-panel']"
           )

    assert has_element?(view, "#graph-mobile-reader-link[href^='/g/#{graph.slug}?node=']")
    refute has_element?(view, "#graph-mobile-back-to-reader[href*=tools]")
    assert has_element?(view, "#side-drawer.hidden")
    assert has_element?(view, "#cy.hidden")
  end

  test "owner can reach visibility and protection from grid tools", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    {:ok, view, _html} = live(log_in_user(conn, owner), ~p"/g/#{graph.slug}/graph")

    assert has_element?(view, "#graph-header #graph-heading #graph-title")
    assert has_element?(view, "#right-panel #graph-help-button")
    refute has_element?(view, "#graph-header #graph-help-button")
    assert has_element?(view, "#graph-header #graph-workspace-bar")

    assert has_element?(view, "#graph-header #document-menu-settings-document-menu")
    assert has_element?(view, "#graph-header #graph-access-settings", "Public")
    refute has_element?(view, "#details-workspace[open]")

    view |> element("#graph-access-settings") |> render_click()
    assert has_element?(view, "#details-workspace[open]")

    view |> element("#toggle_public_graph") |> render_click()
    refute Repo.reload!(graph).is_public
    assert has_element?(view, "#graph-access-settings", "Private")
    assert has_element?(view, "#graph-access-settings .hero-lock-closed")

    refute has_element?(view, "#toggle_public_graph[checked]")

    view |> element("#toggle_public_graph") |> render_click()
    assert Repo.reload!(graph).is_public
    assert has_element?(view, "#toggle_public_graph[checked]")

    view |> element("#toggle_lock_graph") |> render_click()
    assert Repo.reload!(graph).is_locked

    refute has_element?(view, "#toggle_lock_graph[checked]")

    view |> element("#toggle_lock_graph") |> render_click()
    refute Repo.reload!(graph).is_locked

    assert has_element?(view, "#toggle_lock_graph[checked]")
  end

  test "access and explanation sections open within grid tools", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    {:ok, view, _html} = live(log_in_user(conn, owner), ~p"/g/#{graph.slug}/graph")

    view |> element("#details-workspace > summary") |> render_click()
    assert has_element?(view, "#details-workspace[open]")
    refute has_element?(view, "#details-configure[open]")

    view |> element("#details-workspace > summary") |> render_click()
    view |> element("#details-configure > summary") |> render_click()
    assert has_element?(view, "#details-configure[open]")
    refute has_element?(view, "#details-workspace[open]")

    view |> element("#details-configure > summary") |> render_click()
    view |> element("#details-workspace > summary") |> render_click()
    assert has_element?(view, "#details-workspace[open]")
    refute has_element?(view, "#details-configure[open]")
  end

  test "forged access-setting events cannot change another user's grid", %{
    conn: conn,
    graph: graph
  } do
    for user <- [nil, user_fixture()] do
      visitor_conn = if user, do: log_in_user(conn, user), else: conn
      {:ok, view, _html} = live(visitor_conn, ~p"/g/#{graph.slug}/graph")
      assert has_element?(view, "#graph-layout")
      assert has_element?(view, "#graph-access-settings[aria-label='Grid visibility: Public']")
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

  test "owner locking a grid prevents contributions from an already open editor", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    {:ok, visitor, _html} = live(conn, ~p"/g/#{graph.slug}/graph")
    {:ok, owner_view, _html} = live(log_in_user(conn, owner), ~p"/g/#{graph.slug}/graph")

    response =
      GraphManager.add_node(graph.title, %Dialectic.Graph.Vertex{
        class: "answer",
        content: "A response open for discussion"
      })

    GraphManager.add_edges(graph.title, response, [GraphManager.find_node_by_id(graph.title, "1")])

    render_click(visitor, "node_clicked", %{"id" => response.id})
    count = length(GraphManager.vertices(graph.title))

    render_click(owner_view, "toggle_lock_graph")
    assert Repo.reload!(graph).is_locked
    render_click(visitor, "answer", %{"vertex" => %{"content" => "A blocked contribution"}})

    assert has_element?(visitor, "#flash-error", "locked")
    assert length(GraphManager.vertices(graph.title)) == count

    render_click(owner_view, "toggle_lock_graph")
    refute Repo.reload!(graph).is_locked
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
