defmodule DialecticWeb.PageController do
  use DialecticWeb, :controller

  alias Dialectic.DbActions.Notes

  def my_graphs(conn, _params) do
    stats = Notes.get_my_stats(conn.assigns.current_user)

    # IO.inspect(stats, label: "Stats")
    render(conn, :my_graphs, stats: stats)
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

  def graph_md(conn, %{"graph_name" => graph_id_uri}) do
    graph_name = URI.decode(graph_id_uri)
    graph_struct = Dialectic.DbActions.Graphs.get_graph_by_title(graph_name)
    graph = Dialectic.Graph.Serialise.json_to_graph(graph_struct.data)

    vertices =
      :digraph.vertices(graph)
      |> Enum.filter(fn v ->
        {_, data} = :digraph.vertex(graph, v)
        !Map.get(data, :compound, false)
      end)

    # First pass: Generate filenames for all vertices to ensure consistent linking
    # Format: "Index - Title.md"
    id_to_filename =
      vertices
      |> Enum.with_index(1)
      |> Map.new(fn {v, index} ->
        {_, data} = :digraph.vertex(graph, v)
        title = extract_title(data.content)

        sanitized_title =
          title
          |> String.replace(~r/\s+/, " ")
          |> String.replace(~r/[^a-zA-Z0-9\s\-_]/, "")
          |> String.trim()

        sanitized_title = if sanitized_title == "", do: "Untitled", else: sanitized_title

        {v, "#{index} - #{sanitized_title}.md"}
      end)

    # Second pass: Generate file content with links
    files =
      Enum.map(vertices, fn v ->
        {_, data} = :digraph.vertex(graph, v)
        filename = id_to_filename[v]

        title = extract_title(data.content)
        body = extract_body(data.content)

        children = :digraph.out_neighbours(graph, v)

        links =
          children
          |> Enum.filter(&Map.has_key?(id_to_filename, &1))
          |> Enum.map_join("\n", fn child_id ->
            child_filename = id_to_filename[child_id]
            # Obsidian link format: [[Filename]]
            "- [[#{child_filename}]]"
          end)

        file_content = """
        #{body}

        **Class**: #{data.class}

        ## Children
        #{links}
        """

        {String.to_charlist(filename), file_content}
      end)

    sanitized_graph_name =
      graph_name
      |> String.replace(~r/[^a-zA-Z0-9\s-_]/, "")
      |> String.trim()
      |> String.replace(~r/\s+/, "_")

    # Create ZIP file in memory
    {:ok, {_filename, binary}} =
      :zip.create(String.to_charlist("#{sanitized_graph_name}.zip"), files, [:memory])

    conn
    |> put_resp_content_type("application/zip")
    |> put_resp_header("content-disposition", "attachment; filename=#{sanitized_graph_name}.zip")
    |> send_resp(200, binary)
  end

  def guide(conn, _params) do
    render(conn, :how)
  end

  defp extract_title(content) do
    content = content || ""

    first_line =
      content
      |> String.replace(~r/\r\n|\r/, "\n")
      |> String.trim_leading()
      |> String.split("\n", parts: 2)
      |> List.first() || ""

    first_line
    |> String.replace(~R/^\s*#{1,6}\s*/, "")
    |> String.replace(~r/^\s*title\s*:?\s*/i, "")
    |> String.replace("**", "")
    |> String.trim()
  end

  defp extract_body(content) do
    content = content || ""

    parts =
      content
      |> String.replace(~r/\r\n|\r/, "\n")
      |> String.split("\n")

    # Drop first line
    rest = Enum.drop(parts, 1)

    # Check if we should drop the second line (if it looks like a header/title)
    case rest do
      [] ->
        ""

      [next | _] ->
        if String.match?(next, ~R/^\s*#{1,6}\s+\S/) or
             String.match?(next, ~r/^\s*(title|Title)\s*:?\s*/) do
          Enum.drop(rest, 1) |> Enum.join("\n")
        else
          Enum.join(rest, "\n")
        end
    end
    |> String.trim()
  end
end
