defmodule DialecticWeb.SelectionActionsComp do
  @moduledoc """
  LiveComponent for handling text selection actions.

  Provides a modal interface for creating highlights, explanations,
  questions, pros/cons, and related ideas from selected text.
  """
  use DialecticWeb, :live_component
  alias Dialectic.Highlights
  alias DialecticWeb.ColUtils

  @critical_tool_actions %{
    "clarify" => :clarify,
    "assumptions" => :assumptions,
    "counterexample" => :counterexample,
    "implications" => :implications,
    "blind_spots" => :blind_spots,
    "says_who" => :says_who,
    "who_disagrees" => :who_disagrees,
    "steel_man" => :steel_man,
    "what_if" => :what_if
  }

  @selection_actions Map.merge(@critical_tool_actions, %{
                       "explain" => :explain,
                       "highlight_only" => :highlight_only,
                       "pros_cons" => :pros_cons,
                       "related_ideas" => :related_ideas,
                       "ask_question" => :ask_question,
                       "comment" => :comment
                     })

  @critical_tool_sections [
    %{
      title: "Understand",
      tools: [
        %{
          key: "clarify",
          icon: "hero-light-bulb",
          label: "Clarify Terms",
          blurb: "What do we mean?",
          title:
            "Clarify Terms: Identify key terms, hidden ambiguity, conceptual boundaries, and what would count as evidence."
        },
        %{
          key: "assumptions",
          icon: "hero-cube-transparent",
          label: "Assumptions",
          blurb: "What has to be true?",
          title: "Assumptions: Reveal what must be true for this claim to work."
        },
        %{
          key: "says_who",
          icon: "hero-user",
          label: "Source Check",
          blurb: "Says who?",
          title: "Source Check: Question the authority and evidence behind claims."
        },
        %{
          key: "steel_man",
          icon: "hero-star",
          label: "Steel Man",
          blurb: "Strongest argument",
          title: "Steel Man: Build the strongest, most charitable version of this argument."
        }
      ]
    },
    %{
      title: "Challenge",
      tools: [
        %{
          key: "counterexample",
          icon: "hero-x-mark",
          label: "Test",
          blurb: "Is that always true?",
          title: "Test: Find counterexamples that challenge this claim."
        },
        %{
          key: "who_disagrees",
          icon: "hero-users",
          label: "Other Perspectives",
          blurb: "Who disagrees?",
          title: "Who Disagrees: Explore opposing viewpoints."
        }
      ]
    },
    %{
      title: "Expand",
      tools: [
        %{
          key: "implications",
          icon: "hero-arrow-trending-up",
          label: "Implications",
          blurb: "If true, then what?",
          title: "Implications: Trace what follows if this selection is true."
        },
        %{
          key: "blind_spots",
          icon: "hero-eye-slash",
          label: "Blind Spots",
          blurb: "What are we missing?",
          title: "Blind Spots: Identify perspectives or constraints being overlooked."
        },
        %{
          key: "what_if",
          icon: "hero-question-mark-circle",
          label: "What If",
          blurb: "Hypothetical scenarios",
          title: "What If: Explore alternative possibilities around this text."
        }
      ]
    }
  ]

  @impl true
  def mount(socket), do: {:ok, socket}

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_new(:highlight_only, fn -> false end)}
  end

  @impl true
  def handle_event(
        "action",
        %{
          "action" => action_key,
          "selectedText" => selected_text,
          "nodeId" => node_id,
          "offsets" => %{"start" => start_offset, "end" => end_offset} = offsets
        } = params,
        socket
      )
      when is_binary(selected_text) and selected_text != "" and is_binary(node_id) and
             is_integer(start_offset) and is_integer(end_offset) and start_offset < end_offset do
    with {:ok, action} <- Map.fetch(@selection_actions, action_key),
         {:ok, extra_params} <- action_input(action, params) do
      highlight =
        Highlights.get_highlight_for_selection(
          socket.assigns.graph_id,
          node_id,
          start_offset,
          end_offset
        )

      selection_params = %{
        action: action,
        selected_text: selected_text,
        node_id: node_id,
        offsets: offsets,
        highlight: highlight
      }

      send(self(), {:selection_action, Map.merge(selection_params, extra_params)})
    end

    {:noreply, socket}
  end

  def handle_event("action", _params, socket), do: {:noreply, socket}

  defp action_input(:ask_question, %{"input" => input}) when is_binary(input),
    do: {:ok, %{question: input}}

  defp action_input(:comment, %{"input" => input}) when is_binary(input),
    do: {:ok, %{comment: input}}

  defp action_input(action, _params) when action in [:ask_question, :comment], do: :error
  defp action_input(_action, _params), do: {:ok, %{}}

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, critical_tool_sections: @critical_tool_sections)

    ~H"""
    <div id={@id}>
      <div id={"selection-actions-modal-#{@id}"} class="hidden" phx-update="ignore" aria-hidden="true">
        <div
          data-selection-close
          class="fixed inset-0 z-[999] bg-slate-950/45 backdrop-blur-sm transition-opacity duration-200"
        >
        </div>
        <div class="fixed left-1/2 top-1/2 z-[1000] flex max-h-[88vh] w-[92vw] max-w-[620px] -translate-x-1/2 -translate-y-1/2 flex-col overflow-hidden rounded-[28px] border border-slate-200 bg-white shadow-[0_32px_80px_rgba(15,23,42,0.22)] ring-1 ring-slate-200/80 transition-all duration-200 opacity-100 scale-100">
          <div class="relative overflow-y-auto px-4 pb-4 pt-4 sm:px-5 sm:pb-5 sm:pt-4">
            <div class="mb-3 flex items-start justify-between gap-4">
              <span class="inline-flex items-center rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-slate-600">
                Selection actions
              </span>
              <button
                type="button"
                data-selection-close
                class="inline-flex h-9 w-9 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-400 shadow-sm transition-colors hover:bg-slate-50 hover:text-slate-700"
                aria-label="Close selection actions"
              >
                <.icon name="hero-x-mark" class="h-[18px] w-[18px]" />
              </button>
            </div>

            <div class="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 shadow-sm">
              <div class="mb-1.5 text-[10px] font-semibold uppercase tracking-[0.16em] text-slate-600">
                Selected text
              </div>
              <div
                data-selection-text
                class="max-h-24 overflow-y-auto text-[0.95rem] font-medium leading-6 text-slate-900"
              >
              </div>
            </div>

            <div class={[
              "mt-3 grid gap-2.5",
              if(@highlight_only, do: "grid-cols-1", else: "grid-cols-2")
            ]}>
              <%= if !@highlight_only do %>
                <button
                  type="button"
                  data-selection-action="explain"
                  data-disable-if-links="explain"
                  data-base-disabled={to_string(!@can_edit)}
                  disabled={!@can_edit}
                  title="Create an AI explanation"
                  class="group flex min-h-[96px] flex-col items-start justify-between rounded-2xl border-2 border-slate-200 bg-white px-3.5 py-3 text-left shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-sky-300 hover:shadow-[0_12px_24px_rgba(15,23,42,0.08)] active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-sky-100 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <span class="w-full space-y-1">
                    <span class="flex items-center gap-2 text-[1.05rem] font-semibold leading-5 text-slate-900">
                      <span class="inline-flex h-9 w-9 items-center justify-center rounded-xl bg-sky-500 text-white shadow-sm ring-4 ring-white/70">
                        <.icon name="hero-question-mark-circle" class="h-4.5 w-4.5" />
                      </span>
                      <span>Explain</span>
                    </span>
                    <span class="block whitespace-nowrap text-[12px] leading-4 text-slate-600">
                      Ask AI to unpack this phrase.
                    </span>
                  </span>
                  <span class="mt-auto flex w-full items-center justify-between border-t border-slate-200 pt-1.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-sky-700">
                    <span>Use this</span>
                    <.icon
                      name="hero-arrow-right"
                      class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
                    />
                  </span>
                </button>
              <% end %>

              <button
                type="button"
                data-selection-action="highlight_only"
                data-disable-if-highlight="true"
                data-base-disabled={to_string(!@can_edit)}
                disabled={!@can_edit}
                title="Save this text selection as a highlight"
                class="group flex min-h-[96px] flex-col items-start justify-between rounded-2xl border-2 border-slate-200 bg-white px-3.5 py-3 text-left shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-amber-300 hover:shadow-[0_12px_24px_rgba(15,23,42,0.08)] active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-amber-100 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <span class="w-full space-y-1">
                  <span class="flex items-center gap-2 text-[1.05rem] font-semibold leading-5 text-slate-900">
                    <span class="inline-flex h-9 w-9 items-center justify-center rounded-xl bg-amber-400 text-amber-950 shadow-sm ring-4 ring-white/70">
                      <.icon name="hero-bookmark" class="h-4.5 w-4.5" />
                    </span>
                    <span>Highlight</span>
                  </span>
                  <span class="block whitespace-nowrap text-[12px] leading-4 text-slate-600">
                    Save this passage to return to later.
                  </span>
                </span>
                <span class="mt-auto flex w-full items-center justify-between border-t border-slate-200 pt-1.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-amber-700">
                  <span>Use this</span>
                  <.icon
                    name="hero-arrow-right"
                    class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
                  />
                </span>
              </button>

              <%= if !@highlight_only do %>
                <button
                  type="button"
                  data-selection-action="pros_cons"
                  data-disable-if-links="pro,con"
                  data-base-disabled={to_string(!@can_edit)}
                  disabled={!@can_edit}
                  title="Analyze pros and cons"
                  class="group flex min-h-[96px] flex-col items-start justify-between rounded-2xl border-2 border-slate-200 bg-white px-3.5 py-3 text-left shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-emerald-300 hover:shadow-[0_12px_24px_rgba(15,23,42,0.08)] active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-emerald-100 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <span class="w-full space-y-1">
                    <span class="flex items-center gap-2 text-[1.05rem] font-semibold leading-5 text-slate-900">
                      <span class="inline-flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-500 text-white shadow-sm ring-4 ring-white/70">
                        <.icon name="hero-scale" class="h-4.5 w-4.5" />
                      </span>
                      <span>Pros & Cons</span>
                    </span>
                    <span class="block whitespace-nowrap text-[12px] leading-4 text-slate-600">
                      Test the strongest case for and against it.
                    </span>
                  </span>
                  <span class="mt-auto flex w-full items-center justify-between border-t border-slate-200 pt-1.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-emerald-700">
                    <span>Use this</span>
                    <.icon
                      name="hero-arrow-right"
                      class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
                    />
                  </span>
                </button>

                <button
                  type="button"
                  data-selection-action="related_ideas"
                  data-disable-if-links="related_idea"
                  data-base-disabled={to_string(!@can_edit)}
                  disabled={!@can_edit}
                  title="Find related ideas"
                  class="group flex min-h-[96px] flex-col items-start justify-between rounded-2xl border-2 border-slate-200 bg-white px-3.5 py-3 text-left shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-orange-300 hover:shadow-[0_12px_24px_rgba(15,23,42,0.08)] active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-orange-100 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <span class="w-full space-y-1">
                    <span class="flex items-center gap-2 text-[1.05rem] font-semibold leading-5 text-slate-900">
                      <span class="inline-flex h-9 w-9 items-center justify-center rounded-xl bg-orange-500 text-white shadow-sm ring-4 ring-white/70">
                        <.icon name="hero-light-bulb" class="h-4.5 w-4.5" />
                      </span>
                      <span>Related Ideas</span>
                    </span>
                    <span class="block whitespace-nowrap text-[12px] leading-4 text-slate-600">
                      Pull in adjacent comparisons and next angles.
                    </span>
                  </span>
                  <span class="mt-auto flex w-full items-center justify-between border-t border-slate-200 pt-1.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-orange-700">
                    <span>Use this</span>
                    <.icon
                      name="hero-arrow-right"
                      class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
                    />
                  </span>
                </button>
              <% end %>
            </div>

            <%= if !@highlight_only do %>
              <div class="mt-3 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
                <button
                  type="button"
                  id={"selection-advanced-tools-toggle-#{@id}"}
                  data-selection-advanced-toggle
                  aria-expanded="false"
                  class="flex w-full items-center justify-between gap-3 px-4 py-3 text-left transition hover:bg-slate-50"
                >
                  <span>
                    <span class="block text-sm font-semibold text-slate-900">
                      Critical thinking tools
                    </span>
                    <span class="block text-[11px] leading-4 text-slate-500">
                      A toolkit for better understanding ideas, stress-testing them, and exploring where they lead.
                    </span>
                  </span>
                  <.icon name="hero-chevron-down" class="h-4 w-4 text-slate-500 transition-transform" />
                </button>

                <div
                  data-selection-advanced-tools
                  class="hidden space-y-4 border-t border-slate-200 bg-slate-50/70 px-3 py-3"
                >
                  <div :for={section <- @critical_tool_sections} class="space-y-2">
                    <div class="text-[10px] font-semibold uppercase tracking-[0.16em] text-slate-500">
                      {section.title}
                    </div>
                    <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
                      <button
                        :for={tool <- section.tools}
                        type="button"
                        id={"selection-tool-#{@id}-#{tool.key}"}
                        data-selection-action={tool.key}
                        data-disable-if-links={tool.key}
                        data-base-disabled={to_string(!@can_edit)}
                        disabled={!@can_edit}
                        title={tool.title}
                        class={[
                          "group flex min-h-[86px] flex-col items-start justify-between rounded-2xl px-3 py-2.5 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-sm disabled:cursor-not-allowed disabled:opacity-50",
                          ColUtils.advanced_tool_surface_class(tool.key)
                        ]}
                      >
                        <span class="space-y-1">
                          <span class={[
                            "inline-flex h-8 w-8 items-center justify-center rounded-xl ring-1 ring-white/70",
                            ColUtils.advanced_tool_icon_class(tool.key)
                          ]}>
                            <.icon name={tool.icon} class="h-4 w-4" />
                          </span>
                          <span class="block text-sm font-semibold leading-4 text-slate-900">
                            {tool.label}
                          </span>
                          <span class="block text-[11px] leading-4 text-slate-500">
                            {tool.blurb}
                          </span>
                        </span>
                        <span class={[
                          "mt-2 text-[10px] font-semibold uppercase tracking-[0.12em]",
                          ColUtils.advanced_tool_text_class(tool.key)
                        ]}>
                          Use this
                        </span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <div class="mt-3 rounded-2xl border border-slate-200 bg-slate-50/85 p-3 shadow-sm">
                <form
                  id={"selection-input-form-#{@id}"}
                  data-selection-input-form
                  class="flex flex-col gap-2.5"
                >
                  <div class="flex items-center justify-between gap-3">
                    <div>
                      <label
                        for={"selection-question-input-#{@id}"}
                        data-selection-input-label
                        class="text-sm font-semibold text-slate-800"
                      >
                        Ask a custom question
                      </label>
                      <p
                        data-selection-input-description
                        class="mt-0.5 text-[11px] leading-4 text-slate-500"
                      >
                        Use the selected text as the context for a more specific answer.
                      </p>
                    </div>

                    <div class="inline-flex rounded-full border border-slate-200 bg-white p-1 shadow-sm">
                      <button
                        type="button"
                        data-selection-mode="ask_question"
                        class="rounded-full bg-indigo-500 px-3 py-1 text-xs font-semibold text-white shadow-sm transition-all"
                        title="Get an AI-generated response"
                      >
                        Ask
                      </button>
                      <button
                        type="button"
                        data-selection-mode="comment"
                        class="rounded-full px-3 py-1 text-xs font-semibold text-slate-600 transition-all hover:text-slate-900"
                        title="Add your own thought directly"
                      >
                        Comment
                      </button>
                    </div>
                  </div>

                  <div class="flex items-start gap-2">
                    <textarea
                      name="question"
                      data-selection-input
                      rows="1"
                      phx-hook="AutoExpandTextarea"
                      id={"selection-question-input-#{@id}"}
                      class="min-h-[2.5rem] max-h-[7rem] flex-1 resize-none rounded-2xl border border-slate-300 bg-white px-3.5 py-2.5 text-sm text-slate-800 shadow-sm outline-none transition focus:border-indigo-400 focus:ring-4 focus:ring-indigo-100"
                      placeholder="What do you want to know about this exact wording?"
                      autocomplete="off"
                      disabled={!@can_edit}
                    ></textarea>
                    <button
                      type="submit"
                      data-selection-input-submit
                      disabled={!@can_edit}
                      class="self-start whitespace-nowrap rounded-2xl bg-gradient-to-r from-indigo-500 to-sky-500 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-[0_12px_24px_rgba(79,70,229,0.24)] disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      Ask
                    </button>
                  </div>

                  <div class="flex items-center justify-between gap-3 text-[11px] text-slate-500">
                    <span>Press Enter to submit • Escape to close</span>
                    <div class="flex flex-wrap justify-end gap-2">
                      <span
                        data-selection-question-count
                        class="hidden rounded-full bg-indigo-50 px-2.5 py-1 font-medium text-indigo-700 ring-1 ring-indigo-200"
                      >
                      </span>
                      <span
                        data-selection-comment-count
                        class="hidden rounded-full bg-emerald-50 px-2.5 py-1 font-medium text-emerald-700 ring-1 ring-emerald-200"
                      >
                      </span>
                    </div>
                  </div>
                </form>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
