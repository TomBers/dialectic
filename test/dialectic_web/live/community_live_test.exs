defmodule DialecticWeb.CommunityLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Repo

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
