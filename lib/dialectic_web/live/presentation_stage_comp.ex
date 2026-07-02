defmodule DialecticWeb.PresentationStageComp do
  use DialecticWeb, :html

  alias DialecticWeb.Utils.NodeTitleHelper
  import DialecticWeb.GraphPresentation

  attr :slides, :list, required: true
  attr :current_node, :map, default: nil
  attr :presentation_title, :string, default: ""

  def presentation_stage(assigns) do
    active_slide = active_slide(assigns.slides, assigns.current_node)
    active_slide_id = if active_slide, do: active_slide.id, else: nil

    assigns =
      assigns
      |> assign(:active_slide, active_slide)
      |> assign(:active_slide_id, active_slide_id)
      |> assign(:active_index, slide_position(assigns.slides, active_slide_id))
      |> assign(:previous_slide, adjacent_slide(assigns.slides, active_slide_id, "previous"))
      |> assign(:next_slide, adjacent_slide(assigns.slides, active_slide_id, "next"))
      |> assign(:parent_slides, parent_slides(active_slide, assigns.slides))
      |> assign(:child_slides, child_slides(active_slide, assigns.slides))

    ~H"""
    <section
      id="presentation-stage"
      class="w-full shrink-0 border-b border-slate-200/80 bg-slate-950 text-slate-100 md:h-full md:w-[clamp(20rem,42vw,34rem)] md:border-b-0 md:border-r md:border-slate-800"
    >
      <div class="flex h-full flex-col">
        <div class="border-b border-slate-800 px-5 py-5 sm:px-6">
          <h2 class="text-2xl font-semibold tracking-tight text-white sm:text-[2rem]">
            {if @active_slide,
              do: NodeTitleHelper.extract_node_title(@active_slide, max_length: :infinity),
              else: @presentation_title}
          </h2>

          <div class="mt-5 flex items-center gap-2">
            <button
              id="presentation-prev-slide"
              phx-click="presentation_step"
              phx-value-direction="previous"
              disabled={is_nil(@previous_slide)}
              class={[
                "inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-medium transition",
                if(is_nil(@previous_slide),
                  do: "cursor-not-allowed border border-slate-800 bg-slate-900 text-slate-600",
                  else: "border border-slate-700 bg-slate-900 text-slate-100 hover:border-slate-500"
                )
              ]}
            >
              <.icon name="hero-arrow-left" class="h-4 w-4" /> Previous
            </button>
            <button
              id="presentation-next-slide"
              phx-click="presentation_step"
              phx-value-direction="next"
              disabled={is_nil(@next_slide)}
              class={[
                "inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-medium transition",
                if(is_nil(@next_slide),
                  do: "cursor-not-allowed border border-slate-800 bg-slate-900 text-slate-600",
                  else:
                    "border border-indigo-400/40 bg-indigo-500/10 text-indigo-100 hover:border-indigo-300 hover:bg-indigo-500/20"
                )
              ]}
            >
              Next <.icon name="hero-arrow-right" class="h-4 w-4" />
            </button>
          </div>
        </div>

        <div class="flex-1 space-y-5 overflow-y-auto px-5 py-5 sm:px-6">
          <section class="rounded-2xl border border-white/10 bg-white/5 p-4 shadow-[0_20px_60px_-40px_rgba(15,23,42,0.95)]">
            <div class="flex items-center justify-between gap-3">
              <div>
                <h3 class="text-sm font-semibold text-white">Agenda</h3>
                <p class="mt-1 text-xs text-slate-400">Jump between selected talking points.</p>
              </div>
              <span class="text-xs text-slate-500">
                {@active_index || 1} of {max(length(@slides), 1)}
              </span>
            </div>

            <div id="presentation-agenda" class="mt-4 space-y-2">
              <%= for {slide, idx} <- Enum.with_index(@slides, 1) do %>
                <button
                  id={"presentation-agenda-slide-#{slide.id}"}
                  phx-click="presentation_go_to_slide"
                  phx-value-node-id={slide.id}
                  class={[
                    "flex w-full items-start gap-3 rounded-2xl border px-3 py-3 text-left transition",
                    if(slide.id == @active_slide_id,
                      do:
                        "border-indigo-300/60 bg-indigo-400/15 shadow-[0_20px_45px_-30px_rgba(99,102,241,0.8)]",
                      else:
                        "border-white/10 bg-slate-900/60 hover:border-slate-600 hover:bg-slate-900"
                    )
                  ]}
                >
                  <span class={[
                    "mt-0.5 inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-[11px] font-bold",
                    if(slide.id == @active_slide_id,
                      do: "bg-white text-slate-950",
                      else: "bg-slate-800 text-slate-200"
                    )
                  ]}>
                    {idx}
                  </span>
                  <span class="min-w-0 flex-1">
                    <span class="block truncate text-sm font-semibold text-white">
                      {NodeTitleHelper.extract_node_title(slide, max_length: :infinity)}
                    </span>
                    <span class="mt-1 block text-xs text-slate-400">
                      {type_label(slide.class)}
                    </span>
                  </span>
                </button>
              <% end %>
            </div>
          </section>

          <section
            id="presentation-current-slide"
            class="overflow-hidden rounded-[1.75rem] border border-slate-200/70 bg-white text-slate-900 shadow-[0_35px_90px_-55px_rgba(15,23,42,0.55)]"
          >
            <div class="border-b border-slate-200 bg-slate-50/90 px-5 py-4">
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-500">
                Current slide
              </p>
              <p class="mt-2 text-lg font-semibold tracking-tight text-slate-950">
                {if @active_slide,
                  do: NodeTitleHelper.extract_node_title(@active_slide, max_length: :infinity),
                  else: "Select a slide"}
              </p>
            </div>

            <div class="px-5 py-5">
              <%= if @active_slide && body_markdown(@active_slide) != "" do %>
                <article class="prose prose-slate max-w-none prose-headings:tracking-tight prose-p:leading-7 prose-li:leading-7">
                  <div
                    phx-hook="Markdown"
                    id={"presentation-markdown-body-#{@active_slide.id}"}
                    data-md={body_markdown(@active_slide)}
                  >
                  </div>
                </article>
              <% else %>
                <p class="text-sm leading-6 text-slate-600">
                  This talking point works best as a title slide. Use the agenda and graph structure to elaborate live.
                </p>
              <% end %>
            </div>
          </section>

          <section class="grid gap-4 lg:grid-cols-2">
            <div class="rounded-2xl border border-white/10 bg-white/5 p-4">
              <h3 class="text-sm font-semibold text-white">Builds On</h3>
              <p class="mt-1 text-xs text-slate-400">
                Earlier points in the deck that set this up.
              </p>
              <div class="mt-4 space-y-2">
                <%= if @parent_slides == [] do %>
                  <p class="text-sm leading-6 text-slate-400">
                    No earlier deck node links into this point yet.
                  </p>
                <% else %>
                  <%= for slide <- Enum.take(@parent_slides, 4) do %>
                    <button
                      phx-click="presentation_go_to_slide"
                      phx-value-node-id={slide.id}
                      class="flex w-full items-start gap-2 rounded-xl border border-white/10 bg-slate-900/60 px-3 py-2 text-left transition hover:border-slate-500 hover:bg-slate-900"
                    >
                      <.icon
                        name="hero-arrow-turn-up-left"
                        class="mt-0.5 h-4 w-4 shrink-0 text-slate-400"
                      />
                      <span class="text-sm leading-5 text-slate-200">
                        {NodeTitleHelper.extract_node_title(slide, max_length: :infinity)}
                      </span>
                    </button>
                  <% end %>
                <% end %>
              </div>
            </div>

            <div class="rounded-2xl border border-white/10 bg-white/5 p-4">
              <h3 class="text-sm font-semibold text-white">Leads To</h3>
              <p class="mt-1 text-xs text-slate-400">
                Where this idea can take the audience next.
              </p>
              <div class="mt-4 space-y-2">
                <%= if @child_slides == [] do %>
                  <p class="text-sm leading-6 text-slate-400">
                    No later deck node branches from this point yet.
                  </p>
                <% else %>
                  <%= for slide <- Enum.take(@child_slides, 4) do %>
                    <button
                      phx-click="presentation_go_to_slide"
                      phx-value-node-id={slide.id}
                      class="flex w-full items-start gap-2 rounded-xl border border-white/10 bg-slate-900/60 px-3 py-2 text-left transition hover:border-slate-500 hover:bg-slate-900"
                    >
                      <.icon
                        name="hero-arrow-uturn-right"
                        class="mt-0.5 h-4 w-4 shrink-0 text-slate-400"
                      />
                      <span class="text-sm leading-5 text-slate-200">
                        {NodeTitleHelper.extract_node_title(slide, max_length: :infinity)}
                      </span>
                    </button>
                  <% end %>
                <% end %>
              </div>
            </div>
          </section>
        </div>
      </div>
    </section>
    """
  end
end
