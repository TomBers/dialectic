defmodule DialecticWeb.UserProfileLiveTest do
  use DialecticWeb.ConnCase, async: true

  alias Dialectic.Accounts
  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

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
    test "shows 'Edit Profile' link when viewing own profile", %{conn: conn} do
      user = create_user_with_username("ownprofile")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/ownprofile")

      assert html =~ "Edit Profile"
      assert html =~ "edit-profile-link"
      assert html =~ "My Public Grids"
    end

    test "does not show 'Edit Profile' link when viewing another user's profile", %{conn: conn} do
      _other_user = create_user_with_username("otheruser")
      viewer = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/u/otheruser")

      refute html =~ "edit-profile-link"
      assert html =~ "Grids by otheruser"
    end

    test "shows 'Create your first graph' only on own empty profile", %{conn: conn} do
      user = create_user_with_username("emptyown")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/emptyown")

      assert html =~ "Create your first graph"
    end

    test "does not show 'Create your first graph' on other user's empty profile", %{conn: conn} do
      _other_user = create_user_with_username("emptyother")
      viewer = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/u/emptyother")

      refute html =~ "Create your first graph"
    end
  end

  describe "case-insensitive username lookup" do
    test "finds user regardless of URL casing", %{conn: conn} do
      _user = create_user_with_username("MixedCase")

      {:ok, _lv, html} = live(conn, ~p"/u/mixedcase")

      assert html =~ "MixedCase"
    end
  end

  describe "theme support" do
    test "applies theme classes when user has a non-default theme", %{conn: conn} do
      user = create_user_with_username("themeduser")
      {:ok, _} = Accounts.update_user_profile(user, %{username: "themeduser", theme: "indigo"})

      {:ok, _lv, html} = live(conn, ~p"/u/themeduser")

      assert html =~ "from-indigo"
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
end
