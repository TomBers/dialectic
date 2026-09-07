defmodule DialecticWeb.QuestionLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @path "/questions/does-ai-make-us-better-thinkers"

  test "serves the complete answer, evidence and exercise before LiveView connects", %{conn: conn} do
    document = conn |> get(@path) |> html_response(200) |> LazyHTML.from_document()

    for id <-
          ~w(short-answer study-work study-maths study-tutor question-uncertainty question-exercise-feedback question-provenance) do
      assert document |> LazyHTML.query("##{id}") |> LazyHTML.to_html() != ""
    end

    assert document |> LazyHTML.query("#source-work") |> LazyHTML.attribute("href") ==
             ["https://doi.org/10.1287/orsc.2025.21838"]

    assert document |> LazyHTML.query("#source-maths") |> LazyHTML.attribute("href") ==
             ["https://doi.org/10.1073/pnas.2422633122"]

    assert document |> LazyHTML.query("#source-tutor") |> LazyHTML.attribute("href") ==
             ["https://doi.org/10.1038/s41598-025-97652-6"]

    ids = document |> LazyHTML.query("[id]") |> LazyHTML.attribute("id")
    assert length(ids) == length(Enum.uniq(ids))

    for fragment <-
          document
          |> LazyHTML.query("#public-question a[href^='#']")
          |> LazyHTML.attribute("href") do
      assert document |> LazyHTML.query(fragment) |> LazyHTML.to_html() != ""
    end
  end

  test "has question-specific sharing metadata and a canonical URL without query parameters", %{
    conn: conn
  } do
    document =
      conn |> get(@path <> "?utm_source=shared") |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim() ==
             "Does AI make us better thinkers? | RationalGrid"

    for selector <- ["link[rel=canonical]", "meta[property='og:url']"] do
      attribute = if String.starts_with?(selector, "link"), do: "href", else: "content"

      assert document |> LazyHTML.query(selector) |> LazyHTML.attribute(attribute) ==
               [DialecticWeb.Endpoint.url() <> @path]
    end

    assert document |> LazyHTML.query("meta[property='og:type']") |> LazyHTML.attribute("content") ==
             ["article"]

    assert document |> LazyHTML.query("meta[name=description]") |> LazyHTML.attribute("content") !=
             []

    assert document |> LazyHTML.query("meta[name=robots]") |> LazyHTML.to_html() == ""
  end

  test "anonymous readers can explore without generating content or signing in", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)

    for id <- ~w(path-case path-objection path-practice question-exercise-answer) do
      assert has_element?(view, "details##{id} > summary")
      refute has_element?(view, "details##{id}[open]")
    end

    assert has_element?(view, "#question-related-grids[href='/search?q=AI']")

    view |> element("#question-related-grids") |> render_click()
    assert_redirect(view, "/search?q=AI")
  end

  test "the pilot is discoverable from home, community and the sitemap", %{conn: conn} do
    for {route, id} <- [{"/", "home-question-pilot"}, {"/community", "community-question-pilot"}] do
      {:ok, view, _html} = live(conn, route)
      assert has_element?(view, "##{id}[href='#{@path}']")
    end

    xml = conn |> get("/sitemap.xml") |> response(200)
    assert xml =~ "<loc>#{DialecticWeb.Endpoint.url()}#{@path}</loc>"
  end
end
