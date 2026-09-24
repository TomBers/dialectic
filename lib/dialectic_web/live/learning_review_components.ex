defmodule DialecticWeb.LearningReviewComponents do
  use DialecticWeb, :html

  alias Dialectic.LearningReview

  attr :review, :map, required: true
  attr :reason_form, :any, required: true
  attr :answer_form, :any, required: true

  def learning_review(assigns) do
    assigns =
      assigns
      |> assign(:card, LearningReview.current(assigns.review))
      |> assign(:total, LearningReview.count(assigns.review))

    ~H"""
    <section
      id="learning-review"
      aria-labelledby="learning-review-title"
      class="mt-8 scroll-mt-16 rounded-2xl border border-teal-200 bg-teal-50 p-5 sm:p-7"
    >
      <div class="flex items-start gap-3">
        <span class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white text-teal-800"><.icon
          name="hero-arrow-path"
          class="h-5 w-5"
        /></span>
        <div>
          <p class="text-xs font-semibold uppercase tracking-wide text-teal-800">
            Between lessons · Pilot
          </p>
          <h2 id="learning-review-title" class="mt-1 text-2xl font-semibold text-slate-950">
            Pick up the thread.
          </h2>
          <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
            Revisit an idea you saved. Explain it in your own words, compare it with the source, then decide what to explore next.
          </p>
        </div>
      </div>

      <%= cond do %>
        <% @total == 0 -> %>
          <div id="learning-review-empty" class="mt-5 rounded-xl border border-teal-100 bg-white p-5">
            <p class="text-sm leading-6 text-slate-700">
              Save an idea you want to understand better: bookmark a node or highlight a passage in a grid. Return here before your next lesson to practise explaining it.
            </p>
            <a
              id="learning-review-explore"
              href={~p"/community"}
              class="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-teal-800"
            >Find a grid to explore <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
          </div>
        <% @review.status == :ready -> %>
          <div class="mt-5 grid gap-5 lg:grid-cols-2">
            <div class="rounded-xl border border-teal-100 bg-white p-5">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                An idea you saved
              </p>
              <h3 class="mt-2 font-semibold text-slate-950">{@card.title}</h3>
              <p class="mt-1 text-sm text-slate-500">{@card.graph.title}</p>
              <a
                id="learning-review-continue"
                href={graph_path(@card.graph, @card.node_id)}
                data-analytics-event="learning_continued"
                data-analytics-location="profile_learning"
                class="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-teal-800"
              >Continue this idea <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
            </div>
            <.form
              for={@reason_form}
              id="learning-review-start-form"
              phx-submit="start_learning_review"
              class="rounded-xl border border-teal-100 bg-white p-5"
            >
              <.input
                field={@reason_form[:reason]}
                type="select"
                label="What brings you back today?"
                prompt="Choose a reason"
                options={[
                  {"Preparing for a lesson", "prepare_lesson"},
                  {"Revisiting something I’m unsure about", "revisit_gap"},
                  {"My tutor asked me to", "tutor_request"},
                  {"Practising for myself", "independent_practice"}
                ]}
                required
              />
              <button
                id="learning-review-start"
                type="submit"
                class="mt-4 rounded-lg bg-teal-800 px-4 py-3 text-sm font-semibold text-white hover:bg-teal-900"
              >Practise {@total} saved {if @total == 1, do: "idea", else: "ideas"}</button>
            </.form>
          </div>
        <% @review.status == :complete -> %>
          <div
            id="learning-review-complete"
            role="status"
            class="mt-5 rounded-xl border border-teal-100 bg-white p-5"
          >
            <h3 class="text-lg font-semibold text-slate-950">
              You’ve revisited {@total} {if @total == 1, do: "idea", else: "ideas"}.
            </h3>
            <p class="mt-2 text-sm leading-6 text-slate-700">
              Your self-check this visit: {@review.understood} felt clearer; {@review.revisit} needed more exploration. These are your reflections, not a test score.
            </p>
            <p class="mt-2 text-sm leading-6 text-slate-600">
              For your next lesson, bring one question you still have. As you explore, bookmark an idea or highlight a passage to return to next time.
            </p>
            <a
              id="learning-review-back-to-saved"
              href="#profile-thinking-library"
              class="mt-4 inline-flex text-sm font-semibold text-teal-800"
            >Return to your saved grids ↓</a>
          </div>
        <% true -> %>
          <div
            id="learning-review-practice"
            class="mt-5 rounded-xl border border-teal-100 bg-white p-5 sm:p-6"
          >
            <p class="text-xs font-semibold uppercase tracking-wide text-teal-800">
              Idea {@review.index + 1} of {@total}
            </p>
            <h3 class="mt-2 text-xl font-semibold text-slate-950">{@card.title}</h3>
            <p class="mt-1 text-sm text-slate-500">From {@card.graph.title}</p>
            <.form
              for={@answer_form}
              id="learning-review-answer-form"
              phx-submit="reveal_learning_review"
              class="mt-5"
            >
              <.input
                field={@answer_form[:answer]}
                type="textarea"
                label="How would you explain this to someone else?"
                placeholder="Use your own words. Include what you’re still unsure about."
                rows="4"
                maxlength="2000"
                required
                readonly={@review.revealed?}
              />
              <button
                :if={!@review.revealed?}
                id="learning-review-reveal"
                type="submit"
                class="mt-4 rounded-lg bg-teal-800 px-4 py-3 text-sm font-semibold text-white hover:bg-teal-900"
              >Compare with what I saved</button>
            </.form>
            <p class="mt-2 text-xs leading-5 text-slate-500">
              Your practice answer isn’t saved. Review progress resets when you leave this page.
            </p>
            <%= if @review.revealed? do %>
              <div
                id="learning-review-source"
                class="mt-5 rounded-lg border border-slate-200 bg-slate-50 p-4"
              >
                <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Saved source · Check its claims, too
                </p>
                <p class="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-700">
                  {@card.passage}
                </p>
                <p :if={@card.truncated?} class="mt-2 text-xs text-slate-500">
                  Showing an excerpt. Open the grid for the full passage.
                </p>
              </div>
              <a
                id="learning-review-source-link"
                href={graph_path(@card.graph, @card.node_id)}
                target="_blank"
                rel="noopener"
                data-analytics-event="learning_source_reopened"
                data-analytics-location="profile_learning"
                class="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-teal-800"
              >Explore this idea in its grid (new tab)
              <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
              <%= if @review.status == :practising do %>
                <fieldset id="learning-review-rating" class="mt-5">
                  <legend class="text-sm font-semibold text-slate-900">
                    After comparing, how does it feel?
                  </legend>
                  <div class="mt-3 flex flex-wrap gap-3">
                    <button
                      id="learning-review-understood"
                      type="button"
                      phx-click="rate_learning_review"
                      phx-value-rating="understood"
                      class="rounded-lg border border-teal-700 px-4 py-3 text-sm font-semibold text-teal-900 hover:bg-teal-50"
                    >I can explain it</button>
                    <button
                      id="learning-review-revisit"
                      type="button"
                      phx-click="rate_learning_review"
                      phx-value-rating="revisit"
                      class="rounded-lg border border-slate-300 px-4 py-3 text-sm font-semibold text-slate-700 hover:bg-slate-50"
                    >I need to explore more</button>
                  </div>
                </fieldset>
              <% else %>
                <p
                  id="learning-review-next-step"
                  role="status"
                  class="mt-5 text-sm leading-6 text-slate-700"
                >
                  If something is unclear, reopen the grid and challenge the explanation or ask a follow-up question. You can also bring it to your tutor.
                </p>
                <button
                  id="learning-review-next"
                  type="button"
                  phx-click="next_learning_review"
                  class="mt-4 rounded-lg bg-teal-800 px-4 py-3 text-sm font-semibold text-white hover:bg-teal-900"
                >{if @review.index + 1 < @total, do: "Next idea", else: "Finish this review"}</button>
              <% end %>
            <% end %>
          </div>
      <% end %>
    </section>
    """
  end
end
