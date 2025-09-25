defmodule DialecticWeb.ReferencesComp do
  use DialecticWeb, :live_component

  @moduledoc """
  A right-side slide-in panel that shows:
    1) Structured references parsed from a node's `ReferencesJSON:` line (with confidence badges)
    2) Aggregated references for the entire graph, grouped by type

  Expected assigns:
    - id: component id
    - show: boolean to show/hide the panel (defaults to false)
    - node: current node map or nil
    - references_by_type: map of type => [ref], where each ref is:
        %{
          type: :doi | :arxiv | :url | :isbn | :citation,
          label: String.t(),
          value: String.t(),
          link: String.t() | nil,
          nodes: [String.t()],
          count: non_neg_integer()
        }
    - close_event: event name to close the panel (defaults to "toggle_references_panel")
  """

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:show, fn -> false end)
      |> assign_new(:node, fn -> nil end)
      |> assign_new(:references_by_type, fn -> %{} end)
      |> assign_new(:close_event, fn -> "toggle_references_panel" end)
      |> assign(:structured_refs, parse_structured_refs(assigns[:node]))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={
      if @show,
        do:
          "fixed top-0 right-0 h-full w-80 bg-white border-l border-gray-200 shadow-lg z-40 transform translate-x-0 transition-transform duration-200",
        else:
          "fixed top-0 right-0 h-full w-80 bg-white border-l border-gray-200 shadow-lg z-40 transform translate-x-full transition-transform duration-200"
    }>
      <div class="flex items-center justify-between px-3 py-2 border-b border-gray-200">
        <h3 class="text-sm font-semibold">References</h3>
        <button
          type="button"
          class="p-1 rounded hover:bg-gray-100"
          phx-click={@close_event}
          title="Close"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>

      <div class="h-[calc(100%-44px)] overflow-y-auto p-3 space-y-4">
        <% structured_all =
          (@references_by_type || %{})
          |> Enum.flat_map(fn {_, refs} -> refs end)
          |> Enum.filter(fn r -> is_number(r[:confidence]) and r[:confidence] >= 0.5 end)
          |> Enum.map(fn r ->
            id = to_string(r[:value] || "")

            type =
              case r[:type] do
                t when is_atom(t) -> Atom.to_string(t)
                t when is_binary(t) -> t
                _ -> "url"
              end

            url =
              cond do
                is_binary(r[:link]) and r[:link] != "" -> r[:link]
                type == "doi" and id != "" -> "https://doi.org/" <> id
                type == "arxiv" and id != "" -> "https://arxiv.org/abs/" <> id
                true -> nil
              end

            %{
              "title" => to_string(r[:title] || ""),
              "authors" =>
                case r[:authors] do
                  l when is_list(l) -> l
                  _ -> []
                end,
              "year" => r[:year],
              "venue" => to_string(r[:venue] || ""),
              "type" => type,
              "id" => id,
              "url" => url,
              "confidence" => r[:confidence]
            }
          end) %>
        <% show_refs = if length(structured_all) > 0, do: structured_all, else: @structured_refs %>
        <%= if length(show_refs) > 0 do %>
          <section>
            <div class="flex items-center justify-between mb-1">
              <h4 class="text-xs font-semibold text-gray-700">Structured</h4>
              <span class="text-[11px] text-gray-500">({length(show_refs)})</span>
            </div>
            <ul class="space-y-3">
              <%= for ref <- show_refs do %>
                <% url = ref_url(ref) %>
                <% conf = ref_confidence(ref) %>
                <% conf_class = confidence_class(conf) %>
                <% type = ref["type"] %>
                <% id = ref_id(ref) %>
                <% authors = format_authors(ref["authors"]) %>
                <% year = ref_year(ref) %>
                <% venue = ref_venue(ref) %>
                <li class="text-sm border border-gray-200 rounded-md p-2">
                  <!-- Top row: title link + confidence -->
                  <div class="flex items-start justify-between gap-2">
                    <div class="min-w-0">
                      <%= if url do %>
                        <a
                          href={url}
                          target="_blank"
                          class="text-blue-600 hover:underline break-all font-medium"
                          title={ref_title(ref)}
                        >
                          {ref_title(ref)}
                        </a>
                      <% else %>
                        <span class="text-gray-900 break-all font-medium">{ref_title(ref)}</span>
                      <% end %>
                    </div>
                    <span class={"shrink-0 text-[11px] px-1.5 py-0.5 rounded-full " <> conf_class}>
                      {if conf, do: "#{trunc(Float.round(conf * 100, 0))}%", else: "N/A"}
                    </span>
                  </div>
                  
    <!-- Meta row: authors • year • venue -->
                  <div class="mt-1 text-[12px] text-gray-600 break-words">
                    <%= if authors != "" do %>
                      <span>{authors}</span>
                    <% end %>
                    <%= if authors != "" and (year || venue) do %>
                      <span> • </span>
                    <% end %>
                    <%= if year do %>
                      <span>{year}</span>
                    <% end %>
                    <%= if year && venue != "" do %>
                      <span> • </span>
                    <% end %>
                    <%= if venue != "" do %>
                      <span>{venue}</span>
                    <% end %>
                  </div>
                  
    <!-- Badges row: type, id with copy, open link -->
                  <div class="mt-2 flex items-center gap-2 flex-wrap">
                    <span class={"text-[11px] px-1.5 py-0.5 rounded-full " <> type_badge_class(type)}>
                      {type_badge_label(type)}
                    </span>

                    <%= if id != "" do %>
                      <button
                        type="button"
                        class="text-[11px] px-1.5 py-0.5 rounded-full border border-gray-300 hover:bg-gray-100"
                        onclick={"navigator.clipboard.writeText('#{id}')"}
                        title={"Copy #{String.upcase(to_string(type))} ID"}
                      >
                        ID: {id}
                      </button>
                    <% end %>

                    <%= if url do %>
                      <a
                        href={url}
                        target="_blank"
                        class="text-[11px] px-1.5 py-0.5 rounded-full border border-gray-300 hover:bg-gray-100"
                        title="Open link in new tab"
                      >
                        Open
                      </a>
                    <% end %>
                  </div>
                </li>
              <% end %>
            </ul>
          </section>
        <% end %>

        <% types = [] %>
        <% refs_by_type =
          (@references_by_type || %{})
          |> Enum.map(fn {t, refs} ->
            {t, Enum.filter(refs, fn r -> is_number(r[:confidence]) and r[:confidence] >= 0.5 end)}
          end)
          |> Enum.into(%{}) %>

        <%= for type <- types do %>
          <% refs = Map.get(refs_by_type, type, []) %>
          <%= if length(refs) > 0 do %>
            <% label =
              case type do
                :doi -> "DOIs"
                :arxiv -> "arXiv"
                :url -> "Links"
                :isbn -> "ISBNs"
                :citation -> "Citations"
                _ -> to_string(type)
              end %>
            <section>
              <div class="flex items-center justify-between mb-1">
                <h4 class="text-xs font-semibold text-gray-700">{label}</h4>
                <span class="text-[11px] text-gray-500">({length(refs)})</span>
              </div>
              <ul class="space-y-2">
                <%= for ref <- refs do %>
                  <li class="text-sm border border-gray-200 rounded-md p-2">
                    <div class="flex items-start justify-between gap-2">
                      <div class="min-w-0">
                        <%= if ref[:link] do %>
                          <a
                            href={ref[:link]}
                            target="_blank"
                            class="text-blue-600 hover:underline break-all font-medium"
                          >
                            {if is_binary(ref[:title]) and String.trim(to_string(ref[:title])) != "",
                              do: String.trim(to_string(ref[:title])),
                              else: ref[:label]}
                          </a>
                        <% else %>
                          <span class="text-gray-900 break-all font-medium">
                            {if is_binary(ref[:title]) and String.trim(to_string(ref[:title])) != "",
                              do: String.trim(to_string(ref[:title])),
                              else: ref[:label]}
                          </span>
                        <% end %>
                      </div>
                      <span class="text-[11px] text-gray-500">×{ref[:count] || 1}</span>
                    </div>
                    <div class="mt-1 text-[12px] text-gray-600 break-words">
                      <% authors =
                        case ref[:authors] do
                          l when is_list(l) ->
                            l
                            |> Enum.filter(&is_binary/1)
                            |> Enum.map(&String.trim/1)
                            |> Enum.reject(&(&1 == ""))
                            |> Enum.join(", ")

                          _ ->
                            ""
                        end %>
                      <% year = ref[:year] %>
                      <% venue = ref[:venue] || "" %>
                      <%= if authors != "" do %>
                        <span>{authors}</span>
                      <% end %>
                      <%= if authors != "" and (year || venue != "") do %>
                        <span> • </span>
                      <% end %>
                      <%= if year do %>
                        <span>{year}</span>
                      <% end %>
                      <%= if year && venue != "" do %>
                        <span> • </span>
                      <% end %>
                      <%= if venue != "" do %>
                        <span>{venue}</span>
                      <% end %>
                    </div>
                    <div class="mt-1 flex flex-wrap gap-1">
                      <%= for nid <- ref[:nodes] || [] do %>
                        <button
                          type="button"
                          class="px-2 py-0.5 text-[11px] border border-gray-300 rounded-full hover:bg-gray-100"
                          phx-click="node_clicked"
                          phx-value-id={nid}
                          title={"Go to node " <> to_string(nid)}
                        >
                          Node {nid}
                        </button>
                      <% end %>
                    </div>
                  </li>
                <% end %>
              </ul>
            </section>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Helpers: Structured references (from ReferencesJSON in node content)
  # ───────────────────────────────────────────────────────────────────────────

  defp parse_structured_refs(nil), do: []
  defp parse_structured_refs(%{content: nil}), do: []

  defp parse_structured_refs(%{content: content}) when is_binary(content) do
    with [_, raw_json] <- Regex.run(~r/ReferencesJSON:\s*(.+)\s*$/mi, content),
         json <- normalize_curly_quotes(String.trim(raw_json)),
         {:ok, list} <- Jason.decode(json),
         true <- is_list(list) do
      list
      |> Enum.filter(&is_map/1)
    else
      _ -> []
    end
  end

  defp ref_url(ref) when is_map(ref) do
    cond do
      is_binary(ref["url"]) and ref["url"] != "" ->
        ref["url"]

      ref["type"] == "doi" and is_binary(ref["id"]) and ref["id"] != "" ->
        "https://doi.org/" <> ref["id"]

      ref["type"] == "arxiv" and is_binary(ref["id"]) and ref["id"] != "" ->
        "https://arxiv.org/abs/" <> ref["id"]

      true ->
        nil
    end
  end

  defp ref_confidence(ref) when is_map(ref) do
    case ref["confidence"] do
      c when is_float(c) or is_integer(c) -> c * 1.0
      _ -> nil
    end
  end

  defp ref_title(ref) when is_map(ref) do
    title = if is_binary(ref["title"]), do: String.trim(ref["title"]), else: ""
    id = if is_binary(ref["id"]), do: String.trim(ref["id"]), else: ""
    url = if is_binary(ref["url"]), do: String.trim(ref["url"]), else: ""

    cond do
      title != "" -> title
      id != "" -> id
      url != "" -> url
      true -> "reference"
    end
  end

  defp ref_id(ref) when is_map(ref) do
    id = if is_binary(ref["id"]), do: String.trim(ref["id"]), else: ""

    if id != "" do
      id
    else
      # best-effort derive from URL for known types
      case {ref["type"], ref["url"]} do
        {"doi", url} when is_binary(url) ->
          String.replace_prefix(url, "https://doi.org/", "")

        {"arxiv", url} when is_binary(url) ->
          String.replace_prefix(url, "https://arxiv.org/abs/", "")

        _ ->
          ""
      end
    end
  end

  defp ref_year(ref) when is_map(ref) do
    case ref["year"] do
      y when is_integer(y) -> y
      y when is_float(y) -> trunc(y)
      _ -> nil
    end
  end

  defp ref_venue(ref) when is_map(ref) do
    v = if is_binary(ref["venue"]), do: String.trim(ref["venue"]), else: ""
    v
  end

  defp format_authors(list) when is_list(list) do
    list
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(", ")
  end

  defp format_authors(_), do: ""

  defp type_badge_label(type) do
    case type do
      "doi" -> "DOI"
      "arxiv" -> "arXiv"
      "isbn" -> "ISBN"
      "url" -> "URL"
      _ -> "Ref"
    end
  end

  defp type_badge_class(type) do
    case type do
      "doi" -> "bg-indigo-100 text-indigo-700"
      "arxiv" -> "bg-purple-100 text-purple-700"
      "isbn" -> "bg-amber-100 text-amber-700"
      "url" -> "bg-blue-100 text-blue-700"
      _ -> "bg-gray-100 text-gray-700"
    end
  end

  # Replace curly quotes with straight quotes to allow JSON decoding
  defp normalize_curly_quotes(s) when is_binary(s) do
    s
    # curly double quotes -> "
    |> String.replace(~r/[\x{201C}\x{201D}]/u, "\"")
    # curly single quotes -> '
    |> String.replace(~r/[\x{2018}\x{2019}]/u, "'")
  end

  defp confidence_class(conf) do
    cond do
      (is_float(conf) or is_integer(conf)) and conf >= 0.8 ->
        "bg-green-100 text-green-700"

      (is_float(conf) or is_integer(conf)) and conf >= 0.6 ->
        "bg-amber-100 text-amber-700"

      true ->
        "bg-gray-100 text-gray-700"
    end
  end
end
