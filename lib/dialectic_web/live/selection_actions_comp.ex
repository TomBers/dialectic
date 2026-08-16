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
    <div id={@id} data-can-edit={to_string(@can_edit)}>
      <div id={"selection-actions-modal-#{@id}"} class="hidden" phx-update="ignore" aria-hidden="true">
        <div
          data-selection-close
          class="fixed inset-0 z-[999] bg-slate-950/40 backdrop-blur-sm transition-opacity duration-200"
        >
        </div>
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby={"selection-actions-title-#{@id}"}
          class="fixed left-1/2 top-1/2 z-[1000] flex max-h-[88vh] w-[92vw] max-w-[620px] -translate-x-1/2 -translate-y-1/2 flex-col overflow-hidden rounded-[1.35rem] border border-slate-200 bg-white shadow-[0_28px_72px_rgba(15,23,42,0.2)] ring-1 ring-slate-950/5 transition-all duration-200 opacity-100 scale-100"
        >
          <div class="relative overflow-y-auto px-4 pb-5 pt-4 sm:px-5 sm:pb-5 sm:pt-5">
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0">
                <p class="text-[10px] font-semibold uppercase tracking-[0.16em] text-teal-700">
                  Selection tools
                </p>
                <h2
                  id={"selection-actions-title-#{@id}"}
                  class="mt-1 font-serif text-2xl font-semibold leading-tight tracking-tight text-slate-950"
                >
                  {if(@highlight_only, do: "Save this passage", else: "Take this passage further")}
                </h2>
                <p class="mt-1 text-sm leading-5 text-slate-600">
                  <%= if @highlight_only do %>
                    Keep this exact passage so you can return to it later.
                  <% else %>
                    Choose what you want to understand, test, or remember.
                  <% end %>
                </p>
              </div>

              <button
                id={"selection-actions-close-#{@id}"}
                type="button"
                data-selection-close
                class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-400 transition-colors hover:bg-slate-50 hover:text-slate-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-300"
                aria-label="Close selection actions"
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>

            <div class="mt-3 rounded-xl border border-slate-200/80 bg-slate-50/70 px-3 py-2.5 shadow-[inset_3px_0_0_rgba(20,184,166,0.35)]">
              <p class="mb-0.5 text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-500">
                Selected passage
              </p>
              <div
                data-selection-text
                class="max-h-20 overflow-y-auto font-serif text-[0.98rem] leading-5 text-slate-800"
              >
              </div>
            </div>

            <div class={[
              "mt-3 grid gap-2 rounded-xl border border-slate-200 bg-slate-100/80 p-2 shadow-inner",
              if(@highlight_only, do: "grid-cols-1", else: "grid-cols-1 sm:grid-cols-2")
            ]}>
              <%= if !@highlight_only do %>
                <button
                  id={"selection-action-explain-#{@id}"}
                  type="button"
                  data-selection-action="explain"
                  data-disable-if-links="explain"
                  disabled={!@can_edit}
                  title="Create an AI explanation"
                  class="group grid w-full min-w-0 cursor-pointer grid-cols-[2.25rem_minmax(0,1fr)_auto] items-start gap-3 rounded-lg border border-slate-200 bg-white px-3 py-3 text-left shadow-sm transition hover:-translate-y-px hover:border-sky-300 hover:bg-sky-50/50 hover:shadow-md active:translate-y-0 active:shadow-sm focus-visible:z-10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-300 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <span class="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-sky-100 text-sky-800 shadow-sm ring-1 ring-inset ring-sky-300/80">
                    <.icon name="hero-question-mark-circle" class="h-[18px] w-[18px]" />
                  </span>
                  <span class="min-w-0">
                    <span class="block text-sm font-semibold leading-5 text-slate-900">
                      Explain this passage
                    </span>
                    <span class="block text-xs leading-4 text-slate-500">
                      Unpack its meaning and context.
                    </span>
                  </span>
                  <.icon
                    name="hero-arrow-right"
                    class="mt-1 h-3.5 w-3.5 text-slate-400 transition group-hover:translate-x-0.5 group-hover:text-sky-700"
                  />
                </button>
              <% end %>

              <button
                id={"selection-action-highlight-#{@id}"}
                type="button"
                data-selection-action="highlight_only"
                data-disable-if-highlight="true"
                disabled={!@can_edit}
                title="Save this text selection as a highlight"
                class="group grid w-full min-w-0 cursor-pointer grid-cols-[2.25rem_minmax(0,1fr)_auto] items-start gap-3 rounded-lg border border-slate-200 bg-white px-3 py-3 text-left shadow-sm transition hover:-translate-y-px hover:border-amber-300 hover:bg-amber-50/50 hover:shadow-md active:translate-y-0 active:shadow-sm focus-visible:z-10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-300 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <span class="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-amber-100 text-amber-800 shadow-sm ring-1 ring-inset ring-amber-300/80">
                  <.icon name="hero-bookmark" class="h-[18px] w-[18px]" />
                </span>
                <span class="min-w-0">
                  <span class="block text-sm font-semibold leading-5 text-slate-900">
                    Save as a highlight
                  </span>
                  <span class="block text-xs leading-4 text-slate-500">
                    Keep this passage for later.
                  </span>
                </span>
                <.icon
                  name="hero-arrow-right"
                  class="mt-1 h-3.5 w-3.5 text-slate-400 transition group-hover:translate-x-0.5 group-hover:text-amber-700"
                />
              </button>

              <%= if !@highlight_only do %>
                <button
                  id={"selection-action-pros-cons-#{@id}"}
                  type="button"
                  data-selection-action="pros_cons"
                  data-disable-if-links="pro,con"
                  disabled={!@can_edit}
                  title="Analyze pros and cons"
                  class="group grid w-full min-w-0 cursor-pointer grid-cols-[2.25rem_minmax(0,1fr)_auto] items-start gap-3 rounded-lg border border-slate-200 bg-white px-3 py-3 text-left shadow-sm transition hover:-translate-y-px hover:border-emerald-300 hover:bg-emerald-50/50 hover:shadow-md active:translate-y-0 active:shadow-sm focus-visible:z-10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-300 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <span class="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-emerald-100 text-emerald-800 shadow-sm ring-1 ring-inset ring-emerald-300/80">
                    <.icon name="hero-scale" class="h-[18px] w-[18px]" />
                  </span>
                  <span class="min-w-0">
                    <span class="block text-sm font-semibold leading-5 text-slate-900">
                      Test both sides
                    </span>
                    <span class="block text-xs leading-4 text-slate-500">
                      Build the case for and against.
                    </span>
                  </span>
                  <.icon
                    name="hero-arrow-right"
                    class="mt-1 h-3.5 w-3.5 text-slate-400 transition group-hover:translate-x-0.5 group-hover:text-emerald-700"
                  />
                </button>

                <button
                  id={"selection-action-related-#{@id}"}
                  type="button"
                  data-selection-action="related_ideas"
                  data-disable-if-links="related_idea"
                  disabled={!@can_edit}
                  title="Find related ideas"
                  class="group grid w-full min-w-0 cursor-pointer grid-cols-[2.25rem_minmax(0,1fr)_auto] items-start gap-3 rounded-lg border border-slate-200 bg-white px-3 py-3 text-left shadow-sm transition hover:-translate-y-px hover:border-orange-300 hover:bg-orange-50/50 hover:shadow-md active:translate-y-0 active:shadow-sm focus-visible:z-10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <span class="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-orange-100 text-orange-800 shadow-sm ring-1 ring-inset ring-orange-300/80">
                    <.icon name="hero-light-bulb" class="h-[18px] w-[18px]" />
                  </span>
                  <span class="min-w-0">
                    <span class="block text-sm font-semibold leading-5 text-slate-900">
                      Find related ideas
                    </span>
                    <span class="block text-xs leading-4 text-slate-500">
                      Find useful connections and comparisons.
                    </span>
                  </span>
                  <.icon
                    name="hero-arrow-right"
                    class="mt-1 h-3.5 w-3.5 text-slate-400 transition group-hover:translate-x-0.5 group-hover:text-orange-700"
                  />
                </button>
              <% end %>
            </div>

            <%= if !@highlight_only do %>
              <div class="mt-2">
                <button
                  type="button"
                  id={"selection-advanced-tools-toggle-#{@id}"}
                  data-selection-advanced-toggle
                  aria-expanded="false"
                  class="flex w-full items-center justify-between gap-3 rounded-xl px-2 py-2 text-left transition hover:bg-slate-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-300"
                >
                  <span class="min-w-0">
                    <span class="block text-sm font-semibold text-slate-900">
                      More ways to examine this passage
                    </span>
                    <span class="block text-xs leading-4 text-slate-500">
                      Clarify it, challenge it, or follow its implications.
                    </span>
                  </span>
                  <.icon
                    name="hero-chevron-down"
                    class="h-4 w-4 shrink-0 text-slate-400 transition-transform"
                  />
                </button>

                <div
                  data-selection-advanced-tools
                  class="hidden mt-3 space-y-4 border-t border-slate-200/70 pt-4"
                >
                  <div :for={section <- @critical_tool_sections} class="space-y-1.5">
                    <div class="px-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
                      {section.title}
                    </div>
                    <div class="grid gap-2 sm:grid-cols-2">
                      <button
                        :for={tool <- section.tools}
                        type="button"
                        id={"selection-tool-#{@id}-#{tool.key}"}
                        data-selection-action={tool.key}
                        data-disable-if-links={tool.key}
                        disabled={!@can_edit}
                        title={tool.title}
                        class={[
                          "group flex min-w-0 cursor-pointer items-start gap-3 rounded-lg px-3 py-3 text-left shadow-sm transition hover:-translate-y-px hover:shadow-md active:translate-y-0 active:shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-300 disabled:cursor-not-allowed disabled:opacity-50",
                          ColUtils.advanced_tool_surface_class(tool.key)
                        ]}
                      >
                        <span class={[
                          "inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg shadow-sm ring-1 ring-inset ring-black/5",
                          ColUtils.advanced_tool_icon_class(tool.key)
                        ]}>
                          <.icon name={tool.icon} class="h-[18px] w-[18px]" />
                        </span>
                        <span class="min-w-0">
                          <span class="block text-sm font-semibold leading-5 text-slate-900">
                            {tool.label}
                          </span>
                          <span class="mt-0.5 block text-xs leading-4 text-slate-500">
                            {tool.blurb}
                          </span>
                        </span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <div class="mt-3 border-t border-slate-200/80 pt-3">
                <form
                  id={"selection-input-form-#{@id}"}
                  data-selection-input-form
                  class="flex flex-col gap-2"
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
                      <p data-selection-input-description class="text-[11px] leading-4 text-slate-500">
                        Use the selected passage as context.
                      </p>
                    </div>

                    <div class="inline-flex rounded-full border border-slate-200 bg-slate-50 p-1">
                      <button
                        id={"selection-mode-ask-#{@id}"}
                        type="button"
                        data-selection-mode="ask_question"
                        class="rounded-full bg-indigo-500 px-3 py-1 text-xs font-semibold text-white shadow-sm transition-all"
                        title="Get an AI-generated response"
                      >
                        Ask
                      </button>
                      <button
                        id={"selection-mode-comment-#{@id}"}
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
                      class="min-h-9 max-h-[7rem] flex-1 resize-none rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 outline-none transition focus:border-teal-400 focus:ring-4 focus:ring-teal-100"
                      placeholder="What do you want to know about this exact wording?"
                      autocomplete="off"
                      disabled={!@can_edit}
                    ></textarea>
                    <button
                      type="submit"
                      data-selection-input-submit
                      disabled={!@can_edit}
                      class="self-start whitespace-nowrap rounded-xl bg-slate-950 px-4 py-2 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      Ask
                    </button>
                  </div>

                  <div class="flex items-center justify-between gap-3 text-[10px] text-slate-500">
                    <span>Enter to submit · Escape to close</span>
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
