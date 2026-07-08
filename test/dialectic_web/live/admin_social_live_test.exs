defmodule DialecticWeb.AdminSocialLiveTest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  alias Dialectic.Content.DraftGenerator
  alias Dialectic.GraphFixtures
  alias Dialectic.Highlights
  alias Dialectic.Repo

  defmodule FakeGenerator do
    def generate_pack(graph, opts) do
      posts =
        opts
        |> Keyword.fetch!(:platforms)
        |> Enum.map(fn platform ->
          %{
            graph_title: graph.title,
            platform: platform,
            platform_label: DraftGenerator.platform_label(platform),
            format: DraftGenerator.platform_format(platform),
            title: "#{DraftGenerator.platform_label(platform)} post",
            body:
              "Post for #{graph.title} on #{platform}\n\n#{opts[:url]}?utm_source=#{platform}",
            excerpt: "A test hook for #{platform}",
            utm_source: platform,
            utm_campaign: "content_studio",
            metadata: %{"post_type" => opts[:post_type], "source" => "test"}
          }
        end)

      {:ok, posts}
    end
  end

  defp make_admin(user) do
    user
    |> Ecto.Changeset.change(%{is_admin: true})
    |> Repo.update!()
  end

  defp content_graph(title) do
    GraphFixtures.insert_graph(%{
      title: title,
      is_public: true,
      is_published: true,
      data: %{
        "nodes" => [
          %{
            "id" => "1",
            "content" => "## Should AI tutors teach critical thinking?",
            "class" => "origin",
            "user" => "",
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          },
          %{
            "id" => "2",
            "content" =>
              "AI tutors can personalize feedback at scale.\n\n## Follow-up questions\n1. What evidence shows AI tutors improve transfer?\n2. When does help become dependency?\n3. How should teachers audit generated explanations?",
            "class" => "answer",
            "user" => "",
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          },
          %{
            "id" => "3",
            "content" => "Students may outsource the productive struggle of learning.",
            "class" => "antithesis",
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

  setup do
    original_generator = Application.get_env(:dialectic, :content_post_generator)
    Application.put_env(:dialectic, :content_post_generator, FakeGenerator)

    on_exit(fn ->
      if original_generator do
        Application.put_env(:dialectic, :content_post_generator, original_generator)
      else
        Application.delete_env(:dialectic, :content_post_generator)
      end
    end)
  end

  describe "access control" do
    test "non-admin user is denied access and redirected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "Access denied."}}}} =
               live(conn, ~p"/admin/social")
    end

    test "unauthenticated user is redirected to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/admin/social")
      assert {:redirect, %{to: to}} = redirect
      assert to =~ "/users/log_in"
    end

    test "admin user can access the page with no platforms selected", %{conn: conn} do
      admin = user_fixture() |> make_admin()
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/admin/social")

      assert html =~ "Content Studio"
      assert html =~ "content-generate-form"
      assert html =~ "Nothing is selected by default"
      refute html =~ ~s(id="content-platform-x" checked)
    end
  end

  describe "post generation" do
    setup %{conn: conn} do
      admin = user_fixture() |> make_admin()
      graph = content_graph("AI Tutor Content Pack #{System.unique_integer([:positive])}")

      %{conn: log_in_user(conn, admin), admin: admin, graph: graph}
    end

    test "admin can choose platforms and generate post copy", %{
      conn: conn,
      graph: graph,
      admin: admin
    } do
      {:ok, _highlight} =
        Highlights.create_highlight(%{
          mudg_id: graph.title,
          node_id: "2",
          text_source_type: "node",
          selection_start: 0,
          selection_end: 23,
          selected_text_snapshot: "AI tutors can personalize feedback at scale.",
          created_by_user_id: admin.id
        })

      {:ok, view, _html} = live(conn, ~p"/admin/social")

      html =
        view
        |> form("#content-graph-search-form", %{"search" => graph.title})
        |> render_change()

      assert html =~ graph.title

      html =
        view
        |> element("button[phx-click=select_graph][phx-value-title='#{graph.title}']")
        |> render_click()

      assert html =~ graph.title
      assert html =~ "Key follow-up questions"
      assert html =~ "What evidence shows AI tutors improve transfer?"
      assert html =~ "/g/#{graph.slug}/follow-up-card.svg"
      assert html =~ "Visual assets"
      assert html =~ "/g/#{graph.slug}/share-card.svg"
      assert html =~ "/g/#{graph.slug}/highlights/"
      refute html =~ "/g/#{graph.slug}/full-grid.svg"
      assert html =~ "AI tutors can personalize feedback"
      assert html =~ "Download PNG"
      refute html =~ "Focus node"
      refute html =~ "Saved drafts"

      view |> element("#content-platform-x") |> render_click()
      view |> element("#content-platform-instagram") |> render_click()
      view |> element("#content-platform-linkedin") |> render_click()
      view |> element("#content-platform-substack") |> render_click()

      html =
        view
        |> form("#content-generate-form", %{
          "content_generation" => %{"post_type" => "question_hook"}
        })
        |> render_submit()

      assert html =~ "Generated 4 posts"
      assert html =~ "X post"
      assert html =~ "Instagram post"
      assert html =~ "Substack post"
      assert html =~ "generated-post-0"
      refute html =~ "Save draft"
    end
  end
end
