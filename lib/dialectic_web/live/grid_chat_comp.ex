defmodule DialecticWeb.GridChatComp do
  @moduledoc false
  use DialecticWeb, :html

  attr :graph_id, :any, required: true
  attr :presence_count, :integer, default: 0

  def grid_chat_toggle(assigns) do
    ~H"""
    <div class="pointer-events-none absolute left-4 top-4 z-20">
      <button
        :if={@graph_id}
        id="grid-chat-toggle"
        type="button"
        phx-click={JS.dispatch("toggle-panel", to: "#graph-layout", detail: %{id: "chat-drawer"})}
        data-panel-toggle="chat-drawer"
        class="pointer-events-auto inline-flex items-center gap-2 rounded-full border border-slate-200/90 bg-white/95 px-3 py-2 text-xs font-semibold text-slate-700 shadow-[0_18px_30px_-24px_rgba(15,23,42,0.55)] ring-1 ring-white/80 backdrop-blur transition hover:border-indigo-200 hover:bg-indigo-50 hover:text-indigo-800"
        aria-controls="chat-drawer"
        aria-label="Open viewer chat"
        title="Open viewer chat"
      >
        <span class="relative inline-flex h-7 w-7 items-center justify-center rounded-full bg-indigo-100 text-indigo-700 ring-1 ring-indigo-200">
          <.icon name="hero-user-group" class="h-4 w-4" />
          <span class="absolute -right-1 -top-1 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-slate-900 px-1 text-[9px] font-bold leading-none text-white ring-2 ring-white">
            {@presence_count}
          </span>
        </span>
        <span>{viewer_count_label(@presence_count)}</span>
        <span class="hidden h-4 w-px bg-slate-200 md:block"></span>
        <span class="hidden text-[10px] font-semibold uppercase tracking-[0.14em] text-indigo-600 md:inline">
          Chat
        </span>
      </button>
    </div>
    """
  end

  attr :presences, :any, required: true
  attr :messages, :any, required: true
  attr :chat_form, :any, required: true

  def grid_chat_drawer(assigns) do
    ~H"""
    <div
      id="chat-drawer"
      data-right-drawer
      class="absolute inset-y-0 right-0 z-50 w-0 overflow-hidden border-l border-gray-200 bg-white opacity-0 transform translate-x-full transition-all duration-300 ease-in-out"
    >
      <div class="flex h-full flex-col">
        <div class="border-b border-slate-200 px-3 py-3">
          <div class="mb-3 flex items-start justify-between gap-3">
            <div>
              <h2 class="text-sm font-semibold text-slate-900">Viewer chat</h2>
              <p class="mt-0.5 text-[11px] leading-4 text-slate-500">
                Ephemeral messages for people currently viewing this grid.
              </p>
            </div>
            <button
              type="button"
              phx-click={
                JS.dispatch("toggle-panel", to: "#graph-layout", detail: %{id: "chat-drawer"})
              }
              class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md border border-gray-200 text-gray-600 transition hover:bg-gray-50"
              aria-label="Close viewer chat"
              title="Close panel"
            >
              <.icon name="hero-x-mark" class="h-4 w-4" />
            </button>
          </div>

          <div>
            <p class="mb-2 text-[10px] font-semibold uppercase tracking-[0.14em] text-slate-500">
              Currently viewing
            </p>
            <div id="grid-chat-viewers" phx-update="stream" class="flex flex-wrap gap-1.5">
              <div
                id="grid-chat-viewers-empty"
                class="hidden only:flex rounded-full border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs text-slate-500"
              >
                No active viewers
              </div>
              <div
                :for={{presence_dom_id, presence} <- @presences}
                id={presence_dom_id}
                class="inline-flex max-w-full items-center gap-1.5 rounded-full border border-slate-200 bg-white px-2 py-1 text-xs font-medium text-slate-700 shadow-sm"
                title={presence_title(presence)}
              >
                <span class="inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-indigo-100 text-[9px] font-bold uppercase text-indigo-700 ring-1 ring-indigo-200">
                  {presence_initials(presence)}
                </span>
                <span class="truncate">{presence_label(presence)}</span>
                <span
                  :if={presence_session_count(presence) > 1}
                  class="shrink-0 rounded-full bg-slate-100 px-1.5 py-0.5 text-[10px] font-semibold text-slate-600"
                >
                  {presence_session_count(presence)}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div
          id="grid-chat-messages"
          phx-update="stream"
          class="min-h-0 flex-1 space-y-3 overflow-y-auto px-3 py-3"
        >
          <div
            id="grid-chat-messages-empty"
            class="hidden only:flex h-full items-center justify-center rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-4 py-8 text-center text-sm text-slate-500"
          >
            No messages yet. Start the conversation with the people viewing this grid.
          </div>
          <div :for={{message_dom_id, message} <- @messages} id={message_dom_id}>
            <div class="flex items-start gap-2.5">
              <span class="mt-0.5 inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-slate-900 text-[10px] font-bold uppercase text-white shadow-sm">
                {message.author_initials}
              </span>
              <div class="min-w-0 flex-1 rounded-2xl border border-slate-200 bg-slate-50 px-3 py-2">
                <div class="mb-1 flex items-center justify-between gap-2">
                  <span class="truncate text-xs font-semibold text-slate-900">
                    {message.author}
                  </span>
                  <span class="shrink-0 text-[10px] font-medium text-slate-400">
                    {message.sent_at_label}
                  </span>
                </div>
                <p class="whitespace-pre-wrap break-words text-sm leading-5 text-slate-700">
                  {message.body}
                </p>
              </div>
            </div>
          </div>
        </div>

        <div class="border-t border-slate-200 bg-white p-3">
          <.form for={@chat_form} id="grid-chat-form" phx-submit="send_grid_chat" class="space-y-2">
            <.input
              field={@chat_form[:message]}
              type="text"
              label="Message viewers"
              placeholder="Message everyone viewing this grid..."
              maxlength="500"
              autocomplete="off"
            />
            <div class="flex justify-end">
              <button
                type="submit"
                class="inline-flex items-center gap-1.5 rounded-full bg-slate-900 px-3.5 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-700"
              >
                Send <.icon name="hero-paper-airplane" class="h-4 w-4" />
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp viewer_count_label(1), do: "1 viewing"
  defp viewer_count_label(count), do: "#{count} viewing"

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
    |> initials_for_name()
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

  defp initials_for_name(name) do
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
end
