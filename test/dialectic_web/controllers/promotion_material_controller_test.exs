defmodule DialecticWeb.PromotionMaterialControllerTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.GraphFixtures

  alias Dialectic.Content.PromotionMaterial
  alias Dialectic.Highlights

  @token "test-promotion-token"

  setup do
    original_app_token = Application.get_env(:dialectic, :promotion_api_token)
    original_system_token = System.get_env("PROMOTION_API_TOKEN")

    Application.put_env(:dialectic, :promotion_api_token, @token)
    System.delete_env("PROMOTION_API_TOKEN")

    on_exit(fn ->
      if original_app_token do
        Application.put_env(:dialectic, :promotion_api_token, original_app_token)
      else
        Application.delete_env(:dialectic, :promotion_api_token)
      end

      if original_system_token do
        System.put_env("PROMOTION_API_TOKEN", original_system_token)
      else
        System.delete_env("PROMOTION_API_TOKEN")
      end
    end)
  end

  test "returns 503 when promotion token is not configured", %{conn: conn} do
    Application.delete_env(:dialectic, :promotion_api_token)

    conn = get(conn, ~p"/api/promotion/grids")

    assert json_response(conn, 503) == %{"error" => "Promotion API token is not configured"}
  end

  test "rejects missing or wrong bearer token", %{conn: conn} do
    conn = get(conn, ~p"/api/promotion/grids")
    assert json_response(conn, 401) == %{"error" => "Unauthorized"}

    conn =
      recycle(conn)
      |> put_req_header("authorization", "Bearer wrong-token")
      |> get(~p"/api/promotion/grids")

    assert json_response(conn, 401) == %{"error" => "Unauthorized"}
  end

  test "lists all public promotion grids", %{conn: conn} do
    public_graph = promotion_graph("Promotion Index Public Grid")
    _private_graph = promotion_graph("Promotion Index Private Grid", is_public: false)
    _deleted_graph = promotion_graph("Promotion Index Deleted Grid", is_deleted: true)

    conn = conn |> authed() |> get(~p"/api/promotion/grids")
    response = json_response(conn, 200)

    matching = Enum.filter(response["grids"], &(&1["slug"] == public_graph.slug))

    assert response["count"] >= 1
    assert [grid] = matching
    assert grid["title"] == public_graph.title
    assert grid["url"] =~ "/g/#{public_graph.slug}"
    assert grid["api_url"] =~ "/api/promotion/grids/#{public_graph.slug}"

    slugs = Enum.map(response["grids"], & &1["slug"])
    refute Enum.any?(slugs, &(&1 == _private_graph.slug))
    refute Enum.any?(slugs, &(&1 == _deleted_graph.slug))
  end

  test "returns graph metadata, raw graph data, and highlights", %{conn: conn} do
    graph = promotion_graph("AI Tutors Promotion Grid")
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "2",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 23,
        selected_text_snapshot: "AI tutors can personalize feedback at scale.",
        created_by_user_id: user.id
      })

    conn =
      conn
      |> authed()
      |> get(~p"/api/promotion/grids/#{graph.slug}")

    response = json_response(conn, 200)

    assert response["metadata"]["title"] == graph.title
    assert response["metadata"]["slug"] == graph.slug
    assert response["metadata"]["url"] =~ "/g/#{graph.slug}"
    assert response["graph"] == graph.data

    assert [%{"id" => highlight_id} = highlight_response] = response["highlights"]
    assert highlight_id == highlight.id
    assert highlight_response["node_id"] == "2"
    assert highlight_response["text"] == "AI tutors can personalize feedback at scale."
    assert highlight_response["text_source_type"] == "node"

    refute Map.has_key?(response, "content")
    refute Map.has_key?(response, "assets")
    refute Map.has_key?(response, "posts")
  end

  test "builder returns metadata, graph, and highlights" do
    graph = promotion_graph("Default Include Promotion Grid")

    response = PromotionMaterial.build(graph)

    assert Map.has_key?(response, "metadata")
    assert Map.has_key?(response, "graph")
    assert Map.has_key?(response, "highlights")
    refute Map.has_key?(response, "content")
    refute Map.has_key?(response, "assets")
    refute Map.has_key?(response, "posts")
  end

  test "returns metadata, graph, and highlights and ignores include filters", %{conn: conn} do
    graph = promotion_graph("All Sections Promotion Grid")

    conn =
      conn
      |> authed()
      |> get(~p"/api/promotion/grids/#{graph.slug}", %{"include" => "grid"})

    response = json_response(conn, 200)

    assert Map.has_key?(response, "metadata")
    assert Map.has_key?(response, "graph")
    assert Map.has_key?(response, "highlights")
    refute Map.has_key?(response, "content")
    refute Map.has_key?(response, "assets")
  end

  test "returns 404 for unknown or non-public grids", %{conn: conn} do
    private_graph = promotion_graph("Private Promotion Grid", is_public: false)

    assert %{"error" => "Grid not found"} =
             conn
             |> authed()
             |> get(~p"/api/promotion/grids/missing")
             |> json_response(404)

    conn = recycle(conn)

    assert %{"error" => "Grid not found"} =
             conn
             |> authed()
             |> get(~p"/api/promotion/grids/#{private_graph.slug}")
             |> json_response(404)
  end

  defp authed(conn), do: put_req_header(conn, "authorization", "Bearer #{@token}")

  defp promotion_graph(title, attrs \\ []) do
    insert_graph(
      Map.merge(
        %{
          title: title,
          is_public: true,
          is_published: true,
          data: %{
            "nodes" => [
              %{
                "id" => "1",
                "content" => "## Should AI tutors teach critical thinking?",
                "class" => "origin",
                "deleted" => false,
                "compound" => false
              },
              %{
                "id" => "2",
                "content" => "AI tutors can personalize feedback at scale.",
                "class" => "answer",
                "deleted" => false,
                "compound" => false
              }
            ],
            "edges" => []
          }
        },
        Map.new(attrs)
      )
    )
  end
end
