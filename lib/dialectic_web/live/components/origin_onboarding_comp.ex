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
    <div class="space-y-5">
      <section class="rounded-2xl border border-indigo-100 bg-indigo-50/60 p-5 sm:p-6">
        <p class="inline-flex items-center rounded-full bg-white px-3 py-1 text-xs font-semibold uppercase tracking-wide text-indigo-700 ring-1 ring-indigo-200">
          Quick start
        </p>
        <h4 class="mt-4 text-xl font-semibold text-gray-900">
          Branch from one good node at a time
        </h4>
        <p class="mt-2 text-sm text-gray-700">
          This page turns each answer into a connected node. Read the selected node, then
          choose one clear next step instead of expanding everything at once.
        </p>

        <div class="mt-5 grid gap-3 sm:grid-cols-3">
          <div class="rounded-xl border border-white/80 bg-white/80 p-4">
            <p class="text-sm font-semibold text-gray-900">1. Read the current node</p>
            <p class="mt-1 text-xs text-gray-600">
              Click a node, read it, and only then decide what needs a follow-up.
            </p>
          </div>
          <div class="rounded-xl border border-white/80 bg-white/80 p-4">
            <p class="text-sm font-semibold text-gray-900">2. Ask or Post</p>
            <p class="mt-1 text-xs text-gray-600">
              Ask for a new AI branch, or Post your own interpretation into the map.
            </p>
          </div>
          <div class="rounded-xl border border-white/80 bg-white/80 p-4">
            <p class="text-sm font-semibold text-gray-900">3. Save what matters</p>
            <p class="mt-1 text-xs text-gray-600">
              Highlight useful passages, star important nodes, then share when the grid is ready.
            </p>
          </div>
        </div>
      </section>

      <section class="grid gap-4 lg:grid-cols-2">
        <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <p class="inline-flex items-center rounded-full bg-sky-50 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-sky-700 ring-1 ring-sky-200">
            Bottom composer
          </p>
          <h5 class="mt-4 text-lg font-semibold text-gray-900">Ask and Post are different</h5>

          <div class="mt-4 space-y-3">
            <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
              <div class="flex items-start gap-3">
                <.icon name="hero-question-mark-circle" class="mt-0.5 h-5 w-5 shrink-0 text-sky-500" />
                <div>
                  <p class="text-sm font-semibold text-gray-900">Ask</p>
                  <p class="mt-1 text-xs text-gray-600">
                    Use when you want the AI to continue from the selected node with a new answer.
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
                    Use when you want your own claim, objection, example, or note inside the map.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <p class="inline-flex items-center rounded-full bg-amber-50 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-amber-700 ring-1 ring-amber-200">
            Grid tools
          </p>
          <h5 class="mt-4 text-lg font-semibold text-gray-900">Use tools when the branch is clear</h5>

          <div class="mt-4 space-y-3">
            <div class="flex items-start gap-3 rounded-xl border border-gray-200 bg-gray-50 p-4">
              <.icon name="hero-scale" class="mt-0.5 h-5 w-5 shrink-0 text-emerald-500" />
              <div>
                <p class="text-sm font-semibold text-gray-900">Pro | Con</p>
                <p class="mt-1 text-xs text-gray-600">Test a claim from both sides.</p>
              </div>
            </div>

            <div class="flex items-start gap-3 rounded-xl border border-gray-200 bg-gray-50 p-4">
              <.icon name="hero-light-bulb" class="mt-0.5 h-5 w-5 shrink-0 text-amber-500" />
              <div>
                <p class="text-sm font-semibold text-gray-900">Related</p>
                <p class="mt-1 text-xs text-gray-600">
                  Find nearby ideas, counterpoints, or adjacent angles.
                </p>
              </div>
            </div>

            <div class="flex items-start gap-3 rounded-xl border border-gray-200 bg-gray-50 p-4">
              <.icon name="hero-sparkles" class="mt-0.5 h-5 w-5 shrink-0 text-rose-500" />
              <div>
                <p class="text-sm font-semibold text-gray-900">Expand</p>
                <p class="mt-1 text-xs text-gray-600">Split one dense node into several branches.</p>
              </div>
            </div>

            <div class="flex items-start gap-3 rounded-xl border border-gray-200 bg-gray-50 p-4">
              <.icon name="hero-arrows-pointing-in" class="mt-0.5 h-5 w-5 shrink-0 text-violet-500" />
              <div>
                <p class="text-sm font-semibold text-gray-900">Blend</p>
                <p class="mt-1 text-xs text-gray-600">Synthesize two nodes into one shared view.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="grid gap-4 sm:grid-cols-3">
        <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
          <div class="flex items-start gap-3">
            <.icon name="hero-magnifying-glass" class="mt-0.5 h-5 w-5 shrink-0 text-gray-500" />
            <div>
              <p class="text-sm font-semibold text-gray-900">Select text for precision</p>
              <p class="mt-1 text-xs text-gray-600">
                Highlight a phrase when you want a narrower follow-up or a saved highlight.
              </p>
            </div>
          </div>
        </div>

        <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
          <div class="flex items-start gap-3">
            <.icon name="hero-bookmark" class="mt-0.5 h-5 w-5 shrink-0 text-amber-500" />
            <div>
              <p class="text-sm font-semibold text-gray-900">Keep your place</p>
              <p class="mt-1 text-xs text-gray-600">
                Use highlights and notes to keep the grid useful when you come back later.
              </p>
            </div>
          </div>
        </div>

        <a
          href="/intro/how"
          class="rounded-xl border border-emerald-200 bg-emerald-50 p-4 transition hover:bg-emerald-100"
        >
          <div class="flex items-start gap-3">
            <.icon name="hero-book-open" class="mt-0.5 h-5 w-5 shrink-0 text-emerald-600" />
            <div>
              <p class="text-sm font-semibold text-gray-900">Open the full guide</p>
              <p class="mt-1 text-xs text-gray-600">
                See screenshots, example prompts, and a fuller breakdown of every control.
              </p>
            </div>
          </div>
        </a>
      </section>

      <div class="rounded-xl border border-gray-200 bg-gray-50 px-4 py-3">
        <p class="text-xs text-gray-600">
          Navigation: drag to pan, scroll to zoom, click any node to focus it.
        </p>
      </div>
    </div>
    """
  end
end
