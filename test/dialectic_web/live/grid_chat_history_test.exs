defmodule DialecticWeb.GridChatHistoryTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  alias DialecticWeb.GridChat

  test "restores local history in order without broadcasting, deduplicates it and clears it", %{
    conn: conn
  } do
    graph = insert_graph(%{title: "Local chat history"})
    Phoenix.PubSub.subscribe(Dialectic.PubSub, GridChat.topic(graph.title))
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}/graph")
    first = message("First saved message")
    second = message("Second saved message")

    render_hook(view, "restore_grid_chat", %{messages: [first, first, second, %{"bad" => true}]})

    assert has_element?(view, "#chat_messages-#{first.id}")
    assert has_element?(view, "#chat_messages-#{first.id} + #chat_messages-#{second.id}")
    assert has_element?(view, "#grid-chat-toggle[aria-label='Open viewer chat, 2 messages']")
    refute_received {:grid_chat_message, _}

    render_hook(view, "restore_grid_chat", %{messages: [message("Repeated restore")]})
    assert has_element?(view, "#grid-chat-toggle[aria-label='Open viewer chat, 2 messages']")

    view |> element("#grid-chat-clear-history") |> render_click()
    refute has_element?(view, "#chat_messages-#{first.id}")
    assert has_element?(view, "#grid-chat-toggle[aria-label='Open viewer chat']")

    storage_key = GridChat.storage_key(graph.title, nil)
    assert_push_event(view, "grid_chat_history_cleared", %{storage_key: ^storage_key})

    render_hook(view, "sync_grid_chat_history", %{messages: [second]})
    assert has_element?(view, "#chat_messages-#{second.id}")
    render_hook(view, "sync_grid_chat_history", %{messages: []})
    refute has_element?(view, "#chat_messages-#{second.id}")
    assert has_element?(view, "#grid-chat-toggle[aria-label='Open viewer chat']")
    refute_push_event(view, "grid_chat_history_cleared", %{storage_key: ^storage_key})
  end

  test "restoration is bounded and rejects malformed messages", %{conn: conn} do
    graph = insert_graph(%{title: "Bounded chat history"})
    {:ok, view, _} = live(conn, ~p"/g/#{graph.slug}/graph")
    messages = for index <- 1..105, do: message("Saved #{index}")
    render_hook(view, "restore_grid_chat", %{messages: messages})

    refute has_element?(view, "#chat_messages-#{hd(messages).id}")
    assert has_element?(view, "#chat_messages-#{List.last(messages).id}")
    assert has_element?(view, "#grid-chat-toggle[aria-label='Open viewer chat, 100 messages']")
  end

  test "storage keys isolate grids, guests and accounts" do
    user = %{id: 1}
    refute GridChat.storage_key("A", user) == GridChat.storage_key("B", user)
    refute GridChat.storage_key("A", user) == GridChat.storage_key("A", %{id: 2})
    refute GridChat.storage_key("A", user) == GridChat.storage_key("A", nil)
  end

  defp message(body) do
    %{
      id: Ecto.UUID.generate(),
      author: "Local viewer",
      author_id: nil,
      body: body,
      sent_at_label: "09:47"
    }
  end
end
