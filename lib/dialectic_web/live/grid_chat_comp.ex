defmodule DialecticWeb.GridChatComp do
  @moduledoc false
  use DialecticWeb, :html

  attr :graph_id, :any, required: true
  attr :presence_count, :integer, default: 0
  attr :avatar_url, :string, default: nil
  attr :current_user, :any, default: nil

  def grid_chat_toggle(assigns) do
    ~H"""
    <div class="pointer-events-none absolute left-4 top-4 z-20">
      <button
        :if={@graph_id}
        id="grid-chat-toggle"
        type="button"
        phx-click={JS.dispatch("toggle-panel", to: "#graph-layout", detail: %{id: "chat-drawer"})}
        data-panel-toggle="chat-drawer"
        class="pointer-events-auto inline-flex items-center gap-2 rounded-full border border-slate-200/90 bg-white/96 px-2.5 py-1.5 text-xs font-semibold text-slate-700 shadow-[0_18px_30px_-24px_rgba(15,23,42,0.55)] ring-1 ring-white/80 backdrop-blur transition hover:border-indigo-200/80 hover:bg-indigo-50/80 hover:text-indigo-800"
        aria-controls="chat-drawer"
        aria-label="Open viewer chat"
        title="Open viewer chat"
      >
        <span class="relative inline-flex h-8 w-8 items-center justify-center overflow-visible rounded-full bg-gradient-to-br from-indigo-100 via-white to-violet-100 text-indigo-700 ring-1 ring-indigo-200/90 shadow-sm">
          <img
            :if={avatar_url?(@avatar_url)}
            src={@avatar_url}
            alt={chat_avatar_alt(@current_user)}
            class="h-8 w-8 rounded-full object-cover"
          />
          <.icon :if={!avatar_url?(@avatar_url)} name="hero-user-group" class="h-4 w-4" />
          <span class="absolute -right-1 -top-1 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-slate-900 px-1 text-[9px] font-bold leading-none text-white ring-2 ring-white">
            {@presence_count}
          </span>
        </span>
      </button>
    </div>
    """
  end

  attr :presences, :any, required: true
  attr :messages, :any, required: true
  attr :chat_form, :any, required: true
  attr :presence_count, :integer, default: 0
  attr :current_user, :any, default: nil
  attr :avatar_url, :string, default: nil

  def grid_chat_drawer(assigns) do
    ~H"""
    <div
      id="chat-drawer"
      data-right-drawer
      class="absolute inset-y-0 right-0 z-50 w-0 overflow-hidden border-l border-slate-200/90 bg-[linear-gradient(180deg,_rgba(248,250,252,0.98)_0%,_rgba(255,255,255,0.98)_16%,_rgba(248,250,252,0.98)_100%)] opacity-0 shadow-[-28px_0_50px_-40px_rgba(15,23,42,0.42)] transform translate-x-full transition-all duration-300 ease-in-out"
    >
      <div class="flex h-full min-h-0 flex-col">
        <div class="border-b border-slate-200/90 bg-white/92 px-4 py-3 backdrop-blur">
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <div class="flex items-center gap-3">
                <span class="inline-flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-2xl bg-gradient-to-br from-indigo-100 via-white to-violet-100 text-indigo-700 ring-1 ring-indigo-200/90 shadow-sm">
                  <img
                    :if={avatar_url?(@avatar_url)}
                    src={@avatar_url}
                    alt={chat_avatar_alt(@current_user)}
                    class="h-10 w-10 object-cover"
                  />
                  <.icon
                    :if={!avatar_url?(@avatar_url)}
                    name="hero-chat-bubble-left-right"
                    class="h-5 w-5"
                  />
                </span>
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2">
                    <h2 class="truncate text-lg font-semibold tracking-tight text-slate-950">
                      Chat
                    </h2>
                    <span class="inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-2 py-0.5 text-[11px] font-semibold text-emerald-700 ring-1 ring-inset ring-emerald-200/80">
                      <span class="h-1.5 w-1.5 rounded-full bg-emerald-500"></span>
                      {viewer_count_label(@presence_count)}
                    </span>
                  </div>
                </div>
              </div>
            </div>
            <button
              type="button"
              phx-click={
                JS.dispatch("toggle-panel", to: "#graph-layout", detail: %{id: "chat-drawer"})
              }
              class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl border border-slate-200 bg-white/90 text-slate-500 shadow-sm transition hover:border-slate-300 hover:bg-slate-50 hover:text-slate-800"
              aria-label="Close viewer chat"
              title="Close panel"
            >
              <.icon name="hero-x-mark" class="h-4 w-4" />
            </button>
          </div>

          <div class="mt-2 rounded-xl border border-slate-200/80 bg-slate-50/80 px-2 py-1.5 ring-1 ring-white/80">
            <div class="flex items-center gap-1.5">
              <p class="shrink-0 text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-400">
                Online
              </p>
              <div
                id="grid-chat-viewers"
                phx-update="stream"
                class="flex min-w-0 flex-1 items-center gap-1.5 overflow-x-auto"
              >
                <span
                  id="grid-chat-viewers-empty"
                  class="hidden only:flex shrink-0 rounded-full border border-slate-200 bg-white px-2 py-0.5 text-[11px] text-slate-500 shadow-sm"
                >
                  Just you
                </span>
                <div
                  :for={{presence_dom_id, presence} <- @presences}
                  id={presence_dom_id}
                  class="inline-flex max-w-full shrink-0 items-center gap-1.5 rounded-full border border-slate-200/90 bg-white px-2 py-1 text-[11px] font-medium text-slate-700 shadow-sm ring-1 ring-white/80"
                  title={presence_title(presence)}
                >
                  <span class="relative inline-flex h-5 w-5 shrink-0 items-center justify-center overflow-visible rounded-full bg-gradient-to-br from-indigo-100 via-white to-violet-100 text-[8px] font-bold uppercase text-indigo-700 ring-1 ring-indigo-200/90">
                    <span class="absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full bg-emerald-500 ring-2 ring-white">
                    </span>
                    <img
                      :if={avatar_url?(presence_avatar_url(presence))}
                      src={presence_avatar_url(presence)}
                      alt={presence_avatar_alt(presence)}
                      class="h-5 w-5 rounded-full object-cover"
                    />
                    <span :if={!avatar_url?(presence_avatar_url(presence))}>
                      {presence_initials(presence)}
                    </span>
                  </span>
                  <span class="truncate">{presence_label(presence)}</span>
                  <span
                    :if={presence_session_count(presence) > 1}
                    class="shrink-0 rounded-full bg-slate-100 px-1.5 py-0.5 text-[10px] font-semibold text-slate-600 ring-1 ring-inset ring-slate-200"
                  >
                    {presence_session_count(presence)}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div
          id="grid-chat-messages"
          phx-update="stream"
          phx-hook="ChatScroll"
          class="min-h-0 flex-1 space-y-0.5 overflow-y-auto bg-[linear-gradient(180deg,_rgba(248,250,252,0.45)_0%,_rgba(255,255,255,0.25)_18%,_rgba(248,250,252,0.72)_100%)] px-2.5 py-3"
        >
          <div
            id="grid-chat-messages-empty"
            class="hidden only:flex h-full items-center justify-center px-3 py-10 text-center"
          >
            <div class="max-w-sm rounded-[1.5rem] border border-dashed border-slate-200 bg-white/80 px-5 py-8 shadow-[0_12px_28px_-26px_rgba(15,23,42,0.32)]">
              <p class="text-sm font-semibold text-slate-800">No messages yet</p>
              <p class="mt-1 text-sm leading-6 text-slate-500">
                Start the conversation with the people currently exploring this grid.
              </p>
            </div>
          </div>
          <div :for={{message_dom_id, message} <- @messages} id={message_dom_id}>
            <div class={message_row_classes(message, @current_user)}>
              <div class="min-w-0">
                <div class="flex flex-wrap items-baseline gap-x-1.5 gap-y-0.5">
                  <span class={[
                    "inline-flex h-4 w-4 shrink-0 translate-y-0.5 items-center justify-center overflow-hidden rounded-full text-[7px] font-bold uppercase ring-1 ring-white/90",
                    authored_by_current_user?(message, @current_user) &&
                      "bg-gradient-to-br from-indigo-600 to-violet-600 text-white",
                    !authored_by_current_user?(message, @current_user) &&
                      "bg-slate-900 text-white"
                  ]}>
                    <img
                      :if={avatar_url?(message_avatar_url(message))}
                      src={message_avatar_url(message)}
                      alt={message_avatar_alt(message)}
                      class="h-4 w-4 object-cover"
                    />
                    <span :if={!avatar_url?(message_avatar_url(message))}>
                      {message.author_initials}
                    </span>
                  </span>
                  <span class="inline-flex items-baseline gap-x-1.5 leading-5">
                    <span class={message_author_classes(message, @current_user)}>
                      {message.author}
                    </span>
                    <span class="text-[11px] font-medium leading-4 text-slate-400">
                      {message.sent_at_label}
                    </span>
                  </span>
                  <p class={message_body_classes(message, @current_user)}>
                    {message_body_html(message)}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="border-t border-slate-200/90 bg-white/94 px-2.5 py-2 backdrop-blur">
          <.form
            for={@chat_form}
            id="grid-chat-form"
            phx-submit="send_grid_chat"
            phx-hook="GridChatForm"
            class="flex items-end gap-2"
          >
            <div class="min-w-0 flex-1 [&_label]:sr-only">
              <.input
                field={@chat_form[:message]}
                type="textarea"
                label="Message viewers"
                placeholder="Message everyone viewing this grid"
                maxlength="500"
                autocomplete="off"
                rows="1"
                phx-hook="AutoExpandTextarea"
                class="box-border block w-full overflow-hidden rounded-xl border border-slate-200/90 bg-white px-3 py-2 text-sm leading-5 text-slate-900 shadow-[inset_0_1px_2px_rgba(15,23,42,0.04)] transition placeholder:text-slate-400 focus:border-indigo-300 focus:outline-none focus:ring-4 focus:ring-indigo-100/80 resize-none min-h-[2.5rem] [--auto-expand-max-height:9rem] [--auto-expand-border-threshold:6]"
              />
            </div>
            <button
              type="submit"
              class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-slate-900 text-white shadow-[0_12px_24px_-18px_rgba(15,23,42,0.8)] transition hover:bg-slate-800"
              aria-label="Send message"
              title="Send"
            >
              <.icon name="hero-paper-airplane" class="h-4 w-4" />
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp viewer_count_label(1), do: "1 viewer"
  defp viewer_count_label(count), do: "#{count} viewers"

  defp authored_by_current_user?(%{author_id: author_id}, %{id: current_user_id})
       when not is_nil(author_id) and not is_nil(current_user_id) do
    author_id == current_user_id
  end

  defp authored_by_current_user?(_message, _current_user), do: false

  defp message_row_classes(message, current_user) do
    [
      "-mx-1 rounded-xl px-1 py-1.5 transition-colors",
      authored_by_current_user?(message, current_user) && "hover:bg-indigo-50/60",
      !authored_by_current_user?(message, current_user) && "hover:bg-slate-100/80"
    ]
  end

  defp message_author_classes(message, current_user) do
    [
      "text-[12px] font-semibold leading-5",
      authored_by_current_user?(message, current_user) && "text-indigo-700",
      !authored_by_current_user?(message, current_user) && "text-slate-900"
    ]
  end

  defp message_body_classes(message, current_user) do
    [
      "min-w-0 flex-[1_1_100%] break-words text-left text-sm leading-5 [overflow-wrap:anywhere] sm:flex-1",
      authored_by_current_user?(message, current_user) && "text-slate-800",
      !authored_by_current_user?(message, current_user) && "text-slate-700"
    ]
  end

  defp message_body_html(message) do
    message
    |> message_body_text()
    |> String.split(~r/\R/u, trim: false)
    |> Enum.map_join("<br>", fn line ->
      line
      |> html_escape()
      |> safe_to_string()
    end)
    |> raw()
  end

  defp message_body_text(message), do: String.trim(to_string(message.body || ""))

  defp avatar_url?(url), do: is_binary(url) and url != ""

  defp chat_avatar_alt(_current_user), do: "Your profile image"

  defp presence_avatar_url(presence) do
    presence
    |> presence_first_meta()
    |> avatar_url_from_meta()
  end

  defp presence_avatar_alt(presence), do: "#{presence_label(presence)} profile image"

  defp message_avatar_url(message) do
    Map.get(message, :author_avatar_url) || Map.get(message, "author_avatar_url")
  end

  defp message_avatar_alt(message), do: "#{Map.get(message, :author, "Guest")} profile image"

  defp avatar_url_from_meta(%{avatar_url: avatar_url}) when is_binary(avatar_url),
    do: avatar_url

  defp avatar_url_from_meta(%{"avatar_url" => avatar_url}) when is_binary(avatar_url),
    do: avatar_url

  defp avatar_url_from_meta(_meta), do: nil

  defp presence_label(presence) do
    presence
    |> presence_first_meta()
    |> case do
      %{display_name: display_name} when is_binary(display_name) and display_name != "" ->
        display_name

      %{"display_name" => display_name} when is_binary(display_name) and display_name != "" ->
        display_name

      _ ->
        "Guest"
    end
  end

  defp presence_initials(presence) do
    presence
    |> presence_label()
    |> DialecticWeb.GridChat.initials_for_name()
  end

  defp presence_session_count(%{metas: metas}) when is_list(metas), do: length(metas)
  defp presence_session_count(_presence), do: 1

  defp presence_title(presence) do
    label = presence_label(presence)
    session_count = presence_session_count(presence)

    if session_count > 1 do
      "#{label} (#{session_count} sessions)"
    else
      label
    end
  end

  defp presence_first_meta(%{metas: [meta | _]}), do: meta
  defp presence_first_meta(_presence), do: %{}
end
