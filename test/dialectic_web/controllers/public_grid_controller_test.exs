defmodule DialecticWeb.PublicGridControllerTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.GraphFixtures

  test "anonymous search returns public metadata and matching passages", %{conn: conn} do
    graph = insert_graph(%{title: "Public reasoning", data: graph_data()})

    response = conn |> get(~p"/api/public/grids", query: "evidence") |> json_response(200)

    assert [%{"id" => slug, "matches" => [%{"node_id" => "2", "snippet" => snippet}]}] =
             response["grids"]

    assert slug == graph.slug
    assert snippet =~ "evidence"
    assert hd(response["grids"])["url"] == url(~p"/g/#{graph.slug}")

    assert Map.keys(hd(response["grids"])) |> Enum.sort() ==
             ~w(id matches tags title url)
  end

  test "search and read never expose private, unpublished, or deleted grids", %{conn: conn} do
    for attrs <- [%{is_public: false}, %{is_published: false}, %{is_deleted: true}] do
      graph =
        insert_graph(
          Map.merge(attrs, %{
            title: "Hidden evidence #{System.unique_integer([:positive])}",
            data: graph_data()
          })
        )

      response = conn |> get(~p"/api/public/grids/#{graph.slug}") |> json_response(404)
      assert response == %{"error" => "Grid not found"}
    end

    assert conn |> get(~p"/api/public/grids", query: "evidence") |> json_response(200) ==
             %{"grids" => []}
  end

  test "reads paginate persisted nodes and retain cross-page edges without deleted data", %{
    conn: conn
  } do
    graph = insert_graph(%{title: "Read a public grid", data: graph_data()})

    first_page =
      conn |> get(~p"/api/public/grids/#{graph.slug}", limit: 1) |> json_response(200)

    assert first_page["grid"]["id"] == graph.slug
    assert first_page["total_nodes"] == 2
    assert first_page["next_offset"] == 1
    assert [%{"id" => "1"} = node] = first_page["nodes"]
    assert Map.keys(node) |> Enum.sort() == ~w(class content id)
    assert first_page["edges"] == [%{"from" => "1", "to" => "2"}]

    last_page =
      conn
      |> get(~p"/api/public/grids/#{graph.slug}", limit: 1, offset: 1)
      |> json_response(200)

    assert [%{"id" => "2", "content" => "Follow the evidence"}] = last_page["nodes"]
    assert last_page["next_offset"] == nil

    assert get_resp_header(conn |> get(~p"/api/public/grids/#{graph.slug}"), "cache-control") ==
             ["no-store"]
  end

  test "rejects malformed or unbounded query parameters", %{conn: conn} do
    for params <- [
          %{},
          %{query: "x"},
          %{query: String.duplicate("x", 101)},
          %{query: ["evidence"]},
          %{query: "evidence", limit: "21"},
          %{query: "evidence", limit: "1junk"},
          %{query: "evidence", limit: ["1"]}
        ] do
      assert %{"error" => _} = conn |> get(~p"/api/public/grids", params) |> json_response(400)
    end

    for params <- [%{limit: 51}, %{offset: -1}, %{offset: "abc"}] do
      assert %{"error" => _} =
               conn |> get(~p"/api/public/grids/missing", params) |> json_response(400)
    end
  end

  test "limits search results and returns an empty collection for no matches", %{conn: conn} do
    for number <- 1..3, do: insert_graph(%{title: "Evidence #{number}"})

    response =
      conn |> get(~p"/api/public/grids", query: "Evidence", limit: 2) |> json_response(200)

    assert length(response["grids"]) == 2

    assert conn |> get(~p"/api/public/grids", query: "nonexistent") |> json_response(200) ==
             %{"grids" => []}

    assert conn |> get(~p"/api/public/grids/missing") |> json_response(404) ==
             %{"error" => "Grid not found"}
  end

  defp graph_data do
    %{
      "nodes" => [
        %{
          "id" => "1",
          "content" => "Question",
          "class" => "origin",
          "user" => "private attribution"
        },
        %{"id" => "2", "content" => "Follow the evidence", "class" => "answer"},
        %{"id" => "3", "content" => "Deleted evidence", "class" => "answer", "deleted" => true}
      ],
      "edges" => [
        %{"data" => %{"source" => "1", "target" => "2"}},
        %{"data" => %{"source" => "2", "target" => "3"}}
      ]
    }
  end
end
