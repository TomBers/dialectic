defmodule DialecticWeb.HighlightShareImageControllerTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.AccountsFixtures
  import Dialectic.GraphFixtures

  alias Dialectic.Accounts.Graph
  alias Dialectic.Highlights
  alias Dialectic.Repo

  test "renders an svg share card for a public highlight", %{conn: conn} do
    graph = insert_graph(%{title: "Share Card Graph", is_public: true})
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "1",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 9,
        selected_text_snapshot: "The limits of my language mean the limits of my world.",
        created_by_user_id: user.id
      })

    conn = get(conn, "/g/#{graph.slug}/highlights/#{highlight.id}/share-card.svg")
    body = response(conn, 200)

    assert get_resp_header(conn, "content-type") |> List.first() =~ "image/svg+xml"
    assert body =~ "RATIONALGRID HIGHLIGHT"
    assert body =~ "The limits of my language"
    assert body =~ graph.title
  end

  test "requires a token for private highlight share cards", %{conn: conn} do
    graph =
      insert_graph(%{title: "Private Share Card Graph", is_public: false})
      |> Graph.changeset(%{share_token: "secret-token"})
      |> Repo.update!()

    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "1",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 7,
        selected_text_snapshot: "Private quote",
        created_by_user_id: user.id
      })

    forbidden_conn = get(conn, "/g/#{graph.slug}/highlights/#{highlight.id}/share-card.svg")
    assert response(forbidden_conn, 403)

    authed_conn =
      get(
        conn,
        "/g/#{graph.slug}/highlights/#{highlight.id}/share-card.svg?token=#{graph.share_token}"
      )

    assert response(authed_conn, 200) =~ "Private quote"
  end
end
