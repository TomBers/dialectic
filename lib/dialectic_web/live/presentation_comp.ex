defmodule DialecticWeb.PresentationComp do
  @moduledoc """
  LiveComponent that renders the presentation setup panel (slide picker /
  reorder list) as a right-side drawer.
  """
  use DialecticWeb, :live_component

  alias DialecticWeb.Utils.NodeTitleHelper

  # ────────────────────────────────────────────────────────────────────
  # update/2
  # ────────────────────────────────────────────────────────────────────

  @impl true
  def update(assigns, socket) do
    mode = Map.get(assigns, :mode, :off)
    slides = Map.get(assigns, :slides, [])
    presentation_title = Map.get(assigns, :presentation_title, "")

    {:ok,
     assign(socket,
       id: assigns.id,
       mode: mode,
       slides: slides,
       presentation_title: presentation_title
     )}
  end

  # ────────────────────────────────────────────────────────────────────
  # render/1
  # ────────────────────────────────────────────────────────────────────

  @impl true
  def render(%{mode: :setup} = assigns) do
    ~H"""
    <div id={@id}>
      <%!-- Setup panel — rendered as a right-side drawer --%>
      <div class="flex flex-col h-full">
        <%!-- Header --%>
        <div class="flex items-center justify-between px-3 py-2 border-b border-gray-200">
          <h3 class="text-sm font-semibold text-gray-900">Presentation</h3>
          <button
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "presentation-drawer"}
              )
              |> Phoenix.LiveView.JS.push("close_presentation_setup")
            }
            class="inline-flex items-center justify-center w-8 h-8 rounded-md border border-gray-200 text-gray-600 hover:bg-gray-50"
            aria-label="Close setup"
            title="Close"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>

        <%!-- Presentation title --%>
        <div class="px-3 py-2 border-b border-gray-200">
          <label
            for="presentation-title-input"
            class="block text-[10px] font-medium text-gray-500 uppercase tracking-wide mb-1"
          >
            Title
          </label>
          <form phx-change="update_presentation_title" phx-submit="update_presentation_title">
            <input
              type="text"
              name="title"
              id="presentation-title-input"
              value={@presentation_title}
              placeholder="e.g. What if people talked to plants?"
              maxlength="120"
              phx-debounce="300"
              autocomplete="off"
              class="w-full px-2 py-1.5 text-sm font-medium text-gray-900 bg-gray-50 border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 placeholder:text-gray-400 placeholder:font-normal"
            />
          </form>
        </div>

        <%!-- Instructions --%>
        <div class="px-3 py-2 bg-indigo-50 border-b border-indigo-100">
          <p class="text-xs text-indigo-700">
            Click nodes on the graph to add them as slides. Drag to reorder.
          </p>
        </div>

        <%!-- Slide list --%>
        <div class="flex-1 overflow-y-auto px-2 py-2">
          <%= if length(@slides) == 0 do %>
            <div class="flex flex-col items-center justify-center py-8 text-center">
              <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center mb-3">
                <.icon name="hero-presentation-chart-bar" class="w-5 h-5 text-gray-400" />
              </div>
              <p class="text-sm text-gray-500 font-medium">No slides yet</p>
              <p class="text-xs text-gray-400 mt-1">Click on graph nodes to add them</p>
            </div>
          <% else %>
            <ul id="presentation-slide-list" phx-hook="PresentationSetup" class="space-y-1">
              <%= for {slide, idx} <- Enum.with_index(@slides) do %>
                <li
                  id={"pres-slide-item-#{slide.id}"}
                  data-node-id={slide.id}
                  draggable="true"
                  class="group flex items-center gap-2 px-2 py-1.5 rounded-lg bg-white border border-gray-200 hover:border-gray-300 hover:shadow-sm transition-all cursor-grab active:cursor-grabbing"
                >
                  <%!-- Drag handle --%>
                  <span class="text-gray-300 group-hover:text-gray-400 shrink-0">
                    <.icon name="hero-bars-3" class="w-3.5 h-3.5" />
                  </span>

                  <%!-- Slide number --%>
                  <span class={[
                    "shrink-0 w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold",
                    slide_number_classes(slide.class)
                  ]}>
                    {idx + 1}
                  </span>

                  <%!-- Title --%>
                  <div class="flex-1 min-w-0">
                    <p class="text-xs font-medium text-gray-900 truncate">
                      {NodeTitleHelper.extract_node_title(slide, max_length: 40)}
                    </p>
                    <p class="text-[10px] text-gray-400">{type_label(slide.class)}</p>
                  </div>

                  <%!-- Remove button --%>
                  <button
                    phx-click="presentation_remove_slide"
                    phx-value-node-id={slide.id}
                    class="shrink-0 p-0.5 text-gray-300 hover:text-red-500 transition-colors opacity-0 group-hover:opacity-100"
                    aria-label="Remove slide"
                    title="Remove"
                  >
                    <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
                  </button>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>

        <%!-- Footer actions --%>
        <div class="px-3 py-3 border-t border-gray-200 space-y-2">
          <button
            phx-click={
              Phoenix.LiveView.JS.dispatch("toggle-panel",
                to: "#graph-layout",
                detail: %{id: "presentation-drawer"}
              )
              |> Phoenix.LiveView.JS.push("start_presenting")
            }
            disabled={length(@slides) == 0}
            class={[
              "w-full inline-flex items-center justify-center gap-2 px-4 py-2 text-sm font-semibold rounded-lg transition-colors",
              if(length(@slides) > 0,
                do: "bg-indigo-600 text-white hover:bg-indigo-500 shadow-sm",
                else: "bg-gray-100 text-gray-400 cursor-not-allowed"
              )
            ]}
          >
            <.icon name="hero-play" class="w-4 h-4" />
            Present ({length(@slides)} {if length(@slides) == 1, do: "slide", else: "slides"})
          </button>

          <%= if length(@slides) > 0 do %>
            <button
              phx-click="presentation_clear_slides"
              class="w-full inline-flex items-center justify-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-md transition-colors"
            >
              <.icon name="hero-trash" class="w-3.5 h-3.5" /> Clear all
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

  defp slide_number_classes(node_class) do
    case to_string(node_class) do
      "question" -> "bg-sky-100 text-sky-700"
      "thesis" -> "bg-emerald-100 text-emerald-700"
      "antithesis" -> "bg-red-100 text-red-700"
      "synthesis" -> "bg-purple-100 text-purple-700"
      "ideas" -> "bg-orange-100 text-orange-700"
      "deepdive" -> "bg-cyan-100 text-cyan-700"
      "origin" -> "bg-slate-200 text-slate-700"
      "user" -> "bg-green-200 text-green-800"
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
