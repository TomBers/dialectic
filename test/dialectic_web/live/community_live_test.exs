defmodule DialecticWeb.CommunityLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Repo

  defp make_admin(user) do
    user
    |> Ecto.Changeset.change(%{is_admin: true})
    |> Repo.update!()
  end

  describe "community page" do
    test "mounts and filters by category and search", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      assert has_element?(view, "#community-search")

      assert has_element?(
               view,
               "#community-results-heading",
               "Find an idea to explore and extend"
             )

      render_patch(view, ~p"/community?category=deep_dives")
      assert has_element?(view, "#community-results-heading", "Deep dives")

      render_patch(view, ~p"/community?search=ethics")
      assert has_element?(view, "#community-results-heading", "Search results for \"ethics\"")
    end

    test "lets admins generate missing tags and updates the row when they arrive", %{conn: conn} do
      graph =
        Dialectic.GraphFixtures.insert_graph(%{
          title: "Untagged community grid #{System.unique_integer([:positive])}",
          tags: []
        })

      admin = user_fixture() |> make_admin()

      {:ok, view, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/community?search=#{graph.title}")

      row_selector = "#community-grid-#{graph.slug}"
      button_selector = row_selector <> "-generate-tags"

      assert has_element?(view, button_selector, "Generate tags")

      view
      |> element(button_selector)
      |> render_click()

      assert has_element?(view, button_selector <> "[disabled]", "Generating...")

      send(view.pid, {:tags_updated, graph.title, ["Philosophy"]})
      refute has_element?(view, button_selector)
    end

    test "does not expose tag generation to public visitors", %{conn: conn} do
      graph =
        Dialectic.GraphFixtures.insert_graph(%{
          title: "Public untagged grid #{System.unique_integer([:positive])}",
          tags: []
        })

      {:ok, view, _html} = live(conn, ~p"/community?search=#{graph.title}")

      refute has_element?(view, "#community-grid-#{graph.slug}-generate-tags")
    end

    test "finds a small grid by title when it is also browsable by topic", %{conn: conn} do
      title = "Freud and the unconscious #{System.unique_integer([:positive])}"
      slug = Graphs.generate_unique_slug(title)

      graph =
        %Graph{}
        |> Graph.changeset(%{
          title: title,
          slug: slug,
          tags: ["psychology"],
          data: %{
            "nodes" => [
              %{
                "id" => "1",
                "content" => "## #{title}",
                "class" => "origin",
                "user" => "",
                "parent" => nil,
                "noted_by" => [],
                "deleted" => false,
                "compound" => false
              }
            ],
            "edges" => []
          },
          is_public: true,
          is_published: true,
          is_deleted: false,
          is_locked: false
        })
        |> Repo.insert!()

      {:ok, view, _html} = live(conn, ~p"/community?tag=psychology")
      selector = "#community-grid-#{graph.slug}"
      assert has_element?(view, selector)

      render_patch(view, ~p"/community?search=Freud")

      assert has_element?(view, selector)
      assert has_element?(view, "#community-results-heading", "Search results for \"Freud\"")
    end
  end
end
