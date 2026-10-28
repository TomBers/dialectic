defmodule DialecticWeb.AdminCuratedLive do
  use DialecticWeb, :live_view

  alias Dialectic.AdminDashboard
  alias Dialectic.DbActions.Graphs

  @sections ["curated", "featured"]
  @refresh_interval :timer.seconds(30)

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user && user.is_admin do
      if connected?(socket), do: Process.send_after(self(), :refresh_dashboard, @refresh_interval)

      socket =
        socket
        |> configure_grid_streams()
        |> assign(
          page_title: "Admin dashboard",
          dashboard: nil,
          dashboard_error: false,
          refreshing: false,
          search_term: "",
          search_form: to_form(%{"search" => ""}),
          note_form: to_form(%{"note" => ""}),
          add_section: "curated",
          add_note: ""
        )
        |> stream(:search_results, [])
        |> stream(:recent_users, [])
        |> stream(:recent_grids, [])
        |> stream(:queues, [])
        |> stream(:attention_jobs, [])
        |> refresh_curation()

      socket = if connected?(socket), do: refresh_dashboard(socket), else: socket
      {:ok, socket, layout: false}
    else
      {:ok, socket |> put_flash(:error, "Access denied.") |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(:refresh_dashboard, socket) do
    Process.send_after(self(), :refresh_dashboard, @refresh_interval)
    {:noreply, refresh_dashboard(socket)}
  end

  @impl true
  def handle_async(:dashboard, {:ok, {:ok, data}}, socket) do
    totals =
      Enum.reduce(data.queues, %{retrying: 0, failed: 0}, fn queue, acc ->
        Map.new(acc, fn {key, value} -> {key, value + Map.fetch!(queue, key)} end)
      end)

    dashboard =
      data
      |> Map.drop([:queues, :recent_users, :recent_grids, :attention_jobs])
      |> Map.put(:queue_totals, totals)

    {:noreply,
     socket
     |> assign(dashboard: dashboard, refreshing: false, dashboard_error: false)
     |> stream(:queues, data.queues, reset: true)
     |> stream(:recent_users, data.recent_users, reset: true)
     |> stream(:recent_grids, data.recent_grids, reset: true)
     |> stream(:attention_jobs, data.attention_jobs, reset: true)}
  end

  def handle_async(:dashboard, _result, socket) do
    {:noreply, assign(socket, refreshing: false, dashboard_error: true)}
  end

  @impl true
  def handle_event("refresh_dashboard", _params, socket) do
    {:noreply, refresh_dashboard(socket)}
  end

  def handle_event("search_graphs", %{"search" => term}, socket) do
    results =
      if String.trim(term) == "" do
        []
      else
        for {graph, _count, _author} <- Graphs.all_graphs_with_notes(term, limit: 20),
            do: %{id: graph.title, graph: graph}
      end

    {:noreply,
     socket
     |> assign(search_term: term, search_form: to_form(%{"search" => term}))
     |> stream(:search_results, results, reset: true)}
  end

  def handle_event("add_curated", %{"title" => title, "section" => section}, socket)
      when section in @sections do
    case Graphs.add_curated_grid(%{
           graph_title: title,
           curator_id: socket.assigns.current_user.id,
           section: section,
           note: socket.assigns.add_note
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added \"#{title}\" to #{section} section.")
         |> refresh_curation()
         |> reset_search()
         |> assign(add_note: "", note_form: to_form(%{"note" => ""}))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add grid.")}
    end
  end

  def handle_event("remove_curated", %{"title" => title, "section" => section}, socket)
      when section in @sections do
    Graphs.remove_curated_grid(title, section)

    {:noreply,
     socket |> put_flash(:info, "Removed \"#{title}\" from #{section}.") |> refresh_curation()}
  end

  def handle_event("set_section", %{"section" => section}, socket) when section in @sections do
    {:noreply, assign(socket, add_section: section)}
  end

  def handle_event("update_note", %{"note" => note}, socket) do
    {:noreply, assign(socket, add_note: note, note_form: to_form(%{"note" => note}))}
  end

  def handle_event("soft_delete", %{"title" => title}, socket) do
    case Graphs.soft_delete_graph(title) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Hidden \"#{title}\" from homepage.")
         |> refresh_curation()
         |> reset_search()
         |> refresh_dashboard()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to hide grid.")}
    end
  end

  def handle_event("restore_graph", %{"title" => title}, socket) do
    case Graphs.restore_graph(title) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Restored \"#{title}\" to homepage.")
         |> refresh_curation()
         |> refresh_dashboard()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to restore grid.")}
    end
  end

  defp refresh_dashboard(%{assigns: %{refreshing: true}} = socket), do: socket

  defp refresh_dashboard(socket) do
    user = socket.assigns.current_user

    socket
    |> assign(:refreshing, true)
    |> start_async(:dashboard, fn -> AdminDashboard.snapshot(user) end)
  end

  defp reset_search(socket) do
    socket
    |> assign(search_term: "", search_form: to_form(%{"search" => ""}))
    |> stream(:search_results, [], reset: true)
  end

  defp configure_grid_streams(socket) do
    Enum.reduce([:search_results, :curated, :featured, :hidden, :recent_grids], socket, fn name,
                                                                                           acc ->
      stream_configure(acc, name,
        dom_id: fn item -> "#{name}-" <> Base.url_encode64(to_string(item.id), padding: false) end
      )
    end)
  end

  defp refresh_curation(socket) do
    curated =
      for item <- Graphs.list_curated_grids("curated", 20),
          do: Map.put(item, :id, item.graph.title)

    featured =
      for item <- Graphs.list_curated_grids("featured", 20),
          do: Map.put(item, :id, item.graph.title)

    hidden =
      for {graph, author} <- Graphs.list_deleted_graphs(50),
          do: %{id: graph.title, graph: graph, author_name: author}

    socket
    |> assign(
      curated_count: length(curated),
      featured_count: length(featured),
      hidden_count: length(hidden)
    )
    |> stream(:curated, curated, reset: true)
    |> stream(:featured, featured, reset: true)
    |> stream(:hidden, hidden, reset: true)
  end

  defp number(value),
    do: value |> Integer.to_string() |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")

  defp timestamp(value), do: Calendar.strftime(value, "%d %b · %H:%M UTC")

  defp uptime(seconds) when seconds >= 86_400,
    do: "#{div(seconds, 86_400)}d #{div(rem(seconds, 86_400), 3_600)}h"

  defp uptime(seconds) when seconds >= 3_600,
    do: "#{div(seconds, 3_600)}h #{div(rem(seconds, 3_600), 60)}m"

  defp uptime(seconds), do: "#{div(seconds, 60)}m"
  defp queue_label("llm_request"), do: "AI responses"
  defp queue_label("api_request"), do: "API & email"
  defp queue_label("db_write"), do: "Grid saves"
  defp queue_label(queue), do: queue

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :detail, :string, required: true

  defp stat(assigns) do
    ~H"""
    <div id={@id} class="rounded-xl border border-stone-300 bg-white p-5">
      <div class="flex items-center justify-between gap-2">
        <h2 class="text-sm font-medium text-slate-600">{@label}</h2><.icon
          name={@icon}
          class="h-5 w-5 text-slate-500"
        />
      </div>
      <p class="mt-3 text-4xl font-semibold tracking-tight tabular-nums">{@value}</p>
      <p class="mt-2 text-xs leading-relaxed text-slate-500">{@detail}</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, required: true

  defp small_stat(assigns) do
    ~H"""
    <div class="rounded-lg border border-stone-300 p-4">
      <h3 class="text-xs font-medium text-slate-600">{@label}</h3><p class="mt-2 text-xl font-semibold tabular-nums">
        {@value}
      </p><p class="mt-1 text-xs text-slate-500">{@detail}</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp system_row(assigns) do
    ~H"""
    <div class="flex flex-wrap justify-between gap-2 py-2.5">
      <dt class="text-slate-500">{@label}</dt><dd class="font-medium">{@value}</dd>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :item, :map, required: true
  attr :section, :string, required: true

  defp curation_row(assigns) do
    ~H"""
    <div id={@id} class="flex flex-wrap items-center justify-between gap-3 py-3">
      <div class="min-w-0 flex-1 basis-48">
        <.link
          navigate={~p"/g/#{@item.graph.slug || @item.graph.title}"}
          class="break-words text-sm font-semibold hover:underline"
        >{@item.graph.title}</.link>
        <p class="mt-1 text-xs text-slate-500">
          {if @item.author_name, do: "by #{@item.author_name}"}{if @item.note && @item.note != "",
            do: " — #{@item.note}"}
        </p>
      </div>
      <button
        id={@id <> "-remove"}
        type="button"
        phx-click="remove_curated"
        phx-value-title={@item.graph.title}
        phx-value-section={@section}
        class="inline-flex min-h-11 items-center gap-1 rounded-lg px-3 py-2 text-sm font-semibold text-red-800 hover:bg-red-50"
      ><.icon name="hero-x-mark" class="h-4 w-4" /> Remove</button>
    </div>
    """
  end
end
