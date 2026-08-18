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
      |> assign_new(:show_context, fn -> true end)
      |> assign_new(:embedded, fn -> false end)
      |> assign_new(:show_tools, fn -> false end)
      |> assign_new(:tools_open, fn -> false end)
      |> assign_new(:tools_target, fn -> nil end)
      |> assign_new(:tools_button_id, fn -> nil end)
      |> assign_new(:query_origin, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
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
        <input
          :if={@query_origin}
          id={"#{@id}-query-origin"}
          type="hidden"
          name="query_origin"
          value={@query_origin}
        />
        <%!-- Compact Replying-to indicator --%>
        <%= if @show_context && @node && @node.id do %>
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
          <div class="relative min-w-0 flex-1">
            <textarea
              name={@form[:content].name}
              id={@input_id}
              rows="1"
              placeholder={@placeholder}
              phx-hook="AutoExpandTextarea"
              disabled={@disabled}
              class={[
                "box-border w-full text-sm focus:outline-none focus:ring-0 resize-none",
                if(@embedded,
                  do: "min-h-[4.5rem] border-0 bg-transparent px-2.5 py-2 pr-2.5",
                  else: "h-10 min-h-[2.5rem] rounded-3xl border py-2.5 pl-4 pr-[11.25rem]"
                ),
                if(@disabled,
                  do:
                    "cursor-not-allowed border-slate-200 bg-slate-100 text-slate-500 placeholder:text-slate-400",
                  else:
                    if(@embedded,
                      do: "text-slate-800 placeholder:text-slate-400",
                      else: "border-gray-300 bg-white focus:border-indigo-500"
                    )
                )
              ]}
            >{Phoenix.HTML.Form.normalize_value("text", @form[:content].value)}</textarea>

            <%!-- Two submit buttons inside the input --%>
            <div class={[
              "flex items-center gap-1.5",
              if(@embedded,
                do: "mt-1 border-t border-slate-100 px-1 pt-2",
                else: "absolute right-1.5 top-0 bottom-1.5 justify-end"
              )
            ]}>
              <div :if={@show_tools} class="flex min-w-0 items-center gap-1">
                <button
                  id={@tools_button_id}
                  type="button"
                  phx-click="toggle_advanced_tools"
                  phx-target={@tools_target}
                  aria-expanded={to_string(@tools_open)}
                  class={[
                    "inline-flex h-8 shrink-0 items-center gap-1 rounded-full px-2.5 text-xs font-semibold transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-300",
                    if(@tools_open,
                      do: "bg-indigo-100 text-indigo-800",
                      else: "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
                    )
                  ]}
                >
                  <.icon name="hero-plus" class="h-3.5 w-3.5" />
                  <span>Tools</span>
                </button>
              </div>

              <div class="ml-auto flex items-center gap-1">
                <%!-- Post button — adds submit_action=post to form params --%>
                <button
                  type="submit"
                  name="submit_action"
                  value="post"
                  disabled={@disabled}
                  class={[
                    "inline-flex h-8 items-center gap-1 rounded-full px-2.5 text-xs font-semibold leading-none transition-all disabled:cursor-not-allowed disabled:opacity-50",
                    if(@disabled,
                      do: "bg-slate-100 text-slate-400",
                      else: "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
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
                    "inline-flex h-8 items-center gap-1 rounded-full px-3 text-xs font-semibold leading-none shadow-sm transition-all disabled:cursor-not-allowed disabled:opacity-50",
                    if(@disabled,
                      do: "bg-slate-300 text-white shadow-none",
                      else: "bg-slate-950 text-white hover:bg-slate-800 hover:shadow-md"
                    )
                  ]}
                  title={
                    if(@disabled,
                      do: "Choose an existing response to continue",
                      else: "Ask and get an AI response"
                    )
                  }
                >
                  <span>Ask</span>
                  <.icon name="hero-arrow-up" class="h-3.5 w-3.5" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <div :if={@embedded && !@disabled} class="mt-2 px-1">
          <.input
            type="checkbox"
            id={"#{@id}-guided-learning"}
            name="guided_learning"
            value="false"
            label="Guide my learning with next actions and exploration paths"
          />
        </div>
      </.form>
    </div>
    """
  end
end
