defmodule DialecticWeb.SelectionActionsComp do
  @moduledoc """
  LiveComponent for handling text selection actions.

  Provides a modal interface for creating highlights, explanations,
  questions, pros/cons, and related ideas from selected text.
  """
  use DialecticWeb, :live_component

  alias Dialectic.Highlights
  alias DialecticWeb.GraphHelpers

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

  @impl true
  def mount(socket), do: {:ok, socket}

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:highlight_only, fn -> false end)
     |> assign_new(:context, fn -> :selection end)
     |> assign_new(:presentation, fn -> :modal end)
     |> assign_new(:node_id, fn -> nil end)
     |> assign_new(:answer_title, fn -> nil end)
     |> assign_new(:bookmarked, fn -> false end)
     |> assign_new(:trigger_id, fn -> nil end)}
  end

  @impl true
  def handle_event(
        "action",
        %{"nodeId" => node_id} = params,
        %{assigns: %{context: :answer}} = socket
      )
      when is_binary(node_id) do
    send(self(), {:answer_action, params})
    {:noreply, socket}
  end

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
             is_integer(start_offset) and start_offset >= 0 and is_integer(end_offset) and
             start_offset < end_offset do
    with {:ok, action} <- Map.fetch(@selection_actions, action_key),
         :ok <- allowed_action(socket, action),
         :ok <- GraphHelpers.validate_selection_target(socket, action, node_id),
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
        request_id: Map.get(params, "request_id"),
        selected_text: selected_text,
        node_id: node_id,
        offsets: offsets,
        highlight: highlight
      }

      send(self(), {:selection_action, Map.merge(selection_params, extra_params)})
      {:noreply, socket}
    else
      error ->
        message =
          case error do
            {:error, message} -> message
            _ -> "Choose an available passage action."
          end

        {:noreply,
         push_event(socket, "selection:result", %{
           request_id: params["request_id"],
           status: "error",
           message: message
         })}
    end
  end

  def handle_event("action", params, socket),
    do:
      {:noreply,
       push_event(socket, "selection:result", %{
         request_id: params["request_id"],
         status: "error",
         message: "Select a passage to continue."
       })}

  defp allowed_action(%{assigns: %{highlight_only: true}}, action) when action != :highlight_only,
    do: {:error, "Reader view supports highlights only"}

  defp allowed_action(_socket, _action), do: :ok

  defp action_input(action, params) when action in [:ask_question, :comment] do
    case GraphHelpers.inquiry_content(params["input"]) do
      "" -> {:error, "Write a comment or question first."}
      content -> {:ok, %{if(action == :comment, do: :comment, else: :question) => content}}
    end
  end

  defp action_input(_action, _params), do: {:ok, %{}}

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      data-can-edit={to_string(@can_edit)}
      data-action-context={@context}
      data-presentation={@presentation}
      data-node-id={@node_id}
      data-answer-title={@answer_title}
      data-bookmarked={to_string(@bookmarked)}
      data-trigger-id={@trigger_id}
      data-draft-key={"#{@context}-drafts:#{@graph_id}:#{if(@current_user, do: @current_user.id, else: "guest")}"}
      data-guest-draft-key={if(@current_user, do: "#{@context}-drafts:#{@graph_id}:guest")}
    >
      <div
        :if={@presentation == :modal}
        id={"selection-actions-modal-#{@id}"}
        class="hidden"
        phx-update="ignore"
        aria-hidden="true"
      >
        <div
          data-selection-close
          class="fixed inset-0 z-[999] bg-slate-950/40 backdrop-blur-sm transition-opacity duration-200"
        >
        </div>
        <.focus_wrap
          id={"selection-actions-focus-#{@id}"}
          role="dialog"
          data-selection-dialog
          tabindex="-1"
          aria-modal="true"
          aria-label={
            cond do
              @context == :answer -> "Respond to this answer"
              @highlight_only -> "Save selected passage"
              true -> "Selected passage actions"
            end
          }
          class="fixed left-1/2 top-1/2 z-[1000] flex max-h-[88vh] w-[92vw] max-w-[620px] -translate-x-1/2 -translate-y-1/2 flex-col overflow-hidden rounded-[1.35rem] border border-slate-200 bg-white shadow-[0_28px_72px_rgba(15,23,42,0.2)] ring-1 ring-slate-950/5 transition-[max-width,opacity,transform] duration-200 opacity-100 scale-100"
        >
          <.action_content {assigns} />
        </.focus_wrap>
      </div>
      <div
        :if={@presentation == :drawer}
        id={"selection-actions-modal-#{@id}"}
        phx-update="ignore"
        class="hidden rounded-xl border border-teal-200 bg-white transition focus-within:border-indigo-400 focus-within:ring-2 focus-within:ring-indigo-100/70"
        aria-hidden="true"
      >
        <div
          id={"selection-actions-focus-#{@id}"}
          role="region"
          data-selection-dialog
          tabindex="-1"
          aria-label="Response form"
        >
          <.action_content {assigns} />
        </div>
      </div>
    </div>
    """
  end

  defp action_content(assigns) do
    ~H"""
    <div class={[
      "relative",
      if(@presentation == :drawer, do: "p-2 sm:p-3", else: "overflow-y-auto p-3 sm:p-5")
    ]}>
      <div :if={@presentation == :modal} class="flex items-start gap-3">
        <div class="min-w-0 flex-1">
          <blockquote
            id={"selection-actions-passage-#{@id}"}
            data-selection-text
            class="font-serif text-xl font-medium leading-7 tracking-tight text-slate-950 sm:text-[1.35rem] sm:leading-8"
          >
          </blockquote>
          <button
            :if={@context == :selection}
            id={"selection-actions-copy-#{@id}"}
            type="button"
            data-selection-copy
            class="mt-3 inline-flex items-center gap-1.5 rounded-md border border-slate-200 bg-white px-2.5 py-1.5 text-xs font-semibold text-slate-600 transition-colors hover:border-slate-300 hover:bg-slate-50 hover:text-slate-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-300"
          >
            <span data-selection-copy-icon>
              <.icon name="hero-clipboard-document" class="h-3.5 w-3.5" />
            </span>
            <span data-selection-copy-check class="hidden text-emerald-600">
              <.icon name="hero-check" class="h-3.5 w-3.5" />
            </span>
            <span data-selection-copy-label aria-live="polite">Copy text</span>
          </button>
        </div>
        <button
          id={"selection-actions-close-#{@id}"}
          type="button"
          data-selection-close
          class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-400 transition-colors hover:bg-slate-50 hover:text-slate-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-300"
          aria-label={
            cond do
              @presentation == :drawer -> "Hide response form"
              @context == :answer -> "Close answer actions"
              true -> "Close selection actions"
            end
          }
        >
          <.icon
            name={if(@presentation == :drawer, do: "hero-chevron-up", else: "hero-x-mark")}
            class="h-4 w-4"
          />
        </button>
      </div>

      <section
        :if={!@current_user && @context == :selection}
        id={"selection-sign-in-required-#{@id}"}
        aria-labelledby={"selection-sign-in-title-#{@id}"}
        class="mt-5 rounded-xl border border-stone-300 bg-[#f4f1e9] p-4 sm:p-5"
      >
        <p class="mb-3 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.16em] text-teal-800">
          <.icon name="hero-lock-closed" class="h-4 w-4 shrink-0" /> Continue your thinking
        </p>
        <div class="text-slate-950">
          <h2
            id={"selection-sign-in-title-#{@id}"}
            class="font-serif text-2xl font-semibold leading-tight tracking-tight"
          >
            You need to be logged in to use this
          </h2>
        </div>
        <p class="mt-3 text-sm leading-6 text-slate-700">
          <strong class="font-semibold text-teal-800">Accounts are free.</strong>
          Keep track of your contributions, save highlights and bookmarks, and add personal learning plans.
        </p>
        <p :if={@context == :selection} class="mt-2 text-sm leading-6 text-slate-600">
          Reading and copying text are available without an account.
        </p>
        <div class="mt-4 flex flex-col gap-2 sm:flex-row">
          <.link
            id={"selection-log-in-#{@id}"}
            href={~p"/users/log_in"}
            class="inline-flex min-h-11 items-center justify-center rounded-lg bg-teal-800 px-5 py-2.5 text-sm font-semibold text-white hover:bg-teal-700 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
          >
            Log in to continue
          </.link>
          <.link
            id={"selection-sign-up-#{@id}"}
            href={~p"/users/register"}
            class="inline-flex min-h-11 items-center justify-center rounded-lg border border-stone-300 bg-white px-5 py-2.5 text-sm font-semibold text-slate-900 hover:bg-stone-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
          >
            Create a free account
          </.link>
        </div>
        <button
          id={"selection-keep-reading-#{@id}"}
          type="button"
          data-selection-close
          class="mt-2 inline-flex min-h-11 items-center text-sm font-medium text-teal-800 underline decoration-teal-800/30 underline-offset-4 hover:text-teal-700 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
        >
          Keep reading
        </button>
      </section>
      <div
        :if={@current_user && @context == :selection}
        class="mt-2 flex gap-2 text-xs text-slate-500"
      >
        <span data-selection-question-count class="hidden"></span>
        <span data-selection-comment-count class="hidden"></span>
      </div>
      <p
        :if={@highlight_only}
        data-selection-status
        role="status"
        aria-live="polite"
        class="mt-2 text-sm text-slate-700"
      >
      </p>
      <div
        :if={@current_user || @context == :answer}
        class={@presentation == :modal && "mt-3 border-t border-slate-100 pt-3"}
      >
        <.live_component
          module={DialecticWeb.InquiryActionsComp}
          id={"selection-inquiry-actions-#{@id}"}
          owner_id={@id}
          context={@context}
          graph_id={@graph_id}
          can_edit={@can_edit}
          current_user={@current_user}
          highlight_only={@highlight_only}
        />
      </div>
    </div>
    """
  end
end
