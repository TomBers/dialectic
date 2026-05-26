defmodule DialecticWeb.HighlightShare do
  import DialecticWeb.GraphPathHelper

  alias Dialectic.Highlights
  alias Dialectic.Highlights.Highlight
  alias DialecticWeb.Endpoint
  alias DialecticWeb.Utils.NodeTitleHelper

  @image_width 1200
  @image_height 630
  @max_quote_lines 6
  @max_quote_line_length 34
  @image_style_version 2

  def highlight_for_graph(graph, highlight_id) do
    with {:ok, parsed_id} <- parse_highlight_id(highlight_id),
         %Highlight{} = highlight <- Highlights.get_highlight(parsed_id),
         true <- highlight.mudg_id == graph.title do
      highlight
    else
      _ -> nil
    end
  end

  def share_url(graph, highlight) when is_map(highlight) do
    Endpoint.url() <> share_path(graph, highlight)
  end

  def share_path(graph, highlight) when is_map(highlight) do
    graph_path(graph, Map.get(highlight, :node_id), highlight: Map.get(highlight, :id))
  end

  def image_url(graph, highlight) when is_map(highlight) do
    Endpoint.url() <> image_path(graph, highlight)
  end

  def image_path(%{slug: slug} = graph, %{id: highlight_id} = highlight)
      when is_binary(slug) and slug != "" do
    params =
      []
      |> maybe_add_version(highlight)
      |> maybe_add_token_param(graph)

    build_query_path("/g/#{slug}/highlights/#{highlight_id}/share-card.svg", params)
  end

  def share_text(graph, highlight) when is_map(highlight) do
    quote = excerpt(Map.get(highlight, :selected_text_snapshot), 160)
    truncate("“#{quote}” — #{graph.title} on RationalGrid", 220)
  end

  def page_title(graph, highlight) when is_map(highlight) do
    quote = excerpt(Map.get(highlight, :selected_text_snapshot), 90)
    truncate("“#{quote}” · #{graph.title}", 120)
  end

  def page_description(graph, highlight) when is_map(highlight) do
    node_title = node_title(graph, Map.get(highlight, :node_id))
    quote = excerpt(Map.get(highlight, :selected_text_snapshot), 180)

    truncate(
      "Highlighted quote from #{node_title} in \"#{graph.title}\" on RationalGrid: “#{quote}”",
      240
    )
  end

  def node_title(graph, node_id) do
    graph
    |> graph_nodes()
    |> Enum.find_value("Node #{node_id}", fn node ->
      if to_string(Map.get(node, "id")) == to_string(node_id) do
        case NodeTitleHelper.extract_node_title(node, max_length: 72) do
          "Untitled" -> "Node #{node_id}"
          title -> title
        end
      end
    end)
  end

  def image_svg(graph, highlight) when is_map(highlight) do
    quote_lines =
      wrap_lines(
        Map.get(highlight, :selected_text_snapshot),
        @max_quote_line_length,
        @max_quote_lines
      )

    title = node_title(graph, Map.get(highlight, :node_id))
    footer = truncate(graph.title, 80)
    quote_length = String.length(sanitize_text(Map.get(highlight, :selected_text_snapshot)))
    quote_font_size = quote_font_size(quote_lines, quote_length)

    quote_markup =
      quote_lines
      |> Enum.with_index()
      |> Enum.map_join("", fn {line, index} ->
        y = 246 + index * 64
        ~s(<tspan x="150" y="#{y}">#{escape_xml(line)}</tspan>)
      end)

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{@image_width}" height="#{@image_height}" viewBox="0 0 #{@image_width} #{@image_height}" role="img" aria-labelledby="title desc">
      <title id="title">#{escape_xml(page_title(graph, highlight))}</title>
      <desc id="desc">#{escape_xml(page_description(graph, highlight))}</desc>
      <defs>
        <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#0f172a" />
          <stop offset="45%" stop-color="#1e1b4b" />
          <stop offset="100%" stop-color="#172554" />
        </linearGradient>
        <linearGradient id="aurora" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#38bdf8" stop-opacity="0.34" />
          <stop offset="50%" stop-color="#8b5cf6" stop-opacity="0.24" />
          <stop offset="100%" stop-color="#f59e0b" stop-opacity="0.22" />
        </linearGradient>
        <linearGradient id="frame" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#fffdf7" />
          <stop offset="100%" stop-color="#f8fafc" />
        </linearGradient>
        <linearGradient id="accent" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stop-color="#8b5cf6" />
          <stop offset="100%" stop-color="#06b6d4" />
        </linearGradient>
        <linearGradient id="headerBand" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#eef2ff" />
          <stop offset="100%" stop-color="#dbeafe" />
        </linearGradient>
      </defs>

      <rect width="1200" height="630" fill="url(#bg)" />
      <circle cx="1000" cy="96" r="156" fill="#8b5cf6" fill-opacity="0.16" />
      <circle cx="112" cy="586" r="172" fill="#0ea5e9" fill-opacity="0.16" />
      <rect x="118" y="92" width="964" height="446" rx="34" fill="#ffffff" fill-opacity="0.14" />
      <rect x="132" y="106" width="936" height="418" rx="30" fill="url(#frame)" />
      <rect x="132" y="106" width="936" height="418" rx="30" fill="none" stroke="#dbe4f3" stroke-width="2" />
      <rect x="132" y="106" width="20" height="418" rx="10" fill="url(#accent)" />
      <rect x="152" y="106" width="916" height="74" rx="30" fill="url(#headerBand)" fill-opacity="0.76" />
      <circle cx="972" cy="470" r="98" fill="#38bdf8" fill-opacity="0.10" />

      <rect x="174" y="126" width="504" height="40" rx="20" fill="#eef2ff" />
      <text x="176" y="143" fill="#4f46e5" font-size="22" font-weight="700" font-family="Inter, Arial, sans-serif" letter-spacing="1.8">RATIONALGRID HIGHLIGHT</text>

      <text x="176" y="242" fill="#c4b5fd" font-size="126" font-weight="700" font-family="Georgia, serif">“</text>
      <text fill="#172033" font-size="#{quote_font_size}" font-weight="600" font-family="Georgia, serif" letter-spacing="0.1">
        #{quote_markup}
      </text>
      <text x="940" y="396" fill="#dbe4f3" font-size="112" font-weight="700" font-family="Georgia, serif">”</text>

      <rect x="174" y="438" width="846" height="2" fill="#dbe4f3" />
      <rect x="174" y="462" width="586" height="48" rx="24" fill="#ffffff" stroke="#dbe4f3" />
      <text x="176" y="502" fill="#334155" font-size="26" font-weight="700" font-family="Inter, Arial, sans-serif">#{escape_xml(title)}</text>

      <text x="174" y="548" fill="#64748b" font-size="23" font-family="Inter, Arial, sans-serif">#{escape_xml(footer)}</text>

      <rect x="886" y="474" width="146" height="44" rx="22" fill="#312e81" />
      <text x="979" y="518" text-anchor="middle" fill="#e0e7ff" font-size="23" font-weight="700" font-family="Inter, Arial, sans-serif">rationalgrid.ai</text>
    </svg>
    """
  end

  defp quote_font_size(quote_lines, quote_length) do
    cond do
      length(quote_lines) >= 5 or quote_length > 190 -> 40
      length(quote_lines) == 4 or quote_length > 135 -> 44
      true -> 50
    end
  end

  defp graph_nodes(graph) do
    get_in(graph.data || %{}, ["nodes"]) || []
  end

  defp parse_highlight_id(id) when is_integer(id), do: {:ok, id}

  defp parse_highlight_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed_id, ""} -> {:ok, parsed_id}
      _ -> :error
    end
  end

  defp parse_highlight_id(_id), do: :error

  defp excerpt(text, max_length) do
    text
    |> sanitize_text()
    |> truncate(max_length)
  end

  defp sanitize_text(text) do
    text
    |> to_string()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp truncate(text, max_length) when is_binary(text) do
    if String.length(text) > max_length do
      text
      |> String.slice(0, max_length - 1)
      |> String.trim_trailing()
      |> Kernel.<>("…")
    else
      text
    end
  end

  defp wrap_lines(text, max_length, max_lines) do
    text
    |> sanitize_text()
    |> String.split(" ", trim: true)
    |> Enum.reduce([""], fn word, [current | rest] = acc ->
      separator = if current == "", do: "", else: " "
      candidate = current <> separator <> word

      if String.length(candidate) <= max_length do
        [candidate | rest]
      else
        [word | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
    |> limit_lines(max_lines)
  end

  defp limit_lines(lines, max_lines) when length(lines) <= max_lines, do: lines

  defp limit_lines(lines, max_lines) do
    {visible_lines, overflow_lines} = Enum.split(lines, max_lines)
    overflow_text = overflow_lines |> Enum.join(" ") |> truncate(28)

    List.replace_at(
      visible_lines,
      max_lines - 1,
      List.last(visible_lines) <> " " <> overflow_text
    )
  end

  defp maybe_add_version(params, highlight) do
    params = [{"sv", @image_style_version} | params]

    case Map.get(highlight, :updated_at) do
      %DateTime{} = updated_at -> [{"v", DateTime.to_unix(updated_at, :second)} | params]
      _ -> params
    end
  end

  defp maybe_add_token_param(params, %{is_public: false, share_token: token})
       when is_binary(token) and token != "" do
    [{"token", token} | params]
  end

  defp maybe_add_token_param(params, _graph), do: params

  defp build_query_path(path, []), do: path
  defp build_query_path(path, params), do: "#{path}?#{URI.encode_query(params)}"

  defp escape_xml(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
