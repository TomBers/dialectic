defmodule DialecticWeb.ComparisonControllerTest do
  use DialecticWeb.ConnCase

  @pages [
    {"chatgpt", "chatgpt-comparison-hero", "chatgpt-comparison-table", "chatgpt-start-cta"},
    {"elicit", "elicit-comparison-hero", "elicit-comparison-table", "elicit-start-cta"},
    {"kialo", "kialo-comparison-hero", "kialo-comparison-table", "kialo-start-cta"},
    {"mind-maps", "mind-maps-comparison-hero", "mind-maps-comparison-table",
     "mind-maps-start-cta"},
    {"notebooklm", "notebooklm-comparison-hero", "notebooklm-comparison-table",
     "notebooklm-start-cta"},
    {"notion-obsidian", "notion-obsidian-comparison-hero", "notion-obsidian-comparison-table",
     "notion-obsidian-start-cta"}
  ]

  test "renders an index linking to every comparison", %{conn: conn} do
    conn = get(conn, "/compare")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#comparison-index") |> LazyHTML.to_html() != ""

    for {slug, _page_id, _table_id, _cta_id} <- @pages do
      assert document
             |> LazyHTML.query("#comparison-index-#{slug}")
             |> LazyHTML.attribute("href") == ["/compare/#{slug}"]
    end

    assert document
           |> LazyHTML.query("#comparison-index-pages a[id^='comparison-index-']")
           |> LazyHTML.attribute("id") == [
             "comparison-index-chatgpt",
             "comparison-index-notebooklm",
             "comparison-index-elicit",
             "comparison-index-kialo",
             "comparison-index-mind-maps",
             "comparison-index-notion-obsidian"
           ]

    assert document
           |> LazyHTML.query("#comparison-index-start-link")
           |> LazyHTML.attribute("data-analytics-comparison") == ["index"]

    assert document |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim() ==
             "Compare Research and Argument-Mapping Tools | RationalGrid"

    assert document
           |> LazyHTML.query("meta[name=description]")
           |> LazyHTML.attribute("content") == [
             "Compare RationalGrid with ChatGPT, Elicit, Kialo, Gemini Notebook (formerly NotebookLM) and mind maps, or explore a Notion and Obsidian workflow."
           ]
  end

  for {slug, page_id, table_id, cta_id} <- @pages do
    test "renders the #{slug} comparison with metadata and key elements", %{conn: conn} do
      conn = get(conn, "/compare/#{unquote(slug)}")
      html = html_response(conn, 200)
      document = LazyHTML.from_document(html)

      assert document |> LazyHTML.query("##{unquote(page_id)}") |> LazyHTML.to_html() != ""
      assert document |> LazyHTML.query("##{unquote(table_id)}") |> LazyHTML.to_html() != ""

      cta = LazyHTML.query(document, "##{unquote(cta_id)}")

      assert LazyHTML.attribute(cta, "href") == ["/?focus=grid#start-here"]

      assert LazyHTML.attribute(cta, "data-analytics-event") == [
               "comparison_start_grid_clicked"
             ]

      assert document
             |> LazyHTML.query("##{unquote(slug)}-related-comparisons a")
             |> LazyHTML.to_html() != ""

      assert document
             |> LazyHTML.query("link[rel=canonical]")
             |> LazyHTML.attribute("href") == [
               DialecticWeb.Endpoint.url() <> "/compare/#{unquote(slug)}"
             ]

      assert document
             |> LazyHTML.query("meta[name=description]")
             |> LazyHTML.attribute("content") != []

      title = document |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim()

      assert String.ends_with?(title, "| RationalGrid")
      refute title =~ "See what you think"
    end
  end

  test "exposes only the allowlisted slugs", %{conn: _conn} do
    assert DialecticWeb.ComparisonController.slugs() == [
             "chatgpt",
             "elicit",
             "kialo",
             "mind-maps",
             "notebooklm",
             "notion-obsidian"
           ]
  end

  test "returns 404 for an unsupported comparison", %{conn: conn} do
    conn = get(conn, "/compare/not-a-real-page")

    assert conn.status == 404
  end
end
