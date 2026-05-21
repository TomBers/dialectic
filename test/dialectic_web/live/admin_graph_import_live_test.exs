defmodule DialecticWeb.AdminGraphImportLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  alias Dialectic.Accounts.Graph
  alias Dialectic.Repo

  defp make_admin(user) do
    user
    |> Ecto.Changeset.change(%{is_admin: true})
    |> Repo.update!()
  end

  defp unique_title(prefix \\ "Imported Live Graph") do
    "#{prefix} #{System.unique_integer([:positive])}"
  end

  defp valid_node(id, attrs) do
    Map.merge(
      %{
        "id" => id,
        "content" => "Node #{id}",
        "class" => "origin",
        "user" => "",
        "parent" => nil,
        "noted_by" => [],
        "deleted" => false,
        "compound" => false
      },
      attrs
    )
  end

  defp valid_graph do
    %{
      "nodes" => [
        valid_node("1", %{"content" => "Root"}),
        valid_node("2", %{"content" => "Child", "class" => "premise"})
      ],
      "edges" => [%{"data" => %{"id" => "e1-2", "source" => "1", "target" => "2"}}]
    }
  end

  defp upload_graph(view, data, name \\ "graph.json") do
    content = Jason.encode!(data)

    upload =
      file_input(view, "#graph-import-form", :graph_json, [
        %{
          name: name,
          content: content,
          size: byte_size(content),
          type: "application/json",
          last_modified: 1_700_000_000_000
        }
      ])

    render_upload(upload, name)
  end

  describe "access control" do
    test "non-admin user is denied access and redirected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Access denied."}}}} =
               live(conn, ~p"/admin/graphs/import")
    end

    test "unauthenticated user is redirected to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/admin/graphs/import")
      assert {:redirect, %{to: to}} = redirect
      assert to =~ "/users/log_in"
    end

    test "admin user can access the page", %{conn: conn} do
      admin = user_fixture() |> make_admin()
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/admin/graphs/import")

      assert html =~ "Import Graph from JSON"
      assert html =~ "graph-import-form"
    end
  end

  describe "import flow" do
    setup %{conn: conn} do
      admin = user_fixture() |> make_admin()
      %{conn: log_in_user(conn, admin), admin: admin}
    end

    test "previews and imports a valid graph upload", %{conn: conn, admin: admin} do
      title = unique_title()
      {:ok, view, _html} = live(conn, ~p"/admin/graphs/import")

      assert upload_graph(view, valid_graph()) =~ "100%"

      view
      |> form("#graph-import-form", %{
        "graph_import" => %{
          "title" => title,
          "slug" => "",
          "tags" => "philosophy, leisure",
          "prompt_mode" => "university",
          "is_public" => "true",
          "is_published" => "true"
        }
      })
      |> render_change()

      html = render_click(view, "preview")
      assert html =~ "Preview"
      assert html =~ "Nodes"
      assert html =~ "2"
      assert html =~ "Idea nodes"

      html =
        view
        |> form("#graph-import-form", %{
          "graph_import" => %{
            "title" => title,
            "slug" => "",
            "tags" => "philosophy, leisure",
            "prompt_mode" => "university",
            "is_public" => "true",
            "is_published" => "true"
          }
        })
        |> render_submit()

      assert html =~ "Imported"
      assert html =~ title

      graph = Repo.get!(Graph, title)
      assert graph.user_id == admin.id
      assert graph.tags == ["philosophy", "leisure"]
      assert graph.prompt_mode == "university"
      assert graph.is_public
      assert graph.is_published
      assert length(graph.data["nodes"]) == 2
      assert length(graph.data["edges"]) == 1
    end

    test "shows an upload validation error for malformed graph JSON", %{conn: conn} do
      title = unique_title("Bad Live Graph")
      {:ok, view, _html} = live(conn, ~p"/admin/graphs/import")

      bad_graph = %{valid_graph() | "nodes" => ["not-a-node"]}
      assert upload_graph(view, bad_graph, "bad-graph.json") =~ "100%"

      view
      |> form("#graph-import-form", %{
        "graph_import" => %{
          "title" => title,
          "slug" => "",
          "tags" => "",
          "prompt_mode" => "university",
          "is_public" => "true",
          "is_published" => "true"
        }
      })
      |> render_change()

      html = render_click(view, "preview")

      assert html =~ "Every node must be an object."
      refute Repo.get(Graph, title)
    end

    test "replaces cached preview data when a new file is selected", %{conn: conn} do
      title = unique_title("Cache Safety")
      {:ok, view, _html} = live(conn, ~p"/admin/graphs/import")

      assert upload_graph(view, valid_graph(), "first.json") =~ "100%"

      view
      |> form("#graph-import-form", %{
        "graph_import" => %{
          "title" => title,
          "slug" => "",
          "tags" => "",
          "prompt_mode" => "university",
          "is_public" => "true",
          "is_published" => "true"
        }
      })
      |> render_change()

      assert render_click(view, "preview") =~ "2"

      second_graph = %{
        "nodes" => [valid_node("1", %{"content" => "Only node"})],
        "edges" => []
      }

      assert upload_graph(view, second_graph, "second.json") =~ "100%"

      html =
        view
        |> form("#graph-import-form", %{
          "graph_import" => %{
            "title" => title,
            "slug" => "",
            "tags" => "",
            "prompt_mode" => "university",
            "is_public" => "true",
            "is_published" => "true"
          }
        })
        |> render_submit()

      assert html =~ "Imported"
      graph = Repo.get!(Graph, title)
      assert length(graph.data["nodes"]) == 1
      assert graph.data["nodes"] |> hd() |> Map.fetch!("content") == "Only node"
    end
  end
end
