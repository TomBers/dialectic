defmodule DialecticWeb.NoteMenuComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="rounded-md shadow-sm flex items-center justify-between gap-2 text-xs overflow-x-auto whitespace-nowrap w-full">
      <div class="bg-white border border-gray-200 rounded-md shadow-sm p-3">
        <div class="text-xs font-semibold text-gray-600 mb-2">Actions</div>
        <div class="flex items-center gap-2">
          <!-- Improved version with clearer purpose -->
        <!-- Redesigned with clearer visual states -->
          <%= if Enum.any?(@node.noted_by, fn u -> u == @user end) do %>
            <button
              phx-click="unnote"
              phx-value-node={@node.id}
              tabindex="-1"
              class="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1.5 rounded-md border border-indigo-200 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 hover:text-indigo-800 transition-colors shadow-sm"
              title="Remove from your notes"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3 mr-1"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z"
                  clip-rule="evenodd"
                />
              </svg>
              Noted ({length(@node.noted_by)})
            </button>
          <% else %>
            <button
              phx-click="note"
              phx-value-node={@node.id}
              tabindex="-1"
              class="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1.5 rounded-md border border-gray-200 bg-gray-50 text-gray-700 hover:bg-gray-100 hover:text-gray-800 transition-colors shadow-sm"
              title="Add to your notes"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3 mr-1"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                />
              </svg>
              Note
              <%= if length(@node.noted_by) > 0 do %>
                ({length(@node.noted_by)})
              <% end %>
            </button>
          <% end %>

          <.link
            navigate={~p"/#{@graph_id}/story/#{@node.id}"}
            tabindex="-1"
            class="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1.5 rounded-md border border-amber-200 bg-amber-50 text-amber-700 hover:bg-amber-100 hover:text-amber-800 transition-colors shadow-sm"
            title="View conversation thread from root to this node"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3 w-3 mr-1"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
              />
            </svg>
            Thread
          </.link>
          <.link
            navigate={~p"/#{@graph_id}/focus/#{@node.id}"}
            tabindex="-1"
            class="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1.5 rounded-md border border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100 hover:text-emerald-800 transition-colors shadow-sm"
            title="Chat interface for rapid idea expansion"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3 w-3 mr-1"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
              />
            </svg>
            Chat
          </.link>
          <% node_user_norm =
            String.downcase(String.trim(to_string((@node && @node.user) || ""))) %>
          <% current_email_norm =
            String.downcase(to_string((assigns[:current_user] && assigns[:current_user].email) || "")) %>
          <% current_id_str =
            to_string((assigns[:current_user] && assigns[:current_user].id) || "") %>
          <% user_norm = String.downcase(to_string(@user || "")) %>
          <% owner? =
            not is_nil(@node) &&
              ((node_user_norm != "" and
                  (current_email_norm == node_user_norm or
                     current_id_str == node_user_norm or user_norm == node_user_norm)) or
                 (node_user_norm == "" and current_email_norm != "")) %>
          <% children_list = (@node && (@node.children || [])) || [] %>
          <% no_live_children? =
            Enum.count(children_list, fn ch ->
              not Map.get(ch, :deleted, false)
            end) == 0 %>
          <% deletable = owner? && no_live_children? %>
          <button
            id={"delete-node-" <> @node.id}
            phx-click={if deletable, do: "delete_node", else: nil}
            phx-value-node={@node.id}
            phx-confirm={if deletable, do: "Are you sure you want to delete this node?", else: nil}
            tabindex="-1"
            aria-disabled={not deletable}
            data-disabled={not deletable}
            class={[
              "inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1.5 rounded-md transition-colors shadow-sm",
              deletable &&
                "border border-rose-200 bg-rose-50 text-rose-700 hover:bg-rose-100 hover:text-rose-800",
              !deletable && "border border-gray-200 bg-gray-50 text-gray-400 cursor-not-allowed"
            ]}
            title={
              cond do
                deletable ->
                  "Delete this node"

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
                  live_children_count =
                    Enum.count((@node && (@node.children || [])) || [], fn ch ->
                      not Map.get(ch, :deleted, false)
                    end)

                  base =
                    "Cannot delete: this node has #{live_children_count} child" <>
                      if live_children_count == 1, do: "", else: "ren"

                  ids =
                    children_list
                    |> Enum.filter(fn ch -> not Map.get(ch, :deleted, false) end)
                    |> Enum.map(fn ch -> to_string(Map.get(ch, :id, "")) end)
                    |> Enum.reject(&(&1 == ""))

                  case ids do
                    [] -> base
                    _ -> base <> " (child IDs: " <> Enum.join(ids, ", ") <> ")"
                  end

                true ->
                  "Cannot delete"
              end
            }
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3 w-3 mr-1"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6M9 7h6m-7 0a1 1 0 01-1-1V5a1 1 0 011-1h2a2 2 0 002-2h0a2 2 0 002 2h2a1 1 0 011 1v1"
              />
            </svg>
            Delete
          </button>
        </div>
      </div>

      <div class="bg-white border border-gray-200 rounded-md shadow-sm p-3 ml-auto">
        <div class="text-xs font-semibold text-gray-600 mb-2">Export</div>
        <div class="flex items-center gap-2">
          <.link
            navigate={~p"/#{@graph_id}/linear"}
            target="_blank"
            rel="noopener noreferrer"
            id="link-to-pdf-print"
            class="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1.5 rounded-md border border-red-200 bg-red-50 text-red-700 hover:bg-red-100 hover:text-red-800 transition-colors shadow-sm"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4 mr-1.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            PDF
          </.link>

          <.link
            href={"/api/graphs/json/#{@graph_id}"}
            download={"#{@graph_id}.json"}
            class="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1.5 rounded-md border border-blue-200 bg-blue-50 text-blue-700 hover:bg-blue-100 hover:text-blue-800 transition-colors shadow-sm"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4 mr-1.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7 7h10M7 11h10m-5 4h5m-9 2H9m13 0h-9m-1 4l-3-3H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
              />
            </svg>
            JSON
          </.link>

          <.link
            href={"/api/graphs/md/#{@graph_id}"}
            download={"#{@graph_id}.md"}
            class="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1.5 rounded-md border border-purple-200 bg-purple-50 text-purple-700 hover:bg-purple-100 hover:text-purple-800 transition-colors shadow-sm"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4 mr-1.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
              />
            </svg>
            Markdown
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
