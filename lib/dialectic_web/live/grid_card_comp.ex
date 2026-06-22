defmodule DialecticWeb.GridCardComp do
  use DialecticWeb, :html

  @tag_palettes %{
    philosophy: %{
      gradient: "bg-[linear-gradient(135deg,#1e1b4b_0%,#7e22ce_52%,#f59e0b_100%)]",
      border: "border-violet-200 hover:border-violet-300 hover:shadow-violet-950/10",
      pill: "bg-violet-50 text-violet-700 ring-violet-600/20"
    },
    mind: %{
      gradient: "bg-[linear-gradient(135deg,#172554_0%,#4f46e5_50%,#ec4899_100%)]",
      border: "border-indigo-200 hover:border-indigo-300 hover:shadow-indigo-950/10",
      pill: "bg-indigo-50 text-indigo-700 ring-indigo-600/20"
    },
    wellbeing: %{
      gradient: "bg-[linear-gradient(135deg,#064e3b_0%,#0d9488_52%,#38bdf8_100%)]",
      border: "border-emerald-200 hover:border-emerald-300 hover:shadow-emerald-950/10",
      pill: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
    },
    technology: %{
      gradient: "bg-[linear-gradient(135deg,#020617_0%,#2563eb_50%,#22d3ee_100%)]",
      border: "border-blue-200 hover:border-blue-300 hover:shadow-blue-950/10",
      pill: "bg-blue-50 text-blue-700 ring-blue-600/20"
    },
    society: %{
      gradient: "bg-[linear-gradient(135deg,#431407_0%,#b91c1c_50%,#f59e0b_100%)]",
      border: "border-orange-200 hover:border-orange-300 hover:shadow-orange-950/10",
      pill: "bg-orange-50 text-orange-700 ring-orange-600/20"
    },
    history: %{
      gradient: "bg-[linear-gradient(135deg,#422006_0%,#b45309_52%,#fbbf24_100%)]",
      border: "border-amber-200 hover:border-amber-300 hover:shadow-amber-950/10",
      pill: "bg-amber-50 text-amber-700 ring-amber-600/20"
    },
    arts: %{
      gradient: "bg-[linear-gradient(135deg,#4a044e_0%,#c026d3_52%,#fb7185_100%)]",
      border: "border-fuchsia-200 hover:border-fuchsia-300 hover:shadow-fuchsia-950/10",
      pill: "bg-fuchsia-50 text-fuchsia-700 ring-fuchsia-600/20"
    },
    science: %{
      gradient: "bg-[linear-gradient(135deg,#0f172a_0%,#0284c7_52%,#2dd4bf_100%)]",
      border: "border-sky-200 hover:border-sky-300 hover:shadow-sky-950/10",
      pill: "bg-sky-50 text-sky-700 ring-sky-600/20"
    },
    space: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#4338ca_48%,#06b6d4_100%)]",
      border: "border-indigo-200 hover:border-indigo-300 hover:shadow-indigo-950/10",
      pill: "bg-indigo-50 text-indigo-700 ring-indigo-600/20"
    },
    earth: %{
      gradient: "bg-[linear-gradient(135deg,#14532d_0%,#65a30d_52%,#fbbf24_100%)]",
      border: "border-lime-200 hover:border-lime-300 hover:shadow-lime-950/10",
      pill: "bg-lime-50 text-lime-700 ring-lime-600/20"
    },
    sports: %{
      gradient: "bg-[linear-gradient(135deg,#083344_0%,#0d9488_52%,#f97316_100%)]",
      border: "border-teal-200 hover:border-teal-300 hover:shadow-teal-950/10",
      pill: "bg-teal-50 text-teal-700 ring-teal-600/20"
    },
    rose: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#9f1239_58%,#f43f5e_100%)]",
      border: "border-rose-200 hover:border-rose-300 hover:shadow-rose-950/10",
      pill: "bg-rose-50 text-rose-700 ring-rose-600/20"
    },
    ember: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#9a3412_58%,#f97316_100%)]",
      border: "border-orange-200 hover:border-orange-300 hover:shadow-orange-950/10",
      pill: "bg-orange-50 text-orange-700 ring-orange-600/20"
    },
    gold: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#92400e_58%,#f59e0b_100%)]",
      border: "border-amber-200 hover:border-amber-300 hover:shadow-amber-950/10",
      pill: "bg-amber-50 text-amber-700 ring-amber-600/20"
    },
    leaf: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#3f6212_58%,#84cc16_100%)]",
      border: "border-lime-200 hover:border-lime-300 hover:shadow-lime-950/10",
      pill: "bg-lime-50 text-lime-700 ring-lime-600/20"
    },
    forest: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#166534_58%,#22c55e_100%)]",
      border: "border-green-200 hover:border-green-300 hover:shadow-green-950/10",
      pill: "bg-green-50 text-green-700 ring-green-600/20"
    },
    jade: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#065f46_58%,#10b981_100%)]",
      border: "border-emerald-200 hover:border-emerald-300 hover:shadow-emerald-950/10",
      pill: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
    },
    lagoon: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#0f766e_58%,#14b8a6_100%)]",
      border: "border-teal-200 hover:border-teal-300 hover:shadow-teal-950/10",
      pill: "bg-teal-50 text-teal-700 ring-teal-600/20"
    },
    aqua: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#155e75_58%,#06b6d4_100%)]",
      border: "border-cyan-200 hover:border-cyan-300 hover:shadow-cyan-950/10",
      pill: "bg-cyan-50 text-cyan-700 ring-cyan-600/20"
    },
    sky: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#075985_58%,#38bdf8_100%)]",
      border: "border-sky-200 hover:border-sky-300 hover:shadow-sky-950/10",
      pill: "bg-sky-50 text-sky-700 ring-sky-600/20"
    },
    blue: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#1d4ed8_58%,#60a5fa_100%)]",
      border: "border-blue-200 hover:border-blue-300 hover:shadow-blue-950/10",
      pill: "bg-blue-50 text-blue-700 ring-blue-600/20"
    },
    indigo: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#4338ca_58%,#818cf8_100%)]",
      border: "border-indigo-200 hover:border-indigo-300 hover:shadow-indigo-950/10",
      pill: "bg-indigo-50 text-indigo-700 ring-indigo-600/20"
    },
    violet: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#6d28d9_58%,#a78bfa_100%)]",
      border: "border-violet-200 hover:border-violet-300 hover:shadow-violet-950/10",
      pill: "bg-violet-50 text-violet-700 ring-violet-600/20"
    },
    orchid: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#7e22ce_58%,#c084fc_100%)]",
      border: "border-purple-200 hover:border-purple-300 hover:shadow-purple-950/10",
      pill: "bg-purple-50 text-purple-700 ring-purple-600/20"
    },
    magenta: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#a21caf_58%,#e879f9_100%)]",
      border: "border-fuchsia-200 hover:border-fuchsia-300 hover:shadow-fuchsia-950/10",
      pill: "bg-fuchsia-50 text-fuchsia-700 ring-fuchsia-600/20"
    },
    pink: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#be185d_58%,#f472b6_100%)]",
      border: "border-pink-200 hover:border-pink-300 hover:shadow-pink-950/10",
      pill: "bg-pink-50 text-pink-700 ring-pink-600/20"
    },
    default: %{
      gradient: "bg-[linear-gradient(135deg,#111827_0%,#334155_58%,#64748b_100%)]",
      border: "border-slate-200 hover:border-slate-300 hover:shadow-slate-950/10",
      pill: "bg-slate-100 text-slate-600 ring-slate-600/20"
    }
  }

  @fallback_palette_keys [
    :rose,
    :ember,
    :gold,
    :leaf,
    :forest,
    :jade,
    :lagoon,
    :aqua,
    :sky,
    :blue,
    :indigo,
    :violet,
    :orchid,
    :magenta,
    :pink
  ]

  @tag_palette_stops %{
    philosophy: {"#1e1b4b", "#7e22ce", "#f59e0b"},
    mind: {"#172554", "#4f46e5", "#ec4899"},
    wellbeing: {"#064e3b", "#0d9488", "#38bdf8"},
    technology: {"#020617", "#2563eb", "#22d3ee"},
    society: {"#431407", "#b91c1c", "#f59e0b"},
    history: {"#422006", "#b45309", "#fbbf24"},
    arts: {"#4a044e", "#c026d3", "#fb7185"},
    science: {"#0f172a", "#0284c7", "#2dd4bf"},
    space: {"#111827", "#4338ca", "#06b6d4"},
    earth: {"#14532d", "#65a30d", "#fbbf24"},
    sports: {"#083344", "#0d9488", "#f97316"},
    rose: {"#111827", "#9f1239", "#f43f5e"},
    ember: {"#111827", "#9a3412", "#f97316"},
    gold: {"#111827", "#92400e", "#f59e0b"},
    leaf: {"#111827", "#3f6212", "#84cc16"},
    forest: {"#111827", "#166534", "#22c55e"},
    jade: {"#111827", "#065f46", "#10b981"},
    lagoon: {"#111827", "#0f766e", "#14b8a6"},
    aqua: {"#111827", "#155e75", "#06b6d4"},
    sky: {"#111827", "#075985", "#38bdf8"},
    blue: {"#111827", "#1d4ed8", "#60a5fa"},
    indigo: {"#111827", "#4338ca", "#818cf8"},
    violet: {"#111827", "#6d28d9", "#a78bfa"},
    orchid: {"#111827", "#7e22ce", "#c084fc"},
    magenta: {"#111827", "#a21caf", "#e879f9"},
    pink: {"#111827", "#be185d", "#f472b6"},
    default: {"#111827", "#334155", "#64748b"}
  }

  attr :id, :string, required: true
  attr :graph, :map, required: true
  attr :author_name, :string, default: nil
  attr :author_marker, :string, default: ""
  attr :featured_index, :integer, default: 0
  attr :label, :string, default: nil
  attr :show_visibility, :boolean, default: false
  attr :tag_limit, :integer, default: 4
  attr :variant, :atom, default: :profile
  slot :action

  def grid_card(assigns) do
    assigns =
      assigns
      |> assign(:node_count, graph_node_count(assigns.graph))
      |> assign(:tags, Enum.take(graph_tags(assigns.graph), assigns.tag_limit))
      |> assign(:title, graph_title(assigns.graph))

    ~H"""
    <article id={@id} class={card_class(@variant, @featured_index, primary_tag(@graph))}>
      <div class={card_header_class(@variant, @graph)} style={card_header_style(@tags)}>
        <div class="flex items-start justify-between gap-3">
          <span class="inline-flex items-center rounded-full bg-white/10 px-2.5 py-1 text-[11px] font-semibold text-white ring-1 ring-white/20">
            {@label || exploration_label(@node_count)}
          </span>

          <%= if @show_visibility do %>
            <span class={grid_visibility_class(@graph)}>
              <.icon name={grid_visibility_icon(@graph)} class="h-3.5 w-3.5" />
              {grid_visibility_label(@graph)}
            </span>
          <% else %>
            <span class="shrink-0 text-xs font-semibold text-white/60">
              {graph_updated_label(@graph)}
            </span>
          <% end %>
        </div>
      </div>

      <div class={card_body_class(@variant, @featured_index)}>
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0">
            <.link
              navigate={graph_path(@graph)}
              class={[
                "font-semibold leading-7 text-slate-950 transition group-hover:text-teal-700",
                card_title_class(@variant, @featured_index)
              ]}
            >
              {@title}
            </.link>

            <%= if author_visible?(@author_name) and @variant != :compact do %>
              <.link
                navigate={~p"/u/#{@author_name}"}
                class="mt-1 inline-flex text-xs font-semibold text-teal-700 underline decoration-teal-300 underline-offset-4 transition hover:text-teal-900 hover:decoration-teal-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-200"
              >
                {author_text(@author_name, @author_marker)}
              </.link>
            <% end %>
          </div>

          <%= if @variant not in [:featured, :compact] do %>
            <div
              class="shrink-0 rounded-xl bg-slate-50 px-3 py-2 text-center ring-1 ring-slate-200"
              aria-label={"#{@node_count} ideas"}
            >
              <p class="text-base font-semibold leading-5 text-slate-950">{@node_count}</p>
              <p class="mt-0.5 text-[10px] font-semibold uppercase text-slate-500">ideas</p>
            </div>
          <% end %>
        </div>

        <p class={preview_class(@variant)}>
          {graph_preview_sentence(@graph, @node_count)}
        </p>

        <div class={tag_container_class(@variant)}>
          <%= if @tags == [] do %>
            <span class="inline-flex items-center rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-semibold text-slate-500 ring-1 ring-inset ring-slate-200">
              Untagged
            </span>
          <% else %>
            <%= for tag <- @tags do %>
              <span class={[
                "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset",
                tag_pill_class(tag)
              ]}>
                #{tag}
              </span>
            <% end %>
          <% end %>
        </div>

        <div class={footer_class(@variant)}>
          <span class="text-xs font-medium text-slate-500">
            {footer_meta_text(@variant, @node_count, @graph)}
          </span>

          <div class="flex items-center gap-2">
            <.link
              navigate={graph_path(@graph)}
              class={open_link_class(@variant)}
              aria-label={"Open " <> @title}
            >
              {open_link_text(@variant)}
              <.icon name={open_link_icon(@variant)} class="h-3.5 w-3.5" />
            </.link>

            <%= if @action != [] do %>
              {render_slot(@action)}
            <% end %>
          </div>
        </div>
      </div>
    </article>
    """
  end

  defp card_class(:featured, 0, tag) do
    [
      card_base_class(tag),
      "min-h-[28rem] rounded-[1.35rem] lg:col-span-6"
    ]
  end

  defp card_class(:featured, _index, tag) do
    [
      card_base_class(tag),
      "min-h-[28rem] rounded-2xl lg:col-span-3"
    ]
  end

  defp card_class(:compact, _index, tag) do
    [
      card_base_class(tag),
      "min-h-0 rounded-xl"
    ]
  end

  defp card_class(_variant, _index, tag) do
    [
      card_base_class(tag),
      "min-h-72 rounded-2xl"
    ]
  end

  defp card_base_class(tag) do
    [
      "group flex flex-col overflow-hidden border bg-white shadow-sm transition hover:-translate-y-0.5 hover:shadow-lg",
      tag_border_class(tag)
    ]
  end

  defp card_header_class(:featured, graph),
    do: ["h-36 p-5", tag_gradient_class(primary_tag(graph))]

  defp card_header_class(:compact, graph),
    do: ["h-12 p-2.5", tag_gradient_class(primary_tag(graph))]

  defp card_header_class(_variant, graph),
    do: ["h-20 p-4", tag_gradient_class(primary_tag(graph))]

  defp card_body_class(:featured, 0), do: "flex flex-1 flex-col p-5"
  defp card_body_class(:featured, _index), do: "flex flex-1 flex-col p-4"
  defp card_body_class(:compact, _index), do: "flex flex-1 flex-col p-2.5"
  defp card_body_class(_variant, _index), do: "flex flex-1 flex-col p-4"

  defp card_title_class(:featured, 0), do: "line-clamp-4 text-2xl"
  defp card_title_class(:featured, _index), do: "line-clamp-3 text-base"
  defp card_title_class(:compact, _index), do: "line-clamp-2 text-sm"
  defp card_title_class(_variant, _index), do: "line-clamp-3 text-base"

  defp preview_class(:featured), do: "mt-2 line-clamp-2 min-h-12 text-sm leading-6 text-slate-600"
  defp preview_class(:compact), do: "mt-1 line-clamp-1 min-h-4 text-xs leading-4 text-slate-600"
  defp preview_class(_variant), do: "mt-3 line-clamp-2 min-h-10 text-sm leading-5 text-slate-600"

  defp tag_container_class(:compact),
    do: "mt-2 flex min-h-7 flex-wrap content-start gap-1"

  defp tag_container_class(_variant), do: "mt-4 flex min-h-12 flex-wrap content-start gap-1.5"

  defp footer_class(:compact),
    do: "mt-auto flex items-center justify-between gap-2 border-t border-slate-100 pt-2"

  defp footer_class(_variant),
    do: "mt-auto flex items-center justify-between gap-3 border-t border-slate-100 pt-3"

  defp open_link_class(:featured) do
    "inline-flex items-center gap-1 text-xs font-semibold text-teal-700 transition hover:text-teal-800"
  end

  defp open_link_class(:compact) do
    "inline-flex h-7 w-7 items-center justify-center rounded-full bg-slate-950 text-white transition hover:bg-teal-700"
  end

  defp open_link_class(_variant) do
    "inline-flex items-center gap-1.5 rounded-full bg-slate-950 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-teal-700"
  end

  defp open_link_text(:featured), do: "Open grid"
  defp open_link_text(:compact), do: ""
  defp open_link_text(_variant), do: "Open"

  defp open_link_icon(:featured), do: "hero-arrow-right"
  defp open_link_icon(_variant), do: "hero-arrow-up-right"

  defp footer_meta_text(:compact, node_count, _graph), do: "#{node_count} ideas"

  defp footer_meta_text(_variant, node_count, graph) do
    "#{node_count} ideas - #{graph_updated_label(graph)}"
  end

  defp author_text(author_name, marker), do: "by " <> marker <> author_name

  defp author_visible?(author_name) when is_binary(author_name) do
    normalized = author_name |> String.trim() |> String.downcase()
    normalized != "" and normalized not in ["anonymous", "anon", "-"]
  end

  defp author_visible?(_author_name), do: false

  defp graph_title(graph), do: Map.get(graph, :title) || "Untitled grid"

  defp graph_tags(graph) do
    case Map.get(graph, :tags, []) do
      tags when is_list(tags) -> tags
      _other -> []
    end
  end

  defp graph_preview_sentence(graph, node_count) do
    case Enum.take(graph_tags(graph), 2) do
      [] ->
        "A #{String.downcase(exploration_label(node_count))} built from #{node_count} connected ideas."

      tags ->
        "A #{String.downcase(exploration_label(node_count))} around #{human_join(tags)}."
    end
  end

  defp exploration_label(node_count) do
    cond do
      node_count >= 20 -> "Deep dive"
      node_count <= 4 -> "Seedling"
      true -> "Developing map"
    end
  end

  defp graph_updated_label(graph) do
    case Map.get(graph, :updated_at) || Map.get(graph, :inserted_at) do
      %DateTime{} = updated_at -> Calendar.strftime(updated_at, "%b %Y")
      %NaiveDateTime{} = updated_at -> Calendar.strftime(updated_at, "%b %Y")
      _other -> "Recently"
    end
  end

  defp grid_visibility_label(%{is_public: true}), do: "Public"
  defp grid_visibility_label(_graph), do: "Private"

  defp grid_visibility_icon(%{is_public: true}), do: "hero-globe-alt"
  defp grid_visibility_icon(_graph), do: "hero-lock-closed"

  defp grid_visibility_class(%{is_public: true}) do
    "inline-flex shrink-0 items-center gap-1 rounded-full bg-emerald-400/15 px-2 py-1 text-[11px] font-semibold text-emerald-50 ring-1 ring-emerald-200/25"
  end

  defp grid_visibility_class(_graph) do
    "inline-flex shrink-0 items-center gap-1 rounded-full bg-white/10 px-2 py-1 text-[11px] font-semibold text-white ring-1 ring-white/20"
  end

  defp graph_node_count(%{node_count: count}) when is_integer(count), do: count

  defp graph_node_count(graph) do
    nodes =
      (Map.get(graph, :data) || %{})
      |> then(fn data -> Map.get(data, "nodes") || Map.get(data, :nodes) || [] end)

    if is_list(nodes) do
      Enum.count(nodes, fn node -> !Map.get(node, "compound", false) end)
    else
      0
    end
  end

  defp human_join([]), do: ""
  defp human_join([one]), do: one
  defp human_join([first, second]), do: "#{first} and #{second}"

  defp human_join(items) do
    {last, rest} = List.pop_at(items, -1)
    Enum.join(rest, ", ") <> ", and " <> last
  end

  defp primary_tag(graph) do
    Enum.find(graph_tags(graph), fn tag -> is_binary(tag) and String.trim(tag) != "" end)
  end

  defp tag_gradient_class(tag) do
    tag |> tag_palette() |> Map.fetch!(:gradient)
  end

  defp card_header_style(tags) do
    tags
    |> tag_palette_stops()
    |> header_gradient_style()
  end

  defp tag_palette_stops(tags) do
    tags
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&tag_palette_key/1)
    |> Enum.reject(&(&1 == :default))
    |> Enum.uniq()
    |> Enum.map(&Map.fetch!(@tag_palette_stops, &1))
  end

  defp header_gradient_style([]), do: nil

  defp header_gradient_style([{dark, mid, bright}]) do
    "background: linear-gradient(135deg, #{dark} 0%, #{mid} 52%, #{bright} 100%);"
  end

  defp header_gradient_style([{dark, _, _} | _rest] = stops) do
    colors =
      stops
      |> Enum.take(4)
      |> Enum.map(fn {_dark, mid, _bright} -> mid end)
      |> then(&[dark | &1])
      |> Enum.uniq()

    "background: linear-gradient(135deg, #{gradient_stop_list(colors)});"
  end

  defp gradient_stop_list([color]), do: "#{color} 0%, #{color} 100%"

  defp gradient_stop_list(colors) do
    final_index = length(colors) - 1

    colors
    |> Enum.with_index()
    |> Enum.map(fn {color, index} ->
      "#{color} #{round(index * 100 / final_index)}%"
    end)
    |> Enum.join(", ")
  end

  defp tag_border_class(tag) do
    tag |> tag_palette() |> Map.fetch!(:border)
  end

  defp tag_pill_class(tag) do
    tag |> tag_palette() |> Map.fetch!(:pill)
  end

  defp tag_palette(tag) do
    @tag_palettes
    |> Map.get(tag_palette_key(tag), @tag_palettes.default)
  end

  defp tag_palette_key(tag) when is_binary(tag) do
    normalized = normalize_tag(tag)

    cond do
      normalized == "" ->
        :default

      topic_match?(normalized, [
        "philosophy",
        "ethics",
        "epistemology",
        "metaphysics",
        "ontology",
        "logic",
        "phenomenology",
        "post structuralism",
        "critical theory",
        "deconstruction",
        "existentialism",
        "meaning",
        "purpose",
        "absurdism"
      ]) ->
        :philosophy

      topic_match?(normalized, [
        "psychology",
        "cognition",
        "consciousness",
        "subconscious",
        "memory",
        "mind"
      ]) ->
        :mind

      topic_match?(normalized, ["well being", "wellbeing", "health", "mental health"]) ->
        :wellbeing

      technology_tag?(normalized) ->
        :technology

      topic_match?(normalized, [
        "sociology",
        "society",
        "politics",
        "geopolitics",
        "economics",
        "anthropology",
        "cultural studies",
        "social theory"
      ]) ->
        :society

      topic_match?(normalized, ["history", "historiography"]) ->
        :history

      topic_match?(normalized, [
        "literature",
        "language",
        "creativity",
        "speculative fiction",
        "aesthetics"
      ]) ->
        :arts

      topic_match?(normalized, ["space", "cosmology", "astronomy"]) ->
        :space

      topic_match?(normalized, ["ecology", "agriculture", "environment", "climate"]) ->
        :earth

      topic_match?(normalized, [
        "physics",
        "quantum",
        "field theory",
        "higgs",
        "science",
        "discovery"
      ]) ->
        :science

      topic_match?(normalized, ["sports", "rowing"]) ->
        :sports

      true ->
        fallback_palette_key(normalized)
    end
  end

  defp tag_palette_key(_tag), do: :default

  defp technology_tag?(normalized) do
    normalized == "ai" or
      topic_match?(normalized, [
        "artificial intelligence",
        "machine learning",
        "algorithm",
        "data science",
        "technology",
        "cryptography",
        "privacy",
        "security"
      ])
  end

  defp topic_match?(normalized, topics) do
    Enum.any?(topics, &String.contains?(normalized, &1))
  end

  defp fallback_palette_key(normalized) do
    Enum.at(@fallback_palette_keys, :erlang.phash2(normalized, length(@fallback_palette_keys)))
  end

  defp normalize_tag(tag) do
    tag
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, " ")
    |> String.trim()
  end
end
