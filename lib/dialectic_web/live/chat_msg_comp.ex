defmodule DialecticWeb.ChatMsgComp do
  use DialecticWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      # Default cutoff length
      |> assign_new(:cut_off, fn -> 500 end)

    {:ok, socket}
  end

  defp truncated_html(content, cut_off) do
    # If content is already under the cutoff, just return the full text
    if String.length(content) <= cut_off do
      full_html(content)
    else
      truncated = String.slice(content, 0, cut_off) <> "..."
      Earmark.as_html!(truncated) |> Phoenix.HTML.raw()
    end
  end

  defp full_html(content) do
    Earmark.as_html!(content) |> Phoenix.HTML.raw()
  end

  defp modal_title(nil), do: ""

  defp modal_title(class) do
    String.upcase(class) <> ":"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={[
        "node mb-4 rounded-lg shadow-sm",
        "flex items-start gap-3 bg-white border-l-4",
        message_border_class(@node.class)
      ]}
      id={"node-" <> @node.id}
    >
      <div class="shrink-0">
        <h2 class="w-8 h-8 flex items-center justify-center rounded-lg bg-gray-100 text-gray-700 font-mono text-sm">
          {@node.id}
        </h2>
      </div>

      <div class="proposition flex-1 max-w-none relative">
        <.modal
          on_cancel={JS.push("modal_closed")}
          class={message_border_class(@node.class)}
          id={"modal-" <> @node.id}
        >
          <div
            class="modal-content"
            id={"modal-content-" <> @node.id}
            phx-hook="TextSelectionHook"
            data-node-id={@node.id}
          >
            <article class="prose prose-stone prose-sm selection-content">
              <h1 class="">{modal_title(@node.class)}</h1>
              {full_html(@node.content || "")}
            </article>
            
    <!-- Modal selection action button (hidden by default) -->
            <div class="selection-actions hidden absolute bg-white shadow-md rounded-md p-1 z-10">
              <button
                phx-click={JS.hide(transition: "fade-out-scale", to: "#modal-" <> @node.id)}
                class="bg-blue-500 hover:bg-blue-600 text-white text-xs py-1 px-2 rounded"
              >
                Ask about selection
              </button>
            </div>
          </div>
        </.modal>

        <div
          class="summary-content"
          id={"summary-content-" <> @node.id}
          phx-hook="TextSelectionHook"
          data-node-id={@node.id}
        >
          <article class="prose prose-stone prose-sm selection-content">
            {truncated_html(@node.content || "", @cut_off)}
          </article>
          
    <!-- Summary selection action button (hidden by default) -->
          <div class="selection-actions hidden absolute bg-white shadow-md rounded-md p-1 z-10">
            <button class="bg-blue-500 hover:bg-blue-600 text-white text-xs py-1 px-2 rounded">
              Ask about selection
            </button>
          </div>
        </div>

        <%= if String.length(@node.content || "") > @cut_off do %>
          <div class="flex justify-end">
            <button
              phx-click={show_modal("modal-" <> @node.id)}
              class="show_more_modal mt-2 text-blue-600 hover:text-blue-800 text-sm font-medium focus:outline-none"
            >
              Show more
            </button>
          </div>
        <% end %>
        <div class="prose prose-stone prose-sm tiny-text">
          <%= if @node.class == "user"  do %>
            By:{@node.user}
          <% else %>
            Generated
          <% end %>
          <%= if @show_user_controls do %>
            | {length(@node.noted_by)} ⭐ |
            <%= if Enum.any?(@node.noted_by, fn u -> u == @user end) do %>
              <button
                phx-click="unnote"
                phx-value-node={@node.id}
                tabindex="-1"
                class="text-red-600 hover:text-red-800 font-medium focus:outline-none"
              >
                Unnote
              </button>
            <% else %>
              <button
                phx-click="note"
                phx-value-node={@node.id}
                tabindex="-1"
                class="text-green-600 hover:text-green-800 font-medium focus:outline-none"
              >
                Note
              </button>
            <% end %>
            |
            <.link
              navigate={"?node=" <> @node.id}
              tabindex="-1"
              class="text-blue-600 hover:text-blue-400"
            >
              Link
            </.link>
            |
            <button
              phx-click="delete"
              data-confirm="Are you sure?"
              phx-value-node={@node.id}
              tabindex="-1"
              class="text-red-600 hover:text-red-800 font-medium focus:outline-none"
            >
              Delete
            </button>
            |
            <button
              phx-click="edit"
              phx-confirm="Are you sure?"
              phx-value-node={@node.id}
              tabindex="-1"
              class="text-red-600 hover:text-red-800 font-medium focus:outline-none"
            >
              Edit
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Add this helper function to handle message border styling
  defp message_border_class(class) do
    case class do
      # "user" -> "border-red-400"
      "answer" -> "border-blue-400"
      "thesis" -> "border-green-400"
      "antithesis" -> "border-red-400"
      "synthesis" -> "border-purple-600"
      _ -> "border border-gray-200 bg-white"
    end
  end
end
