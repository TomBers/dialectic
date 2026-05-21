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

  @advanced_tool_sections [
    %{
      title: "Core Analysis",
      tools: [
        %{
          key: "steel_man",
          icon: "hero-star",
          label: "Steel Man",
          blurb: "Strongest argument",
          title: "Steel Man: Build the strongest, most charitable version of this argument."
        },
        %{
          key: "assumptions",
          icon: "hero-cube-transparent",
          label: "Assumptions",
          blurb: "What has to be true?",
          title: "Assumptions: Reveal what must be true for this claim to work."
        },
        %{
          key: "counterexample",
          icon: "hero-x-mark",
          label: "Test",
          blurb: "Is that always true?",
          title: "Test: Find counterexamples that challenge this claim."
        }
      ]
    },
    %{
      title: "Critical Evaluation",
      tools: [
        %{
          key: "says_who",
          icon: "hero-user",
          label: "Source Check",
          blurb: "Says who?",
          title: "Source Check: Question the authority and evidence behind claims."
        },
        %{
          key: "blind_spots",
          icon: "hero-eye-slash",
          label: "Blind Spots",
          blurb: "What are we missing?",
          title: "Blind Spots: Identify perspectives or constraints being overlooked."
        },
        %{
          key: "who_disagrees",
          icon: "hero-users",
          label: "Who Disagrees",
          blurb: "Other perspectives?",
          title: "Who Disagrees: Explore opposing viewpoints."
        }
      ]
    },
    %{
      title: "Consequences & Counterfactuals",
      tools: [
        %{
          key: "implications",
          icon: "hero-arrow-trending-up",
          label: "Implications",
          blurb: "If true, then what?",
          title: "Implications: Trace what follows if this selection is true."
        },
        %{
          key: "what_if",
          icon: "hero-question-mark-circle",
          label: "What If",
          blurb: "Hypothetical scenarios",
          title: "What If: Explore alternative possibilities around this text."
        }
      ]
    },
    %{
      title: "Conceptual Precision",
      tools: [
        %{
          key: "clarify",
          icon: "hero-light-bulb",
          label: "Clarify Terms",
          blurb: "What do we mean?",
          title:
            "Clarify Terms: Identify key terms, hidden ambiguity, conceptual boundaries, and what would count as evidence."
        }
      ]
    }
  ]

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       visible: false,
       selected_text: nil,
       node_id: nil,
       offsets: nil,
       highlight: nil,
       links: [],
       ask_question: true,
       advanced_tools_open: false
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:visible, fn -> false end)
     |> assign_new(:advanced_tools_open, fn -> false end)}
  end

  @impl true
  def handle_event("show", params, socket) do
    %{
      "selectedText" => selected_text,
      "nodeId" => node_id,
      "offsets" => offsets
    } = params

    # Query existing highlight for this selection
    {highlight, links} =
      case Highlights.get_highlight_for_selection(
             socket.assigns.graph_id,
             node_id,
             offsets["start"],
             offsets["end"]
           ) do
        nil -> {nil, []}
        h -> {h, h.links}
      end

    {:noreply,
     socket
     |> assign(
       visible: true,
       selected_text: selected_text,
       node_id: node_id,
       offsets: offsets,
       highlight: highlight,
       links: links
     )}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("explain", _params, socket) do
    send_action_to_parent(socket, :explain)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("highlight_only", _params, socket) do
    send_action_to_parent(socket, :highlight_only)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("pros_cons", _params, socket) do
    send_action_to_parent(socket, :pros_cons)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("related_ideas", _params, socket) do
    send_action_to_parent(socket, :related_ideas)
    {:noreply, assign(socket, visible: false)}
  end

  @impl true
  def handle_event("toggle_ask_question", _params, socket) do
    {:noreply, update(socket, :ask_question, &(!&1))}
  end

  @impl true
  def handle_event("toggle_advanced_tools", _params, socket) do
    {:noreply, update(socket, :advanced_tools_open, &(!&1))}
  end

  @impl true
  def handle_event("critical_tool", %{"tool" => tool}, socket) do
    case Map.fetch(@critical_tool_actions, tool) do
      {:ok, action} ->
        send_action_to_parent(socket, action)
        {:noreply, assign(socket, visible: false)}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("submit_input", %{"question" => content}, socket) do
    if socket.assigns.ask_question do
      send_action_to_parent(socket, :ask_question, %{question: content})
    else
      send_action_to_parent(socket, :comment, %{comment: content})
    end

    {:noreply, assign(socket, visible: false)}
  end

  defp send_action_to_parent(socket, action, extra_params \\ %{}) do
    params =
      Map.merge(
        %{
          action: action,
          selected_text: socket.assigns.selected_text,
          node_id: socket.assigns.node_id,
          offsets: socket.assigns.offsets,
          highlight: socket.assigns.highlight
        },
        extra_params
      )

    send(self(), {:selection_action, params})
  end

  defp has_link_type?(links, type) do
    Enum.any?(links, fn link -> link.link_type == type end)
  end

  defp count_link_type(links, type) do
    Enum.count(links, fn link -> link.link_type == type end)
  end

  defp has_pros_or_cons?(links) do
    has_link_type?(links, "pro") || has_link_type?(links, "con")
  end

  defp advanced_tool_used?(links, tool_key) do
    has_link_type?(links, tool_key)
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :advanced_tool_sections, @advanced_tool_sections)

    ~H"""
    <div id={@id}>
      <div
        id={"selection-actions-modal-#{@id}"}
        class={if @visible, do: "", else: "hidden"}
        phx-target={@myself}
      >
        <div
          phx-click="close"
          phx-target={@myself}
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
                phx-click="close"
                phx-target={@myself}
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
              <div class="max-h-24 overflow-y-auto text-[0.95rem] font-medium leading-6 text-slate-900">
                "{@selected_text}"
              </div>
            </div>

            <div class="mt-3 grid grid-cols-2 gap-2.5">
              <button
                type="button"
                phx-click="explain"
                phx-target={@myself}
                disabled={!@can_edit || has_link_type?(@links, "explain")}
                title={
                  if has_link_type?(@links, "explain"),
                    do: "Explanation already exists for this text",
                    else: "Create an AI explanation"
                }
                class="group flex min-h-[96px] flex-col items-start justify-between rounded-2xl border-2 border-slate-200 bg-white px-3.5 py-3 text-left shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-sky-300 hover:shadow-[0_12px_24px_rgba(15,23,42,0.08)] active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-sky-100 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <span class="w-full space-y-1">
                  <span class="flex items-center gap-2 text-[1.05rem] font-semibold leading-5 text-slate-900">
                    <span class="inline-flex h-9 w-9 items-center justify-center rounded-xl bg-sky-500 text-white shadow-sm ring-4 ring-white/70">
                      <.icon name="hero-question-mark-circle" class="h-4.5 w-4.5" />
                    </span>
                    <span>
                      <%= if has_link_type?(@links, "explain") do %>
                        View Explanation
                      <% else %>
                        Explain
                      <% end %>
                    </span>
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

              <button
                type="button"
                phx-click="highlight_only"
                phx-target={@myself}
                disabled={!@can_edit || !is_nil(@highlight)}
                title={
                  if !is_nil(@highlight),
                    do: "Highlight already exists for this selection",
                    else: "Save this text selection as a highlight"
                }
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

              <button
                type="button"
                phx-click="pros_cons"
                phx-target={@myself}
                disabled={!@can_edit || has_pros_or_cons?(@links)}
                title={
                  if has_pros_or_cons?(@links),
                    do: "Pros/Cons already exist for this text",
                    else: "Analyze pros and cons"
                }
                class="group flex min-h-[96px] flex-col items-start justify-between rounded-2xl border-2 border-slate-200 bg-white px-3.5 py-3 text-left shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-emerald-300 hover:shadow-[0_12px_24px_rgba(15,23,42,0.08)] active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-emerald-100 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <span class="w-full space-y-1">
                  <span class="flex items-center gap-2 text-[1.05rem] font-semibold leading-5 text-slate-900">
                    <span class="inline-flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-500 text-white shadow-sm ring-4 ring-white/70">
                      <.icon name="hero-scale" class="h-4.5 w-4.5" />
                    </span>
                    <span>
                      <%= if has_pros_or_cons?(@links) do %>
                        View Pros/Cons
                      <% else %>
                        Pros & Cons
                      <% end %>
                    </span>
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
                phx-click="related_ideas"
                phx-target={@myself}
                disabled={!@can_edit || has_link_type?(@links, "related_idea")}
                title={
                  if has_link_type?(@links, "related_idea"),
                    do: "Related ideas already exist for this text",
                    else: "Find related ideas"
                }
                class="group flex min-h-[96px] flex-col items-start justify-between rounded-2xl border-2 border-slate-200 bg-white px-3.5 py-3 text-left shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-orange-300 hover:shadow-[0_12px_24px_rgba(15,23,42,0.08)] active:scale-[0.99] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-orange-100 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <span class="w-full space-y-1">
                  <span class="flex items-center gap-2 text-[1.05rem] font-semibold leading-5 text-slate-900">
                    <span class="inline-flex h-9 w-9 items-center justify-center rounded-xl bg-orange-500 text-white shadow-sm ring-4 ring-white/70">
                      <.icon name="hero-light-bulb" class="h-4.5 w-4.5" />
                    </span>
                    <span>
                      <%= if has_link_type?(@links, "related_idea") do %>
                        <%= if count_link_type(@links, "related_idea") > 1 do %>
                          View Ideas ({count_link_type(@links, "related_idea")})
                        <% else %>
                          View Related Idea
                        <% end %>
                      <% else %>
                        Related Ideas
                      <% end %>
                    </span>
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
            </div>

            <div class="mt-3 rounded-2xl border border-slate-200 bg-white/95 shadow-sm">
              <button
                type="button"
                phx-click="toggle_advanced_tools"
                phx-target={@myself}
                class="flex w-full items-center justify-between gap-3 px-3.5 py-3 text-left transition hover:bg-slate-50/80"
              >
                <div>
                  <p class="text-sm font-semibold text-slate-900">Advanced Critical Thinking Tools</p>
                  <p class="mt-0.5 text-[12px] leading-4 text-slate-500">
                    Focused reasoning moves for stress-testing the selected wording.
                  </p>
                </div>
                <.icon
                  name="hero-chevron-down"
                  class={
                    if @advanced_tools_open,
                      do: "h-5 w-5 text-slate-400 transition-transform rotate-180",
                      else: "h-5 w-5 text-slate-400 transition-transform"
                  }
                />
              </button>

              <div class={[
                "border-t border-slate-200/80 px-3.5 pb-3.5 pt-3",
                !@advanced_tools_open && "hidden"
              ]}>
                <div class="space-y-3.5">
                  <div :for={section <- @advanced_tool_sections}>
                    <h4 class="mb-2 px-0.5 text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-500">
                      {section.title}
                    </h4>
                    <div class="grid gap-2 sm:grid-cols-2">
                      <button
                        :for={tool <- section.tools}
                        type="button"
                        phx-click="critical_tool"
                        phx-value-tool={tool.key}
                        phx-target={@myself}
                        disabled={!@can_edit || advanced_tool_used?(@links, tool.key)}
                        title={
                          if advanced_tool_used?(@links, tool.key),
                            do: "#{tool.label} already exists for this text",
                            else: tool.title
                        }
                        class={[
                          "group flex min-h-[94px] flex-col items-start gap-2.5 rounded-[1.1rem] px-3.5 py-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
                          ColUtils.advanced_tool_surface_class(tool.key)
                        ]}
                      >
                        <span class="flex w-full items-start gap-2.5">
                          <span class={[
                            "inline-flex items-center justify-center rounded-xl p-2 shadow-sm",
                            ColUtils.advanced_tool_icon_class(tool.key)
                          ]}>
                            <.icon name={tool.icon} class="h-4 w-4" />
                          </span>
                          <span class="space-y-0.5">
                            <span class="block text-xs font-semibold text-slate-900">
                              <%= if advanced_tool_used?(@links, tool.key) do %>
                                View {tool.label}
                              <% else %>
                                {tool.label}
                              <% end %>
                            </span>
                            <span class="block text-xs leading-tight text-slate-600">
                              {tool.blurb}
                            </span>
                          </span>
                        </span>
                        <span class={[
                          "mt-auto flex w-full items-center justify-between border-t pt-2 text-[11px] font-semibold uppercase tracking-[0.12em]",
                          ColUtils.advanced_tool_text_class(tool.key),
                          "border-current/15"
                        ]}>
                          <span>Use this</span>
                          <.icon
                            name="hero-arrow-right"
                            class="h-4 w-4 transition-transform group-hover:translate-x-0.5"
                          />
                        </span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-3 rounded-2xl border border-slate-200 bg-slate-50/85 p-3 shadow-sm">
              <form phx-submit="submit_input" phx-target={@myself} class="flex flex-col gap-2.5">
                <div class="flex items-center justify-between gap-3">
                  <div>
                    <label class="text-sm font-semibold text-slate-800">
                      <%= if @ask_question do %>
                        Ask a custom question
                      <% else %>
                        Add a comment
                      <% end %>
                    </label>
                    <p class="mt-0.5 text-[11px] leading-4 text-slate-500">
                      <%= if @ask_question do %>
                        Use the selected text as the context for a more specific answer.
                      <% else %>
                        Save your own interpretation directly against this excerpt.
                      <% end %>
                    </p>
                  </div>

                  <div class="inline-flex rounded-full border border-slate-200 bg-white p-1 shadow-sm">
                    <button
                      type="button"
                      phx-click="toggle_ask_question"
                      phx-target={@myself}
                      class={[
                        "rounded-full px-3 py-1 text-xs font-semibold transition-all",
                        if @ask_question do
                          "bg-indigo-500 text-white shadow-sm"
                        else
                          "text-slate-600 hover:text-slate-900"
                        end
                      ]}
                      title="Get an AI-generated response"
                    >
                      Ask
                    </button>
                    <button
                      type="button"
                      phx-click="toggle_ask_question"
                      phx-target={@myself}
                      class={[
                        "rounded-full px-3 py-1 text-xs font-semibold transition-all",
                        if !@ask_question do
                          "bg-emerald-500 text-white shadow-sm"
                        else
                          "text-slate-600 hover:text-slate-900"
                        end
                      ]}
                      title="Add your own thought directly"
                    >
                      Comment
                    </button>
                  </div>
                </div>

                <div class="flex items-start gap-2">
                  <textarea
                    name="question"
                    rows="1"
                    phx-hook="AutoExpandTextarea"
                    id={"selection-question-input-#{@id}"}
                    class="min-h-[2.5rem] max-h-[7rem] flex-1 resize-none rounded-2xl border border-slate-300 bg-white px-3.5 py-2.5 text-sm text-slate-800 shadow-sm outline-none transition focus:border-indigo-400 focus:ring-4 focus:ring-indigo-100"
                    placeholder={
                      if @ask_question,
                        do: "What do you want to know about this exact wording?",
                        else: "Add your thought about this selection..."
                    }
                    autocomplete="off"
                    disabled={!@can_edit}
                  ></textarea>
                  <button
                    type="submit"
                    disabled={!@can_edit}
                    class={[
                      "self-start whitespace-nowrap rounded-2xl px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition-all hover:-translate-y-0.5 disabled:cursor-not-allowed disabled:opacity-50",
                      if(@ask_question,
                        do:
                          "bg-gradient-to-r from-indigo-500 to-sky-500 hover:shadow-[0_12px_24px_rgba(79,70,229,0.24)]",
                        else:
                          "bg-gradient-to-r from-emerald-500 to-teal-500 hover:shadow-[0_12px_24px_rgba(16,185,129,0.24)]"
                      )
                    ]}
                  >
                    <%= if @ask_question do %>
                      Ask
                    <% else %>
                      Post
                    <% end %>
                  </button>
                </div>

                <div class="flex items-center justify-between gap-3 text-[11px] text-slate-500">
                  <span>Press Enter to submit • Escape to close</span>
                  <div class="flex flex-wrap justify-end gap-2">
                    <%= if count_link_type(@links, "question") > 0 do %>
                      <span class="rounded-full bg-indigo-50 px-2.5 py-1 font-medium text-indigo-700 ring-1 ring-indigo-200">
                        {count_link_type(@links, "question")} question(s)
                      </span>
                    <% end %>
                    <%= if count_link_type(@links, "comment") > 0 do %>
                      <span class="rounded-full bg-emerald-50 px-2.5 py-1 font-medium text-emerald-700 ring-1 ring-emerald-200">
                        {count_link_type(@links, "comment")} comment(s)
                      </span>
                    <% end %>
                  </div>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
