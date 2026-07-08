defmodule DialecticWeb.HighlightShareImageController do
  use DialecticWeb, :controller

  alias Dialectic.DbActions.Graphs
  alias DialecticWeb.HighlightShare

  def graph(conn, %{"graph_name" => graph_name} = params) do
    current_user = conn.assigns[:current_user]
    graph = Graphs.get_graph_by_slug_or_title(graph_name)

    cond do
      is_nil(graph) ->
        send_resp(conn, :not_found, "Not found")

      not has_access?(current_user, graph, params) ->
        send_resp(conn, :forbidden, "Forbidden")

      true ->
        conn
        |> put_resp_content_type("image/svg+xml")
        |> put_resp_header("cache-control", cache_control(graph))
        |> send_resp(200, HighlightShare.graph_image_svg(graph))
    end
  end

  def follow_up(conn, %{"graph_name" => graph_name, "question" => question} = params) do
    current_user = conn.assigns[:current_user]
    graph = Graphs.get_graph_by_slug_or_title(graph_name)
    question = question |> to_string() |> String.trim() |> String.slice(0, 280)
    node_id = params |> Map.get("node", "1") |> to_string()

    cond do
      is_nil(graph) ->
        send_resp(conn, :not_found, "Not found")

      question == "" ->
        send_resp(conn, :bad_request, "Missing question")

      not has_access?(current_user, graph, params) ->
        send_resp(conn, :forbidden, "Forbidden")

      true ->
        highlight = %{id: "follow-up", node_id: node_id, selected_text_snapshot: question}

        conn
        |> put_resp_content_type("image/svg+xml")
        |> put_resp_header("cache-control", cache_control(graph))
        |> send_resp(200, HighlightShare.image_svg(graph, highlight))
    end
  end

  def show(conn, %{"graph_name" => graph_name, "id" => highlight_id} = params) do
    current_user = conn.assigns[:current_user]
    graph = Graphs.get_graph_by_slug_or_title(graph_name)

    cond do
      is_nil(graph) ->
        send_resp(conn, :not_found, "Not found")

      not has_access?(current_user, graph, params) ->
        send_resp(conn, :forbidden, "Forbidden")

      highlight = HighlightShare.highlight_for_graph(graph, highlight_id) ->
        conn
        |> put_resp_content_type("image/svg+xml")
        |> put_resp_header("cache-control", cache_control(graph))
        |> send_resp(200, HighlightShare.image_svg(graph, highlight))

      true ->
        send_resp(conn, :not_found, "Not found")
    end
  end

  defp has_access?(user, graph, params) do
    token_param = Map.get(params, "token")

    Dialectic.DbActions.Sharing.can_access?(user, graph) or
      (is_binary(token_param) and is_binary(graph.share_token) and
         Plug.Crypto.secure_compare(token_param, graph.share_token))
  end

  defp cache_control(%{is_public: true}), do: "public, max-age=300"
  defp cache_control(_graph), do: "private, max-age=300"
end
