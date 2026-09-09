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
     |> assign_new(:context, fn -> :selection end)}
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
      data-draft-key={"#{@context}-drafts:#{@graph_id}:#{if(@current_user, do: @current_user.id, else: "guest")}"}
      data-guest-draft-key={if(@current_user, do: "#{@context}-drafts:#{@graph_id}:guest")}
    >
      <div id={"selection-actions-modal-#{@id}"} class="hidden" phx-update="ignore" aria-hidden="true">
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
          <div class="relative overflow-y-auto px-4 pb-5 pt-4 sm:px-5 sm:pb-5 sm:pt-5">
            <div class="flex items-start gap-3">
              <div class="min-w-0 flex-1">
                <p :if={@context == :answer} class="mb-1 text-xs font-semibold text-slate-500">
                  Responding to
                </p>
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
                  if(@context == :answer, do: "Close answer actions", else: "Close selection actions")
                }
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>

            <p
              :if={!@current_user && @context == :selection}
              id="selection-sign-in-hint"
              class="mt-3 text-sm text-slate-600"
            >
              <.link href={~p"/users/log_in"} class="font-semibold text-indigo-700 underline">Sign in</.link>
              to use passage actions. Your draft is kept in this tab.
            </p>
            <div class="mt-2 flex gap-2 text-xs text-slate-500">
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
            <div class="mt-4 border-t border-slate-100 pt-4">
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
        </.focus_wrap>
      </div>
    </div>
    """
  end
end
