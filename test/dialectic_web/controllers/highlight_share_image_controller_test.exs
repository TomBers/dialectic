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
    assert body =~ ">Quote<"
    assert body =~ "The limits of my language"
    assert body =~ graph.title
    assert body =~ "RationalGrid.ai"
    refute body =~ "Rational Grid"
  end

  test "serves share cards for image accept headers", %{conn: conn} do
    graph = insert_graph(%{title: "Share Card Accept Graph", is_public: true})
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "1",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 9,
        selected_text_snapshot: "Image clients should be able to fetch this quote card.",
        created_by_user_id: user.id
      })

    conn =
      conn
      |> put_req_header("accept", "image/svg+xml")
      |> get("/g/#{graph.slug}/highlights/#{highlight.id}/share-card.svg")

    assert response(conn, 200) =~ "Image clients"
    assert get_resp_header(conn, "content-type") |> List.first() =~ "image/svg+xml"
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

  test "wraps longer quotes across multiple lines in the share card", %{conn: conn} do
    graph = insert_graph(%{title: "Long Quote Graph", is_public: true})
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "1",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 20,
        selected_text_snapshot:
          "To what extent can modern genetics and epigenetic memory provide a physical mechanism for the transmission of Jungian archetypes across generations without reducing symbolic meaning to a crude biological shortcut?",
        created_by_user_id: user.id
      })

    conn = get(conn, "/g/#{graph.slug}/highlights/#{highlight.id}/share-card.svg")
    body = response(conn, 200)

    assert body =~ "Jungian archetypes"
    assert body =~ "<tspan"
    assert length(Regex.scan(~r/<tspan\b/, body)) >= 3
  end

  test "wraps longer graph titles in the footer area", %{conn: conn} do
    graph =
      insert_graph(%{
        title:
          "Discuss the fairness and public ethics around reserving seats and tables in public spaces by putting coats and bags on them",
        is_public: true
      })

    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "1",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 12,
        selected_text_snapshot:
          "At the heart of reserving seats with bags or coats is a clash between two competing ethical frameworks.",
        created_by_user_id: user.id
      })

    conn = get(conn, "/g/#{graph.slug}/highlights/#{highlight.id}/share-card.svg")
    body = response(conn, 200)

    assert body =~ "Discuss the fairness and public ethics"
    assert length(Regex.scan(~r/<tspan\b/, body)) >= 2
  end
end
