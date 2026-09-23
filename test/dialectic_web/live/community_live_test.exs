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
    test "partner grids remain available through the format filter", %{conn: conn} do
      unique = System.unique_integer([:positive])

      graphs =
        for position <- 0..3 do
          graph =
            Dialectic.GraphFixtures.insert_graph(%{
              title: "Community Partner Grid #{unique} #{position}",
              slug: "community-partner-grid-#{unique}-#{position}"
            })

          {:ok, _curated_grid} =
            Graphs.add_curated_grid(%{
              graph_title: graph.title,
              section: "featured",
              position: position
            })

          graph
        end

      curated_graph =
        Dialectic.GraphFixtures.insert_graph(%{
          title: "Community Curated Grid #{unique}",
          slug: "community-curated-grid-#{unique}"
        })

      {:ok, _curated_grid} =
        Graphs.add_curated_grid(%{
          graph_title: curated_graph.title,
          section: "curated",
          position: 0
        })

      {:ok, view, _html} = live(conn, ~p"/community?category=partners")

      assert has_element?(view, ~s(#community-format-partners[aria-current="page"]))
      refute has_element?(view, "#community-featured-section")
      refute has_element?(view, "#community-grid-#{curated_graph.slug}")

      for graph <- graphs do
        assert has_element?(view, "#community-grid-#{graph.slug}")
      end
    end

    test "partner results show a title link without date metadata", %{conn: conn} do
      graph =
        Dialectic.GraphFixtures.insert_graph(%{
          title: "Dated partner grid #{System.unique_integer([:positive])}",
          slug: "dated-partner-grid-#{System.unique_integer([:positive])}"
        })
        |> Ecto.Changeset.change(%{
          inserted_at: ~U[2024-01-15 12:00:00Z],
          updated_at: ~U[2026-08-15 12:00:00Z]
        })
        |> Repo.update!()

      {:ok, _curated_grid} =
        Graphs.add_curated_grid(%{
          graph_title: graph.title,
          section: "featured",
          position: 0
        })

      {:ok, view, _html} = live(conn, ~p"/community?category=partners")
      selector = "#community-grid-#{graph.slug}"

      assert has_element?(view, selector <> "-title")
      refute has_element?(view, selector <> ~s( [aria-label^="Created "]))
      refute has_element?(view, selector, "Aug 2026")
    end

    test "mounts and filters by category and search", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      assert has_element?(view, "#community-page-title", "Community grids")
      assert has_element?(view, "#community-search-form")
      assert has_element?(view, "#community-search")

      assert has_element?(
               view,
               "#community-results-heading",
               "Curated grids"
             )

      render_patch(view, ~p"/community?category=deep_dives")
      assert has_element?(view, "#community-results-heading", "Large grids")

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

      send(view.pid, {:tag_generation_timeout, graph.title})
      assert has_element?(view, button_selector, "Generate tags")
      refute has_element?(view, button_selector <> "[disabled]")

      view
      |> element(button_selector)
      |> render_click()

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

    test "capitalizes the first character of displayed grid titles", %{conn: conn} do
      graph =
        Dialectic.GraphFixtures.insert_graph(%{
          title: "tell me about gorillas #{System.unique_integer([:positive])}",
          slug: "lowercase-community-title-#{System.unique_integer([:positive])}"
        })

      {:ok, view, _html} = live(conn, ~p"/community?search=#{graph.title}")

      assert has_element?(view, "#community-grid-#{graph.slug}", "Tell me about gorillas")
    end

    test "keeps grid metadata minimal", %{conn: conn} do
      graph =
        Dialectic.GraphFixtures.insert_graph(%{
          title: "Creation dated grid #{System.unique_integer([:positive])}",
          slug: "creation-dated-grid-#{System.unique_integer([:positive])}"
        })

      graph =
        graph
        |> Ecto.Changeset.change(%{
          inserted_at: ~U[2024-01-15 12:00:00Z],
          updated_at: ~U[2026-08-15 12:00:00Z]
        })
        |> Repo.update!()

      {:ok, view, _html} = live(conn, ~p"/community?search=#{graph.title}")
      meta_selector = "#community-grid-#{graph.slug} [data-role=community-grid-meta]"

      assert has_element?(view, meta_selector, "1 idea")
      refute has_element?(view, meta_selector, "Jan 2024")
      refute has_element?(view, meta_selector, "Aug 2026")
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
      assert has_element?(view, selector <> ~s([data-role="community-grid-row"]))
      assert has_element?(view, selector <> " [data-role=community-grid-meta]", "1 idea")
      assert has_element?(view, selector <> "-title", title)
      refute has_element?(view, selector <> ~s( a[aria-label^="Read grid: "]))
      refute has_element?(view, selector <> ~s( [aria-label^="Result "]))

      render_patch(view, ~p"/community?search=Freud")

      assert has_element?(view, selector)
      assert has_element?(view, "#community-results-heading", "Search results for \"Freud\"")
    end
  end
end
