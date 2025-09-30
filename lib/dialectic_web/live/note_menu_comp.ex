defmodule DialecticWeb.NoteMenuComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="rounded-md shadow-sm hidden sm:flex items-center justify-end gap-2 text-xs overflow-x-auto whitespace-nowrap w-full">
      <div class="bg-white border border-gray-200 rounded-md shadow-sm p-3 ml-auto">
        <div class="text-xs font-semibold text-gray-600 mb-2">Export</div>
        <.live_component
          module={DialecticWeb.ExportMenuComp}
          id={"export-menu-" <> @graph_id <> "-" <> @node.id}
          graph_id={@graph_id}
          align="right"
        />
      </div>
    </div>
    """
  end
end
