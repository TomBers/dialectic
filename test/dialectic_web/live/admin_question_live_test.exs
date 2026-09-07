defmodule DialecticWeb.AdminQuestionLiveTest do
  use DialecticWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Dialectic.QuestionPageFixtures
  alias Dialectic.QuestionPages

  setup do
    previous = Application.get_env(:dialectic, :question_page_generator)

    Application.put_env(
      :dialectic,
      :question_page_generator,
      Dialectic.Test.QuestionPageGenerator
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:dialectic, :question_page_generator, previous),
        else: Application.delete_env(:dialectic, :question_page_generator)

      Application.delete_env(:dialectic, :question_page_test_mode)
    end)

    %{admin: admin_fixture(), graph: graph_fixture()}
  end

  test "only authenticated admins can open the publisher", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, "/admin/questions")
    conn = log_in_user(conn, Dialectic.AccountsFixtures.user_fixture())
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/admin/questions")
  end

  test "generate, edit, preview, publish and discover a second question", %{
    conn: conn,
    admin: admin,
    graph: graph
  } do
    {:ok, view, _} = live(log_in_user(conn, admin), "/admin/questions")
    view |> form("#question-grid-search", search: %{query: graph.title}) |> render_submit()
    view |> element("#question-grid-#{graph.slug}") |> render_click()
    assert_patch(view, "/admin/questions?grid=#{graph.slug}")
    view |> form("#question-source-selection", %{"selection" => selection()}) |> render_submit()
    render_async(view)
    assert has_element?(view, "#question-draft-form")
    assert has_element?(view, "#question-preview-title", graph.title)
    refute has_element?(view, "#question-open-published")

    view
    |> form("#question-draft-form", content: %{summary: "An editor checked this answer."})
    |> render_change()

    assert has_element?(view, "#question-preview-answer", "An editor checked this answer.")

    view
    |> form("#question-draft-form")
    |> render_submit(%{"intent" => "publish", "reviewed" => "true"})

    assert has_element?(view, "#question-open-published[href='/questions/#{graph.slug}']")

    {:ok, public, _} = live(conn, "/questions/#{graph.slug}")
    assert has_element?(public, "#public-question-source-grid[href='/g/#{graph.slug}']")
    assert has_element?(public, "#public-question-answer", "An editor checked this answer.")
    assert has_element?(public, "#public-question-evidence-0 a[href='https://example.org/study']")
    assert has_element?(public, "#public-question-answer-node[href='/g/#{graph.slug}?node=2']")
    assert has_element?(public, "#public-question-path-0 a[href='/g/#{graph.slug}?node=4']")
    assert has_element?(public, "#public-question-exercise-answer > summary")

    for route <- ["/", "/community"] do
      {:ok, listing, _} = live(conn, route)
      assert has_element?(listing, "a[href='/questions/#{graph.slug}']")
    end

    assert conn |> get("/sitemap.xml") |> response(200) =~ "/questions/#{graph.slug}"
  end

  test "generation stays responsive and failure preserves the draft", %{
    conn: conn,
    admin: admin,
    graph: graph
  } do
    page = draft_fixture(admin, graph)
    Application.put_env(:dialectic, :question_page_test_mode, {:pause, self()})
    {:ok, view, _} = live(log_in_user(conn, admin), "/admin/questions?grid=#{graph.slug}")
    view |> form("#question-source-selection", %{"selection" => selection()}) |> render_submit()
    assert_receive {:question_generation_started, worker}
    assert has_element?(view, "#question-generating[role='status']")
    assert has_element?(view, "#question-draft-form fieldset[disabled]")
    send(worker, :continue)
    render_async(view)
    refute has_element?(view, "#question-generating")

    Application.put_env(:dialectic, :question_page_test_mode, :fail)
    view |> form("#question-source-selection", %{"selection" => selection()}) |> render_submit()
    render_async(view)
    assert has_element?(view, "#flash-error")
    assert has_element?(view, "#question-preview-answer", page.draft["summary"])
  end

  test "editing several sections preserves their nodes and can clear source links", %{
    conn: conn,
    admin: admin,
    graph: graph
  } do
    selected = %{selection() | "evidence" => ["3", "2"], "paths" => ["4", "2"]}
    {:ok, source, version} = QuestionPages.prepare(admin, graph.slug, selected)
    {:ok, _page} = QuestionPages.save_generated(admin, source, version, content_attrs(source))
    {:ok, view, _} = live(log_in_user(conn, admin), "/admin/questions?grid=#{graph.slug}")

    view
    |> form("#question-draft-form", %{
      "content" => %{
        "evidence" => %{
          "0" => %{"body" => "An edited finding with no verified links.", "source_ids" => [""]},
          "1" => %{"body" => "A different argument from the central answer."}
        }
      }
    })
    |> render_change()

    view
    |> form("#question-draft-form")
    |> render_submit(%{"intent" => "publish", "reviewed" => "true"})

    {:ok, public, _} = live(conn, "/questions/#{graph.slug}")

    assert has_element?(
             public,
             "#public-question-evidence-0",
             "An edited finding with no verified links."
           )

    refute has_element?(public, "#public-question-evidence-0 a[href='https://example.org/study']")
    assert has_element?(public, "#public-question-evidence-0 a[href='/g/#{graph.slug}?node=3']")

    assert has_element?(
             public,
             "#public-question-evidence-1",
             "A different argument from the central answer."
           )

    assert has_element?(public, "#public-question-evidence-1 a[href='/g/#{graph.slug}?node=2']")
    assert has_element?(public, "#public-question-path-1 a[href='/g/#{graph.slug}?node=2']")
  end

  test "the editor flags changed source material and prevents publication", %{
    conn: conn,
    admin: admin,
    graph: graph
  } do
    page = draft_fixture(admin, graph)
    {:ok, view, _} = live(log_in_user(conn, admin), "/admin/questions?grid=#{graph.slug}")

    data =
      Map.update!(graph.data, "nodes", fn nodes ->
        Enum.map(nodes, &Map.put(&1, "content", &1["content"] <> " Revised."))
      end)

    graph |> Ecto.Changeset.change(data: data) |> Dialectic.Repo.update!()
    view |> element("#question-refresh-source") |> render_click()
    assert has_element?(view, "#question-source-changed[role='status']")
    assert has_element?(view, "#question-publish[disabled]")
    assert QuestionPages.get_public(page.slug) == nil
  end

  test "draft and withdrawn routes are unavailable to public readers", %{
    conn: conn,
    admin: admin,
    graph: graph
  } do
    page = draft_fixture(admin, graph)
    assert_error_sent 404, fn -> get(conn, "/questions/#{page.slug}") end
    {:ok, page} = QuestionPages.save(admin, page, page.draft, :publish, true)
    {:ok, _} = QuestionPages.unpublish(admin, page)
    assert_error_sent 404, fn -> get(conn, "/questions/#{page.slug}") end
  end
end
