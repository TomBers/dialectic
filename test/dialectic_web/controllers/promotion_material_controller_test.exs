defmodule DialecticWeb.PromotionMaterialControllerTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.GraphFixtures

  alias Dialectic.Content.PromotionMaterial
  alias Dialectic.Highlights

  @token "test-promotion-token"

  setup do
    original_token = Application.get_env(:dialectic, :promotion_api_token)
    Application.put_env(:dialectic, :promotion_api_token, @token)

    on_exit(fn ->
      if original_token do
        Application.put_env(:dialectic, :promotion_api_token, original_token)
      else
        Application.delete_env(:dialectic, :promotion_api_token)
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

  test "returns promotion material for a public grid", %{conn: conn} do
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

    assert response["grid"]["title"] == graph.title
    assert response["grid"]["slug"] == graph.slug
    assert response["grid"]["url"] =~ "/g/#{graph.slug}"
    assert response["content"]["origin_question"] == "Should AI tutors teach critical thinking?"

    assert response["content"]["follow_up_questions"] == [
             "What evidence shows AI tutors improve transfer?",
             "When does help become dependency?",
             "How should teachers audit generated explanations?"
           ]

    assert [%{"id" => highlight_id}] = response["content"]["highlights"]
    assert highlight_id == highlight.id

    assert Enum.map(response["content"]["key_questions"], & &1["source"]) == [
             "first_answer_follow_up",
             "first_answer_follow_up",
             "first_answer_follow_up",
             "user_question"
           ]

    assert Enum.map(response["content"]["key_questions"], & &1["question"]) == [
             "What evidence shows AI tutors improve transfer?",
             "When does help become dependency?",
             "How should teachers audit generated explanations?",
             "What classroom evidence would change your mind about whether AI tutors actually improve independent critical thinking over a full school year?"
           ]

    refute Map.has_key?(response, "assets")
    refute Map.has_key?(response, "posts")
  end

  test "builder returns grid and content by default" do
    graph = promotion_graph("Default Include Promotion Grid")

    response = PromotionMaterial.build(graph)

    assert Map.has_key?(response, "grid")
    assert Map.has_key?(response, "content")
    refute Map.has_key?(response, "assets")
    refute Map.has_key?(response, "posts")
  end

  test "returns grid and content and ignores include filters", %{conn: conn} do
    graph = promotion_graph("All Sections Promotion Grid")

    conn =
      conn
      |> authed()
      |> get(~p"/api/promotion/grids/#{graph.slug}", %{"include" => "grid"})

    response = json_response(conn, 200)

    assert Map.has_key?(response, "grid")
    assert Map.has_key?(response, "content")
    refute Map.has_key?(response, "assets")
    refute Map.has_key?(response, "posts")
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
                "content" =>
                  "AI tutors can personalize feedback at scale.\n\n## Follow-up questions\n1. What evidence shows AI tutors improve transfer?\n2. When does help become dependency?\n3. How should teachers audit generated explanations?",
                "class" => "answer",
                "deleted" => false,
                "compound" => false
              },
              %{
                "id" => "3",
                "content" => "Students may outsource the productive struggle of learning.",
                "class" => "antithesis",
                "deleted" => false,
                "compound" => false
              },
              %{
                "id" => "4",
                "content" =>
                  "What classroom evidence would change your mind about whether AI tutors actually improve independent critical thinking over a full school year?",
                "class" => "question",
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
