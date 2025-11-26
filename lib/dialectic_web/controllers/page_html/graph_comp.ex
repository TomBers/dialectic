defmodule DialecticWeb.PageHtml.GraphComp do
  use DialecticWeb, :live_component

  def render(assigns) do
    ~H"""
    <.link navigate={@link} class="block group h-full">
      <div class="bg-white text-gray-900 rounded-lg p-5 ring-1 ring-gray-200 hover:bg-gray-50 hover:ring-gray-300 transition-colors flex flex-col h-full">
        <h3 class="font-semibold text-lg">
          {@title}
        </h3>
        <div class="mt-3 flex flex-wrap gap-2">
          <%= if assigns[:node_count] do %>
            <%= if @node_count < 5 do %>
              <span class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
                Seedling
              </span>
            <% end %>
            <%= if @node_count > 20 do %>
              <span class="inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10">
                Deep Dive
              </span>
            <% end %>
          <% end %>
          <%= if assigns[:tags] do %>
            <%= for tag <- @tags do %>
              <span class="inline-flex items-center rounded-md bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700 ring-1 ring-inset ring-indigo-700/10">
                {tag}
              </span>
            <% end %>
          <% end %>
        </div>
        <%= if assigns[:count] && @count > 0 do %>
          <div class="mt-auto pt-4 flex items-center text-sm text-gray-500">
            <.icon name="hero-chat-bubble-left-right" class="w-4 h-4 mr-1" />
            <span>{@count} notes</span>
          </div>
        <% end %>
      </div>
    </.link>
    """
  end
end
