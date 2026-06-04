defmodule DialecticWeb.GridChat do
  @moduledoc false

  alias Dialectic.Accounts.{GravatarCache, User}
  alias DialecticWeb.Presence
  alias Phoenix.PubSub

  require Phoenix.LiveView

  @max_message_length 500
  @message_stream_limit -100

  def default_assigns do
    %{
      presence_count: 0,
      chat_avatar_url: nil,
      chat_avatar_loading?: false,
      chat_avatar_loaded?: false,
      chat_form: empty_form()
    }
  end

  def empty_form, do: Phoenix.Component.to_form(%{}, as: :grid_chat)

  def topic(graph_id), do: "grid_chat:#{graph_id}"

  def subscribe(socket, graph_id) do
    PubSub.subscribe(Dialectic.PubSub, topic(graph_id))

    presence_key = presence_key(socket)

    Presence.track_user(presence_key, %{
      id: presence_key,
      graph_id: graph_id,
      display_name: base_display_name(socket.assigns[:current_user]),
      avatar_url: socket.assigns[:chat_avatar_url]
    })

    Presence.subscribe()

    socket
  end

  def init_streams(socket, graph_id) do
    presences =
      if Phoenix.LiveView.connected?(socket) do
        list_online_presences(graph_id)
      else
        []
      end

    socket
    |> Phoenix.LiveView.stream(:presences, presences)
    |> Phoenix.LiveView.stream(:chat_messages, [])
    |> Phoenix.Component.assign(:presence_count, length(presences))
  end

  def send_message(socket, message) do
    message = normalize_message(message)
    socket = Phoenix.Component.assign(socket, :chat_form, empty_form())

    if message == "" do
      socket
    else
      PubSub.broadcast(
        Dialectic.PubSub,
        topic(socket.assigns.graph_id),
        {:grid_chat_message, build_message(socket, message)}
      )

      Phoenix.LiveView.push_event(socket, "clear_grid_chat_form", %{})
    end
  end

  def open(socket) do
    socket
    |> maybe_load_avatar()
    |> update_presence_avatar()
    |> refresh_presences()
  end

  def handle_presence_join(socket, presence) do
    if connected_to_graph?(presence, socket.assigns.graph_id) do
      refresh_presences(socket)
    else
      socket
    end
  end

  def handle_presence_leave(socket, _presence), do: refresh_presences(socket)

  def insert_message(socket, message) do
    Phoenix.LiveView.stream_insert(socket, :chat_messages, message,
      at: -1,
      limit: @message_stream_limit
    )
  end

  def handle_avatar_result(socket, {:ok, {:ok, %{avatar_url: avatar_url}}}) do
    socket
    |> Phoenix.Component.assign(:chat_avatar_loading?, false)
    |> Phoenix.Component.assign(:chat_avatar_loaded?, true)
    |> Phoenix.Component.assign(:chat_avatar_url, avatar_url)
    |> update_presence_avatar()
    |> refresh_presences()
  end

  def handle_avatar_result(socket, {:ok, _result}) do
    socket
    |> Phoenix.Component.assign(:chat_avatar_loading?, false)
    |> Phoenix.Component.assign(:chat_avatar_loaded?, true)
  end

  def handle_avatar_result(socket, {:exit, _reason}) do
    socket
    |> Phoenix.Component.assign(:chat_avatar_loading?, false)
    |> Phoenix.Component.assign(:chat_avatar_loaded?, true)
  end

  def initials_for_name(name) do
    name
    |> to_string()
    |> String.split(~r/[\s_-]+/, trim: true)
    |> Enum.take(2)
    |> Enum.map(fn part ->
      part
      |> String.graphemes()
      |> List.first("")
    end)
    |> Enum.join()
    |> String.upcase()
    |> case do
      "" -> "?"
      initials -> initials
    end
  end

  defp normalize_message(message) do
    message
    |> to_string()
    |> String.trim()
    |> String.slice(0, @max_message_length)
  end

  defp maybe_load_avatar(%{assigns: %{chat_avatar_loaded?: true}} = socket), do: socket

  defp maybe_load_avatar(%{assigns: %{chat_avatar_loading?: true}} = socket), do: socket

  defp maybe_load_avatar(%{assigns: %{chat_avatar_url: url}} = socket)
       when is_binary(url) and url != "",
       do: Phoenix.Component.assign(socket, :chat_avatar_loaded?, true)

  defp maybe_load_avatar(%{assigns: %{current_user: %User{gravatar_id: gravatar_id}}} = socket)
       when is_binary(gravatar_id) and gravatar_id != "" do
    case GravatarCache.get(gravatar_id) do
      {:ok, %{avatar_url: avatar_url}} when is_binary(avatar_url) and avatar_url != "" ->
        socket
        |> Phoenix.Component.assign(:chat_avatar_url, avatar_url)
        |> Phoenix.Component.assign(:chat_avatar_loaded?, true)

      _ ->
        socket
        |> Phoenix.Component.assign(:chat_avatar_loading?, true)
        |> Phoenix.LiveView.start_async(:fetch_chat_avatar, fn ->
          GravatarCache.fetch(gravatar_id)
        end)
    end
  end

  defp maybe_load_avatar(socket), do: Phoenix.Component.assign(socket, :chat_avatar_loaded?, true)

  defp update_presence_avatar(%{assigns: %{chat_avatar_url: avatar_url}} = socket)
       when is_binary(avatar_url) and avatar_url != "" do
    if Phoenix.LiveView.connected?(socket) do
      presence_key = presence_key(socket)

      _ =
        Presence.update(self(), "online_users", presence_key, fn meta ->
          meta
          |> Map.put(:id, presence_key)
          |> Map.put(:graph_id, socket.assigns.graph_id)
          |> Map.put(:display_name, base_display_name(socket.assigns[:current_user]))
          |> Map.put(:avatar_url, avatar_url)
        end)
    end

    socket
  end

  defp update_presence_avatar(socket), do: socket

  defp refresh_presences(socket), do: refresh_presences(socket, socket.assigns.graph_id)

  defp refresh_presences(socket, graph_id) do
    presences = list_online_presences(graph_id)

    socket
    |> Phoenix.LiveView.stream(:presences, presences, reset: true)
    |> Phoenix.Component.assign(:presence_count, length(presences))
  end

  defp build_message(socket, message) do
    author = display_name(socket)

    %{
      id: Ecto.UUID.generate(),
      author_id: socket.assigns[:current_user] && socket.assigns.current_user.id,
      author: author,
      author_initials: initials_for_name(author),
      author_avatar_url: socket.assigns[:chat_avatar_url],
      body: message,
      sent_at_label: Calendar.strftime(DateTime.utc_now(), "%H:%M")
    }
  end

  defp display_name(%{assigns: %{current_user: %User{} = user}}), do: User.display_name(user)

  defp display_name(socket) do
    socket.assigns.graph_id
    |> guest_labels_by_key()
    |> Map.get(presence_key(socket), "Guest")
  end

  defp base_display_name(%User{} = user), do: User.display_name(user)
  defp base_display_name(_user), do: "Guest"

  defp presence_key(%{assigns: %{current_user: %User{id: user_id}}}) when not is_nil(user_id),
    do: "user:#{user_id}"

  defp presence_key(%{assigns: _assigns, id: socket_id})
       when is_binary(socket_id) and socket_id != "",
       do: "guest:#{socket_id}"

  defp presence_key(%{id: id}) when is_binary(id) and id != "", do: id

  defp presence_key(%{metas: [meta | _]}) do
    Map.get(meta, :id) || Map.get(meta, "id")
  end

  defp presence_key(_socket), do: "guest:#{:erlang.phash2(self())}"

  defp connected_to_graph?(%{metas: metas}, graph_id) do
    Enum.any?(metas, fn meta ->
      Map.get(meta, :graph_id) == graph_id or Map.get(meta, "graph_id") == graph_id
    end)
  end

  defp connected_to_graph?(_presence, _graph_id), do: false

  defp list_online_presences(graph_id) do
    presences = Presence.list_online_users(graph_id)
    labels_by_key = guest_labels_by_key(presences)

    Enum.map(presences, fn presence ->
      case Map.fetch(labels_by_key, presence_key(presence)) do
        {:ok, label} -> put_presence_display_name(presence, label)
        :error -> presence
      end
    end)
  end

  defp guest_labels_by_key(graph_id) when is_binary(graph_id) do
    graph_id
    |> Presence.list_online_users()
    |> guest_labels_by_key()
  end

  defp guest_labels_by_key(presences) when is_list(presences) do
    presences
    |> Enum.map(&presence_key/1)
    |> Enum.filter(&guest_key?/1)
    |> Enum.sort()
    |> Enum.with_index(1)
    |> Map.new(fn
      {key, 1} -> {key, "Guest"}
      {key, index} -> {key, "Guest #{index}"}
    end)
  end

  defp guest_key?("guest:" <> _socket_id), do: true
  defp guest_key?(_key), do: false

  defp put_presence_display_name(%{metas: metas} = presence, label) when is_list(metas) do
    %{presence | metas: Enum.map(metas, &Map.put(&1, :display_name, label))}
  end

  defp put_presence_display_name(presence, _label), do: presence
end
