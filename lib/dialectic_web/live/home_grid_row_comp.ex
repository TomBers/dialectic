defmodule DialecticWeb.HomeGridRowComp do
  use DialecticWeb, :html

  attr :id, :string, required: true
  attr :graph, :map, required: true
  attr :author_name, :string, default: nil
  attr :author_marker, :string, default: ""
  attr :label, :string, default: nil
  attr :tag_limit, :integer, default: 3
  attr :variant, :atom, default: :row
  slot :action

  def home_grid_row(assigns) do
    ~H"""
    <article id={@id} class={article_class(@variant)}>
      <div class="min-w-0 flex-1">
        <.link navigate={graph_path(@graph)} class={title_link_class(@variant)}>
          {@graph.title}
        </.link>

        <div class={meta_class(@variant)}>
          <p class={preview_class(@variant)}>
            {graph_preview_sentence(@graph)}
          </p>

          <%= if author_visible?(@author_name) do %>
            <.link navigate={~p"/u/#{@author_name}"} class={author_link_class(@variant)}>
              {author_text(@author_name, @author_marker)}
            </.link>
          <% end %>
        </div>

        <div class={tag_group_class(@variant)}>
          <%= if @label do %>
            <span class="inline-flex items-center rounded-md bg-slate-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-500 ring-1 ring-inset ring-slate-200">
              {@label}
            </span>
          <% end %>

          <%= if Enum.empty?(@graph.tags || []) do %>
            <span class="inline-flex items-center rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-semibold text-slate-500 ring-1 ring-inset ring-slate-200">
              Untagged
            </span>
          <% else %>
            <%= for tag <- Enum.take(@graph.tags || [], @tag_limit) do %>
              <span class={[
                tag_pill_base_class(@variant),
                table_tag_color_class(tag)
              ]}>
                #{tag}
              </span>
            <% end %>
          <% end %>
        </div>
      </div>

      <%= if @variant == :card do %>
        <.link
          navigate={graph_path(@graph)}
          class={action_link_class(@variant)}
          aria-label={"Open " <> (@graph.title || "grid")}
        >
          <.icon name="hero-magnifying-glass" class="h-4 w-4" />
          <span>Open</span>
        </.link>
      <% else %>
        <div class="flex items-center justify-between gap-3 sm:justify-end">
          <.link
            navigate={graph_path(@graph)}
            class={action_link_class(@variant)}
            aria-label={"Open " <> (@graph.title || "grid")}
          >
            <.icon
              name="hero-arrow-up-right"
              class="absolute right-2 top-2 h-3.5 w-3.5 text-slate-400 transition group-hover/count:text-indigo-600"
            />
            <p class="text-base font-semibold leading-5 text-slate-950">
              {graph_node_count(@graph)}
            </p>
            <p class="mt-0.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-500 transition group-hover/count:text-indigo-600">
              ideas
            </p>
          </.link>

          {render_slot(@action)}
        </div>
      <% end %>
    </article>
    """
  end

  defp article_class(:card) do
    "rounded-[1.35rem] border border-slate-200 bg-gradient-to-br from-white via-slate-50 to-indigo-50/60 p-3.5 shadow-sm ring-1 ring-slate-200/70 sm:rounded-2xl sm:p-4"
  end

  defp article_class(:comfortable) do
    "group grid gap-4 p-4 transition hover:bg-slate-50 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center"
  end

  defp article_class(_row) do
    "group grid gap-3 p-3 transition hover:bg-slate-50 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center"
  end

  defp title_link_class(:card) do
    "block text-[0.98rem] font-semibold leading-6 text-slate-900 transition hover:text-indigo-700 sm:text-base"
  end

  defp title_link_class(:comfortable) do
    "block truncate text-base font-semibold leading-6 text-slate-900 hover:text-indigo-700"
  end

  defp title_link_class(_row) do
    "block line-clamp-2 text-sm font-semibold leading-5 text-slate-900 hover:text-indigo-700"
  end

  defp meta_class(:card), do: "mt-1 flex flex-wrap items-center gap-x-2 gap-y-1"
  defp meta_class(_variant), do: "mt-1 flex flex-wrap items-center gap-x-2 gap-y-1"

  defp preview_class(:comfortable), do: "line-clamp-2 max-w-2xl text-sm leading-6 text-slate-600"

  defp preview_class(_variant),
    do: "line-clamp-2 text-xs leading-5 text-slate-600 sm:text-sm sm:leading-6"

  defp author_link_class(:card) do
    "inline-flex text-xs font-semibold text-indigo-700 underline decoration-indigo-300 underline-offset-4 transition hover:text-indigo-900 hover:decoration-indigo-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-200"
  end

  defp author_link_class(_variant) do
    "inline-flex text-xs font-semibold text-indigo-700 underline decoration-indigo-300 underline-offset-4 transition hover:text-indigo-900 hover:decoration-indigo-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-200"
  end

  defp tag_group_class(:card), do: "mt-2.5 flex flex-wrap gap-1.5"
  defp tag_group_class(:comfortable), do: "mt-3 flex flex-wrap items-center gap-1.5"
  defp tag_group_class(_row), do: "mt-2 flex flex-wrap items-center gap-1.5"

  defp tag_pill_base_class(:card) do
    "inline-flex items-center rounded-full px-2.5 py-0.5 text-[10px] font-semibold ring-1 ring-inset sm:py-1 sm:text-[11px]"
  end

  defp tag_pill_base_class(_variant) do
    "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset"
  end

  defp action_link_class(:card) do
    "mt-3 inline-flex h-10 w-full shrink-0 items-center justify-center gap-2 rounded-full bg-gradient-to-br from-indigo-500 to-sky-500 px-3 text-sm font-medium text-white shadow-sm ring-1 ring-indigo-500/30 transition-transform hover:scale-[1.02] hover:shadow-md sm:w-auto"
  end

  defp action_link_class(_variant) do
    "group/count relative min-w-24 rounded-xl bg-slate-50 px-3 py-2 text-center ring-1 ring-slate-200 transition hover:bg-indigo-50 hover:ring-indigo-200"
  end

  defp author_text(author_name, marker) do
    "by " <> marker <> author_name
  end

  defp author_visible?(author_name) when is_binary(author_name) do
    normalized = author_name |> String.trim() |> String.downcase()
    normalized != "" and normalized not in ["anonymous", "anon", "-"]
  end

  defp author_visible?(_), do: false

  defp graph_preview_sentence(graph) do
    case Enum.take(graph.tags || [], 2) do
      [] ->
        "A #{String.downcase(exploration_label(graph))} built from #{graph_node_count(graph)} connected ideas."

      tags ->
        "A #{String.downcase(exploration_label(graph))} around #{human_join(tags)}."
    end
  end

  defp exploration_label(graph) do
    node_count = graph_node_count(graph)

    cond do
      node_count >= 20 -> "Deep dive"
      node_count <= 4 -> "Seedling"
      true -> "Developing map"
    end
  end

  defp graph_node_count(graph) do
    (graph.data || %{})
    |> Map.get("nodes", [])
    |> Enum.count(fn node -> !Map.get(node, "compound", false) end)
  end

  defp human_join([]), do: ""
  defp human_join([one]), do: one
  defp human_join([first, second]), do: "#{first} and #{second}"

  defp human_join(items) do
    {last, rest} = List.pop_at(items, -1)
    Enum.join(rest, ", ") <> ", and " <> last
  end

  defp table_tag_color_class(tag) do
    colors = [
      "bg-rose-50 text-rose-700 ring-rose-600/20",
      "bg-orange-50 text-orange-700 ring-orange-600/20",
      "bg-amber-50 text-amber-700 ring-amber-600/20",
      "bg-lime-50 text-lime-700 ring-lime-600/20",
      "bg-green-50 text-green-700 ring-green-600/20",
      "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
      "bg-teal-50 text-teal-700 ring-teal-600/20",
      "bg-cyan-50 text-cyan-700 ring-cyan-600/20",
      "bg-sky-50 text-sky-700 ring-sky-600/20",
      "bg-blue-50 text-blue-700 ring-blue-600/20",
      "bg-indigo-50 text-indigo-700 ring-indigo-600/20",
      "bg-violet-50 text-violet-700 ring-violet-600/20",
      "bg-purple-50 text-purple-700 ring-purple-600/20",
      "bg-fuchsia-50 text-fuchsia-700 ring-fuchsia-600/20",
      "bg-pink-50 text-pink-700 ring-pink-600/20"
    ]

    idx = :erlang.phash2(tag, length(colors))
    Enum.at(colors, idx)
  end
end
