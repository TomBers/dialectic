defmodule DialecticWeb.OriginOnboardingComp do
  @moduledoc """
  A LiveComponent that renders onboarding instructions for using a grid page.

  ## Required Assigns
  - `:id` - Component ID (required by LiveComponent)
  """
  use DialecticWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <section class="rounded-2xl border border-slate-200 bg-slate-50/85 px-4 py-3">
        <p class="text-sm leading-6 text-slate-700">
          Use Graph to orient yourself, then switch to Reader when you want the same point in a linear flow.
        </p>
      </section>

      <section class="space-y-2.5">
        <.guide_item
          icon="hero-cursor-arrow-rays"
          icon_classes="bg-sky-50 text-sky-600 ring-sky-100"
          title="Navigate the graph"
        >
          Click a node to focus it. Drag to pan. Scroll to zoom.
        </.guide_item>

        <.guide_item
          icon="hero-arrows-right-left"
          icon_classes="bg-slate-100 text-slate-700 ring-slate-200"
          title="Switch views without losing your place"
        >
          Use <span class="font-semibold text-slate-900">Reader | Graph</span>
          in the top bar. It keeps you on the same node.
        </.guide_item>

        <.guide_item
          icon="hero-sparkles"
          icon_classes="bg-emerald-50 text-emerald-600 ring-emerald-100"
          title="Continue from the selected node"
        >
          Use <span class="font-semibold text-slate-900">Pro | Con</span>, <span class="font-semibold text-slate-900">Related</span>, or
          <span class="font-semibold text-slate-900">Blend</span>
          under the current node to grow the conversation.
        </.guide_item>

        <.guide_item
          icon="hero-bookmark-square"
          icon_classes="bg-amber-50 text-amber-600 ring-amber-100"
          title="Save or return later"
        >
          Use <span class="font-semibold text-slate-900">Search</span>
          to jump, <span class="font-semibold text-slate-900">Highlights</span>
          to keep passages, and <span class="font-semibold text-slate-900">Share</span>
          when you want to send the graph.
        </.guide_item>
      </section>

      <section class="rounded-2xl border border-emerald-200/80 bg-emerald-50/70 px-4 py-3">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-sm font-semibold text-slate-950">Need the full walkthrough?</p>
            <p class="mt-1 text-sm leading-6 text-slate-600">
              Open the guide for screenshots, examples, and a fuller explanation of each control.
            </p>
          </div>

          <.link
            href={~p"/intro/how"}
            class="inline-flex shrink-0 items-center gap-2 whitespace-nowrap rounded-full border border-emerald-300 bg-white px-4 py-2 text-sm font-semibold text-emerald-700 transition hover:bg-emerald-100"
          >
            <.icon name="hero-book-open" class="h-4 w-4" />
            <span>Open full guide</span>
          </.link>
        </div>
      </section>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :icon_classes, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp guide_item(assigns) do
    ~H"""
    <div class="rounded-2xl border border-slate-200 bg-white px-4 py-3 shadow-sm">
      <div class="flex items-start gap-3">
        <div class={[
          "mt-0.5 inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full ring-1",
          @icon_classes
        ]}>
          <.icon name={@icon} class="h-4 w-4" />
        </div>

        <div class="min-w-0">
          <h5 class="text-sm font-semibold text-slate-950">{@title}</h5>
          <p class="mt-0.5 text-sm leading-6 text-slate-600">
            {render_slot(@inner_block)}
          </p>
        </div>
      </div>
    </div>
    """
  end
end
