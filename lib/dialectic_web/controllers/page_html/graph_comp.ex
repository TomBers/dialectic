defmodule DialecticWeb.PageHtml.GraphComp do
  use DialecticWeb, :live_component

  def render(assigns) do
    assigns = assign(assigns, :variant, assigns[:variant] || :glass)

    ~H"""
    <div class={[
      "relative block group h-full rounded-lg ring-1 transition-colors flex flex-col",
      container_class(@variant)
    ]}>
      <.link navigate={@link} class="absolute inset-0 z-0 rounded-lg">
        <span class="sr-only">View {@title}</span>
      </.link>

      <div class="px-3 py-3 flex flex-col h-full pointer-events-none relative z-10">
        <h3 class={[
          "font-semibold text-sm leading-snug line-clamp-2",
          title_class(@variant)
        ]}>
          {@title}
        </h3>

        <div class="mt-2 flex flex-wrap gap-1.5">
          <%= if assigns[:node_count] do %>
            <%= if @node_count < 5 do %>
              <span class={[
                "inline-flex items-center rounded-md px-2 py-0.5 text-[10px] font-bold ring-1 ring-inset",
                badge_class(@variant, :seedling)
              ]}>
                <.icon name="hero-sparkles" class="w-3 h-3 mr-1" /> Seedling
              </span>
            <% end %>

            <%= if @node_count > 20 do %>
              <span class={[
                "inline-flex items-center rounded-md px-2 py-0.5 text-[10px] font-bold ring-1 ring-inset",
                badge_class(@variant, :deep_dive)
              ]}>
                <.icon name="hero-book-open" class="w-3 h-3 mr-1" /> Deep Dive
              </span>
            <% end %>

            <span
              phx-hook="ExplorationStats"
              id={"stats-" <> @title}
              data-graph-id={@title}
              data-total={@node_count}
              class={[
                "inline-flex items-center rounded-md px-2 py-0.5 text-[10px] font-bold ring-1 ring-inset",
                stats_class(@variant)
              ]}
            >
            </span>
          <% end %>

          <%= if assigns[:tags] do %>
            <%= for tag <- @tags do %>
              <span class={[
                "inline-flex items-center rounded-md px-2 py-0.5 text-[10px] font-bold ring-1 ring-inset transition-all hover:scale-105",
                tag_color_class(tag, @variant)
              ]}>
                {tag}
              </span>
            <% end %>
          <% end %>
        </div>

        <%= if is_nil(assigns[:tags]) or @tags == [] do %>
          <div class={[
            "mt-auto pt-2 flex justify-end pointer-events-auto",
            footer_border_class(@variant)
          ]}>
            <%= if assigns[:generating] do %>
              <span class={[
                "inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-bold ring-1 ring-inset animate-pulse",
                generating_class(@variant)
              ]}>
                Generating...
              </span>
            <% else %>
              <%= if assigns[:is_live] do %>
                <button
                  type="button"
                  phx-click="generate_tags"
                  phx-value-title={@title}
                  class={[
                    "inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-bold ring-1 ring-inset transition-all shadow-sm",
                    generate_button_class(@variant)
                  ]}
                >
                  ✨ Generate Tags
                </button>
              <% else %>
                <.form for={%{}} action={~p"/graphs/#{@title}/generate_tags"} method="post">
                  <button
                    type="submit"
                    class={[
                      "inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-bold ring-1 ring-inset transition-all shadow-sm",
                      generate_button_class(@variant)
                    ]}
                  >
                    ✨ Generate Tags
                  </button>
                </.form>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp tag_color_class(tag, variant) do
    colors =
      case variant do
        :light ->
          [
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

        _ ->
          [
            "bg-rose-500/15 text-rose-100 ring-rose-300/30",
            "bg-orange-500/15 text-orange-100 ring-orange-300/30",
            "bg-amber-500/15 text-amber-100 ring-amber-300/30",
            "bg-lime-500/15 text-lime-100 ring-lime-300/30",
            "bg-green-500/15 text-green-100 ring-green-300/30",
            "bg-emerald-500/15 text-emerald-100 ring-emerald-300/30",
            "bg-teal-500/15 text-teal-100 ring-teal-300/30",
            "bg-cyan-500/15 text-cyan-100 ring-cyan-300/30",
            "bg-sky-500/15 text-sky-100 ring-sky-300/30",
            "bg-blue-500/15 text-blue-100 ring-blue-300/30",
            "bg-indigo-500/15 text-indigo-100 ring-indigo-300/30",
            "bg-violet-500/15 text-violet-100 ring-violet-300/30",
            "bg-purple-500/15 text-purple-100 ring-purple-300/30",
            "bg-fuchsia-500/15 text-fuchsia-100 ring-fuchsia-300/30",
            "bg-pink-500/15 text-pink-100 ring-pink-300/30"
          ]
      end

    idx = :erlang.phash2(tag, length(colors))
    Enum.at(colors, idx)
  end

  defp container_class(:light) do
    "bg-white text-gray-900 ring-gray-200 hover:bg-gray-50 hover:ring-gray-300 shadow-sm hover:shadow-md"
  end

  defp container_class(_glass) do
    "bg-white/10 text-white ring-white/15 hover:bg-white/15 hover:ring-white/25 shadow-md"
  end

  defp title_class(:light), do: "text-gray-800"
  defp title_class(_glass), do: "text-white"

  defp stats_class(:light) do
    "bg-gray-100 text-gray-600 ring-gray-500/10"
  end

  defp stats_class(_glass) do
    "bg-white/10 text-white/80 ring-white/15"
  end

  defp badge_class(:light, :seedling) do
    "bg-gradient-to-r from-emerald-50 to-teal-50 text-emerald-700 ring-emerald-600/20"
  end

  defp badge_class(:light, :deep_dive) do
    "bg-gradient-to-r from-blue-50 to-indigo-50 text-blue-700 ring-blue-700/10"
  end

  defp badge_class(_glass, :seedling) do
    "bg-emerald-500/15 text-emerald-100 ring-emerald-300/30"
  end

  defp badge_class(_glass, :deep_dive) do
    "bg-blue-500/15 text-blue-100 ring-blue-300/30"
  end

  defp footer_border_class(:light), do: "border-t border-gray-50"
  defp footer_border_class(_glass), do: "border-t border-white/10"

  defp generating_class(:light) do
    "bg-gray-100 text-gray-500 ring-gray-500/10"
  end

  defp generating_class(_glass) do
    "bg-white/10 text-white/80 ring-white/15"
  end

  defp generate_button_class(:light) do
    "bg-gradient-to-r from-violet-100 to-fuchsia-100 text-violet-700 ring-violet-700/10 hover:from-violet-200 hover:to-fuchsia-200"
  end

  defp generate_button_class(_glass) do
    "bg-white/10 text-white ring-white/15 hover:bg-white/15"
  end
end
