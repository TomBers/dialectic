defmodule DialecticWeb.UserProfileLiveTest do
  use DialecticWeb.ConnCase, async: true

  alias Dialectic.Accounts
  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  @one_pixel_png "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="

  defp create_user_with_username(username, attrs \\ %{}) do
    user = user_fixture(attrs)
    {:ok, user} = Accounts.update_user_profile(user, %{username: username})
    user
  end

  defp create_public_graph(user, title, opts) do
    unique_suffix = System.unique_integer([:positive])
    slug = Keyword.get(opts, :slug, "slug-#{unique_suffix}")
    tags = Keyword.get(opts, :tags, [])
    unique_title = "#{title}-#{unique_suffix}"

    Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
      title: unique_title,
      slug: slug,
      data: %{"nodes" => [%{"id" => "1", "label" => "Node"}]},
      tags: tags,
      is_public: true,
      is_published: true,
      is_deleted: false,
      user_id: user.id
    })
  end

  describe "successful render" do
    test "renders the profile page for a user with a stored username", %{conn: conn} do
      _user = create_user_with_username("profiletest")

      {:ok, _lv, html} = live(conn, ~p"/u/profiletest")

      assert html =~ "profiletest"
      assert html =~ "— Profile"
      assert html =~ "Member since"
      assert html =~ "Grids Created"
      assert html =~ "Ideas Explored"
      assert html =~ "Days Active"
      # Should not see edit link when not logged in
      refute html =~ "Edit Profile"
      # Should see "Graphs by" heading for other users
      assert html =~ "Grids by profiletest"
    end

    test "renders bio when present", %{conn: conn} do
      user = create_user_with_username("biouser")
      {:ok, _} = Accounts.update_user_profile(user, %{username: "biouser", bio: "I love graphs!"})

      {:ok, _lv, html} = live(conn, ~p"/u/biouser")

      assert html =~ "I love graphs!"
    end

    test "renders selected profile banner", %{conn: conn} do
      user = create_user_with_username("banneruser")

      {:ok, _} =
        Accounts.update_user_profile(user, %{
          username: "banneruser",
          profile_banner: "endless-constellation"
        })

      {:ok, _lv, html} = live(conn, ~p"/u/banneruser")

      assert html =~ "/images/profile-banners/endless-constellation.svg"
    end

    test "renders uploaded profile banner before selected SVG banner", %{conn: conn} do
      user = create_user_with_username("uploadedbanner")

      {:ok, user} =
        Accounts.update_user_profile(user, %{
          username: "uploadedbanner",
          profile_banner: "endless-constellation"
        })

      {:ok, user} = Accounts.update_user_banner(user, @one_pixel_png)

      {:ok, _lv, html} = live(conn, ~p"/u/uploadedbanner")

      assert html =~ user.banner_path
      refute html =~ "/images/profile-banners/endless-constellation.svg"
    end

    test "renders manual profile links", %{conn: conn} do
      user = create_user_with_username("linksuser")

      {:ok, _} =
        Accounts.update_user_profile_links(user, [
          %{"label" => "GitHub", "value" => "https://github.com/tomberman"},
          %{"label" => "Email", "value" => "hello@example.com"}
        ])

      {:ok, _lv, html} = live(conn, ~p"/u/linksuser")

      assert html =~ "GitHub"
      assert html =~ "https://github.com/tomberman"
      assert html =~ "Email"
      assert html =~ "mailto:hello@example.com"
    end

    test "renders empty graphs message when user has no public graphs", %{conn: conn} do
      _user = create_user_with_username("emptygraphs")

      {:ok, _lv, html} = live(conn, ~p"/u/emptygraphs")

      assert html =~ "No public grids yet."
    end

    test "renders graphs when user has public graphs", %{conn: conn} do
      user = create_user_with_username("graphuser")
      create_public_graph(user, "My Cool Graph", slug: "my-cool-graph", tags: [])

      {:ok, _lv, html} = live(conn, ~p"/u/graphuser")

      assert html =~ "My Cool Graph"
      refute html =~ "No public graphs yet."
    end

    test "renders common tags when user has tagged graphs", %{conn: conn} do
      user = create_user_with_username("taguser")
      create_public_graph(user, "Tagged Graph 1", slug: "tagged-1", tags: ["elixir", "phoenix"])
      create_public_graph(user, "Tagged Graph 2", slug: "tagged-2", tags: ["elixir", "liveview"])

      {:ok, _lv, html} = live(conn, ~p"/u/taguser")

      assert html =~ "Mainly talking about"
      assert html =~ "elixir"
    end
  end

  describe "missing user redirect" do
    test "redirects to home with flash when username does not exist", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "User not found."}}}} =
               live(conn, ~p"/u/nonexistentuser999")
    end
  end

  describe "own profile vs other profile" do
    test "shows 'Account Settings' link when viewing own profile", %{conn: conn} do
      user = create_user_with_username("ownprofile")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/ownprofile")

      assert html =~ "Account Settings"
      assert html =~ "profile-settings-link"
      assert html =~ "My Public Grids"
    end

    test "does not show 'Account Settings' link when viewing another user's profile", %{
      conn: conn
    } do
      _other_user = create_user_with_username("otheruser")
      viewer = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/u/otheruser")

      refute html =~ "profile-settings-link"
      assert html =~ "Grids by otheruser"
    end

    test "shows 'Create your first grid' only on own empty profile", %{conn: conn} do
      user = create_user_with_username("emptyown")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/emptyown")

      assert html =~ "Create your first grid"
    end

    test "does not show 'Create your first grid' on other user's empty profile", %{conn: conn} do
      _other_user = create_user_with_username("emptyother")
      viewer = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/u/emptyother")

      refute html =~ "Create your first grid"
    end
  end

  describe "case-insensitive username lookup" do
    test "finds user regardless of URL casing", %{conn: conn} do
      _user = create_user_with_username("MixedCase")

      {:ok, _lv, html} = live(conn, ~p"/u/mixedcase")

      assert html =~ "MixedCase"
    end
  end

  describe "graph rendering" do
    test "renders graph links using the graph slug", %{conn: conn} do
      user = create_user_with_username("iduser")
      unique_slug = "test-graph-slug-#{System.unique_integer([:positive])}"
      create_public_graph(user, "Test Graph", slug: unique_slug, tags: [])

      {:ok, _lv, html} = live(conn, ~p"/u/iduser")

      # The graph card links to the slug-based route
      assert html =~ "/g/#{unique_slug}"
    end
  end

  describe "graph deletion" do
    test "shows delete button on own profile for All My Grids section", %{conn: conn} do
      user = create_user_with_username("deleteuser")
      graph = create_public_graph(user, "Graph To Delete", slug: "delete-test", tags: [])

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/deleteuser")

      # Delete button should be visible in All My Grids section
      assert html =~ "delete-grid-btn-"
      assert html =~ graph.title
    end

    test "does not show delete button when viewing another user's profile", %{conn: conn} do
      other_user = create_user_with_username("otherdeleteuser")
      _graph = create_public_graph(other_user, "Other Graph", slug: "other-graph", tags: [])
      viewer = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/u/otherdeleteuser")

      # Delete button should not be visible
      refute html =~ "delete-grid-btn-"
      refute html =~ "delete-public-grid-btn-"
    end

    test "shows delete button in My Public Grids section on own profile", %{conn: conn} do
      user = create_user_with_username("publicdeluser")
      _graph = create_public_graph(user, "Public Graph", slug: "public-delete-test", tags: [])

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/publicdeluser")

      # Delete button should be visible in the public grids section
      assert html =~ "delete-public-grid-btn-public-delete-test"
    end

    test "can delete own graph via confirmation modal", %{conn: conn} do
      user = create_user_with_username("confirmdel")
      graph = create_public_graph(user, "Deletable Graph", slug: "deletable", tags: [])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/confirmdel")

      # Trigger the delete modal
      lv
      |> element("#delete-grid-btn-deletable")
      |> render_click()

      # Confirm the deletion
      html =
        lv
        |> element("#confirm-delete-graph-btn")
        |> render_click()

      # Flash message should appear
      assert html =~ "has been deleted"

      # Verify in database that the graph is soft-deleted
      updated_graph = Dialectic.Repo.get_by(Dialectic.Accounts.Graph, title: graph.title)
      assert updated_graph.is_deleted == true

      # Graph should no longer be visible in the All My Grids section
      # Note: The title might still be in the flash message, so we check specifically
      # that the graph card is gone by checking for the delete button
      refute html =~ "delete-grid-btn-deletable"
    end

    test "can cancel graph deletion", %{conn: conn} do
      user = create_user_with_username("canceluser")
      graph = create_public_graph(user, "Keep This Graph", slug: "keep-graph", tags: [])

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/canceluser")

      # Trigger the delete modal
      lv
      |> element("#delete-grid-btn-keep-graph")
      |> render_click()

      # Cancel the deletion
      html =
        lv
        |> render_click("cancel_delete")

      # Graph should still be visible
      assert html =~ graph.title

      # Verify in database that the graph is NOT deleted
      unchanged_graph = Dialectic.Repo.get_by(Dialectic.Accounts.Graph, title: graph.title)
      refute unchanged_graph.is_deleted
    end
  end
end
