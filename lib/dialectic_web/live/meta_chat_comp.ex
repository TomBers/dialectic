defmodule DialecticWeb.MetaChatComp do
  use DialecticWeb, :live_component

  alias Dialectic.Accounts.Chat
  alias Dialectic.Repo
  alias Phoenix.PubSub
  import Ecto.Query

  @impl true
  def update(%{graph_id: graph_id} = assigns, socket) do
    if connected?(socket) do
      # Subscribe to chat updates for this page
      PubSub.subscribe(Dialectic.PubSub, "chat:#{graph_id}")
    end

    chats =
      Chat
      |> where([c], c.graph_title == ^graph_id)
      |> order_by([c], asc: c.inserted_at)
      |> limit(50)
      |> Repo.all()
      |> Repo.preload(:user)

    # Initialize empty chat with defaults
    chat_changeset =
      Chat.changeset(%Chat{}, %{
        graph_title: graph_id
      })

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:chats, chats)
     |> assign(:page, 1)
     |> assign(:has_more, chats_count(graph_id) > 50)
     |> assign(:is_open, false)
     |> assign(:unread_count, 0)
     |> assign(:chat_changeset, chat_changeset)
     |> assign(:chat_form, to_form(chat_changeset))}
  end

  @impl true
  def update(%{data: data} = _assigns, socket) do
    chat = Repo.preload(data, :user)

    # Check if this chat is already in our list (to avoid duplication)
    already_exists = Enum.any?(socket.assigns.chats, fn existing -> existing.id == chat.id end)

    # Only add the chat if it doesn't already exist in our list
    chats = if already_exists, do: socket.assigns.chats, else: socket.assigns.chats ++ [chat]

    # Increment unread count if chat is closed
    unread_count =
      if socket.assigns.is_open do
        socket.assigns.unread_count
      else
        socket.assigns.unread_count + 1
      end

    {:ok,
     socket
     |> assign(:chats, chats)
     |> assign(:unread_count, unread_count)
     |> push_event("chat_updated", %{})}
  end

  @impl true
  def handle_event("send_message", %{"chat" => chat_params}, socket) do
    %{current_user: current_user, graph_id: graph_id} = socket.assigns

    # Combine form data with required fields
    user_id =
      if current_user do
        current_user.id
      else
        "Anon"
      end

    params =
      Map.merge(chat_params, %{
        "user_id" => user_id,
        "graph_title" => graph_id
      })

    # Create a changeset with the complete params
    chat_changeset = Chat.changeset(%Chat{}, params)

    case Repo.insert(chat_changeset) do
      {:ok, chat} ->
        # Broadcast the new chat message to all subscribers
        PubSub.broadcast(Dialectic.PubSub, "chat:#{graph_id}", {:new_chat, chat})

        # Create a fresh changeset for the form
        new_changeset =
          Chat.changeset(%Chat{}, %{
            "graph_title" => graph_id
          })

        {:noreply,
         socket
         |> assign(:chat_changeset, new_changeset)
         |> assign(:chat_form, to_form(new_changeset))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:chat_changeset, changeset)
         |> assign(:chat_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_chat", _, socket) do
    is_open = socket.assigns.is_open

    {:noreply,
     socket
     |> assign(:is_open, !is_open)
     |> assign(:unread_count, 0)}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    %{graph_id: graph_id, page: page, chats: current_chats} = socket.assigns

    new_page = page + 1
    offset = 50 * (new_page - 1)

    more_chats =
      Chat
      |> where([c], c.graph_title == ^graph_id)
      |> order_by([c], asc: c.inserted_at)
      |> limit(50)
      |> offset(^offset)
      |> Repo.all()
      |> Repo.preload(:user)

    has_more = length(more_chats) == 50

    {:noreply,
     socket
     |> assign(:page, new_page)
     |> assign(:has_more, has_more)
     |> assign(:chats, current_chats ++ more_chats)}
  end

  defp chats_count(graph_id) do
    Chat
    |> where([c], c.graph_title == ^graph_id)
    |> Repo.aggregate(:count)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chat-widget">
      <button class="chat-toggle-button" phx-click="toggle_chat" phx-target={@myself}>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="chat-icon"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path
            fill-rule="evenodd"
            d="M18 10c0 3.866-3.582 7-8 7a8.841 8.841 0 01-4.083-.98L2 17l1.338-3.123C2.493 12.767 2 11.434 2 10c0-3.866 3.582-7 8-7s8 3.134 8 7zM7 9H5v2h2V9zm8 0h-2v2h2V9zM9 9h2v2H9V9z"
            clip-rule="evenodd"
          />
        </svg>
        <%= if @unread_count > 0 do %>
          <span class="unread-badge">{@unread_count}</span>
        <% end %>
      </button>

      <div class={"chat-container #{if @is_open, do: "open", else: "closed"}"}>
        <div class="chat-header">
          <h3>Chat</h3>
          <button class="close-button" phx-click="toggle_chat" phx-target={@myself}>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="close-icon"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                clip-rule="evenodd"
              />
            </svg>
          </button>
        </div>

        <div class="chat-messages" id="chat-messages" phx-hook="ChatScroll" phx-update="append">
          <%= for chat <- @chats do %>
            <div
              class={"message #{if @current_user && chat.user_id == @current_user.id, do: "message-self", else: ""}"}
              id={"chat-#{chat.id}"}
            >
              <div class="message-header">
                <span class="username">{chat.user.email}</span>
                <span class="timestamp">{format_timestamp(chat.inserted_at)}</span>
              </div>
              <div class="message-body">
                {chat.message}
              </div>
            </div>
          <% end %>
        </div>

        <.form for={@chat_form} phx-submit="send_message" phx-target={@myself} class="chat-form">
          <.input
            field={@chat_form[:message]}
            phx-reset
            type="text"
            placeholder="Type your message..."
          />
          <.button type="submit">Send</.button>
        </.form>
      </div>

      <style>
        .chat-widget {
          position: fixed;
          bottom: 20px;
          right: 20px;
          z-index: 1000;
        }

        .chat-toggle-button {
          width: 60px;
          height: 60px;
          border-radius: 50%;
          background-color: #3b82f6;
          color: white;
          border: none;
          box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
          cursor: pointer;
          position: relative;
          transition: all 0.2s ease;
        }

        .chat-toggle-button:hover {
          background-color: #2563eb;
          transform: translateY(-2px);
        }

        .chat-icon {
          width: 30px;
          height: 30px;
        }

        .unread-badge {
          position: absolute;
          top: -5px;
          right: -5px;
          background-color: #ef4444;
          color: white;
          border-radius: 50%;
          width: 24px;
          height: 24px;
          font-size: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-weight: bold;
        }

        .chat-container {
          position: absolute;
          bottom: 80px;
          right: 0;
          width: 350px;
          height: 500px;
          background-color: white;
          border-radius: 0.5rem;
          box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
          display: flex;
          flex-direction: column;
          transition: all 0.3s ease;
          border: 1px solid #e2e8f0;
        }

        .chat-container.closed {
          opacity: 0;
          transform: translateY(20px);
          pointer-events: none;
        }

        .chat-container.open {
          opacity: 1;
          transform: translateY(0);
          pointer-events: auto;
        }

        .chat-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 0.75rem 1rem;
          border-bottom: 1px solid #e2e8f0;
          background-color: #f8fafc;
          border-radius: 0.5rem 0.5rem 0 0;
        }

        .chat-header h3 {
          margin: 0;
          color: #1e40af;
          font-size: 1.125rem;
        }

        .close-button {
          background: none;
          border: none;
          cursor: pointer;
          color: #64748b;
        }

        .close-icon {
          width: 20px;
          height: 20px;
        }

        .chat-messages {
          flex-grow: 1;
          overflow-y: auto;
          padding: 1rem;
          display: flex;
          flex-direction: column;
          gap: 0.75rem;
          background-color: #f8fafc;
        }

        .message {
          max-width: 70%;
          padding: 0.75rem;
          border-radius: 0.5rem;
          background-color: #e2e8f0;
          box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
          align-self: flex-start;
        }

        .message-self {
          align-self: flex-end;
          background-color: #bfdbfe;
        }

        .message-header {
          display: flex;
          justify-content: space-between;
          font-size: 0.875rem;
          margin-bottom: 0.25rem;
        }

        .username {
          font-weight: bold;
          color: #1e40af;
        }

        .timestamp {
          color: #64748b;
        }

        .message-body {
          word-break: break-word;
        }

        .chat-form {
          display: flex;
          padding: 0.75rem;
          border-top: 1px solid #e2e8f0;
          background-color: white;
          border-radius: 0 0 0.5rem 0.5rem;
          gap: 0.5rem;
        }

        .chat-form input {
          flex-grow: 1;
        }
      </style>
    </div>
    """
  end

  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%H:%M:%S")
  end
end
