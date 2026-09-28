defmodule DialecticWeb.LearningPreview do
  use DialecticWeb, :html

  def preview(assigns) do
    ~H"""
    <section
      id="home-grid-preview"
      aria-label="Learn today and remember tomorrow"
      class="mx-auto w-full max-w-md"
    >
      <div class="overflow-hidden rounded-xl border border-white/20 bg-white text-slate-950 shadow-2xl">
        <div
          role="group"
          aria-label="Learn today and remember tomorrow"
          class="grid grid-cols-2 gap-1 border-b border-stone-200 bg-stone-100 p-2"
        >
          <button
            id="home-preview-today-button"
            type="button"
            aria-pressed="true"
            aria-controls="home-preview-today"
            phx-click={show_moment("today")}
            class="min-h-11 rounded-md px-3 py-2 text-sm font-semibold text-slate-600 hover:text-slate-950 aria-pressed:bg-white aria-pressed:text-teal-800 aria-pressed:shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-teal-700"
          >Learn today</button>
          <button
            id="home-preview-later-button"
            type="button"
            aria-pressed="false"
            aria-controls="home-preview-later"
            phx-click={show_moment("later")}
            class="min-h-11 rounded-md px-3 py-2 text-sm font-semibold text-slate-600 hover:text-slate-950 aria-pressed:bg-white aria-pressed:text-teal-800 aria-pressed:shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-teal-700"
          >Remember tomorrow</button>
        </div>

        <div id="home-preview-panels" class="grid">
          <div
            id="home-preview-today"
            role="group"
            aria-label="Learn today: questions and answers"
            aria-hidden="false"
            class="col-start-1 row-start-1 min-w-0 p-4 aria-hidden:invisible sm:p-5"
          >
            <div class="rounded-lg border border-sky-200 border-l-4 border-l-sky-500 bg-sky-50 px-4 py-3">
              <p class="text-xs font-semibold text-sky-800">Your question</p>
              <p class="mt-1 text-sm font-semibold">Does AI make us better thinkers?</p>
            </div>
            <div aria-hidden="true" class="mx-auto h-4 w-px bg-slate-300"></div>
            <.answer id="home-preview-first-answer" />
            <div aria-hidden="true" class="mx-auto h-4 w-px bg-slate-300"></div>
            <div id="home-preview-branches" class="relative -mx-1.5 grid grid-cols-2">
              <div aria-hidden="true" class="absolute inset-x-1/4 top-0 border-t border-slate-300">
              </div>
              <div
                id="home-preview-challenge-branch"
                role="group"
                aria-label="Challenge and answer"
                class="flex min-w-0 flex-col px-1.5"
              >
                <div aria-hidden="true" class="mx-auto h-4 w-px bg-slate-300"></div>
                <div class="flex-1 rounded-lg border border-amber-200 bg-amber-50 px-3 py-3">
                  <p class="text-xs font-semibold text-amber-800">Challenge</p>
                  <p class="mt-1 text-xs leading-5">Could AI make us less independent?</p>
                </div>
                <div aria-hidden="true" class="mx-auto h-4 w-px bg-slate-300"></div>
                <div class="rounded-lg border border-teal-200 bg-teal-50 px-3 py-3">
                  <p class="text-xs font-semibold text-teal-800">Answer</p>
                  <p class="mt-1 text-xs leading-5">
                    It could, if we accept answers without thinking.
                  </p>
                </div>
              </div>
              <div
                id="home-preview-followup-branch"
                role="group"
                aria-label="Follow-up question and answer"
                class="flex min-w-0 flex-col px-1.5"
              >
                <div aria-hidden="true" class="mx-auto h-4 w-px bg-slate-300"></div>
                <div class="flex-1 rounded-lg border border-violet-200 bg-violet-50 px-3 py-3">
                  <p class="text-xs font-semibold text-violet-800">Follow-up</p>
                  <p class="mt-1 text-xs leading-5">What if AI argued the other side?</p>
                </div>
                <div aria-hidden="true" class="mx-auto h-4 w-px bg-slate-300"></div>
                <div class="rounded-lg border border-teal-200 bg-teal-50 px-3 py-3">
                  <p class="text-xs font-semibold text-teal-800">Answer</p>
                  <p class="mt-1 text-xs leading-5">
                    Ask it to challenge your strongest belief. Which reasons survive?
                  </p>
                </div>
              </div>
            </div>
            <p class="mt-4 flex items-center gap-2 text-xs text-slate-500">
              <.icon name="hero-folder" class="h-4 w-4 shrink-0" /> Keep this grid in My Learning.
            </p>
          </div>

          <div
            id="home-preview-later"
            role="group"
            aria-label="Remember tomorrow: grids, bookmarks and highlights in My Learning"
            aria-hidden="true"
            class="col-start-1 row-start-1 min-w-0 bg-[#f4f1e9] p-4 aria-hidden:invisible sm:p-5"
            inert
          >
            <div class="border-b border-stone-300 pb-3">
              <h3 class="font-serif text-lg font-semibold">My Learning</h3>
              <p class="mt-1 text-xs text-slate-500">Grids, bookmarks and highlights</p>
            </div>
            <div
              id="home-preview-grid-list"
              class="mt-3 divide-y divide-stone-200 overflow-hidden rounded-md border border-stone-300 bg-white"
            >
              <article id="home-preview-ai-grid" class="p-3">
                <h4 class="font-serif text-base font-semibold leading-6">
                  Does AI make us better thinkers?
                </h4>
                <div class="mt-2 flex flex-wrap items-center gap-2 text-[11px]">
                  <span class="rounded bg-teal-50 px-2 py-0.5 font-medium text-teal-800">AI &amp; Learning</span>
                  <span class="text-slate-500">Shared grid</span>
                </div>
                <div class="mt-3 rounded-md border border-stone-200 bg-stone-50">
                  <p class="border-b border-stone-200 px-3 py-2 text-[11px] font-semibold text-slate-600">
                    Saved in this grid · 1 bookmark · 1 highlight
                  </p>
                  <div class="space-y-3 p-3">
                    <div
                      id="home-preview-bookmark"
                      class="flex items-start gap-2 text-xs font-semibold text-teal-800"
                    >
                      <.icon name="hero-bookmark" class="h-4 w-4 shrink-0" />
                      <p>What if AI argued the other side?</p>
                    </div>
                    <blockquote
                      id="home-preview-highlight"
                      class="border-l-2 border-amber-400 pl-3 text-xs leading-5 text-slate-700"
                    >
                      Better output and better thinking are different achievements.
                    </blockquote>
                  </div>
                </div>
              </article>
              <article id="home-preview-sources-grid" class="p-3">
                <h4 class="font-serif text-base font-semibold leading-6">
                  What makes a source trustworthy?
                </h4>
                <div class="mt-2 flex flex-wrap items-center gap-2 text-[11px]">
                  <span class="rounded bg-teal-50 px-2 py-0.5 font-medium text-teal-800">Critical Thinking</span>
                  <span class="text-slate-500">2 bookmarks · 1 highlight</span>
                </div>
              </article>
              <article id="home-preview-memory-grid" class="p-3">
                <h4 class="font-serif text-base font-semibold leading-6">
                  How do we remember what we learn?
                </h4>
                <div class="mt-2 flex flex-wrap items-center gap-2 text-[11px]">
                  <span class="rounded bg-teal-50 px-2 py-0.5 font-medium text-teal-800">Study Notes</span>
                  <span class="text-slate-500">1 bookmark · 2 highlights</span>
                </div>
              </article>
            </div>
            <p class="mt-3 flex items-center gap-1.5 text-xs text-slate-500">
              <.icon name="hero-bookmark" class="h-3.5 w-3.5 shrink-0" />
              Return to the point you saved.
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true

  defp answer(assigns) do
    ~H"""
    <div
      id={@id}
      class="rounded-lg border border-teal-200 border-l-4 border-l-teal-500 bg-teal-50 px-4 py-3"
    >
      <p class="flex items-center gap-1.5 text-xs font-semibold text-teal-800">
        Answer
      </p>
      <p class="mt-1 text-sm leading-6">
        Better output and better thinking are different achievements.
      </p>
    </div>
    """
  end

  defp show_moment(moment) do
    other = if moment == "today", do: "later", else: "today"

    JS.set_attribute({"aria-hidden", "true"}, to: "#home-preview-#{other}")
    |> JS.set_attribute({"inert", ""}, to: "#home-preview-#{other}")
    |> JS.set_attribute({"aria-hidden", "false"}, to: "#home-preview-#{moment}")
    |> JS.remove_attribute("inert", to: "#home-preview-#{moment}")
    |> JS.set_attribute({"aria-pressed", "true"}, to: "#home-preview-#{moment}-button")
    |> JS.set_attribute({"aria-pressed", "false"}, to: "#home-preview-#{other}-button")
  end
end
