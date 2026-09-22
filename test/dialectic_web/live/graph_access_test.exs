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

  test "owner can reach visibility and protection from the title bar", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    {:ok, view, _html} = live(log_in_user(conn, owner), ~p"/g/#{graph.slug}/graph")

    assert has_element?(view, "#graph-header #graph-heading > #graph-title + #graph-help-button")
    assert has_element?(view, "#graph-header #graph-workspace-bar")

    assert has_element?(
             view,
             "#graph-header #graph-access-settings[title='Access controls: Public · Editable']"
           )

    assert has_element?(view, "#graph-access-settings .hero-globe-alt")

    refute has_element?(view, "#details-workspace[open]")

    view |> element("#graph-access-settings") |> render_click()
    assert has_element?(view, "#details-workspace[open]")

    view |> element("#toggle_public_graph") |> render_click()
    refute Repo.reload!(graph).is_public

    assert has_element?(
             view,
             "#graph-access-settings[title='Access controls: Private · Editable']"
           )

    assert has_element?(view, "#graph-access-settings .hero-lock-closed")

    refute has_element?(view, "#toggle_public_graph[checked]")

    view |> element("#toggle_public_graph") |> render_click()
    assert Repo.reload!(graph).is_public
    assert has_element?(view, "#toggle_public_graph[checked]")

    view |> element("#toggle_lock_graph") |> render_click()
    assert Repo.reload!(graph).is_locked

    assert has_element?(
             view,
             "#graph-access-settings[title='Access controls: Public · Protected']"
           )

    assert has_element?(view, "#graph-access-settings .hero-globe-alt")

    refute has_element?(view, "#toggle_lock_graph[checked]")

    view |> element("#toggle_lock_graph") |> render_click()
    refute Repo.reload!(graph).is_locked

    assert has_element?(
             view,
             "#graph-access-settings[title='Access controls: Public · Editable']"
           )

    assert has_element?(view, "#toggle_lock_graph[checked]")
  end

  test "access and explanation shortcuts focus their own section", %{
    conn: conn,
    owner: owner,
    graph: graph
  } do
    {:ok, view, _html} = live(log_in_user(conn, owner), ~p"/g/#{graph.slug}/graph")

    view |> element("#graph-access-settings") |> render_click()
    assert has_element?(view, "#details-workspace[open]")
    refute has_element?(view, "#details-configure[open]")

    view |> element("#graph-workspace-bar-level") |> render_click()
    assert has_element?(view, "#details-configure[open]")
    refute has_element?(view, "#details-workspace[open]")

    view |> element("#graph-access-settings") |> render_click()
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
      refute has_element?(view, "#graph-access-settings")
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
