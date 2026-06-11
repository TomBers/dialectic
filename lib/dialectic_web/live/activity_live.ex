defmodule DialecticWeb.ActivityLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts.User
  alias Dialectic.Follows
  alias Dialectic.GridActivity

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Activity")
     |> assign(:topic_form, to_form(%{"name" => ""}, as: :topic))
     |> assign_activity(user)}
  end

  @impl true
  def handle_event("follow_topic", %{"topic" => %{"name" => topic}}, socket) do
    user = socket.assigns.current_user

    socket =
      case Follows.follow_topic(user, topic) do
        {:ok, _follow} ->
          socket
          |> put_flash(:info, "Topic followed.")
          |> assign(:topic_form, to_form(%{"name" => ""}, as: :topic))

        {:error, _reason} ->
          put_flash(socket, :error, "Could not follow that topic.")
      end

    {:noreply, assign_activity(socket, user)}
  end

  def handle_event("unfollow_topic", %{"topic" => topic}, socket) do
    user = socket.assigns.current_user
    {:ok, _count} = Follows.unfollow_topic(user, topic)

    {:noreply,
     socket
     |> put_flash(:info, "Topic unfollowed.")
     |> assign_activity(user)}
  end

  def handle_event("mark_seen", _params, socket) do
    user = socket.assigns.current_user
    Follows.mark_seen(user)

    {:noreply,
     socket
     |> put_flash(:info, "Activity marked as seen.")
     |> assign_activity(user)}
  end

  defp assign_activity(socket, user) do
    socket
    |> assign(:follows, Follows.list_user_follows(user))
    |> assign(:activity_logs, Follows.list_activity_feed(user, limit: 75))
  end

  defp activity_time(nil), do: ""

  defp activity_time(inserted_at) do
    Calendar.strftime(inserted_at, "%d %b %Y, %H:%M")
  end

  defp follow_label(%{target_type: "graph", graph: %{title: title}}), do: title

  defp follow_label(%{target_type: "user", target_user: %User{} = user}),
    do: User.display_name(user)

  defp follow_label(%{target_type: "topic", topic: topic}), do: "##{topic}"
  defp follow_label(follow), do: follow.target_type

  defp follow_icon(%{target_type: "graph"}), do: "hero-squares-2x2"
  defp follow_icon(%{target_type: "user"}), do: "hero-user"
  defp follow_icon(%{target_type: "topic"}), do: "hero-tag"
  defp follow_icon(_follow), do: "hero-bell"

  defp node_label(%{metadata: %{"node_title" => title}}) when is_binary(title) and title != "" do
    title
  end

  defp node_label(%{node_id: node_id}) when is_binary(node_id) and node_id != "",
    do: "Node #{node_id}"

  defp node_label(_log), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div id="activity-page" class="min-h-screen bg-slate-50 px-4 py-8 sm:px-6 sm:py-10">
      <div class="mx-auto max-w-5xl">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-indigo-600">
              Followed updates
            </p>
            <h1 class="mt-1 text-3xl font-semibold tracking-tight text-slate-950">Activity</h1>
          </div>

          <button
            id="activity-mark-seen-button"
            type="button"
            phx-click="mark_seen"
            class="inline-flex items-center justify-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 shadow-sm transition hover:bg-slate-50"
          >
            <.icon name="hero-check" class="h-4 w-4" /> Mark seen
          </button>
        </div>

        <div class="mt-6 grid gap-4 lg:grid-cols-[18rem_minmax(0,1fr)]">
          <aside class="space-y-4">
            <section class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
              <h2 class="text-sm font-semibold text-slate-950">Follow a topic</h2>
              <.form
                for={@topic_form}
                id="activity-topic-follow-form"
                phx-submit="follow_topic"
                class="mt-3 space-y-3"
              >
                <.input field={@topic_form[:name]} type="text" label="Topic" placeholder="philosophy" />
                <button
                  id="activity-follow-topic-button"
                  type="submit"
                  class="inline-flex w-full items-center justify-center gap-1.5 rounded-xl bg-slate-950 px-3 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800"
                >
                  <.icon name="hero-plus" class="h-4 w-4" /> Follow topic
                </button>
              </.form>
            </section>

            <section class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
              <h2 class="text-sm font-semibold text-slate-950">Following</h2>
              <%= if @follows == [] do %>
                <p id="activity-following-empty" class="mt-3 text-sm leading-6 text-slate-500">
                  Follow a grid, user, or topic to build this feed.
                </p>
              <% else %>
                <div id="activity-following-list" class="mt-3 flex flex-wrap gap-2">
                  <%= for follow <- @follows do %>
                    <span class="inline-flex items-center gap-1.5 rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-xs font-semibold text-slate-700">
                      <.icon name={follow_icon(follow)} class="h-3.5 w-3.5" />
                      {follow_label(follow)}
                      <button
                        :if={follow.target_type == "topic"}
                        type="button"
                        phx-click="unfollow_topic"
                        phx-value-topic={follow.topic}
                        class="ml-0.5 text-slate-400 transition hover:text-red-600"
                        aria-label={"Unfollow " <> follow.topic}
                      >
                        <.icon name="hero-x-mark" class="h-3.5 w-3.5" />
                      </button>
                    </span>
                  <% end %>
                </div>
              <% end %>
            </section>
          </aside>

          <main>
            <%= if @activity_logs == [] do %>
              <div
                id="activity-feed-empty"
                class="rounded-2xl border border-slate-200 bg-white p-10 text-center shadow-sm"
              >
                <.icon name="hero-bell-alert" class="mx-auto h-10 w-10 text-slate-300" />
                <p class="mt-3 text-sm text-slate-500">No activity yet.</p>
              </div>
            <% else %>
              <ol
                id="activity-feed"
                class="divide-y divide-slate-100 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm"
              >
                <%= for log <- @activity_logs do %>
                  <li id={"activity-log-#{log.id}"} class="p-4 sm:p-5">
                    <div class="flex items-start gap-3">
                      <div class="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-indigo-50 text-indigo-600">
                        <.icon name="hero-bolt" class="h-4 w-4" />
                      </div>
                      <div class="min-w-0 flex-1">
                        <p class="text-sm font-medium leading-6 text-slate-900">
                          {GridActivity.display_message(log)}
                        </p>
                        <.link
                          navigate={graph_path(log.graph, log.node_id)}
                          class="mt-1 inline-flex max-w-full items-center gap-1.5 text-sm font-semibold text-indigo-700 hover:text-indigo-800"
                        >
                          <span class="truncate">{log.graph.title}</span>
                          <.icon name="hero-arrow-right" class="h-3.5 w-3.5 shrink-0" />
                        </.link>
                        <p :if={node_label(log)} class="mt-1 text-xs leading-5 text-slate-500">
                          {node_label(log)}
                        </p>
                        <p class="mt-2 text-xs text-slate-400">
                          {activity_time(log.inserted_at)}
                        </p>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ol>
            <% end %>
          </main>
        </div>
      </div>
    </div>
    """
  end
end
