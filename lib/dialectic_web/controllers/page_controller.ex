defmodule DialecticWeb.PageController do
  use DialecticWeb, :controller

  alias Dialectic.DbActions.Notes

  def my_graphs(conn, _params) do
    stats = Notes.get_my_stats(conn.assigns.current_user)

    noted_notes =
      stats.notes
      |> Enum.filter(& &1.is_noted)
      |> Enum.map(fn note ->
        node_title =
          (note.graph.data["nodes"] || [])
          |> Enum.find_value(fn n ->
            if n["id"] == note.node_id, do: node_content_to_title(n["content"])
          end)

        Map.put(note, :node_title, node_title || "Node #{note.node_id}")
      end)

    render(conn, :my_graphs, stats: stats, noted_notes: noted_notes)
  end

  def view_all(conn, params) do
    redirect(conn, to: ~p"/?#{params}")
  end

  def generate_tags(conn, %{"title" => title}) do
    case Dialectic.DbActions.Graphs.get_graph_by_title(title) do
      nil ->
        conn
        |> put_flash(:error, "Graph not found.")
        |> redirect(to: ~p"/")

      graph ->
        Dialectic.Categorisation.AutoTagger.tag_graph(graph)

        referer = get_req_header(conn, "referer") |> List.first()

        conn =
          conn
          |> put_flash(:info, "Generating tags for \"#{graph.title}\" in the background...")

        if referer do
          redirect(conn, external: referer)
        else
          redirect(conn, to: ~p"/")
        end
    end
  end

  # def graph_json(conn, %{"graph_name" => graph_id_uri}) do
  #   graph_name = URI.decode(graph_id_uri)
  #   graph = Graphs.get_graph_by_title(graph_name).data
  #   json(conn, graph)
  # end

  def graph_md(conn, %{"graph_name" => graph_id_uri} = params) do
    graph_name = URI.decode(graph_id_uri)
    graph_struct = Dialectic.DbActions.Graphs.get_graph_by_slug_or_title(graph_name)
    current_user = conn.assigns[:current_user]

    cond do
      is_nil(graph_struct) ->
        conn
        |> put_status(:not_found)
        |> text("Graph not found")

      # Check access control: public, owner, shared, or valid token
      not has_access?(current_user, graph_struct, params) ->
        conn
        |> put_status(:forbidden)
        |> text("You do not have permission to access this graph")

      true ->
        graph = Dialectic.Graph.Serialise.json_to_graph(graph_struct.data)

        # Convert the graph to markdown
        markdown_content =
          Dialectic.Linear.ThreadedConv.prepare_conversation(graph)
          |> Enum.map(&(&1.content <> "\n\n"))

        # Use slug for filename if available, otherwise title
        # Sanitize filename to remove any CR/LF or unsafe characters
        base_filename =
          if graph_struct.slug, do: graph_struct.slug, else: graph_struct.title

        safe_filename =
          base_filename
          |> String.replace(~r/[^A-Za-z0-9_.-]/, "_")
          |> String.slice(0, 200)

        safe_filename = "#{safe_filename}.md"

        conn
        |> put_resp_content_type("text/markdown")
        |> put_resp_header("content-disposition", "attachment; filename=#{safe_filename}")
        |> send_resp(200, markdown_content)
    end
  end

  # Check if user has access to the graph (same logic as LiveViews)
  defp has_access?(user, graph_struct, params) do
    token_param = Map.get(params, "token")

    Dialectic.DbActions.Sharing.can_access?(user, graph_struct) or
      (is_binary(token_param) and is_binary(graph_struct.share_token) and
         Plug.Crypto.secure_compare(token_param, graph_struct.share_token))
  end

  def guide(conn, _params) do
    render(conn, :how)
  end

  # Extracts a short title from node markdown content
  defp node_content_to_title(nil), do: nil

  defp node_content_to_title(content) do
    content
    |> String.split("\n", trim: true)
    |> List.first("")
    |> String.replace(~r/^#+\s*/, "")
    |> String.trim()
    |> String.slice(0, 80)
    |> case do
      "" -> nil
      title -> title
    end
  end
end
