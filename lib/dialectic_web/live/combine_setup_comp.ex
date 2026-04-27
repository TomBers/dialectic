defmodule DialecticWeb.CombineSetupComp do
  @moduledoc """
  LiveComponent that renders the combine setup panel where users can
  select two nodes to synthesize.
  """
  use DialecticWeb, :live_component

  alias DialecticWeb.Utils.NodeTitleHelper

  @impl true
  def update(assigns, socket) do
    mode = Map.get(assigns, :mode, :off)
    selected_nodes = Map.get(assigns, :selected_nodes, [])

    {:ok,
     assign(socket,
       id: assigns.id,
       mode: mode,
       selected_nodes: selected_nodes
     )}
  end

  @impl true
  def render(%{mode: :setup} = assigns) do
    ~H"""
    <div id={@id}>
      <%!-- Setup panel — rendered as a right-side drawer --%>
      <div class="flex flex-col h-full">
        <%!-- Header --%>
        <div class="flex items-center justify-between px-3 py-2 border-b border-gray-200">
          <h3 class="text-sm font-semibold text-gray-900">Combine Nodes</h3>
          <button
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "combine-drawer"}
              )
              |> Phoenix.LiveView.JS.push("close_combine_setup")
            }
            class="inline-flex items-center justify-center w-8 h-8 rounded-md border border-gray-200 text-gray-600 hover:bg-gray-50"
            aria-label="Close combine setup"
            title="Close"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>

        <%!-- Instructions --%>
        <div class="px-3 py-2 bg-violet-50 border-b border-violet-100">
          <p class="text-xs text-violet-700">
            Click two boxes on the grid to create a synthesis between them.
          </p>
        </div>

        <%!-- Selected nodes display --%>
        <div class="flex-1 overflow-y-auto px-3 py-3">
          <%= if length(@selected_nodes) == 0 do %>
            <div class="flex flex-col items-center justify-center py-8 text-center">
              <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center mb-3">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5 text-gray-400"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"></path>
                  <path d="M19 10v2a7 7 0 0 1-14 0v-2"></path>
                  <line x1="12" x2="12" y1="19" y2="22"></line>
                </svg>
              </div>
              <p class="text-sm text-gray-500 font-medium">No nodes selected</p>
              <p class="text-xs text-gray-400 mt-1">Click on graph nodes to select them</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <div class="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
                Selected Nodes ({length(@selected_nodes)}/2)
              </div>

              <%= for {node, idx} <- Enum.with_index(@selected_nodes) do %>
                <div class="group flex items-start gap-2 px-3 py-2 rounded-lg bg-white border-2 border-violet-200 hover:border-violet-300 hover:shadow-sm transition-all">
                  <%!-- Node number --%>
                  <span class={[
                    "shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold",
                    node_number_classes(idx)
                  ]}>
                    {idx + 1}
                  </span>

                  <%!-- Node info --%>
                  <div class="flex-1 min-w-0">
                    <p class="text-xs font-medium text-gray-900 mb-0.5">
                      {NodeTitleHelper.extract_node_title(node, max_length: 50)}
                    </p>
                    <p class="text-[10px] text-gray-400">{type_label(node.class)}</p>
                  </div>

                  <%!-- Remove button --%>
                  <button
                    phx-click="combine_deselect_node"
                    phx-value-node-id={node.id}
                    class="shrink-0 p-0.5 text-gray-300 hover:text-red-500 transition-colors opacity-0 group-hover:opacity-100"
                    aria-label="Remove node"
                    title="Remove"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Footer actions --%>
        <div class="px-3 py-3 border-t border-gray-200 space-y-2">
          <button
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "combine-drawer"}
              )
              |> Phoenix.LiveView.JS.push("execute_combine")
            }
            disabled={length(@selected_nodes) != 2}
            class={[
              "w-full inline-flex items-center justify-center gap-2 px-4 py-2 text-sm font-semibold rounded-lg transition-colors",
              if(length(@selected_nodes) == 2,
                do: "bg-violet-600 text-white hover:bg-violet-500 shadow-sm",
                else: "bg-gray-100 text-gray-400 cursor-not-allowed"
              )
            ]}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"></path>
              <path d="M19 10v2a7 7 0 0 1-14 0v-2"></path>
              <line x1="12" x2="12" y1="19" y2="22"></line>
            </svg>
            <%= if length(@selected_nodes) == 2 do %>
              Create Synthesis
            <% else %>
              Select 2 nodes to combine
            <% end %>
          </button>

          <%= if length(@selected_nodes) > 0 do %>
            <button
              phx-click="combine_clear_selection"
              class="w-full inline-flex items-center justify-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-md transition-colors"
            >
              <.icon name="hero-trash" class="w-3.5 h-3.5" /> Clear selection
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Catch-all for unexpected modes — renders nothing
  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}></div>
    """
  end

  # ────────────────────────────────────────────────────────────────────
  # Helpers
  # ────────────────────────────────────────────────────────────────────

  defp node_number_classes(idx) do
    case idx do
      0 -> "bg-violet-100 text-violet-700"
      1 -> "bg-purple-100 text-purple-700"
      _ -> "bg-gray-100 text-gray-600"
    end
  end

  defp type_label(node_class) do
    case to_string(node_class) do
      "question" -> "Question"
      "thesis" -> "Thesis"
      "antithesis" -> "Counterargument"
      "synthesis" -> "Synthesis"
      "ideas" -> "Related Ideas"
      "deepdive" -> "Deep Dive"
      "origin" -> "Stream"
      "user" -> "Comment"
      "answer" -> "Response"
      "explain" -> "Explanation"
      other -> String.capitalize(other)
    end
  end
end
