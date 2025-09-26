defmodule DialecticWeb.ActionToolbarComp do
  use DialecticWeb, :live_component
  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div
        class="fixed left-1/2 -translate-x-1/2 z-20 bottom-24 sm:bottom-8 md:bottom-6 pointer-events-none"
        data-external="true"
      >
        <div class="bg-white rounded-full shadow border border-gray-200 px-2 py-1 flex flex-wrap items-center justify-center gap-1 pointer-events-auto">
          <%= if @can_edit == false do %>
            <span
              class="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1 rounded-full border border-amber-200 bg-amber-50 text-amber-700"
              title="Graph is locked; editing is disabled"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M16 10V8a4 4 0 10-8 0v2m-1 0h10a2 2 0 012 2v6a2 2 0 01-2 2H7a2 2 0 01-2-2v-6a2 2 0 012-2z"
                />
              </svg>
              Locked
            </span>
          <% end %>

          <button
            type="button"
            class="px-3 py-1 text-sm text-gray-700 rounded-full transition-colors hover:bg-[#d1d5db] hover:text-gray-900"
            phx-click={show_modal("modal-graph-live-modal-comp")}
            title="Open reader"
          >
            <span class="inline-flex items-center gap-1.5">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15"
                />
              </svg>
              <span>Reader</span>
            </span>
          </button>

          <button
            type="button"
            class="px-3 py-1 text-sm text-gray-700 rounded-full transition-colors hover:bg-[#3b82f6] hover:text-white"
            phx-click={
              JS.push("reply-and-answer",
                value: %{
                  vertex: %{
                    content:
                      "Generate a list of related concepts and themes, focused on breadth and diversity, with short explanations for each. Return only the list."
                  },
                  prefix: "ideas"
                }
              )
            }
            title="Related ideas"
          >
            <span class="inline-flex items-center gap-1.5">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                />
              </svg>
              <span>Related</span>
            </span>
          </button>

          <button
            type="button"
            class="px-3 py-1 text-sm text-gray-700 rounded-full transition-colors hover:text-white hover:bg-gradient-to-r hover:from-emerald-500 hover:to-rose-500"
            phx-click="node_branch"
            phx-value-id={@node && @node.id}
            title="Pros and Cons"
          >
            <span class="inline-flex items-center gap-1.5">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
                />
              </svg>
              <span>Pros/Cons</span>
            </span>
          </button>

          <button
            type="button"
            class="px-3 py-1 text-sm text-gray-700 rounded-full transition-colors hover:bg-[#8b5cf6] hover:text-white"
            phx-click="node_combine"
            phx-value-id={@node && @node.id}
            title="Combine with another"
          >
            <span class="inline-flex items-center gap-1.5">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0 0 12 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c1.01.143 2.01.317 3 .52m-3-.52 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.988 5.988 0 0 1-2.031.352 5.988 5.988 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L18.75 4.971Zm-16.5.52c.99-.203 1.99-.377 3-.52m0 0 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.989 5.989 0 0 1-2.031.352 5.989 5.989 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L5.25 4.971Z"
                />
              </svg>
              <span>Combine</span>
            </span>
          </button>

          <button
            id="explore-all-points"
            type="button"
            class="px-3 py-1 text-sm text-gray-400 opacity-50 cursor-not-allowed rounded-full transition-colors"
            disabled
            title="Explore all points"
          >
            <span class="inline-flex items-center gap-1.5">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z"
                />
              </svg>
              <span>Explore</span>
            </span>
          </button>

          <% node_user_norm =
            String.downcase(String.trim(to_string((@node && @node.user) || ""))) %>
          <% current_email_norm =
            String.downcase(to_string((assigns[:current_user] && assigns[:current_user].email) || "")) %>
          <% current_id_str =
            to_string((assigns[:current_user] && assigns[:current_user].id) || "") %>
          <% user_norm = String.downcase(to_string(@user || "")) %>

          <% children_list = (@node && (@node.children || [])) || [] %>
          <% no_live_children? =
            Enum.count(children_list, fn ch -> not Map.get(ch, :deleted, false) end) == 0 %>

          <% owner? =
            not is_nil(@node) &&
              ((node_user_norm != "" and
                  (current_email_norm == node_user_norm or
                     current_id_str == node_user_norm or user_norm == node_user_norm)) or
                 (node_user_norm == "" and current_email_norm != "")) %>

          <% locked? = @can_edit == false %>
          <% deletable = owner? && no_live_children? && !locked? %>

          <button
            id={"delete-node-#{@graph_id}-#{@node && @node.id}"}
            type="button"
            phx-click={if deletable, do: "delete_node", else: nil}
            phx-value-node={@node && @node.id}
            phx-confirm={if deletable, do: "Are you sure you want to delete this node?", else: nil}
            aria-disabled={not deletable}
            data-disabled={not deletable}
            class={[
              "px-3 py-1 text-sm rounded-full transition-colors",
              deletable &&
                "inline-flex items-center gap-1.5 border border-rose-200 bg-rose-50 text-rose-700 hover:bg-rose-100 hover:text-rose-800",
              !deletable &&
                "inline-flex items-center gap-1.5 border border-gray-200 bg-gray-50 text-gray-400 cursor-not-allowed"
            ]}
            title={
              cond do
                deletable ->
                  "Delete this node"

                locked? ->
                  "Cannot delete: graph is locked"

                not owner? ->
                  "Cannot delete: you are not the author (you=" <>
                    if(assigns[:current_user] && assigns[:current_user].email,
                      do: assigns[:current_user].email,
                      else: to_string(@user || "")
                    ) <>
                    ", node.user=" <>
                    to_string((@node && @node.user) || "") <>
                    if(
                      String.trim(to_string((@node && @node.user) || "")) == "",
                      do: " [blank owner assumed current user]",
                      else: ""
                    ) <> ")"

                not no_live_children? ->
                  live_children =
                    Enum.filter(children_list, fn ch -> not Map.get(ch, :deleted, false) end)

                  live_children_count = length(live_children)

                  live_child_ids =
                    live_children
                    |> Enum.map(fn ch -> to_string(Map.get(ch, :id, "")) end)
                    |> Enum.reject(&(&1 == ""))
                    |> Enum.join(", ")

                  base =
                    "Cannot delete: this node has #{live_children_count} child" <>
                      if live_children_count == 1, do: "", else: "ren"

                  if live_child_ids != "" do
                    base <> " (child IDs: " <> live_child_ids <> ")"
                  else
                    base
                  end

                true ->
                  "Cannot delete"
              end
            }
          >
            <span class="inline-flex items-center gap-1.5">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6M9 7h6m-7 0a1 1 0 01-1-1V5a1 1 0 011-1h2a2 2 0 002-2h0a2 2 0 002 2h2a1 1 0 011 1v1"
                />
              </svg>
              <span>Delete</span>
            </span>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
