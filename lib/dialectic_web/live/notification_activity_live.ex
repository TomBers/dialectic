defmodule DialecticWeb.NotificationActivityLive do
  use DialecticWeb, :live_view

  alias Dialectic.Notifications
  alias Dialectic.Notifications.GraphEvent

  @event_limit 50

  @impl true
  def mount(_params, _session, socket) do
    scope = :owned
    events = list_events(socket.assigns.current_user, scope)
    follows = list_follows(socket.assigns.current_user, scope)

    {:ok,
     socket
     |> assign(:page_title, "Notification activity")
     |> assign(:event_limit, @event_limit)
     |> assign(:scope, scope)
     |> assign(:events_empty?, events == [])
     |> assign(:graph_follows, follows)
     |> assign(:graph_follows_empty?, follows == [])
     |> stream(:events, events)}
  end

  @impl true
  def handle_event("set_scope", %{"scope" => scope}, socket)
      when scope in ["owned", "followed"] do
    scope = String.to_existing_atom(scope)
    events = list_events(socket.assigns.current_user, scope)
    follows = list_follows(socket.assigns.current_user, scope)

    {:noreply,
     socket
     |> assign(:scope, scope)
     |> assign(:events_empty?, events == [])
     |> assign(:graph_follows, follows)
     |> assign(:graph_follows_empty?, follows == [])
     |> stream(:events, events, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-[calc(100vh-2.5rem)] bg-slate-50 px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-5xl">
        <div class="rounded-3xl border border-slate-200 bg-white shadow-sm">
          <div class="border-b border-slate-100 px-5 py-6 sm:px-8">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <p class="inline-flex items-center gap-2 rounded-full bg-indigo-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.14em] text-indigo-700 ring-1 ring-indigo-100">
                  <.icon name="hero-bell" class="h-3.5 w-3.5" /> Event stream preview
                </p>
                <h1 class="mt-4 text-2xl font-bold tracking-tight text-slate-950 sm:text-3xl">
                  Notification activity
                </h1>
                <p class="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
                  A read-only view of graph events that will power weekly digests and followed-grid notifications.
                </p>
              </div>

              <.link
                id="notification-activity-settings-link"
                navigate={~p"/users/settings"}
                class="inline-flex items-center justify-center rounded-xl border border-slate-200 bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-100"
              >
                <.icon name="hero-cog-6-tooth" class="mr-1.5 h-4 w-4" /> Settings
              </.link>
            </div>
          </div>

          <div class="px-5 py-5 sm:px-8">
            <div class="inline-flex rounded-2xl bg-slate-100 p-1 ring-1 ring-inset ring-slate-200">
              <button
                id="notification-scope-owned"
                type="button"
                phx-click="set_scope"
                phx-value-scope="owned"
                class={scope_tab_classes(@scope == :owned)}
              >
                My grids
              </button>
              <button
                id="notification-scope-followed"
                type="button"
                phx-click="set_scope"
                phx-value-scope="followed"
                class={scope_tab_classes(@scope == :followed)}
              >
                Followed grids
              </button>
            </div>
          </div>

          <div :if={@scope == :followed} class="px-5 pb-6 sm:px-8">
            <section
              id="followed-grids-section"
              class="rounded-2xl border border-slate-200 bg-slate-50 p-4"
            >
              <div class="flex items-center justify-between gap-3">
                <div>
                  <h2 class="text-sm font-semibold text-slate-950">Grids you follow</h2>
                  <p class="mt-1 text-sm text-slate-500">
                    These subscriptions will be used for followed-grid digests.
                  </p>
                </div>
                <span class="rounded-full bg-white px-3 py-1 text-xs font-semibold text-slate-600 ring-1 ring-slate-200">
                  {length(@graph_follows)} following
                </span>
              </div>

              <div
                :if={@graph_follows_empty?}
                id="followed-grids-empty"
                class="mt-4 rounded-xl border border-dashed border-slate-300 bg-white px-4 py-6 text-center text-sm text-slate-500"
              >
                You are not following any grids yet.
              </div>

              <div
                :if={!@graph_follows_empty?}
                id="followed-grids-list"
                class="mt-4 grid gap-3 sm:grid-cols-2"
              >
                <.link
                  :for={follow <- @graph_follows}
                  id={"followed-grid-#{follow.id}"}
                  navigate={graph_follow_path(follow)}
                  class="rounded-xl border border-slate-200 bg-white p-3 transition hover:border-indigo-200 hover:bg-indigo-50/40"
                >
                  <p class="truncate text-sm font-semibold text-slate-950">{follow.graph.title}</p>
                  <p class="mt-1 text-xs text-slate-500">Digest frequency: {follow.frequency}</p>
                </.link>
              </div>
            </section>
          </div>

          <div class="px-5 pb-8 sm:px-8">
            <div class="mb-3 flex items-center justify-between gap-3">
              <h2 class="text-sm font-semibold text-slate-950">
                {if @scope == :owned,
                  do: "Event activity for my grids",
                  else: "Event activity from followed grids"}
              </h2>
              <span class="text-xs font-medium text-slate-400">Latest #{@event_limit}</span>
            </div>

            <div id="notification-events" phx-update="stream" class="space-y-3">
              <div
                :if={@events_empty?}
                id="notification-events-empty"
                class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-slate-50 px-5 py-10 text-center"
              >
                <.icon name="hero-inbox" class="mx-auto h-8 w-8 text-slate-400" />
                <h2 class="mt-3 text-sm font-semibold text-slate-900">No events to show yet</h2>
                <p class="mt-1 text-sm text-slate-500">
                  Create, edit, follow, or share grids to populate this event preview.
                </p>
              </div>

              <div
                :for={{id, event} <- @streams.events}
                id={id}
                class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm transition hover:border-slate-300"
              >
                <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div class="min-w-0">
                    <div class="flex flex-wrap items-center gap-2">
                      <span class={event_badge_classes(event.event_type)}>
                        {event_label(event.event_type)}
                      </span>
                      <time class="text-xs font-medium text-slate-400">
                        {format_event_time(event.occurred_at)}
                      </time>
                    </div>

                    <h2 class="mt-2 truncate text-base font-semibold text-slate-950">
                      <.link navigate={graph_event_path(event)} class="hover:text-indigo-600">
                        {event.graph.title}
                      </.link>
                    </h2>

                    <p class="mt-1 text-sm text-slate-600">
                      {event.summary || event_label(event.event_type)}
                      <span :if={event.actor_user}>
                        by {event.actor_user.username || event.actor_user.email}
                      </span>
                    </p>
                  </div>

                  <div class="shrink-0 text-left sm:text-right">
                    <p class="text-xs font-semibold uppercase tracking-[0.14em] text-slate-400">
                      Operation
                    </p>
                    <p class="mt-1 rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700">
                      {event_operation(event)}
                    </p>
                  </div>
                </div>

                <div :if={metadata_items(event) != []} class="mt-4 flex flex-wrap gap-2">
                  <span
                    :for={{key, value} <- metadata_items(event)}
                    class="rounded-full bg-slate-50 px-2.5 py-1 text-xs font-medium text-slate-500 ring-1 ring-slate-200"
                  >
                    {key}: {inspect(value)}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp list_events(user, :owned) do
    Notifications.list_owned_graph_events(user, limit: @event_limit)
  end

  defp list_events(user, :followed) do
    Notifications.list_followed_graph_events(user, include_self?: true, limit: @event_limit)
  end

  defp list_follows(user, :followed), do: Notifications.list_graph_follows(user)
  defp list_follows(_user, :owned), do: []

  defp scope_tab_classes(true) do
    "rounded-xl bg-white px-4 py-2 text-sm font-semibold text-slate-950 shadow-sm ring-1 ring-slate-200"
  end

  defp scope_tab_classes(false) do
    "rounded-xl px-4 py-2 text-sm font-semibold text-slate-500 transition hover:text-slate-900"
  end

  defp event_badge_classes("graph.updated") do
    "inline-flex items-center rounded-full bg-blue-50 px-2.5 py-1 text-xs font-semibold text-blue-700 ring-1 ring-blue-100"
  end

  defp event_badge_classes("graph.created") do
    "inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700 ring-1 ring-emerald-100"
  end

  defp event_badge_classes("graph.shared") do
    "inline-flex items-center rounded-full bg-violet-50 px-2.5 py-1 text-xs font-semibold text-violet-700 ring-1 ring-violet-100"
  end

  defp event_badge_classes(_event_type) do
    "inline-flex items-center rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 ring-1 ring-slate-200"
  end

  defp event_label(event_type) do
    event_type
    |> String.replace("graph.", "")
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp event_operation(%GraphEvent{metadata: %{"operation" => operation}})
       when is_binary(operation) do
    operation |> String.replace("_", " ") |> String.capitalize()
  end

  defp event_operation(%GraphEvent{event_type: event_type}), do: event_label(event_type)

  defp metadata_items(%GraphEvent{metadata: metadata}) when is_map(metadata) do
    metadata
    |> Enum.reject(fn {key, _value} -> key == "operation" end)
    |> Enum.sort_by(fn {key, _value} -> key end)
  end

  defp metadata_items(_event), do: []

  defp graph_event_path(%GraphEvent{graph: %{slug: slug}}) when is_binary(slug) and slug != "" do
    ~p"/g/#{slug}"
  end

  defp graph_event_path(%GraphEvent{graph_title: graph_title}), do: ~p"/g/#{graph_title}"

  defp graph_follow_path(%{graph: %{slug: slug}}) when is_binary(slug) and slug != "" do
    ~p"/g/#{slug}"
  end

  defp graph_follow_path(%{graph_title: graph_title}), do: ~p"/g/#{graph_title}"

  defp format_event_time(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %-d, %Y at %H:%M")
  end

  defp format_event_time(%NaiveDateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %-d, %Y at %H:%M")
  end
end
