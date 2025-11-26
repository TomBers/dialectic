defmodule DialecticWeb.PageHtml.GraphComp do
  use DialecticWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="relative block group h-full bg-white text-gray-900 rounded-lg ring-1 ring-gray-200 hover:bg-gray-50 hover:ring-gray-300 transition-colors flex flex-col shadow-sm hover:shadow-md">
      <.link navigate={@link} class="absolute inset-0 z-0 rounded-lg">
        <span class="sr-only">View {@title}</span>
      </.link>
      <div class="p-5 flex flex-col h-full pointer-events-none relative z-10">
        <h3 class="font-semibold text-lg text-gray-800">
          {@title}
        </h3>
        <div class="mt-4 flex flex-wrap gap-2">
          <%= if assigns[:node_count] do %>
            <%= if @node_count < 5 do %>
              <span class="inline-flex items-center rounded-md bg-gradient-to-r from-emerald-50 to-teal-50 px-2.5 py-1 text-xs font-semibold text-emerald-700 ring-1 ring-inset ring-emerald-600/20">
                <.icon name="hero-sparkles" class="w-3 h-3 mr-1 text-emerald-600" /> Seedling
              </span>
            <% end %>
            <%= if @node_count > 20 do %>
              <span class="inline-flex items-center rounded-md bg-gradient-to-r from-blue-50 to-indigo-50 px-2.5 py-1 text-xs font-semibold text-blue-700 ring-1 ring-inset ring-blue-700/10">
                <.icon name="hero-book-open" class="w-3 h-3 mr-1 text-blue-600" /> Deep Dive
              </span>
            <% end %>
          <% end %>
          <%= if assigns[:tags] do %>
            <%= for tag <- @tags do %>
              <span class={[
                "inline-flex items-center rounded-md px-2 py-1 text-xs font-medium ring-1 ring-inset transition-all hover:scale-105",
                tag_color_class(tag)
              ]}>
                {tag}
              </span>
            <% end %>
          <% end %>
        </div>
        <div class="mt-auto pt-5 flex items-center justify-between pointer-events-auto border-t border-gray-50">
          <%= if assigns[:count] && @count > 0 do %>
            <div class="flex items-center text-xs font-medium text-gray-500">
              <.icon name="hero-chat-bubble-left-right" class="w-4 h-4 mr-1.5 text-gray-400" />
              <span>{@count} notes</span>
            </div>
          <% else %>
            <div></div>
          <% end %>
          <%= if (is_nil(assigns[:tags]) or @tags == []) do %>
            <.form for={%{}} action={~p"/graphs/#{@title}/generate_tags"} method="post">
              <button
                type="submit"
                class="inline-flex items-center rounded-full bg-gradient-to-r from-violet-100 to-fuchsia-100 px-3 py-1 text-xs font-semibold text-violet-700 ring-1 ring-inset ring-violet-700/10 hover:from-violet-200 hover:to-fuchsia-200 transition-all shadow-sm"
              >
                ✨ Generate Tags
              </button>
            </.form>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp tag_color_class(tag) do
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
