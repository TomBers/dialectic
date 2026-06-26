defmodule DialecticWeb.GridCardComp do
  use DialecticWeb, :html

  @tag_palettes %{
    philosophy: %{
      border: "border-violet-200 hover:border-violet-300 hover:shadow-violet-950/10",
      pill: "bg-violet-50 text-violet-700 ring-violet-600/20"
    },
    mind: %{
      border: "border-indigo-200 hover:border-indigo-300 hover:shadow-indigo-950/10",
      pill: "bg-indigo-50 text-indigo-700 ring-indigo-600/20"
    },
    wellbeing: %{
      border: "border-emerald-200 hover:border-emerald-300 hover:shadow-emerald-950/10",
      pill: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
    },
    technology: %{
      border: "border-blue-200 hover:border-blue-300 hover:shadow-blue-950/10",
      pill: "bg-blue-50 text-blue-700 ring-blue-600/20"
    },
    society: %{
      border: "border-orange-200 hover:border-orange-300 hover:shadow-orange-950/10",
      pill: "bg-orange-50 text-orange-700 ring-orange-600/20"
    },
    history: %{
      border: "border-amber-200 hover:border-amber-300 hover:shadow-amber-950/10",
      pill: "bg-amber-50 text-amber-700 ring-amber-600/20"
    },
    arts: %{
      border: "border-fuchsia-200 hover:border-fuchsia-300 hover:shadow-fuchsia-950/10",
      pill: "bg-fuchsia-50 text-fuchsia-700 ring-fuchsia-600/20"
    },
    science: %{
      border: "border-sky-200 hover:border-sky-300 hover:shadow-sky-950/10",
      pill: "bg-sky-50 text-sky-700 ring-sky-600/20"
    },
    space: %{
      border: "border-indigo-200 hover:border-indigo-300 hover:shadow-indigo-950/10",
      pill: "bg-indigo-50 text-indigo-700 ring-indigo-600/20"
    },
    earth: %{
      border: "border-lime-200 hover:border-lime-300 hover:shadow-lime-950/10",
      pill: "bg-lime-50 text-lime-700 ring-lime-600/20"
    },
    sports: %{
      border: "border-teal-200 hover:border-teal-300 hover:shadow-teal-950/10",
      pill: "bg-teal-50 text-teal-700 ring-teal-600/20"
    },
    rose: %{
      border: "border-rose-200 hover:border-rose-300 hover:shadow-rose-950/10",
      pill: "bg-rose-50 text-rose-700 ring-rose-600/20"
    },
    ember: %{
      border: "border-orange-200 hover:border-orange-300 hover:shadow-orange-950/10",
      pill: "bg-orange-50 text-orange-700 ring-orange-600/20"
    },
    gold: %{
      border: "border-amber-200 hover:border-amber-300 hover:shadow-amber-950/10",
      pill: "bg-amber-50 text-amber-700 ring-amber-600/20"
    },
    leaf: %{
      border: "border-lime-200 hover:border-lime-300 hover:shadow-lime-950/10",
      pill: "bg-lime-50 text-lime-700 ring-lime-600/20"
    },
    forest: %{
      border: "border-green-200 hover:border-green-300 hover:shadow-green-950/10",
      pill: "bg-green-50 text-green-700 ring-green-600/20"
    },
    jade: %{
      border: "border-emerald-200 hover:border-emerald-300 hover:shadow-emerald-950/10",
      pill: "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
    },
    lagoon: %{
      border: "border-teal-200 hover:border-teal-300 hover:shadow-teal-950/10",
      pill: "bg-teal-50 text-teal-700 ring-teal-600/20"
    },
    aqua: %{
      border: "border-cyan-200 hover:border-cyan-300 hover:shadow-cyan-950/10",
      pill: "bg-cyan-50 text-cyan-700 ring-cyan-600/20"
    },
    sky: %{
      border: "border-sky-200 hover:border-sky-300 hover:shadow-sky-950/10",
      pill: "bg-sky-50 text-sky-700 ring-sky-600/20"
    },
    blue: %{
      border: "border-blue-200 hover:border-blue-300 hover:shadow-blue-950/10",
      pill: "bg-blue-50 text-blue-700 ring-blue-600/20"
    },
    indigo: %{
      border: "border-indigo-200 hover:border-indigo-300 hover:shadow-indigo-950/10",
      pill: "bg-indigo-50 text-indigo-700 ring-indigo-600/20"
    },
    violet: %{
      border: "border-violet-200 hover:border-violet-300 hover:shadow-violet-950/10",
      pill: "bg-violet-50 text-violet-700 ring-violet-600/20"
    },
    orchid: %{
      border: "border-purple-200 hover:border-purple-300 hover:shadow-purple-950/10",
      pill: "bg-purple-50 text-purple-700 ring-purple-600/20"
    },
    magenta: %{
      border: "border-fuchsia-200 hover:border-fuchsia-300 hover:shadow-fuchsia-950/10",
      pill: "bg-fuchsia-50 text-fuchsia-700 ring-fuchsia-600/20"
    },
    pink: %{
      border: "border-pink-200 hover:border-pink-300 hover:shadow-pink-950/10",
      pill: "bg-pink-50 text-pink-700 ring-pink-600/20"
    },
    default: %{
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

  @card_variant_classes %{
    featured: %{
      card: "min-h-[28rem] rounded-2xl lg:col-span-3",
      header: "h-36 p-5",
      body: "flex flex-1 flex-col p-4",
      title: "line-clamp-3 text-base",
      preview: "mt-2 line-clamp-2 min-h-12 text-sm leading-6 text-slate-600",
      tag_container: "mt-4 flex min-h-12 flex-wrap content-start gap-1.5",
      footer: "mt-auto flex items-center justify-between gap-3 border-t border-slate-100 pt-3",
      open_link:
        "inline-flex items-center gap-1 text-xs font-semibold text-teal-700 transition hover:text-teal-800",
      open_text: "Open grid"
    },
    compact: %{
      card: "min-h-0 rounded-xl",
      header: "h-12 p-2.5",
      body: "flex flex-1 flex-col p-2.5",
      title: "line-clamp-2 text-sm",
      preview: "mt-1 line-clamp-1 min-h-4 text-xs leading-4 text-slate-600",
      tag_container: "mt-2 flex min-h-7 flex-wrap content-start gap-1",
      footer: "mt-auto flex items-center justify-between gap-2 border-t border-slate-100 pt-2",
      open_link:
        "inline-flex h-7 w-7 items-center justify-center rounded-full bg-slate-950 text-white transition hover:bg-teal-700",
      open_text: ""
    },
    default: %{
      card: "min-h-72 rounded-2xl",
      header: "h-18 p-4",
      body: "flex flex-1 flex-col p-4",
      title: "line-clamp-3 text-base",
      preview: "mt-3 line-clamp-2 min-h-10 text-sm leading-5 text-slate-600",
      tag_container: "mt-4 flex min-h-12 flex-wrap content-start gap-1.5",
      footer: "mt-auto flex items-center justify-between gap-3 border-t border-slate-100 pt-3",
      open_link:
        "inline-flex items-center gap-1.5 rounded-full bg-slate-950 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-teal-700",
      open_text: "Open"
    }
  }

  @featured_lead_classes %{
    card: "min-h-[28rem] rounded-[1.35rem] lg:col-span-6",
    body: "flex flex-1 flex-col p-5",
    title: "line-clamp-4 text-2xl"
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
      |> assign(:primary_tag, primary_tag(assigns.graph))
      |> assign(:title, graph_title(assigns.graph))

    ~H"""
    <article id={@id} class={card_class(@variant, @featured_index, @primary_tag)}>
      <div class={card_header_class(@variant, @graph)} style={card_header_style(@primary_tag)}>
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

  def preview_sentence(graph), do: graph_preview_sentence(graph, graph_node_count(graph))

  def tag_pill_classes(tag), do: tag_pill_class(tag)

  defp card_class(variant, index, tag) do
    [
      card_base_class(tag),
      variant_class(variant, index, :card)
    ]
  end

  defp card_base_class(tag) do
    [
      "group flex flex-col overflow-hidden border bg-white shadow-sm transition hover:-translate-y-0.5 hover:shadow-lg",
      tag_border_class(tag)
    ]
  end

  defp card_header_class(variant, _graph), do: variant_class(variant, 1, :header)
  defp card_body_class(variant, index), do: variant_class(variant, index, :body)
  defp card_title_class(variant, index), do: variant_class(variant, index, :title)
  defp preview_class(variant), do: variant_class(variant, 1, :preview)
  defp tag_container_class(variant), do: variant_class(variant, 1, :tag_container)
  defp footer_class(variant), do: variant_class(variant, 1, :footer)
  defp open_link_class(variant), do: variant_class(variant, 1, :open_link)
  defp open_link_text(variant), do: variant_class(variant, 1, :open_text)

  defp variant_class(:featured, 0, key) do
    Map.get(@featured_lead_classes, key) || variant_class(:featured, 1, key)
  end

  defp variant_class(variant, _index, key) do
    @card_variant_classes
    |> Map.get(variant, @card_variant_classes.default)
    |> Map.fetch!(key)
  end

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

  defp card_header_style(tag) do
    tag
    |> tag_palette_stop()
    |> header_gradient_style()
  end

  defp tag_palette_stop(tag) do
    @tag_palette_stops
    |> Map.fetch!(tag_palette_key(tag))
  end

  defp header_gradient_style({dark, mid, bright}) do
    "background: linear-gradient(135deg, #{dark} 0%, #{mid} 52%, #{bright} 100%);"
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
