defmodule DialecticWeb.CombineMsgComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Live.TextUtils

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={[
        "node mb-4 rounded-lg shadow-sm",
        "flex items-start gap-3 bg-white border-l-4",
        "transition duration-200 ease-in-out",
        "hover:bg-gray-50 hover:shadow-md hover:scale-[1.01]",
        message_border_class(@node.class)
      ]}
      phx-click="combine_node_select"
      phx-value-selected_node={@node.id}
    >
      <div class="shrink-0">
        <h2 class="w-8 h-8 flex items-center justify-center rounded-lg bg-gray-100 text-gray-700 font-mono text-sm">
          {@node.id}
        </h2>
      </div>

      <div class="proposition flex-1 max-w-none">
        <article class="prose prose-stone prose-sm">
          {case TextUtils.render_content(@node.content || "") |> Map.get(:title) do
            "" -> "Untitled"
            t -> t
          end}
        </article>
      </div>
    </div>
    """
  end

  # Add this helper function to handle message border styling
  defp message_border_class(class) do
    case class do
      # "user" -> "border-red-400"
      "answer" -> "border-blue-400"
      "thesis" -> "border-green-400"
      "antithesis" -> "border-red-400"
      "synthesis" -> "border-purple-600"
      "deepdive" -> "border-cyan-500"
      _ -> "border border-gray-200 bg-white"
    end
  end
end
