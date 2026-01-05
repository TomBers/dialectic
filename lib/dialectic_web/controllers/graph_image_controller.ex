defmodule DialecticWeb.GraphImageController do
  use DialecticWeb, :controller
  alias Dialectic.Accounts.Graph

  def show(conn, %{"title" => title} = params) do
    # 1. Fetch the graph
    case Dialectic.DbActions.Graphs.get_graph_by_title(title) do
      %Graph{} = graph ->
        # 2. Check access (Public or Valid Token)
        if authorized?(graph, params["token"]) do
          # 3. Serve Image
          serve_preview_image(conn, graph)
        else
          conn
          |> put_status(:forbidden)
          |> text("Forbidden")
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> text("Graph not found")
    end
  end

  defp authorized?(%Graph{is_public: true}, _), do: true

  defp authorized?(%Graph{share_token: token}, provided_token)
       when is_binary(token) and token == provided_token,
       do: true

  defp authorized?(_, _), do: false

  defp serve_preview_image(conn, graph) do
    preview_data = Map.get(graph.data || %{}, "preview_image")

    case parse_data_uri(preview_data) do
      {:ok, binary_data, content_type} ->
        conn
        |> put_resp_content_type(content_type)
        |> send_resp(200, binary_data)

      _ ->
        # Fallback to default or 404
        conn
        |> put_status(:not_found)
        |> text("No preview image available")
    end
  end

  defp parse_data_uri("data:" <> rest) do
    case String.split(rest, ";base64,", parts: 2) do
      [content_type, b64_data] ->
        case Base.decode64(b64_data) do
          {:ok, binary} -> {:ok, binary, content_type}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp parse_data_uri(_), do: :error
end
