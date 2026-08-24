defmodule DialecticWeb.HighlightShare do
  import DialecticWeb.GraphPathHelper

  alias Dialectic.Highlights
  alias Dialectic.Highlights.Highlight
  alias DialecticWeb.Endpoint
  alias DialecticWeb.Utils.NodeTitleHelper

  @image_style_version 19
  @max_svg_quote_chars 800
  @max_svg_title_chars 220
  @sanitize_slice_multiplier 4
  @quote_font_family "Georgia, 'Times New Roman', serif"
  @ui_font_family "Arial, Helvetica, sans-serif"
  @favicon_path Path.expand("../../priv/static/images/favicon-32.png", __DIR__)
  @external_resource @favicon_path
  @favicon_data_uri "data:image/png;base64," <> Base.encode64(File.read!(@favicon_path))

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

  def share_path(%{slug: slug} = graph, highlight)
      when is_map(highlight) and is_binary(slug) and slug != "" do
    graph_path(graph, Map.get(highlight, :node_id), highlight: Map.get(highlight, :id))
  end

  def share_path(graph, highlight) when is_map(graph) and is_map(highlight) do
    params =
      []
      |> maybe_add_highlight_param(highlight)
      |> maybe_add_token_param(graph)
      |> maybe_add_node_param(highlight)

    build_query_path("/g/#{title_identifier(graph)}", params)
  end

  def image_url(graph, target \\ nil, opts \\ []),
    do: Endpoint.url() <> image_path(graph, target, opts)

  def image_path(graph, target \\ nil, opts \\ [])

  def image_path(%{slug: slug} = graph, nil, opts) when is_binary(slug) and slug != "" do
    params =
      []
      |> maybe_add_graph_version(graph)
      |> maybe_add_orientation(opts)
      |> maybe_add_token_param(graph)

    build_query_path("/g/#{slug}/share-card.svg", params)
  end

  def image_path(graph, nil, opts) when is_map(graph) do
    params =
      []
      |> maybe_add_graph_version(graph)
      |> maybe_add_orientation(opts)
      |> maybe_add_token_param(graph)

    build_query_path("/g/#{title_identifier(graph)}/share-card.svg", params)
  end

  def image_path(%{slug: slug} = graph, %{id: highlight_id} = highlight, opts)
      when is_binary(slug) and slug != "" do
    params =
      []
      |> maybe_add_version(highlight)
      |> maybe_add_orientation(opts)
      |> maybe_add_token_param(graph)

    build_query_path("/g/#{slug}/highlights/#{highlight_id}/share-card.svg", params)
  end

  def image_path(graph, %{id: highlight_id} = highlight, opts) when is_map(graph) do
    params =
      []
      |> maybe_add_version(highlight)
      |> maybe_add_orientation(opts)
      |> maybe_add_token_param(graph)

    build_query_path(
      "/g/#{title_identifier(graph)}/highlights/#{highlight_id}/share-card.svg",
      params
    )
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
        case NodeTitleHelper.extract_node_title(node, max_length: :infinity) do
          "Untitled" -> "Node #{node_id}"
          title -> title
        end
      end
    end)
  end

  def image_svg(graph, target \\ nil, opts \\ []) do
    layout = image_layout(Keyword.get(opts, :orientation, :landscape))

    graph
    |> share_card_content(target)
    |> render_share_card(layout)
  end

  defp share_card_content(graph, nil) do
    %{
      title: "#{graph.title} · RationalGrid",
      description: "Share card for #{graph.title} on RationalGrid",
      text: sanitize_text(graph.title, @max_svg_title_chars),
      source_label: nil
    }
  end

  defp share_card_content(graph, highlight) when is_map(highlight) do
    %{
      title: page_title(graph, highlight),
      description: page_description(graph, highlight),
      text: sanitize_text(Map.get(highlight, :selected_text_snapshot), @max_svg_quote_chars),
      source_label: node_title(graph, Map.get(highlight, :node_id))
    }
  end

  defp render_share_card(card, layout) do
    text_layout = quote_layout(card.text, layout)

    source_label =
      card.source_label
      |> sanitize_text(140)
      |> truncate_line_to_units(900 / 24)

    quote_markup =
      text_layout.lines
      |> Enum.with_index()
      |> Enum.map_join(fn {line, index} ->
        y = text_layout.start_y + index * text_layout.line_gap
        ~s(<tspan x="#{layout.text_left}" y="#{y}">#{escape_xml(line)}</tspan>)
      end)

    source_markup =
      if source_label == "" do
        ""
      else
        ~s(<text x="#{layout.text_left}" y="#{layout.source_y}" fill="#f8fafc" fill-opacity="0.9" font-size="24" font-weight="800" font-family="#{@ui_font_family}" letter-spacing="0">#{escape_xml(source_label)}</text>)
      end

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{layout.output_width}" height="#{layout.output_height}" viewBox="0 0 1200 #{layout.canvas_height}" role="img" aria-labelledby="title desc" data-orientation="#{layout.orientation}">
      <title id="title">#{escape_xml(card.title)}</title>
      <desc id="desc">#{escape_xml(card.description)}</desc>
      <defs>
        <linearGradient id="quoteCanvas" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#120f16" />
          <stop offset="45%" stop-color="#21132a" />
          <stop offset="100%" stop-color="#08231f" />
        </linearGradient>
        <radialGradient id="amberBloom" cx="12%" cy="12%" r="68%">
          <stop offset="0%" stop-color="#f59e0b" stop-opacity="0.52" />
          <stop offset="100%" stop-color="#f59e0b" stop-opacity="0" />
        </radialGradient>
        <radialGradient id="tealBloom" cx="88%" cy="18%" r="72%">
          <stop offset="0%" stop-color="#14b8a6" stop-opacity="0.42" />
          <stop offset="100%" stop-color="#14b8a6" stop-opacity="0" />
        </radialGradient>
        <radialGradient id="violetBloom" cx="66%" cy="88%" r="62%">
          <stop offset="0%" stop-color="#8b5cf6" stop-opacity="0.36" />
          <stop offset="100%" stop-color="#8b5cf6" stop-opacity="0" />
        </radialGradient>
        <linearGradient id="quotePanel" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#fff7ed" stop-opacity="0.18" />
          <stop offset="42%" stop-color="#ffffff" stop-opacity="0.07" />
          <stop offset="100%" stop-color="#2dd4bf" stop-opacity="0.13" />
        </linearGradient>
        <linearGradient id="highlightAccent" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#f59e0b" />
          <stop offset="48%" stop-color="#fef3c7" />
          <stop offset="100%" stop-color="#2dd4bf" />
        </linearGradient>
        <filter id="cardShadow" x="-8%" y="-10%" width="116%" height="124%">
          <feDropShadow dx="0" dy="28" stdDeviation="24" flood-color="#000000" flood-opacity="0.36" />
        </filter>
      </defs>

      <rect width="1200" height="#{layout.canvas_height}" fill="url(#quoteCanvas)" />
      <rect width="1200" height="#{layout.canvas_height}" fill="url(#amberBloom)" />
      <rect width="1200" height="#{layout.canvas_height}" fill="url(#tealBloom)" />
      <rect width="1200" height="#{layout.canvas_height}" fill="url(#violetBloom)" />
      <circle cx="1032" cy="112" r="168" fill="#14b8a6" fill-opacity="0.12" />
      <circle cx="158" cy="#{layout.canvas_height - 114}" r="152" fill="#f59e0b" fill-opacity="0.11" />

      <rect x="38" y="34" width="1124" height="#{layout.outer_height}" rx="40" fill="#0b1017" fill-opacity="0.88" filter="url(#cardShadow)" />
      <rect x="38.5" y="34.5" width="1123" height="#{layout.outer_height - 1}" rx="39.5" fill="none" stroke="#ffffff" stroke-opacity="0.13" />
      <rect x="58" y="54" width="1084" height="#{layout.panel_height}" rx="30" fill="url(#quotePanel)" stroke="#ffffff" stroke-opacity="0.12" />

      <image href="#{@favicon_data_uri}" x="78" y="76" width="28" height="28" />
      <text x="116" y="97" fill="#f8fafc" fill-opacity="0.78" font-size="16" font-weight="700" font-family="#{@ui_font_family}" letter-spacing="0">RationalGrid.ai</text>

      <rect x="78" y="#{layout.separator_y}" width="1044" height="1" fill="#ffffff" fill-opacity="0.13" />
      <rect x="#{layout.text_left}" y="#{layout.accent_y}" width="344" height="6" rx="3" fill="url(#highlightAccent)" opacity="0.96" />

      <text fill="#fff7ed" font-size="#{text_layout.font_size}" font-weight="700" font-family="#{@quote_font_family}" letter-spacing="0" paint-order="stroke" stroke="#120f16" stroke-width="2.2" stroke-opacity="0.24">
        #{quote_markup}
      </text>

      #{source_markup}
    </svg>
    """
  end

  defp image_layout(orientation) when orientation in [:portrait, "portrait"] do
    %{
      orientation: "portrait",
      output_width: 1080,
      output_height: 1350,
      canvas_height: 1500,
      outer_height: 1432,
      panel_height: 1392,
      separator_y: 126,
      text_left: 78,
      text_top: 170,
      text_width: 1044,
      text_height: 1120,
      accent_y: 1340,
      source_y: 1390,
      max_lines: 10,
      font_sizes: [112, 104, 96, 88, 80, 72, 64, 56, 48, 44]
    }
  end

  defp image_layout(_orientation) do
    %{
      orientation: "landscape",
      output_width: 1200,
      output_height: 630,
      canvas_height: 630,
      outer_height: 562,
      panel_height: 522,
      separator_y: 126,
      text_left: 78,
      text_top: 140,
      text_width: 1044,
      text_height: 350,
      accent_y: 514,
      source_y: 552,
      max_lines: 6,
      font_sizes: [88, 84, 80, 76, 72, 68, 64, 60, 56, 52, 48, 44, 40]
    }
  end

  defp quote_layout(text, layout) do
    text
    |> quote_layout_candidates(layout)
    |> Enum.max_by(&quote_layout_score/1, fn -> nil end)
    |> case do
      nil -> fallback_quote_layout(text, layout)
      layout -> layout
    end
  end

  defp quote_layout_score(%{font_size: font_size, lines: lines, max_units: max_units}) do
    {longest_line, shortest_line, total_units, line_count} =
      Enum.reduce(lines, {1, nil, 0, 0}, fn line, {longest, shortest, total, count} ->
        units = text_units(line)
        {max(longest, units), min(shortest || units, units), total + units, count + 1}
      end)

    shortest_line = shortest_line || 1
    average_line = total_units / max(line_count, 1)
    line_count_penalty = max(line_count - 4, 0) * 0.12

    fill_score = average_line / max_units
    balance_score = shortest_line / max(longest_line, 1)
    font_score = font_size / 76

    fill_score * 0.3 + balance_score * 0.25 + font_score * 0.45 - line_count_penalty
  end

  defp quote_layout_candidates(text, layout) do
    layout.font_sizes
    |> Enum.map(fn font_size ->
      max_units = max_line_units(font_size, layout)
      lines = wrap_lines_by_width(text, max_units, layout.max_lines)
      line_gap = quote_line_gap(font_size)
      block_height = quote_block_height(lines, line_gap)

      if block_height <= layout.text_height do
        %{
          font_size: font_size,
          line_gap: line_gap,
          start_y: quote_start_y(block_height, font_size, layout),
          max_units: max_units,
          lines: lines
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp fallback_quote_layout(text, layout) do
    font_size = List.last(layout.font_sizes)
    line_gap = quote_line_gap(font_size)
    max_units = max_line_units(font_size, layout)
    lines = wrap_lines_by_width(text, max_units, layout.max_lines)
    block_height = quote_block_height(lines, line_gap)

    %{
      font_size: font_size,
      line_gap: line_gap,
      start_y: quote_start_y(block_height, font_size, layout),
      max_units: max_units,
      lines: lines
    }
  end

  defp quote_line_gap(font_size), do: round(font_size * 1.18)

  defp quote_block_height(lines, line_gap) do
    case length(lines) do
      0 -> 0
      1 -> line_gap
      count -> (count - 1) * line_gap + round(line_gap * 0.92)
    end
  end

  defp quote_start_y(block_height, font_size, layout) do
    extra_space = max(layout.text_height - block_height, 0)
    layout.text_top + div(extra_space, 2) + font_size
  end

  defp max_line_units(font_size, layout), do: layout.text_width / font_size

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
    lines
    |> Enum.map(&truncate_line_to_units(&1, max_units))
    |> balance_line_endings(max_units)
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
    |> balance_line_endings(max_units)
  end

  defp balance_line_endings(lines, _max_units) when length(lines) < 2, do: lines

  defp balance_line_endings(lines, max_units) do
    last_line = List.last(lines)

    if String.ends_with?(last_line, "…") or text_units(last_line) >= max_units * 0.42 do
      lines
    else
      previous_index = length(lines) - 2
      previous_line = Enum.at(lines, previous_index)
      previous_words = String.split(previous_line, " ", trim: true)

      maybe_move_word_to_last_line(lines, previous_index, previous_words, last_line, max_units)
    end
  end

  defp maybe_move_word_to_last_line(
         lines,
         _previous_index,
         previous_words,
         _last_line,
         _max_units
       )
       when length(previous_words) < 2 do
    lines
  end

  defp maybe_move_word_to_last_line(lines, previous_index, previous_words, last_line, max_units) do
    word = List.last(previous_words)
    new_previous = previous_words |> Enum.drop(-1) |> Enum.join(" ")
    new_last = word <> " " <> last_line

    if text_units(new_previous) >= max_units * 0.32 and text_units(new_last) <= max_units do
      lines
      |> List.replace_at(previous_index, new_previous)
      |> List.replace_at(length(lines) - 1, new_last)
    else
      lines
    end
  end

  defp truncate_line_to_units(text, max_units) do
    trimmed = String.trim(text)

    if text_units(trimmed) <= max_units do
      trimmed
    else
      {graphemes, _units, truncated?} =
        trimmed
        |> String.graphemes()
        |> Enum.reduce_while({[], 0.0, false}, fn grapheme, {acc, units, false} ->
          next_units = units + char_units(grapheme)

          if next_units + char_units("…") <= max_units do
            {:cont, {[grapheme | acc], next_units, false}}
          else
            {:halt, {acc, units, true}}
          end
        end)

      truncated_text = graphemes |> Enum.reverse() |> IO.iodata_to_binary()

      if truncated?, do: String.trim_trailing(truncated_text) <> "…", else: truncated_text
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

  defp sanitize_text(nil, _max_length), do: ""

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

  defp maybe_add_graph_version(params, graph) do
    params = [{"sv", @image_style_version} | params]

    case Map.get(graph, :updated_at) || Map.get(graph, :inserted_at) do
      %DateTime{} = updated_at -> [{"v", DateTime.to_unix(updated_at, :second)} | params]
      _ -> params
    end
  end

  defp maybe_add_version(params, highlight) do
    params = [{"sv", @image_style_version} | params]

    case Map.get(highlight, :updated_at) do
      %DateTime{} = updated_at -> [{"v", DateTime.to_unix(updated_at, :second)} | params]
      _ -> params
    end
  end

  defp maybe_add_orientation(params, opts) do
    case Keyword.get(opts, :orientation, :landscape) do
      orientation when orientation in [:portrait, "portrait"] ->
        [{"orientation", "portrait"} | params]

      _orientation ->
        params
    end
  end

  defp maybe_add_token_param(params, %{is_public: false, share_token: token})
       when is_binary(token) and token != "" do
    [{"token", token} | params]
  end

  defp maybe_add_token_param(params, _graph), do: params

  defp maybe_add_highlight_param(params, %{id: highlight_id}) when not is_nil(highlight_id),
    do: [{:highlight, highlight_id} | params]

  defp maybe_add_highlight_param(params, _highlight), do: params

  defp maybe_add_node_param(params, %{node_id: node_id})
       when is_binary(node_id) and node_id != "",
       do: [{:node, node_id} | params]

  defp maybe_add_node_param(params, _highlight), do: params

  defp title_identifier(%{title: title}) do
    title
    |> to_string()
    |> URI.encode(&URI.char_unreserved?/1)
  end

  defp build_query_path(path, []), do: path
  defp build_query_path(path, params), do: "#{path}?#{URI.encode_query(params)}"

  defp escape_xml(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
