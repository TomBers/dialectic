defmodule DialecticWeb.SelectionActionsComp do
  @moduledoc """
  LiveComponent for handling text selection actions.

  Provides a modal interface for creating highlights, explanations,
  questions, pros/cons, and related ideas from selected text.
  """
  use DialecticWeb, :live_component
  alias Dialectic.Highlights

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
       ask_question: true
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:visible, fn -> false end)}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <div
        id={"selection-actions-modal-#{@id}"}
        class={if @visible, do: "", else: "hidden"}
        phx-target={@myself}
      >
        <!-- Modal backdrop -->
        <div
          phx-click="close"
          phx-target={@myself}
          class="fixed inset-0 bg-gray-900/50 backdrop-blur-sm z-[999] transition-opacity duration-200"
        >
        </div>
        <!-- Modal content -->
        <div class="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white shadow-2xl rounded-xl p-4 sm:p-6 z-[1000] border border-gray-200 flex flex-col gap-3 w-[90vw] max-w-[500px] transition-all duration-200 opacity-100 scale-100">
          <%!-- Header with close button --%>
          <div class="flex items-center justify-between mb-2">
            <h3 class="text-lg font-semibold text-gray-900">Selection Actions</h3>
            <button
              type="button"
              phx-click="close"
              phx-target={@myself}
              class="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100 transition-colors"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          <%!-- Selected text display --%>
          <div class="p-4 bg-gradient-to-br from-indigo-50 to-blue-50 rounded-lg border-2 border-indigo-200 shadow-sm">
            <div class="text-xs text-indigo-700 mb-2 font-semibold uppercase tracking-wide">
              Selected text:
            </div>
            <div class="text-base text-gray-900 font-medium leading-relaxed max-h-32 overflow-y-auto">
              {@selected_text}
            </div>
          </div>
          <%!-- Action buttons grid --%>
          <div class="grid grid-cols-2 gap-3">
            <%!-- Explain Button --%>
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
              class="bg-blue-500 hover:bg-blue-600 text-white text-sm py-2.5 px-4 rounded-lg flex items-center justify-center transition-all hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-1.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z"
                />
              </svg>
              <%= if has_link_type?(@links, "explain") do %>
                View Explanation
              <% else %>
                Explain
              <% end %>
            </button>
            <%!-- Highlight Only Button --%>
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
              class="bg-yellow-400 hover:bg-yellow-500 text-gray-900 text-sm py-2.5 px-4 rounded-lg flex items-center justify-center transition-all hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 mr-1.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                />
              </svg>
              Highlight
            </button>
            <%!-- Pros/Cons Button --%>
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
              class="bg-gradient-to-r from-emerald-500 to-rose-500 hover:from-emerald-600 hover:to-rose-600 text-white text-sm py-2.5 px-4 rounded-lg flex items-center justify-center transition-all hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-1.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
                />
              </svg>
              <%= if has_pros_or_cons?(@links) do %>
                View Pros/Cons
              <% else %>
                Pros & Cons
              <% end %>
            </button>
            <%!-- Related Ideas Button --%>
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
              class="bg-orange-500 hover:bg-orange-600 text-white text-sm py-2.5 px-4 rounded-lg flex items-center justify-center transition-all hover:shadow-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-1.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                />
              </svg>
              <%= if has_link_type?(@links, "related_idea") do %>
                <%= if count_link_type(@links, "related_idea") > 1 do %>
                  View Ideas ({count_link_type(@links, "related_idea")})
                <% else %>
                  View Related Idea
                <% end %>
              <% else %>
                Related Ideas
              <% end %>
            </button>
          </div>
          <%!-- Custom question/comment form --%>
          <div class="border-t border-gray-200 pt-3 mt-1">
            <form phx-submit="submit_input" phx-target={@myself} class="flex flex-col gap-2">
              <div class="flex items-center justify-between">
                <label class="text-sm font-medium text-gray-700">
                  <%= if @ask_question do %>
                    Ask a custom question:
                  <% else %>
                    Add a comment:
                  <% end %>
                </label>
                <%!-- Ask/Comment Segmented Control --%>
                <div class="inline-flex rounded-md border border-gray-200 bg-gray-50 flex-none scale-90 origin-right">
                  <button
                    type="button"
                    phx-click="toggle_ask_question"
                    phx-target={@myself}
                    class={[
                      "px-2 py-1 text-xs font-medium transition-all",
                      if @ask_question do
                        "bg-blue-500 text-white rounded-l-md"
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
                    phx-target={@myself}
                    class={[
                      "px-2 py-1 text-xs font-medium transition-all",
                      if !@ask_question do
                        "bg-emerald-500 text-white rounded-r-md"
                      else
                        "text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-r-md"
                      end
                    ]}
                    title="Add your own thought directly"
                  >
                    Comment
                  </button>
                </div>
              </div>

              <div class="flex gap-2 items-start">
                <textarea
                  name="question"
                  rows="1"
                  phx-hook="AutoExpandTextarea"
                  id={"selection-question-input-#{@id}"}
                  class="flex-1 px-3 py-2 text-sm border border-gray-300 rounded-lg focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 focus:outline-none resize-none min-h-[2.5rem] max-h-[8rem]"
                  placeholder={
                    if @ask_question,
                      do: "What would you like to know?",
                      else: "Add your thought about this selection..."
                  }
                  autocomplete="off"
                  disabled={!@can_edit}
                ></textarea>
                <button
                  type="submit"
                  disabled={!@can_edit}
                  class={[
                    "text-white text-sm py-2 px-4 rounded-lg font-medium transition-all hover:shadow-lg whitespace-nowrap self-start disabled:opacity-50 disabled:cursor-not-allowed",
                    if(@ask_question,
                      do: "bg-indigo-500 hover:bg-indigo-600",
                      else: "bg-emerald-500 hover:bg-emerald-600"
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
              <div class="text-xs text-gray-500 flex items-center justify-between">
                <span>Press Enter to submit • Escape to close</span>
                <div class="flex gap-2">
                  <%= if count_link_type(@links, "question") > 0 do %>
                    <span class="text-indigo-600 font-medium">
                      {count_link_type(@links, "question")} question(s)
                    </span>
                  <% end %>
                  <%= if count_link_type(@links, "comment") > 0 do %>
                    <span class="text-emerald-600 font-medium">
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
    """
  end
end
