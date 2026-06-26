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
    <div class="space-y-3">
      <section class="divide-y divide-slate-100">
        <.guide_item
          icon="hero-cursor-arrow-rays"
          icon_classes="bg-sky-50 text-sky-600 ring-sky-100"
          text="Click a node, drag to pan, scroll to zoom."
        />

        <.guide_item
          icon="hero-arrows-right-left"
          icon_classes="bg-slate-100 text-slate-700 ring-slate-200"
          text="Switch Reader | Grid without losing your place."
        />

        <.guide_item
          icon="hero-sparkles"
          icon_classes="bg-emerald-50 text-emerald-600 ring-emerald-100"
          text="Use Pro, Con, Related, or Blend below a node."
        />

        <.guide_item
          icon="hero-bookmark-square"
          icon_classes="bg-amber-50 text-amber-600 ring-amber-100"
          text="Search, highlight, or share from the top bar."
        />
      </section>

      <.link
        href={~p"/intro/how"}
        class="inline-flex items-center gap-2 text-sm font-semibold text-emerald-700 transition hover:text-emerald-800"
      >
        <.icon name="hero-book-open" class="h-4 w-4" />
        <span>Open full guide</span>
      </.link>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :icon_classes, :string, required: true
  attr :text, :string, required: true

  defp guide_item(assigns) do
    ~H"""
    <div class="py-2.5 first:pt-0 last:pb-0">
      <div class="flex items-center gap-3">
        <div class={[
          "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full ring-1",
          @icon_classes
        ]}>
          <.icon name={@icon} class="h-4 w-4" />
        </div>

        <p class="min-w-0 text-sm font-medium leading-5 text-slate-800">{@text}</p>
      </div>
    </div>
    """
  end
end
