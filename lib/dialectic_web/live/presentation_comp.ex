defmodule DialecticWeb.PresentationComp do
  @moduledoc """
  LiveComponent that renders a full-screen slideshow-style presentation
  over the existing graph view. Each slide corresponds to a graph node,
  rendered with markdown content and colored accents based on node type.

  Also renders the setup panel (slide picker / reorder list) when
  `mode` is `:setup`.
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
    current_index = Map.get(assigns, :current_index, 0)
    total = length(slides)

    current_slide =
      if total > 0 do
        Enum.at(slides, current_index) || List.first(slides)
      else
        nil
      end

    progress_percent =
      if total > 1 do
        Float.round(current_index / (total - 1) * 100, 1)
      else
        100.0
      end

    {:ok,
     assign(socket,
       id: assigns.id,
       mode: mode,
       slides: slides,
       current_index: current_index,
       total: total,
       current_slide: current_slide,
       graph_title: Map.get(assigns, :graph_title, ""),
       is_owner: Map.get(assigns, :is_owner, false),
       slide_node_ids: Map.get(assigns, :slide_node_ids, []),
       all_nodes: Map.get(assigns, :all_nodes, []),
       progress_percent: progress_percent,
       can_prev: current_index > 0,
       can_next: current_index < total - 1
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
            phx-click="exit_presentation"
            class="text-gray-400 hover:text-gray-600 transition-colors"
            aria-label="Close setup"
            title="Close"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
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
            phx-click="start_presenting"
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

  def render(%{mode: :presenting} = assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-[9999] flex flex-col"
      phx-hook="Presentation"
      data-slide-index={@current_index}
    >
      <%!-- Dark background --%>
      <div class="absolute inset-0 bg-gray-900" style="background-color: #111827;"></div>

      <%!-- Content --%>
      <div class="relative flex-1 flex flex-col items-center justify-center px-4 py-6 overflow-hidden">
        <%!-- Header --%>
        <div class="absolute top-4 left-6 right-6 flex items-center justify-between">
          <h2 class="text-sm font-medium text-gray-400 truncate max-w-md">
            {@graph_title}
          </h2>
          <button
            phx-click="exit_presentation"
            class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-400 hover:text-white bg-gray-800 hover:bg-gray-700 rounded-lg border border-gray-700 transition-colors"
            title="Exit presentation (Esc)"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-3.5 h-3.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
            Exit
          </button>
        </div>

        <%!-- Slide card --%>
        <%= if @current_slide do %>
          <% accent = slide_accent_classes(@current_slide.class) %>
          <div class="presentation-slide-content transition-all duration-300 ease-out w-full max-w-4xl">
            <div class={[
              "relative bg-white rounded-xl shadow-2xl overflow-hidden",
              "flex flex-col max-h-[calc(100vh-12rem)]",
              accent.border_left
            ]}>
              <%!-- Badge & counter --%>
              <div class="flex items-center gap-2 px-6 pt-5 pb-0">
                <span class={[
                  "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold",
                  accent.badge_bg,
                  accent.badge_text
                ]}>
                  {type_label(@current_slide.class)}
                </span>
                <span class="text-xs text-gray-400">
                  Slide {@current_index + 1} of {@total}
                </span>
              </div>

              <%!-- Content --%>
              <div class="flex-1 overflow-y-auto px-8 pt-4 pb-8">
                <article class="prose prose-stone prose-lg md:prose-xl max-w-none">
                  <h2 class="text-xl sm:text-2xl md:text-3xl mt-0 mb-4 pb-3 border-b border-gray-200">
                    <span
                      phx-hook="Markdown"
                      id={"pres-title-#{@current_slide.id}-#{@current_index}"}
                      data-md={@current_slide.content || ""}
                      data-title-only="true"
                    >
                    </span>
                  </h2>
                  <div class="text-base sm:text-lg leading-relaxed">
                    <div
                      phx-hook="Markdown"
                      id={"pres-body-#{@current_slide.id}-#{@current_index}"}
                      data-md={@current_slide.content || ""}
                      data-body-only="true"
                    >
                    </div>
                  </div>
                </article>
              </div>
            </div>
          </div>
        <% else %>
          <div class="text-gray-400 text-lg">No slides available</div>
        <% end %>
      </div>

      <%!-- Bottom navigation --%>
      <div class="relative z-10 flex flex-col">
        <%!-- Slide dots --%>
        <%= if @total > 1 and @total <= 20 do %>
          <div class="flex items-center justify-center gap-1.5 pb-3">
            <%= for idx <- 0..(@total - 1) do %>
              <button
                phx-click="presentation_goto"
                phx-value-index={idx}
                class={[
                  "w-2 h-2 rounded-full transition-all duration-200",
                  if(idx == @current_index,
                    do: "bg-indigo-400 scale-125",
                    else: "bg-gray-600 hover:bg-gray-500"
                  )
                ]}
                title={"Go to slide #{idx + 1}"}
                aria-label={"Slide #{idx + 1}"}
              />
            <% end %>
          </div>
        <% end %>

        <%!-- Nav buttons --%>
        <div class="flex items-center justify-center gap-4 px-6 py-3">
          <button
            phx-click="presentation_prev"
            disabled={!@can_prev}
            class={[
              "inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-lg border transition-colors",
              if(@can_prev,
                do: "text-gray-200 bg-gray-800 border-gray-600 hover:bg-gray-700 hover:text-white",
                else: "text-gray-600 bg-gray-800/50 border-gray-700 cursor-not-allowed"
              )
            ]}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
            </svg>
            Previous
          </button>

          <span class="text-sm text-gray-400 font-medium tabular-nums min-w-[4rem] text-center">
            {@current_index + 1} / {@total}
          </span>

          <button
            phx-click="presentation_next"
            disabled={!@can_next}
            class={[
              "inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-lg border transition-colors",
              if(@can_next,
                do: "text-gray-200 bg-gray-800 border-gray-600 hover:bg-gray-700 hover:text-white",
                else: "text-gray-600 bg-gray-800/50 border-gray-700 cursor-not-allowed"
              )
            ]}
          >
            Next
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>

        <%!-- Keyboard hints --%>
        <div class="text-center pb-2">
          <span class="text-xs text-gray-500">
            <kbd class="px-1.5 py-0.5 text-[10px] font-medium bg-gray-800 border border-gray-600 rounded text-gray-400">
              ←
            </kbd>
            <kbd class="px-1.5 py-0.5 text-[10px] font-medium bg-gray-800 border border-gray-600 rounded text-gray-400 ml-0.5">
              →
            </kbd>
            <span class="mx-1.5 text-gray-600">navigate</span>
            <kbd class="px-1.5 py-0.5 text-[10px] font-medium bg-gray-800 border border-gray-600 rounded text-gray-400">
              Esc
            </kbd>
            <span class="ml-1.5 text-gray-600">exit</span>
          </span>
        </div>

        <%!-- Progress bar --%>
        <div class="w-full h-1 bg-gray-800">
          <div
            class="h-full bg-indigo-500 transition-all duration-300 ease-out"
            style={"width: #{@progress_percent}%"}
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Off — render nothing
  def render(assigns) do
    ~H"""
    <div id={@id}></div>
    """
  end

  # ────────────────────────────────────────────────────────────────────
  # Helpers
  # ────────────────────────────────────────────────────────────────────

  defp slide_accent_classes(node_class) do
    case to_string(node_class) do
      "question" ->
        %{
          border_left: "border-l-4 border-l-sky-400",
          badge_bg: "bg-sky-100",
          badge_text: "text-sky-700"
        }

      "thesis" ->
        %{
          border_left: "border-l-4 border-l-emerald-400",
          badge_bg: "bg-emerald-100",
          badge_text: "text-emerald-700"
        }

      "antithesis" ->
        %{
          border_left: "border-l-4 border-l-red-400",
          badge_bg: "bg-red-100",
          badge_text: "text-red-700"
        }

      "synthesis" ->
        %{
          border_left: "border-l-4 border-l-purple-400",
          badge_bg: "bg-purple-100",
          badge_text: "text-purple-700"
        }

      "ideas" ->
        %{
          border_left: "border-l-4 border-l-orange-400",
          badge_bg: "bg-orange-100",
          badge_text: "text-orange-700"
        }

      "deepdive" ->
        %{
          border_left: "border-l-4 border-l-cyan-400",
          badge_bg: "bg-cyan-100",
          badge_text: "text-cyan-700"
        }

      "origin" ->
        %{
          border_left: "border-l-4 border-l-slate-400",
          badge_bg: "bg-slate-200",
          badge_text: "text-slate-700"
        }

      _ ->
        %{
          border_left: "border-l-4 border-l-gray-300",
          badge_bg: "bg-gray-100",
          badge_text: "text-gray-600"
        }
    end
  end

  defp slide_number_classes(node_class) do
    case to_string(node_class) do
      "question" -> "bg-sky-100 text-sky-700"
      "thesis" -> "bg-emerald-100 text-emerald-700"
      "antithesis" -> "bg-red-100 text-red-700"
      "synthesis" -> "bg-purple-100 text-purple-700"
      "ideas" -> "bg-orange-100 text-orange-700"
      "deepdive" -> "bg-cyan-100 text-cyan-700"
      "origin" -> "bg-slate-200 text-slate-700"
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
