defmodule DialecticWeb.AdminCuratedLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  alias Dialectic.Repo

  defp make_admin(user) do
    user
    |> Ecto.Changeset.change(%{is_admin: true})
    |> Repo.update!()
  end

  defp create_published_graph(title) do
    Dialectic.GraphFixtures.insert_graph(%{
      title: title,
      is_public: true,
      is_published: true,
      data: %{
        "nodes" => [
          %{
            "id" => "1",
            "content" => "Node 1",
            "class" => "origin",
            "user" => "",
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          },
          %{
            "id" => "2",
            "content" => "Node 2",
            "class" => "user",
            "user" => "",
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          },
          %{
            "id" => "3",
            "content" => "Node 3",
            "class" => "user",
            "user" => "",
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          },
          %{
            "id" => "4",
            "content" => "Node 4",
            "class" => "user",
            "user" => "",
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          }
        ],
        "edges" => []
      }
    })
  end

  describe "access control" do
    test "non-admin user is denied access and redirected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Access denied."}}}} =
               live(conn, ~p"/admin/curated")
    end

    test "unauthenticated user is redirected to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/admin/curated")
      assert {:redirect, %{to: to}} = redirect
      assert to =~ "/users/log_in"
    end

    test "admin user can access the page", %{conn: conn} do
      user = user_fixture() |> make_admin()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/admin/curated")
      assert html =~ "Manage Curated Grids"
    end
  end

  describe "add and remove curated entries" do
    setup %{conn: conn} do
      admin = user_fixture() |> make_admin()
      conn = log_in_user(conn, admin)
      graph = create_published_graph("Test Curated Graph #{System.unique_integer([:positive])}")
      %{conn: conn, admin: admin, graph: graph}
    end

    test "searching for graphs returns results", %{conn: conn, graph: graph} do
      {:ok, view, _html} = live(conn, ~p"/admin/curated")

      html =
        view
        |> form("#curated-search-form", %{"search" => graph.title})
        |> render_change()

      assert html =~ graph.title
    end

    test "adding a graph to the curated section", %{conn: conn, graph: graph} do
      {:ok, view, _html} = live(conn, ~p"/admin/curated")

      # Search for the graph first
      view
      |> form("#curated-search-form", %{"search" => graph.title})
      |> render_change()

      # Add to curated section
      html =
        view
        |> element("button[phx-click=add_curated][phx-value-title='#{graph.title}']")
        |> render_click()

      assert html =~ "Added"
      assert html =~ graph.title
    end

    test "removing a graph from the curated section", %{conn: conn, graph: graph, admin: admin} do
      # Add the graph to curated section first
      {:ok, _} =
        Dialectic.DbActions.Graphs.add_curated_grid(%{
          graph_title: graph.title,
          curator_id: admin.id,
          section: "curated",
          note: ""
        })

      {:ok, view, html} = live(conn, ~p"/admin/curated")
      assert html =~ graph.title

      # Remove from curated
      html =
        view
        |> element(
          "button[phx-click=remove_curated][phx-value-title='#{graph.title}'][phx-value-section=curated]"
        )
        |> render_click()

      assert html =~ "Removed"
    end

    test "adding a graph to the featured section", %{conn: conn, graph: graph} do
      {:ok, view, _html} = live(conn, ~p"/admin/curated")

      # Switch to featured section
      view
      |> element("button[phx-click=set_section][phx-value-section=featured]")
      |> render_click()

      # Search for the graph
      view
      |> form("#curated-search-form", %{"search" => graph.title})
      |> render_change()

      # Add to featured section
      html =
        view
        |> element("button[phx-click=add_curated][phx-value-title='#{graph.title}']")
        |> render_click()

      assert html =~ "Added"
      assert html =~ "featured"
    end

    test "empty search returns no results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/curated")

      html =
        view
        |> form("#curated-search-form", %{"search" => ""})
        |> render_change()

      # Should not contain the search results container with graph entries
      refute html =~ "phx-click=\"add_curated\""
    end
  end

  describe "soft delete (hide) functionality" do
    setup %{conn: conn} do
      admin = user_fixture() |> make_admin()
      conn = log_in_user(conn, admin)
      graph = create_published_graph("Hideable Graph #{System.unique_integer([:positive])}")
      %{conn: conn, admin: admin, graph: graph}
    end

    test "hiding a graph from search results", %{conn: conn, graph: graph} do
      {:ok, view, _html} = live(conn, ~p"/admin/curated")

      # Search for the graph first
      view
      |> form("#curated-search-form", %{"search" => graph.title})
      |> render_change()

      # Hide the graph
      html =
        view
        |> element("button[phx-click=soft_delete][phx-value-title='#{graph.title}']")
        |> render_click()

      assert html =~ "Hidden"
      assert html =~ graph.title
    end

    test "hidden graphs appear in the hidden section", %{conn: conn, graph: graph} do
      # Soft delete the graph first
      {:ok, _} = Dialectic.DbActions.Graphs.soft_delete_graph(graph.title)

      {:ok, _view, html} = live(conn, ~p"/admin/curated")

      assert html =~ "Hidden from Homepage"
      assert html =~ graph.title
    end

    test "restoring a hidden graph", %{conn: conn, graph: graph} do
      # Soft delete the graph first
      {:ok, _} = Dialectic.DbActions.Graphs.soft_delete_graph(graph.title)

      {:ok, view, html} = live(conn, ~p"/admin/curated")
      assert html =~ graph.title

      # Restore the graph
      html =
        view
        |> element("button[phx-click=restore_graph][phx-value-title='#{graph.title}']")
        |> render_click()

      assert html =~ "Restored"
    end

    test "hidden graphs do not appear in homepage search", %{conn: _conn, graph: graph} do
      # Verify graph appears before hiding
      results_before = Dialectic.DbActions.Graphs.all_graphs_with_notes(graph.title, limit: 10)
      assert Enum.any?(results_before, fn {g, _, _} -> g.title == graph.title end)

      # Soft delete the graph
      {:ok, _} = Dialectic.DbActions.Graphs.soft_delete_graph(graph.title)

      # Verify graph no longer appears
      results_after = Dialectic.DbActions.Graphs.all_graphs_with_notes(graph.title, limit: 10)
      refute Enum.any?(results_after, fn {g, _, _} -> g.title == graph.title end)
    end
  end
end
