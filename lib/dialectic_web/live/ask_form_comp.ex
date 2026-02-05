defmodule DialecticWeb.AskFormComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Utils.NodeTitleHelper

  @moduledoc """
  LiveComponent that renders the bottom ask/comment form used by GraphLive.

  Assigns:
  - `id` (string, optional): DOM id for the form. Defaults to `"ask-form"`.
  - `form` (Phoenix.Component.Form, required): The form generated via `to_form/2` in the parent.
  - `ask_question` (boolean, optional): When true, uses the ask flow; otherwise comment flow. Defaults to `true`.
  - `graph_id` (string | nil, optional): Used to tailor the placeholder and hint for the empty graph state.
  - `submit_event` (string, optional): Overrides the default submit event. Defaults to `"reply-and-answer"` when `ask_question` is true,
    otherwise `"answer"`.
  - `submit_label` (string, optional): Overrides the button label. Defaults to `"Ask"` or `"Post"`.
  - `input_id` (string, optional): DOM id for the text input. Defaults to `"global-chat-input"`.
  - `placeholder` (string, optional): Placeholder text for the input. Will be derived from `graph_id`/`ask_question` if not provided.
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
      |> assign_new(:submit_label, fn -> nil end)
      |> assign_new(:input_id, fn -> "global-chat-input" end)
      |> assign_new(:show_hint, fn -> true end)
      |> assign_new(:prompt_mode, fn -> "structured" end)
      |> assign_new(:node, fn -> nil end)
      |> then(fn s ->
        if Map.has_key?(assigns, :placeholder) and not is_nil(assigns[:placeholder]) do
          assign(s, :placeholder, assigns[:placeholder])
        else
          assign(
            s,
            :placeholder,
            placeholder_for(s.assigns[:ask_question], s.assigns[:prompt_mode])
          )
        end
      end)

    {:ok, socket}
  end

  defp placeholder_for(ask_q, _mode) do
    if ask_q do
      "Ask a question"
    else
      "Add your comment..."
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full min-w-0 space-y-1.5">
      <%!-- Current Node Indicator --%>
      <%= if @node && @node.id do %>
        <div class="flex items-center justify-center gap-2 px-3 py-1.5 bg-gradient-to-r from-indigo-50 to-blue-50 border border-indigo-200 rounded-lg">
          <div class="flex items-center gap-1.5 text-xs">
            <div class="w-2 h-2 rounded-full bg-indigo-500 animate-pulse"></div>
            <span class="font-medium text-indigo-900">Active:</span>
            <button
              type="button"
              phx-click="node_clicked"
              phx-value-id={@node.id}
              class="text-indigo-700 hover:text-indigo-900 font-semibold hover:underline transition-colors max-w-[300px] truncate"
              title={"Click to focus: " <> NodeTitleHelper.extract_node_title(@node)}
            >
              {NodeTitleHelper.extract_node_title(@node, max_length: 50)}
            </button>
          </div>
        </div>
      <% end %>
      <.form
        for={@form}
        phx-submit={@submit_event || if(@ask_question, do: "reply-and-answer", else: "answer")}
        id={@id}
        class="w-full min-w-0"
      >
        <div class="flex items-center gap-2 w-full">
          <%!-- Ask/Comment Segmented Control - Compact text-only --%>
          <div class="inline-flex rounded-md border border-gray-200 bg-gray-50 flex-none">
            <button
              type="button"
              phx-click="toggle_ask_question"
              class={[
                "px-2 py-1 text-xs font-medium transition-all",
                if @ask_question do
                  "bg-blue-500 text-white rounded-md"
                else
                  "text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-l-md"
                end
              ]}
              title="Get an AI-generated response"
            >
              Ask
            </button>
            <button
              type="button"
              phx-click="toggle_ask_question"
              class={[
                "px-2 py-1 text-xs font-medium transition-all",
                if !@ask_question do
                  "bg-emerald-500 text-white rounded-md"
                else
                  "text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-r-md"
                end
              ]}
              title="Add your own thought directly"
            >
              Comment
            </button>
          </div>

          <%!-- Input Field with Submit Button - Enhanced prominence --%>
          <div class="relative min-w-0 flex-1 overflow-hidden rounded-3xl shadow-sm transition-all focus-within:shadow-md">
            <textarea
              name={@form[:content].name}
              id={@input_id}
              rows="1"
              placeholder={@placeholder}
              phx-hook="AutoExpandTextarea"
              class="box-border w-full h-[3rem] min-h-[3rem] overflow-hidden rounded-3xl pl-4 pr-20 py-2 text-base border-2 border-gray-300 focus:border-indigo-500 focus:ring-0 focus:outline-none bg-white resize-none"
            >{Phoenix.HTML.Form.normalize_value("text", @form[:content].value)}</textarea>

            <button
              type="submit"
              class="absolute right-2 top-1.5 bg-indigo-600 hover:bg-indigo-700 text-white text-sm leading-none px-3.5 h-9 rounded-full font-medium shadow-sm transition-all hover:shadow-md"
            >
              {if @submit_label, do: @submit_label, else: if(@ask_question, do: "Ask", else: "Post")}
            </button>
          </div>
        </div>

        <%!-- Explanatory text below form --%>
        <div class="text-[11px] text-gray-600 text-center">
          <%= if @ask_question do %>
            Ask a question to get an AI-generated
            <span class="font-medium">{String.capitalize(@prompt_mode)}</span>
            level response • <span class="text-gray-500">Change level in settings panel</span>
          <% else %>
            <span class="text-gray-600">
              Add your comment directly to the graph • No AI response will be generated
            </span>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end
end
