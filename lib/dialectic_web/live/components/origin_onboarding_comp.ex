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
      <div class="space-y-1.5">
        <p class="text-sm font-semibold leading-5 text-slate-950">
          This grid starts with your question.
        </p>
        <p class="text-sm leading-5 text-slate-600">
          Each box is a question, an AI answer, or a comment. Open one, then follow the
          branch that interests you. Share the grid to think together live.
        </p>
      </div>

      <section class="divide-y divide-slate-100">
        <.guide_item
          icon="hero-arrow-uturn-right"
          icon_classes="bg-sky-50 text-sky-600 ring-sky-100"
          title="Open the first response"
          text="Click the connected box in the map to read the first answer."
        />

        <.guide_item
          icon="hero-question-mark-circle"
          icon_classes="bg-emerald-50 text-emerald-600 ring-emerald-100"
          title="Ask from any idea"
          text="Use a suggested follow-up, select a phrase, or type your own question."
        />

        <.guide_item
          icon="hero-scale"
          icon_classes="bg-violet-50 text-violet-600 ring-violet-100"
          title="Compare and connect"
          text="Try Pro / Con, Related, or Blend when you want the map to branch."
        />

        <.guide_item
          icon="hero-user-group"
          icon_classes="bg-amber-50 text-amber-600 ring-amber-100"
          title="Think together live"
          text="Share the grid for real-time, multiplayer thinking around the same topic."
        />
      </section>

      <div class="flex flex-wrap items-center gap-3 border-t border-slate-100 pt-3">
        <.link
          href={~p"/intro/how"}
          class="inline-flex items-center gap-2 rounded-full bg-emerald-50 px-3 py-1.5 text-sm font-semibold text-emerald-700 ring-1 ring-emerald-100 transition hover:bg-emerald-100 hover:text-emerald-800"
        >
          <.icon name="hero-book-open" class="h-4 w-4" />
          <span>Open the full guide</span>
        </.link>

        <p class="text-xs leading-5 text-slate-500">
          A good first session is simple: read one node, ask one better question.
        </p>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :marker, :string, default: "icon"
  attr :icon_classes, :string, required: true
  attr :title, :string, required: true
  attr :text, :string, required: true

  defp guide_item(assigns) do
    ~H"""
    <div class="py-2.5 first:pt-0 last:pb-0">
      <div class="flex items-center gap-3">
        <%= if @marker == "node" do %>
          <div
            class="inline-flex h-8 w-10 shrink-0 items-center justify-center rounded-xl border border-slate-300 bg-[#fffdf8] shadow-[0_2px_0_rgba(15,23,42,0.13),0_8px_18px_rgba(15,23,42,0.08)] ring-1 ring-white"
            aria-hidden="true"
          >
            <span class="flex w-5 flex-col gap-1">
              <span class="h-1 rounded-full bg-slate-700/75"></span>
              <span class="h-1 rounded-full bg-slate-400/80"></span>
            </span>
          </div>
        <% else %>
          <div class={[
            "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full ring-1",
            @icon_classes
          ]}>
            <.icon name={@icon} class="h-4 w-4" />
          </div>
        <% end %>

        <div class="min-w-0">
          <p class="text-sm font-semibold leading-5 text-slate-900">{@title}</p>
          <p class="text-sm leading-5 text-slate-600">{@text}</p>
        </div>
      </div>
    </div>
    """
  end
end
