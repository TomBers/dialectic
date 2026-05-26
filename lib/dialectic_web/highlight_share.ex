defmodule DialecticWeb.HighlightShare do
  import DialecticWeb.GraphPathHelper

  alias Dialectic.Highlights
  alias Dialectic.Highlights.Highlight
  alias DialecticWeb.Endpoint
  alias DialecticWeb.Utils.NodeTitleHelper

  @image_width 1200
  @image_height 630
  @max_quote_lines 6
  @image_style_version 10
  @quote_area_left 118
  @quote_area_top 170
  @quote_area_width 960
  @quote_area_height 285
  @title_area_left 78
  @title_area_top 500
  @title_area_width 940
  @title_area_height 72
  @max_title_lines 2
  @max_svg_quote_chars 800
  @max_svg_title_chars 220
  @sanitize_slice_multiplier 4
  @quote_font_family "Baskerville, Georgia, serif"
  @ui_font_family "Arial, Helvetica, sans-serif"

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
    quote_text = sanitize_text(Map.get(highlight, :selected_text_snapshot), @max_svg_quote_chars)
    title_layout = title_layout(graph.title)
    quote_layout = quote_layout(quote_text)

    title_markup =
      title_layout.lines
      |> Enum.with_index()
      |> Enum.map_join("", fn {line, index} ->
        y = title_layout.start_y + index * title_layout.line_gap
        ~s(<tspan x="#{@title_area_left}" y="#{y}">#{escape_xml(line)}</tspan>)
      end)

    quote_markup =
      quote_layout.lines
      |> Enum.with_index()
      |> Enum.map_join("", fn {line, index} ->
        y = quote_layout.start_y + index * quote_layout.line_gap
        ~s(<tspan x="#{@quote_area_left}" y="#{y}">#{escape_xml(line)}</tspan>)
      end)

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{@image_width}" height="#{@image_height}" viewBox="0 0 #{@image_width} #{@image_height}" role="img" aria-labelledby="title desc">
      <title id="title">#{escape_xml(page_title(graph, highlight))}</title>
      <desc id="desc">#{escape_xml(page_description(graph, highlight))}</desc>
      <defs>
        <linearGradient id="canvas" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#fffef8" />
          <stop offset="100%" stop-color="#f6f8fc" />
        </linearGradient>
        <linearGradient id="wash" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#ede9fe" stop-opacity="0.8" />
          <stop offset="100%" stop-color="#e0f2fe" stop-opacity="0.4" />
        </linearGradient>
      </defs>

      <rect width="1200" height="630" fill="url(#canvas)" />
      <circle cx="1080" cy="98" r="150" fill="#eef2ff" />
      <circle cx="150" cy="540" r="124" fill="#eff6ff" />
      <rect x="78" y="82" width="130" height="8" rx="4" fill="url(#wash)" />
      <text x="78" y="118" fill="#6366f1" font-size="24" font-weight="700" font-family="#{@ui_font_family}" letter-spacing="0.8">Quote</text>

      <text x="70" y="198" fill="#c4b5fd" font-size="72" font-weight="700" font-family="#{@quote_font_family}">“</text>
      <text fill="#172033" font-size="#{quote_layout.font_size}" font-weight="600" font-style="italic" font-family="#{@quote_font_family}" letter-spacing="0">
        #{quote_markup}
      </text>
      <text fill="#334155" font-size="#{title_layout.font_size}" font-weight="700" font-family="#{@ui_font_family}" letter-spacing="-0.2">
        #{title_markup}
      </text>

      <text x="1128" y="586" text-anchor="end" fill="#64748b" fill-opacity="0.8" font-size="15" font-weight="600" font-family="#{@ui_font_family}" letter-spacing="0.2">RationalGrid.ai</text>
    </svg>
    """
  end

  defp quote_layout(text) do
    Enum.find_value(candidate_font_sizes(), fn font_size ->
      lines = wrap_lines_by_width(text, max_line_units(font_size), @max_quote_lines)
      line_gap = quote_line_gap(font_size)
      block_height = quote_block_height(lines, line_gap)

      if block_height <= @quote_area_height do
        %{
          font_size: font_size,
          line_gap: line_gap,
          start_y: quote_start_y(block_height, font_size),
          lines: lines
        }
      end
    end) || fallback_quote_layout(text)
  end

  defp fallback_quote_layout(text) do
    font_size = 36
    line_gap = quote_line_gap(font_size)
    lines = wrap_lines_by_width(text, max_line_units(font_size), @max_quote_lines)
    block_height = quote_block_height(lines, line_gap)

    %{
      font_size: font_size,
      line_gap: line_gap,
      start_y: quote_start_y(block_height, font_size),
      lines: lines
    }
  end

  defp title_layout(text) do
    title_text = sanitize_text(text, @max_svg_title_chars)

    Enum.find_value([30, 28, 26, 24, 22], fn font_size ->
      lines = wrap_lines_by_width(title_text, @title_area_width / font_size, @max_title_lines)
      line_gap = round(font_size * 1.18)
      block_height = quote_block_height(lines, line_gap)

      if block_height <= @title_area_height do
        %{
          font_size: font_size,
          line_gap: line_gap,
          start_y: @title_area_top + font_size,
          lines: lines
        }
      end
    end) || fallback_title_layout(title_text)
  end

  defp fallback_title_layout(text) do
    font_size = 20
    line_gap = round(font_size * 1.18)
    lines = wrap_lines_by_width(text, @title_area_width / font_size, @max_title_lines)

    %{
      font_size: font_size,
      line_gap: line_gap,
      start_y: @title_area_top + font_size,
      lines: lines
    }
  end

  defp candidate_font_sizes, do: [82, 76, 72, 68, 64, 60, 56, 52, 48, 44, 40, 36]

  defp quote_line_gap(font_size), do: round(font_size * 1.22)

  defp quote_block_height(lines, line_gap) do
    case length(lines) do
      0 -> 0
      1 -> line_gap
      count -> (count - 1) * line_gap + round(line_gap * 0.92)
    end
  end

  defp quote_start_y(block_height, font_size) do
    extra_space = max(@quote_area_height - block_height, 0)
    @quote_area_top + div(extra_space, 2) + font_size
  end

  defp max_line_units(font_size) do
    @quote_area_width / font_size
  end

  defp wrap_lines_by_width(text, max_units, max_lines) do
    text
    |> String.split(" ", trim: true)
    |> Enum.reduce([], fn word, acc ->
      append_word_to_lines(acc, word, max_units)
    end)
    |> limit_lines_by_width(max_units, max_lines)
  end

  defp append_word_to_lines([], word, _max_units), do: [word]

  defp append_word_to_lines(lines, word, max_units) do
    current_line = List.last(lines)
    candidate = current_line <> " " <> word

    if text_units(candidate) <= max_units do
      List.replace_at(lines, length(lines) - 1, candidate)
    else
      lines ++ [word]
    end
  end

  defp limit_lines_by_width(lines, max_units, max_lines) when length(lines) <= max_lines do
    Enum.map(lines, &truncate_line_to_units(&1, max_units))
  end

  defp limit_lines_by_width(lines, max_units, max_lines) do
    {visible_lines, overflow_lines} = Enum.split(lines, max_lines)
    overflow_text = Enum.join(overflow_lines, " ")
    merged_last_line = List.last(visible_lines) <> " " <> overflow_text

    visible_lines
    |> Enum.map(&truncate_line_to_units(&1, max_units))
    |> List.replace_at(
      max_lines - 1,
      truncate_line_to_units(merged_last_line, max_units)
    )
  end

  defp truncate_line_to_units(text, max_units) do
    trimmed = String.trim(text)

    if text_units(trimmed) <= max_units do
      trimmed
    else
      trimmed
      |> String.graphemes()
      |> Enum.reduce_while({"", 0.0}, fn grapheme, {acc, units} ->
        next_units = units + char_units(grapheme)

        if next_units + char_units("…") <= max_units do
          {:cont, {acc <> grapheme, next_units}}
        else
          {:halt, {String.trim_trailing(acc) <> "…", next_units}}
        end
      end)
      |> elem(0)
    end
  end

  defp text_units(text) do
    text
    |> String.graphemes()
    |> Enum.reduce(0.0, fn grapheme, total -> total + char_units(grapheme) end)
  end

  defp char_units(" "), do: 0.32
  defp char_units("…"), do: 0.55

  defp char_units(grapheme)
       when grapheme in ["i", "l", "I", "j", "t", "'", "\"", ".", ",", ":", ";", "!"] do
    0.28
  end

  defp char_units(grapheme) when grapheme in ["m", "w", "M", "W", "Q", "G", "@", "%", "&"] do
    0.9
  end

  defp char_units(grapheme) do
    if grapheme =~ ~r/[A-Z]/ do
      0.72
    else
      0.56
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
    sanitize_text(text, max_length)
  end

  defp sanitize_text(text, nil) do
    text
    |> to_string()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp sanitize_text(text, max_length) when is_integer(max_length) and max_length > 0 do
    text
    |> to_string()
    |> String.slice(0, max_length * @sanitize_slice_multiplier)
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> truncate(max_length)
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
