defmodule DialecticWeb.GridCardComp do
  use DialecticWeb, :html

  @tag_palettes %{
    philosophy: %{
      color: "#8b5cf6",
      pill: "bg-white text-violet-700 ring-violet-200"
    },
    mind: %{
      color: "#6366f1",
      pill: "bg-white text-indigo-700 ring-indigo-200"
    },
    wellbeing: %{
      color: "#10b981",
      pill: "bg-white text-emerald-700 ring-emerald-200"
    },
    technology: %{
      color: "#3b82f6",
      pill: "bg-white text-blue-700 ring-blue-200"
    },
    society: %{
      color: "#f97316",
      pill: "bg-white text-orange-700 ring-orange-200"
    },
    history: %{
      color: "#f59e0b",
      pill: "bg-white text-amber-700 ring-amber-200"
    },
    arts: %{
      color: "#d946ef",
      pill: "bg-white text-fuchsia-700 ring-fuchsia-200"
    },
    science: %{
      color: "#0ea5e9",
      pill: "bg-white text-sky-700 ring-sky-200"
    },
    space: %{
      color: "#6366f1",
      pill: "bg-white text-indigo-700 ring-indigo-200"
    },
    earth: %{
      color: "#84cc16",
      pill: "bg-white text-lime-700 ring-lime-200"
    },
    sports: %{
      color: "#14b8a6",
      pill: "bg-white text-teal-700 ring-teal-200"
    },
    rose: %{
      color: "#f43f5e",
      pill: "bg-white text-rose-700 ring-rose-200"
    },
    ember: %{
      color: "#f97316",
      pill: "bg-white text-orange-700 ring-orange-200"
    },
    gold: %{
      color: "#f59e0b",
      pill: "bg-white text-amber-700 ring-amber-200"
    },
    leaf: %{
      color: "#84cc16",
      pill: "bg-white text-lime-700 ring-lime-200"
    },
    forest: %{
      color: "#22c55e",
      pill: "bg-white text-green-700 ring-green-200"
    },
    jade: %{
      color: "#10b981",
      pill: "bg-white text-emerald-700 ring-emerald-200"
    },
    lagoon: %{
      color: "#14b8a6",
      pill: "bg-white text-teal-700 ring-teal-200"
    },
    aqua: %{
      color: "#06b6d4",
      pill: "bg-white text-cyan-700 ring-cyan-200"
    },
    sky: %{
      color: "#0ea5e9",
      pill: "bg-white text-sky-700 ring-sky-200"
    },
    blue: %{
      color: "#3b82f6",
      pill: "bg-white text-blue-700 ring-blue-200"
    },
    indigo: %{
      color: "#6366f1",
      pill: "bg-white text-indigo-700 ring-indigo-200"
    },
    violet: %{
      color: "#8b5cf6",
      pill: "bg-white text-violet-700 ring-violet-200"
    },
    orchid: %{
      color: "#a855f7",
      pill: "bg-white text-purple-700 ring-purple-200"
    },
    magenta: %{
      color: "#d946ef",
      pill: "bg-white text-fuchsia-700 ring-fuchsia-200"
    },
    pink: %{
      color: "#ec4899",
      pill: "bg-white text-pink-700 ring-pink-200"
    },
    default: %{
      color: "#64748b",
      pill: "bg-white text-slate-600 ring-slate-200"
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

  @card_variant_classes %{
    featured: %{
      card: "min-h-[20rem] lg:col-span-3",
      body: "flex flex-1 flex-col p-5",
      title: "line-clamp-3 text-xl",
      preview: "mt-2.5 line-clamp-3 min-h-14 text-sm leading-6 text-slate-600",
      tag_container: "mt-3.5 flex min-h-7 flex-wrap content-start justify-center gap-1.5",
      footer: "mt-auto flex items-center justify-between gap-3 border-t border-slate-200 pt-3.5",
      open_link:
        "relative z-30 pointer-events-auto inline-flex items-center gap-1 text-xs font-semibold text-teal-700 transition hover:text-teal-900",
      open_text: "Explore"
    },
    compact: %{
      card: "min-h-[15rem]",
      body: "flex flex-1 flex-col p-4",
      title: "line-clamp-3 text-base",
      preview: "mt-2 line-clamp-2 min-h-10 text-xs leading-5 text-slate-600",
      tag_container: "mt-3 flex min-h-7 flex-wrap content-start justify-center gap-1.5",
      footer: "mt-auto flex items-center justify-between gap-2 border-t border-slate-200 pt-3",
      open_link:
        "relative z-30 pointer-events-auto inline-flex items-center gap-1 text-[11px] font-semibold text-teal-700 transition hover:text-teal-900",
      open_text: "Open"
    },
    community: %{
      card: "min-h-[19rem]",
      body: "flex flex-1 flex-col p-5",
      title: "line-clamp-3 text-lg",
      preview: "mt-2.5 line-clamp-2 min-h-10 text-sm leading-5 text-slate-600",
      tag_container: "mt-3.5 flex min-h-7 flex-wrap content-start justify-center gap-1.5",
      footer: "mt-auto flex items-center justify-between gap-3 border-t border-slate-200 pt-3.5",
      open_link:
        "relative z-30 pointer-events-auto inline-flex items-center gap-1 text-xs font-semibold text-teal-700 transition hover:text-teal-900",
      open_text: "View grid"
    },
    community_compact: %{
      card: "min-h-[16rem]",
      body: "flex flex-1 flex-col p-4",
      title: "line-clamp-3 text-base",
      preview: "mt-2 line-clamp-2 min-h-10 text-xs leading-5 text-slate-600",
      tag_container: "mt-3 flex min-h-7 flex-wrap content-start justify-center gap-1.5",
      footer: "mt-auto flex items-center justify-between gap-2 border-t border-slate-200 pt-3",
      open_link:
        "relative z-30 pointer-events-auto inline-flex items-center gap-1 text-[11px] font-semibold text-teal-700 transition hover:text-teal-900",
      open_text: "View grid"
    },
    default: %{
      card: "min-h-[18rem]",
      body: "flex flex-1 flex-col p-4",
      title: "line-clamp-3 text-lg",
      preview: "mt-2.5 line-clamp-2 min-h-10 text-sm leading-5 text-slate-600",
      tag_container: "mt-3.5 flex min-h-7 flex-wrap content-start justify-center gap-1.5",
      footer: "mt-auto flex items-center justify-between gap-3 border-t border-slate-200 pt-3.5",
      open_link:
        "relative z-30 pointer-events-auto inline-flex items-center gap-1 text-xs font-semibold text-teal-700 transition hover:text-teal-900",
      open_text: "Explore"
    }
  }

  @featured_lead_classes %{
    card: "min-h-[20rem] lg:col-span-6",
    body: "flex flex-1 flex-col p-6",
    title: "line-clamp-4 text-2xl"
  }

  attr :id, :string, required: true
  attr :graph, :map, required: true
  attr :author_name, :string, default: nil
  attr :author_marker, :string, default: ""
  attr :featured_index, :integer, default: 0
  attr :label, :string, default: nil
  attr :show_badge, :boolean, default: true
  attr :show_visibility, :boolean, default: false
  attr :tag_limit, :integer, default: 4
  attr :variant, :atom, default: :profile
  slot :action

  def grid_card(assigns) do
    node_count = graph_node_count(assigns.graph)
    primary_tag = primary_tag(assigns.graph)
    tags = Enum.take(graph_tags(assigns.graph), assigns.tag_limit)

    assigns =
      assigns
      |> assign(:node_count, node_count)
      |> assign(:tags, tags)
      |> assign(:primary_tag, primary_tag)
      |> assign(:border_style, card_border_style(tags))
      |> assign(:title, graph_title(assigns.graph))
      |> assign(:created_label, graph_created_label(assigns.graph))

    if assigns.variant in [:compact, :community, :community_compact] do
      standard_grid_card(assigns)
    else
      editorial_grid_card(assigns)
    end
  end

  defp editorial_grid_card(assigns) do
    assigns =
      assign(assigns, :editorial_role, Atom.to_string(assigns.variant) <> "-grid-card")

    ~H"""
    <article
      id={@id}
      data-role={@editorial_role}
      class={editorial_card_class(@variant, @featured_index)}
    >
      <div aria-hidden="true" class="h-1.5 shrink-0" style={@border_style}></div>
      <div class="flex flex-1 flex-col p-5 sm:p-6">
        <div class="flex items-center justify-between gap-4 border-b border-stone-200 pb-3 text-[10px] font-semibold uppercase tracking-[0.16em] text-slate-500">
          <span>{@label || exploration_label(@node_count)}</span>
          <%= if @show_visibility do %>
            <span class="inline-flex shrink-0 items-center gap-1.5">
              <.icon name={grid_visibility_icon(@graph)} class="h-3.5 w-3.5" />
              {grid_visibility_label(@graph)}
            </span>
          <% else %>
            <span class="shrink-0" aria-label={"Created " <> @created_label}>
              {@created_label}
            </span>
          <% end %>
        </div>

        <div class="pt-5">
          <.link
            navigate={graph_path(@graph)}
            class="block text-balance font-serif text-[1.7rem] font-semibold leading-[1.12] tracking-tight text-slate-950 transition group-hover:text-teal-800 hover:text-teal-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-300 focus-visible:ring-offset-4"
          >
            {@title}
          </.link>

          <.link
            :if={author_visible?(@author_name)}
            navigate={~p"/u/#{@author_name}"}
            class="mt-3 inline-flex text-xs font-medium text-slate-500 transition hover:text-teal-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-300"
          >
            {author_text(@author_name, @author_marker)}
          </.link>
        </div>

        <div class="mt-6 flex flex-wrap gap-x-4 gap-y-2">
          <%= if @tags == [] do %>
            <span class="text-xs font-medium text-slate-500">Untagged</span>
          <% else %>
            <%= for tag <- @tags do %>
              <span class="inline-flex items-center gap-1.5 text-xs font-medium text-slate-600">
                <span
                  aria-hidden="true"
                  class="h-1.5 w-1.5 shrink-0 rounded-full"
                  style={"background-color: " <> tag_color(tag)}
                >
                </span>
                {tag}
              </span>
            <% end %>
          <% end %>
        </div>

        <div class="mt-auto pt-6">
          <div class="flex items-center justify-between gap-4 border-t border-stone-200 pt-4">
            <span class="text-xs text-slate-500">
              <strong class="font-semibold text-slate-800">{@node_count}</strong> connected ideas
            </span>
            <div class="flex items-center gap-2">
              <.link
                navigate={graph_path(@graph)}
                class="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-800 transition hover:text-teal-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-300"
                aria-label={"Read grid: " <> @title}
              >
                Read grid
                <.icon
                  name="hero-arrow-right"
                  class="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5"
                />
              </.link>
              <%= if @action != [] do %>
                {render_slot(@action)}
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </article>
    """
  end

  defp standard_grid_card(assigns) do
    ~H"""
    <article id={@id} class={card_class(@variant, @featured_index)} style={@border_style}>
      <div class="flex min-h-0 flex-1 flex-col overflow-hidden rounded-[calc(0.5rem-2px)] bg-white">
        <div class={card_body_class(@variant, @featured_index)}>
          <div class={[
            "mb-3.5 flex items-center gap-3",
            if(@show_badge, do: "justify-between", else: "justify-end")
          ]}>
            <span
              :if={@show_badge}
              data-role="grid-card-badge"
              class={[
                "inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.12em] ring-1 ring-inset",
                card_badge_class(@primary_tag)
              ]}
            >
              <.icon name={exploration_icon(@node_count)} class="h-3.5 w-3.5" />
              {@label || exploration_label(@node_count)}
            </span>

            <%= if @show_visibility do %>
              <span class={grid_visibility_class(@graph)}>
                <.icon name={grid_visibility_icon(@graph)} class="h-3.5 w-3.5" />
                {grid_visibility_label(@graph)}
              </span>
            <% else %>
              <span
                class="shrink-0 text-[11px] font-medium text-slate-500"
                aria-label={"Created " <> @created_label}
              >
                {@created_label}
              </span>
            <% end %>
          </div>
          <div class="min-w-0 px-1 text-center">
            <.link
              navigate={graph_path(@graph)}
              class={[
                "relative z-30 block pointer-events-auto font-semibold leading-snug text-slate-950 transition group-hover:text-teal-800 hover:text-teal-900",
                card_title_class(@variant, @featured_index)
              ]}
            >
              {@title}
            </.link>

            <%= if author_visible?(@author_name) and @variant != :compact do %>
              <.link
                navigate={~p"/u/#{@author_name}"}
                class="relative z-30 mt-1.5 inline-flex pointer-events-auto text-xs font-medium text-slate-500 transition hover:text-teal-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-200"
              >
                {author_text(@author_name, @author_marker)}
              </.link>
            <% end %>
          </div>

          <p class={preview_class(@variant)}>
            {graph_preview_sentence(@graph, @node_count)}
          </p>

          <div class={tag_container_class(@variant)}>
            <%= if @tags == [] do %>
              <span class="inline-flex items-center rounded-full bg-white px-2.5 py-1 text-[10px] font-medium text-slate-500 shadow-sm ring-1 ring-inset ring-slate-200">
                Untagged
              </span>
            <% else %>
              <%= for tag <- @tags do %>
                <span class={[
                  "inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[10px] font-semibold shadow-sm ring-1 ring-inset",
                  tag_pill_class(tag)
                ]}>
                  <span
                    aria-hidden="true"
                    class="h-1.5 w-1.5 shrink-0 rounded-full"
                    style={"background-color: " <> tag_color(tag)}
                  >
                  </span>
                  {tag}
                </span>
              <% end %>
            <% end %>
          </div>

          <div class={footer_class(@variant)}>
            <span class="inline-flex items-center gap-1.5 text-xs font-medium text-slate-500">
              <.icon name="hero-squares-2x2" class="h-3.5 w-3.5 text-slate-400" />
              {footer_meta_text(@variant, @node_count, @graph)}
            </span>

            <div class="relative z-30 flex pointer-events-none items-center gap-2">
              <.link
                navigate={graph_path(@graph)}
                class={open_link_class(@variant)}
                aria-label={"Open " <> @title}
              >
                {open_link_text(@variant)}
                <.icon
                  name={open_link_icon(@variant)}
                  class="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5"
                />
              </.link>

              <%= if @action != [] do %>
                <span class="pointer-events-auto">
                  {render_slot(@action)}
                </span>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </article>
    """
  end

  def preview_sentence(graph), do: graph_preview_sentence(graph, graph_node_count(graph))

  def tag_pill_classes(tag), do: tag_pill_class(tag)
  def tag_color_hex(tag), do: tag_color(tag)
  def created_label(graph), do: graph_created_label(graph)

  defp editorial_card_class(:featured, 0) do
    [editorial_card_base_class(), "lg:col-span-6"]
  end

  defp editorial_card_class(:featured, _index) do
    [editorial_card_base_class(), "lg:col-span-3"]
  end

  defp editorial_card_class(_variant, _index), do: editorial_card_base_class()

  defp editorial_card_base_class do
    "group relative flex min-h-[20rem] flex-col overflow-hidden border border-stone-300 bg-white shadow-[0_12px_32px_-26px_rgba(15,23,42,0.7)] transition duration-200 hover:-translate-y-0.5 hover:border-slate-400 hover:shadow-[0_22px_42px_-26px_rgba(15,23,42,0.55)] focus-within:border-slate-400 focus-within:shadow-[0_22px_42px_-26px_rgba(15,23,42,0.55)]"
  end

  defp card_class(variant, index) do
    [
      card_base_class(),
      variant_class(variant, index, :card)
    ]
  end

  defp card_base_class do
    "group relative flex flex-col overflow-hidden rounded-lg bg-slate-200 p-[2px] shadow-sm transition duration-200 hover:shadow-lg focus-within:shadow-lg"
  end

  defp card_border_style(tags) do
    colors =
      tags
      |> Enum.filter(&(is_binary(&1) and String.trim(&1) != ""))
      |> Enum.take(3)
      |> Enum.map(&tag_color/1)
      |> Enum.uniq()

    gradient_colors =
      case colors do
        [] -> [@tag_palettes.default.color, "#cbd5e1"]
        [color] -> [color, "#cbd5e1"]
        colors -> colors
      end

    "background-image: linear-gradient(135deg, #{Enum.join(gradient_colors, ", ")});"
  end

  defp card_badge_class(tag) do
    case accent_family(tag) do
      :violet -> "bg-violet-50 text-violet-700 ring-violet-200"
      :sky -> "bg-sky-50 text-sky-700 ring-sky-200"
      :emerald -> "bg-emerald-50 text-emerald-700 ring-emerald-200"
      :amber -> "bg-amber-50 text-amber-800 ring-amber-200"
      :rose -> "bg-rose-50 text-rose-700 ring-rose-200"
      :teal -> "bg-teal-50 text-teal-700 ring-teal-200"
    end
  end

  defp accent_family(tag) do
    case tag_palette_key(tag) do
      key when key in [:philosophy, :mind, :space, :indigo, :violet, :orchid] ->
        :violet

      key when key in [:technology, :science, :sky, :blue, :aqua] ->
        :sky

      key when key in [:wellbeing, :earth, :sports, :leaf, :forest, :jade, :lagoon] ->
        :emerald

      key when key in [:society, :history, :ember, :gold] ->
        :amber

      key when key in [:arts, :rose, :magenta, :pink] ->
        :rose

      _key ->
        :teal
    end
  end

  defp card_body_class(variant, index) do
    ["relative z-20 pointer-events-none", variant_class(variant, index, :body)]
  end

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

  defp footer_meta_text(_variant, node_count, _graph), do: "#{node_count} ideas"

  defp author_text(author_name, marker) when marker in [nil, "", "by"], do: "by " <> author_name
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

  defp exploration_icon(node_count) do
    cond do
      node_count >= 20 -> "hero-book-open"
      node_count <= 4 -> "hero-light-bulb"
      true -> "hero-map"
    end
  end

  defp graph_created_label(graph) do
    case Map.get(graph, :inserted_at) do
      %DateTime{} = inserted_at -> Calendar.strftime(inserted_at, "%b %Y")
      %NaiveDateTime{} = inserted_at -> Calendar.strftime(inserted_at, "%b %Y")
      _other -> "Recently"
    end
  end

  defp grid_visibility_label(%{is_public: true}), do: "Public"
  defp grid_visibility_label(_graph), do: "Private"

  defp grid_visibility_icon(%{is_public: true}), do: "hero-globe-alt"
  defp grid_visibility_icon(_graph), do: "hero-lock-closed"

  defp grid_visibility_class(%{is_public: true}) do
    "inline-flex shrink-0 items-center gap-1 border border-stone-200 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-600"
  end

  defp grid_visibility_class(_graph) do
    "inline-flex shrink-0 items-center gap-1 border border-stone-200 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-600"
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

  defp tag_pill_class(tag) do
    tag |> tag_palette() |> Map.fetch!(:pill)
  end

  defp tag_color(tag) do
    tag |> tag_palette() |> Map.fetch!(:color)
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
