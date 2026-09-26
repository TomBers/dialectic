defmodule DialecticWeb.UserProfileLiveTest do
  use DialecticWeb.ConnCase, async: true

  alias Dialectic.Accounts
  alias Dialectic.DbActions.Notes
  alias Dialectic.Follows
  alias Dialectic.Highlights
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
    nodes = Keyword.get(opts, :nodes, [%{"id" => "1", "label" => "Node"}])
    is_public = Keyword.get(opts, :is_public, true)
    unique_title = "#{title}-#{unique_suffix}"

    Dialectic.Repo.insert!(%Dialectic.Accounts.Graph{
      title: unique_title,
      slug: slug,
      data: %{"nodes" => nodes},
      tags: tags,
      is_public: is_public,
      is_published: true,
      is_deleted: false,
      user_id: user.id
    })
  end

  defp create_private_graph(user, title, opts) do
    create_public_graph(user, title, Keyword.put(opts, :is_public, false))
  end

  describe "successful render" do
    test "renders the profile page for a user with a stored username", %{conn: conn} do
      _user = create_user_with_username("profiletest")

      {:ok, lv, html} = live(conn, ~p"/u/profiletest")

      assert html =~ "profiletest"
      assert html =~ "— Profile"
      assert html =~ "Member since"
      assert html =~ "Grids"
      assert html =~ "Ideas"
      assert html =~ "Days"
      # Should not see edit link when not logged in
      refute html =~ "Edit Profile"
      assert has_element?(lv, "#public-grids-content")
      assert has_element?(lv, "h2", "Public grids")
    end

    test "renders bio when present", %{conn: conn} do
      user = create_user_with_username("biouser")
      {:ok, _} = Accounts.update_user_profile(user, %{username: "biouser", bio: "I love graphs!"})

      {:ok, lv, _html} = live(conn, ~p"/u/biouser")

      assert has_element?(lv, "#profile-bio.text-2xl", "I love graphs!")
    end

    test "scales bio text for medium and long bios", %{conn: conn} do
      medium_bio =
        "I build public thinking maps for careful questions, useful disagreements, and shared curiosity."

      long_bio =
        "I build public thinking maps for careful questions, useful disagreements, shared curiosity, and the patient work of turning scattered notes into durable conversations that other people can revisit."

      medium_user = create_user_with_username("mediumbio")
      long_user = create_user_with_username("longbio")

      {:ok, _} =
        Accounts.update_user_profile(medium_user, %{username: "mediumbio", bio: medium_bio})

      {:ok, _} = Accounts.update_user_profile(long_user, %{username: "longbio", bio: long_bio})

      {:ok, medium_lv, _html} = live(conn, ~p"/u/mediumbio")
      {:ok, long_lv, _html} = live(conn, ~p"/u/longbio")

      assert has_element?(medium_lv, "#profile-bio.text-xl", medium_bio)
      assert has_element?(long_lv, "#profile-bio.text-lg", long_bio)
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

      {:ok, lv, html} = live(conn, ~p"/u/graphuser")

      assert html =~ "My Cool Graph"
      refute html =~ "No public graphs yet."
      assert has_element?(lv, "#public-grids-content:not(.hidden)")
      assert has_element?(lv, "#profile-public-grid-list")
      assert has_element?(lv, ~s([data-role="profile-public-grid-row"]), "My Cool Graph")
    end

    test "renders common tags when user has tagged graphs", %{conn: conn} do
      user = create_user_with_username("taguser")
      create_public_graph(user, "Tagged Graph 1", slug: "tagged-1", tags: ["elixir", "phoenix"])
      create_public_graph(user, "Tagged Graph 2", slug: "tagged-2", tags: ["elixir", "liveview"])

      {:ok, _lv, html} = live(conn, ~p"/u/taguser")

      assert html =~ "Topics"
      assert html =~ "elixir"
    end

    test "renders metadata-driven start here cards for public graphs", %{conn: conn} do
      user = create_user_with_username("starthere")

      create_public_graph(user, "Seed Question",
        slug: "seed-question",
        tags: ["attention"],
        nodes: [%{"id" => "1", "label" => "Node"}]
      )

      create_public_graph(user, "Deep Question",
        slug: "deep-question",
        tags: ["media", "psychology"],
        nodes: Enum.map(1..22, fn id -> %{"id" => Integer.to_string(id), "label" => "Node"} end)
      )

      {:ok, lv, html} = live(conn, ~p"/u/starthere")

      assert html =~ "Start here"
      assert html =~ "Entry points"
      assert html =~ "Deep Question"
      assert html =~ "Deep dive"
      assert html =~ "find thinking on"
      assert html =~ "public grids"
      assert has_element?(lv, ~s([data-role="featured-grid-card"]), "connected ideas")
      assert has_element?(lv, ~s([data-role="featured-grid-card"] strong), "22")
    end
  end

  describe "missing user redirect" do
    test "redirects to home with flash when username does not exist", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "User not found."}}}} =
               live(conn, ~p"/u/nonexistentuser999")
    end
  end

  describe "own profile vs other profile" do
    test "always shows the public social profile, including for its owner", %{conn: conn} do
      user = create_user_with_username("ownprofile")
      private = create_private_graph(user, "Private notes", slug: "private-notes", tags: [])
      public = create_public_graph(user, "Public work", slug: "public-work", tags: [])
      {:ok, lv, _} = conn |> log_in_user(user) |> live(~p"/u/ownprofile")
      assert has_element?(lv, "#public-profile-header")
      assert has_element?(lv, "#profile-settings-link", "Edit public profile")
      assert has_element?(lv, "#profile-public-grid-row-#{public.slug}")
      refute has_element?(lv, "#profile-public-grid-row-#{private.slug}")
      refute has_element?(lv, "#profile-view-switcher")
      refute has_element?(lv, "#profile-thinking-library")
      refute has_element?(lv, "#profile-owned-grids")
      refute has_element?(lv, "#delete-graph-modal")
    end

    test "does not show 'Account Settings' link when viewing another user's profile", %{
      conn: conn
    } do
      _other_user = create_user_with_username("otheruser")
      viewer = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/u/otheruser")

      refute has_element?(lv, "#profile-settings-link")
      assert has_element?(lv, "#public-grids-content")
    end

    test "keeps grid creation out of the public profile", %{conn: conn} do
      user = create_user_with_username("emptyown")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/emptyown")

      refute html =~ "Start a grid"
    end

    test "does not show 'Create your first grid' on other user's empty profile", %{conn: conn} do
      _other_user = create_user_with_username("emptyother")
      viewer = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/u/emptyother")

      refute html =~ "Start a grid"
    end

    test "can follow and unfollow another user's profile", %{conn: conn} do
      profile_user = create_user_with_username("followprofile")
      viewer = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/u/followprofile")

      assert has_element?(lv, "#profile-follow-button", "Follow")

      lv
      |> element("#profile-follow-button")
      |> render_click()

      assert Follows.following_user?(viewer, profile_user)
      assert has_element?(lv, "#profile-follow-button", "Following")
      assert has_element?(lv, "#profile-followers-stat", "1")

      lv
      |> element("#profile-follow-button")
      |> render_click()

      refute Follows.following_user?(viewer, profile_user)
      assert has_element?(lv, "#profile-follow-button", "Follow")
      assert has_element?(lv, "#profile-followers-stat", "0")
    end

    test "shows following and follower stats with modal user lists", %{conn: conn} do
      profile_user = create_user_with_username("socialprofile")
      followed_user = create_user_with_username("profilefollowing")
      follower_user = create_user_with_username("profilefollower")

      assert {:ok, _follow} = Follows.follow_user(profile_user, followed_user)
      assert {:ok, _follow} = Follows.follow_user(follower_user, profile_user)

      {:ok, lv, _html} = live(conn, ~p"/u/socialprofile")

      assert has_element?(lv, "#profile-following-stat", "1")
      assert has_element?(lv, "#profile-followers-stat", "1")

      assert has_element?(lv, "#profile-social-following-panel-title", "Following")

      assert has_element?(
               lv,
               "#profile-social-following-panel-user-#{followed_user.id}",
               "profilefollowing"
             )

      refute has_element?(lv, "#profile-social-following-panel-user-#{follower_user.id}")

      assert has_element?(lv, "#profile-social-followers-panel-title", "Followers")

      assert has_element?(
               lv,
               "#profile-social-followers-panel-user-#{follower_user.id}",
               "profilefollower"
             )

      refute has_element?(lv, "#profile-social-followers-panel-user-#{followed_user.id}")
    end

    test "crafted unauthenticated profile follow events do not crash", %{conn: conn} do
      _profile_user = create_user_with_username("craftedfollow")

      {:ok, lv, _html} = live(conn, ~p"/u/craftedfollow")

      assert render_click(lv, "follow_profile") =~ "Log in to follow profiles."
      assert render_click(lv, "unfollow_profile") =~ "Log in to manage followed profiles."
    end

    test "keeps private activity in My Learning", %{conn: conn} do
      user = create_user_with_username("activitylink")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/u/activitylink")

      refute has_element?(lv, ~s(#profile-activity-link[href="/activity"]))
    end

    test "saved bookmarks and highlights live in My Learning and never the public profile", %{
      conn: conn
    } do
      user = create_user_with_username("highlightprofile")

      graph =
        create_public_graph(user, "Quote Grid",
          slug: "quote-grid",
          tags: [],
          nodes: [
            %{
              "id" => "quote-node",
              "content" => "# Source Node Title\n\nBody text."
            }
          ]
        )

      {:ok, note} = Notes.add_note(graph.title, "quote-node", user)

      {:ok, highlight} =
        Highlights.create_highlight(%{
          mudg_id: graph.title,
          node_id: "quote-node",
          text_source_type: "node",
          text_source_id: "quote-node",
          selection_start: 0,
          selection_end: 21,
          selected_text_snapshot: "This is a saved quote.",
          note: "A useful saved thought.",
          created_by_user_id: user.id
        })

      conn = log_in_user(conn, user)
      {:ok, profile, _} = live(conn, ~p"/u/highlightprofile")
      refute has_element?(profile, "#profile-thinking-library")
      refute has_element?(profile, "#learning-bookmark-#{note.id}")
      refute has_element?(profile, "#learning-highlight-#{highlight.id}")
      {:ok, learning, _} = live(conn, ~p"/my/learning")
      assert has_element?(learning, "#learning-bookmark-#{note.id}", "Source Node Title")

      assert has_element?(
               learning,
               "#learning-highlight-#{highlight.id}",
               "This is a saved quote."
             )

      assert has_element?(
               learning,
               "#learning-highlight-#{highlight.id}",
               "A useful saved thought."
             )

      assert has_element?(
               learning,
               ~s(#learning-bookmark-#{note.id}-open[href="/g/quote-grid?node=quote-node"])
             )

      assert has_element?(
               learning,
               ~s(#learning-highlight-#{highlight.id}-open[href="/g/quote-grid?node=quote-node&highlight=#{highlight.id}"])
             )
    end

    test "followed grids live in My Learning", %{conn: conn} do
      user = create_user_with_username("followedgridprofile")
      graph_author = create_user_with_username("followedgridauthor")

      followed_graph =
        create_public_graph(graph_author, "Followed Grid",
          slug: "followed-grid-link",
          tags: ["attention"]
        )

      assert {:ok, _follow} = Follows.follow_graph(user, followed_graph)

      conn = log_in_user(conn, user)
      {:ok, profile, _} = live(conn, ~p"/u/followedgridprofile")
      refute has_element?(profile, "#profile-followed-grids")
      {:ok, learning, _} = live(conn, ~p"/my/learning")
      id = "learning-grid-" <> Base.url_encode64(followed_graph.title, padding: false)
      assert has_element?(learning, "##{id}-open[href='/g/followed-grid-link']")
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
end
