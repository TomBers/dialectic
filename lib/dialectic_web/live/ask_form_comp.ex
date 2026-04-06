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
      |> then(fn s ->
        if Map.has_key?(assigns, :placeholder) and not is_nil(assigns[:placeholder]) do
          assign(s, :placeholder, assigns[:placeholder])
        else
          assign(s, :placeholder, "Ask or comment...")
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
            <span class="text-[11px] text-gray-600 group-hover:text-indigo-600 truncate max-w-[200px]">
              {NodeTitleHelper.extract_node_title(@node, max_length: 40)}
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
              class="box-border w-full h-10 min-h-[2.5rem] rounded-3xl pl-4 pr-[8.5rem] py-2.5 text-sm border border-gray-300 focus:border-indigo-500 focus:ring-0 focus:outline-none bg-white resize-none"
            >{Phoenix.HTML.Form.normalize_value("text", @form[:content].value)}</textarea>

            <%!-- Two submit buttons inside the input --%>
            <div class="absolute right-1.5 top-0 bottom-1.5 flex items-center gap-1">
              <%!-- Post button — adds submit_action=post to form params --%>
              <button
                type="submit"
                name="submit_action"
                value="post"
                class="bg-emerald-500 hover:bg-emerald-600 text-white text-xs leading-none px-3.5 h-7 rounded-full font-medium transition-all hover:shadow-sm"
                title="Post your comment — no AI response"
              >
                Post
              </button>
              <%!-- Ask button — default submit (no name, so no submit_action param) --%>
              <button
                type="submit"
                class="bg-indigo-600 hover:bg-indigo-700 text-white text-xs leading-none px-3.5 h-7 rounded-full font-medium shadow-sm transition-all hover:shadow-md"
                title="Ask and get an AI-generated response"
              >
                Ask
              </button>
            </div>
          </div>
        </div>

        <%!-- Compact hint text --%>
        <%= if @show_hint do %>
          <div class="text-[10px] text-gray-400 mt-1 ml-1">
            <span class="text-indigo-500">Ask</span> = AI response
            · <span class="text-emerald-500">Post</span> = your comment
          </div>
        <% end %>
      </.form>
    </div>
    """
  end
end
