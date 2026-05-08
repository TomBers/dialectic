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
      <section class="rounded-2xl border border-indigo-100 bg-indigo-50/60 p-5 sm:p-6">
        <p class="inline-flex items-center rounded-full bg-white px-3 py-1 text-xs font-semibold uppercase tracking-wide text-indigo-700 ring-1 ring-indigo-200">
          Quick start
        </p>
        <h4 class="mt-4 text-xl font-semibold text-gray-900">This is a map of ideas</h4>
        <p class="mt-2 text-sm text-gray-700">
          Each box is one idea. Click a box to read it. Then either continue it, challenge it,
          or save part of it.
        </p>

        <div class="mt-5 grid gap-3 sm:grid-cols-3">
          <div class="rounded-xl border border-white/80 bg-white/80 p-4">
            <p class="text-sm font-semibold text-gray-900">1. Click one box</p>
            <p class="mt-1 text-xs text-gray-600">
              Read one idea first.
            </p>
          </div>
          <div class="rounded-xl border border-white/80 bg-white/80 p-4">
            <p class="text-sm font-semibold text-gray-900">2. Pick one action</p>
            <p class="mt-1 text-xs text-gray-600">
              Ask, Post, Pro | Con, Related, or Blend.
            </p>
          </div>
          <div class="rounded-xl border border-white/80 bg-white/80 p-4">
            <p class="text-sm font-semibold text-gray-900">3. Select text when needed</p>
            <p class="mt-1 text-xs text-gray-600">
              Highlight a short phrase for more precise tools.
            </p>
          </div>
        </div>
      </section>

      <section class="grid gap-4 lg:grid-cols-2">
        <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <h5 class="text-lg font-semibold text-gray-900">Two main ways to add something</h5>

          <div class="mt-4 space-y-3">
            <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
              <div class="flex items-start gap-3">
                <.icon name="hero-question-mark-circle" class="mt-0.5 h-5 w-5 shrink-0 text-sky-500" />
                <div>
                  <p class="text-sm font-semibold text-gray-900">Ask</p>
                  <p class="mt-1 text-xs text-gray-600">
                    Let the AI continue the idea.
                  </p>
                </div>
              </div>
            </div>

            <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
              <div class="flex items-start gap-3">
                <.icon
                  name="hero-chat-bubble-bottom-center-text"
                  class="mt-0.5 h-5 w-5 shrink-0 text-emerald-500"
                />
                <div>
                  <p class="text-sm font-semibold text-gray-900">Post</p>
                  <p class="mt-1 text-xs text-gray-600">
                    Add your own thought to the map.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <h5 class="text-lg font-semibold text-gray-900">What the buttons do</h5>

          <div class="mt-4 grid gap-3">
            <div class="flex items-start gap-3 rounded-xl border border-gray-200 bg-gray-50 p-4">
              <.icon name="hero-scale" class="mt-0.5 h-5 w-5 shrink-0 text-emerald-500" />
              <div>
                <p class="text-sm font-semibold text-gray-900">Pro | Con</p>
                <p class="mt-1 text-xs text-gray-600">See both sides.</p>
              </div>
            </div>

            <div class="flex items-start gap-3 rounded-xl border border-gray-200 bg-gray-50 p-4">
              <.icon name="hero-light-bulb" class="mt-0.5 h-5 w-5 shrink-0 text-amber-500" />
              <div>
                <p class="text-sm font-semibold text-gray-900">Related</p>
                <p class="mt-1 text-xs text-gray-600">Find nearby ideas.</p>
              </div>
            </div>

            <div class="flex items-start gap-3 rounded-xl border border-gray-200 bg-gray-50 p-4">
              <.icon name="hero-arrows-pointing-in" class="mt-0.5 h-5 w-5 shrink-0 text-violet-500" />
              <div>
                <p class="text-sm font-semibold text-gray-900">Blend</p>
                <p class="mt-1 text-xs text-gray-600">Combine two ideas.</p>
              </div>
            </div>

            <div class="flex items-start gap-3 rounded-xl border border-gray-200 bg-gray-50 p-4">
              <.icon name="hero-chevron-down" class="mt-0.5 h-5 w-5 shrink-0 text-slate-500" />
              <div>
                <p class="text-sm font-semibold text-gray-900">Advanced tools</p>
                <p class="mt-1 text-xs text-gray-600">Go deeper when you need to.</p>
              </div>
            </div>
            <div class="flex items-start gap-3 rounded-xl border border-gray-200 bg-gray-50 p-4">
              <.icon name="hero-magnifying-glass" class="mt-0.5 h-5 w-5 shrink-0 text-gray-500" />
              <div>
                <p class="text-sm font-semibold text-gray-900">Select text</p>
                <p class="mt-1 text-xs text-gray-600">Work on one exact phrase.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <div class="rounded-xl border border-gray-200 bg-gray-50 px-4 py-3">
        <p class="text-xs text-gray-600">
          Drag to move around. Scroll to zoom. Click any box to focus it.
        </p>
      </div>
    </div>
    """
  end
end
