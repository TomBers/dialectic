defmodule DialecticWeb.PageHtml.GraphComp do
  use DialecticWeb, :live_component

  def gen_link(graph, node \\ nil) do
    case node do
      nil -> ~p"/#{URI.encode(graph, &URI.char_unreserved?/1)}"
      _ -> ~p"/#{URI.encode(graph, &URI.char_unreserved?/1)}?node=#{node}"
    end
  end

  def render(assigns) do
    ~H"""
    <.link navigate={gen_link(@graph.title)} class="block">
      <div class="bg-white text-gray-800 shadow rounded-lg p-6 hover:shadow-lg hover:bg-black hover:text-white transition">
        <h3 class="font-bold text-xl  mb-1">
          <span :if={!@graph.is_public}>🔒</span>{@graph.title}
        </h3>
        <p class="text-sm text-gray-500">({@count} notes)</p>
      </div>
    </.link>
    """
  end
end
