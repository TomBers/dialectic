defmodule DialecticWeb.AskFormComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Utils.NodeTitleHelper

  @moduledoc """
  LiveComponent that renders the bottom ask/comment form used by GraphLive.

  Instead of a modal toggle between Ask and Comment modes, this component
  renders two submit buttons side-by-side — "Ask" (AI responds) and "Post"
  (no AI). The user types once and picks the action at submit time.

  When "Post" is clicked, a hidden `submit_action=post` param is included
  in the form data so the parent LiveView can route to the correct handler.

  Assigns:
  - `id` (string, optional): DOM id for the form. Defaults to `"ask-form"`.
  - `form` (Phoenix.Component.Form, required): The form generated via `to_form/2` in the parent.
  - `ask_question` (boolean, optional): Legacy assign, accepted but ignored. Kept for caller compatibility.
  - `graph_id` (string | nil, optional): Used to tailor the placeholder and hint for the empty graph state.
  - `submit_event` (string, optional): Overrides the default submit event. Defaults to `"reply-and-answer"`.
  - `input_id` (string, optional): DOM id for the text input. Defaults to `"global-chat-input"`.
  - `placeholder` (string, optional): Placeholder text for the input.
  - `show_hint` (boolean, optional): When true and `graph_id` is nil, show a hint above the input. Defaults to `true`.
  - `prompt_mode` (string, optional): Current AI mode ("structured" or "creative"). Used for display only.
  - `node` (map | nil, optional): The currently active node. Used to display current node indicator.
  - `autofocus` (boolean, optional): When true, autofocus the textarea. Defaults to `false`.
  """

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:id, fn -> "ask-form" end)
      |> assign_new(:ask_question, fn -> true end)
      |> assign_new(:graph_id, fn -> nil end)
      |> assign_new(:submit_event, fn -> nil end)
      |> assign_new(:input_id, fn -> "global-chat-input" end)
      |> assign_new(:show_hint, fn -> true end)
      |> assign_new(:prompt_mode, fn -> "structured" end)
      |> assign_new(:node, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:autofocus, fn -> false end)
      |> then(fn s ->
        cond do
          Map.has_key?(assigns, :placeholder) and not is_nil(assigns[:placeholder]) ->
            assign(s, :placeholder, assigns[:placeholder])

          s.assigns.disabled ->
            assign(s, :placeholder, "Choose an existing response to continue the grid...")

          true ->
            assign(s, :placeholder, "Write a comment or ask AI to continue...")
        end
      end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full min-w-0" data-role="ask-form-container">
      <.form
        for={@form}
        phx-submit={@submit_event || "reply-and-answer"}
        id={@id}
        class="w-full min-w-0"
        aria-disabled={@disabled}
      >
        <%!-- Compact Replying-to indicator --%>
        <%= if @node && @node.id do %>
          <button
            type="button"
            phx-click="node_clicked"
            phx-value-id={@node.id}
            class="flex items-center gap-1.5 mb-1 text-left group"
            title="Click to focus this node on the graph"
          >
            <span class="text-[10px] text-gray-400">↩</span>
            <span class={"inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-medium " <> DialecticWeb.ColUtils.badge_class(@node.class || "")}>
              {DialecticWeb.ColUtils.node_type_label(@node.class || "")}
            </span>
            <span class="text-[11px] text-gray-600 group-hover:text-indigo-600 whitespace-normal break-words">
              {NodeTitleHelper.extract_node_title(@node, max_length: :infinity)}
            </span>
          </button>
        <% end %>

        <div class="flex items-center gap-2 w-full">
          <%!-- Input Field --%>
          <div class="relative min-w-0 flex-1 rounded-3xl shadow-sm transition-all focus-within:shadow-md">
            <textarea
              name={@form[:content].name}
              id={@input_id}
              rows="1"
              placeholder={@placeholder}
              phx-hook="AutoExpandTextarea"
              disabled={@disabled}
              autofocus={@autofocus && !@disabled}
              class={[
                "box-border w-full h-10 min-h-[2.5rem] rounded-3xl border py-2.5 pl-4 pr-[11.25rem] text-sm focus:outline-none focus:ring-0 resize-none",
                if(@disabled,
                  do:
                    "cursor-not-allowed border-slate-200 bg-slate-100 text-slate-500 placeholder:text-slate-400",
                  else: "border-gray-300 bg-white focus:border-indigo-500"
                )
              ]}
            >{Phoenix.HTML.Form.normalize_value("text", @form[:content].value)}</textarea>

            <%!-- Two submit buttons inside the input --%>
            <div class="absolute right-1.5 top-0 bottom-1.5 flex items-center gap-1">
              <%!-- Post button — adds submit_action=post to form params --%>
              <button
                type="submit"
                name="submit_action"
                value="post"
                disabled={@disabled}
                class={[
                  "inline-flex h-7 items-center gap-1 rounded-full border px-3 text-xs font-semibold leading-none transition-all disabled:cursor-not-allowed disabled:opacity-50",
                  if(@disabled,
                    do: "border-slate-200 bg-slate-100 text-slate-400",
                    else:
                      "border-emerald-200 bg-emerald-50 text-emerald-700 hover:border-emerald-300 hover:bg-emerald-100"
                  )
                ]}
                title={
                  if(@disabled,
                    do: "Choose an existing response to continue",
                    else: "Add your comment without an AI reply"
                  )
                }
              >
                <.icon name="hero-chat-bubble-left-ellipsis" class="h-3.5 w-3.5" />
                <span>Comment</span>
              </button>
              <%!-- Ask button — default submit (no name, so no submit_action param) --%>
              <button
                type="submit"
                disabled={@disabled}
                class={[
                  "inline-flex h-7 items-center gap-1 rounded-full px-3 text-xs font-semibold leading-none shadow-sm transition-all disabled:cursor-not-allowed disabled:opacity-50",
                  if(@disabled,
                    do: "bg-slate-300 text-white shadow-none",
                    else: "bg-indigo-600 text-white hover:bg-indigo-700 hover:shadow-md"
                  )
                ]}
                title={
                  if(@disabled,
                    do: "Choose an existing response to continue",
                    else: "Ask and get an AI response"
                  )
                }
              >
                <.icon name="hero-sparkles" class="h-3.5 w-3.5" />
                <span>Ask AI</span>
              </button>
            </div>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
