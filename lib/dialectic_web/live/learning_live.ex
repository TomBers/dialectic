defmodule DialecticWeb.LearningLive do
  use DialecticWeb, :live_view

  alias Dialectic.Learning
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Learning.CollectionGrid

  @page_size 24

  @impl true
  def mount(_params, _session, socket) do
    {:ok, _} = Learning.initialize_topics(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(
       page_title: "My Learning",
       noindex: true,
       collection: nil,
       adding?: false,
       editing?: false,
       search: "",
       search_form: to_form(%{"q" => ""}),
       collection_form: to_form(Learning.change_collection()),
       edit_form: nil,
       saved_kind: "all",
       collection_options: [],
       organise_title: nil,
       organise_form: to_form(Ecto.Changeset.change(%CollectionGrid{}), as: :membership),
       graph_to_delete: nil,
       more?: false,
       offset: 0
     )
     |> stream_configure(:grids, dom_id: &grid_id/1)
     |> stream(:grids, [])
     |> stream(:collections, []), layout: false}
  end

  @impl true
  def handle_params(params, _url, socket) do
    collection = Learning.get_collection(socket.assigns.current_user, params["collection"])

    if params["collection"] && is_nil(collection) do
      {:noreply,
       socket
       |> put_flash(:error, "Collection not found.")
       |> push_patch(to: ~p"/my/learning")}
    else
      search = String.slice(params["q"] || "", 0, 200)

      {:noreply,
       socket
       |> assign(
         collection: collection,
         saved_kind:
           if(params["saved"] in ["bookmarks", "highlights"], do: params["saved"], else: "all"),
         adding?: not is_nil(collection) and params["add"] == "true",
         editing?: false,
         edit_form: if(collection, do: to_form(Learning.change_collection(collection))),
         search: search,
         search_form: to_form(%{"q" => search})
       )
       |> refresh_collections()
       |> load_grids(true)}
    end
  end

  @impl true
  def handle_event("create_collection", %{"collection" => params}, socket) do
    case Learning.create_collection(socket.assigns.current_user, params) do
      {:ok, collection} ->
        {:noreply,
         socket
         |> assign(:collection_form, to_form(Learning.change_collection()))
         |> push_patch(to: ~p"/my/learning?collection=#{collection.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :collection_form, to_form(changeset))}
    end
  end

  def handle_event("edit_collection", _params, socket) do
    {:noreply, assign(socket, :editing?, true)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing?, false)}
  end

  def handle_event("save_collection", %{"collection" => params}, socket) do
    case Learning.update_collection(socket.assigns.current_user, collection_id(socket), params) do
      {:ok, collection} ->
        {:noreply,
         socket
         |> assign(
           collection: collection,
           editing?: false,
           edit_form: to_form(Learning.change_collection(collection))
         )
         |> refresh_collections()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Collection not found.")}
    end
  end

  def handle_event("delete_collection", _params, socket) do
    case Learning.delete_collection(socket.assigns.current_user, collection_id(socket)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Collection deleted. Your grids have been kept.")
         |> push_patch(to: ~p"/my/learning")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Collection not found.")}
    end
  end

  def handle_event("search", %{"q" => query}, socket) do
    params = %{q: String.slice(query, 0, 200)}

    params =
      if socket.assigns.collection,
        do: Map.put(params, :collection, collection_id(socket)),
        else: params

    params = if socket.assigns.adding?, do: Map.put(params, :add, "true"), else: params

    params =
      if socket.assigns.saved_kind != "all",
        do: Map.put(params, :saved, socket.assigns.saved_kind),
        else: params

    {:noreply, push_patch(socket, to: ~p"/my/learning?#{params}")}
  end

  def handle_event("drop_grid", %{"title" => title, "collection_id" => id}, socket) do
    add_to_collection(socket, id, title)
  end

  def handle_event("organise_grid", %{"title" => title}, socket) do
    {:noreply, assign(socket, :organise_title, title)}
  end

  def handle_event("cancel_organise", _params, socket) do
    {:noreply, assign(socket, :organise_title, nil)}
  end

  def handle_event("file_grid", %{"membership" => %{"collection_id" => id}}, socket) do
    add_to_collection(socket, id, socket.assigns.organise_title)
  end

  def handle_event("remove_bookmark", %{"id" => id}, socket) do
    case Learning.remove_bookmark(socket.assigns.current_user, id) do
      {:ok, _} -> {:noreply, socket |> refresh_collections() |> load_grids(true)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Bookmark not found.")}
    end
  end

  def handle_event("remove_highlight", %{"id" => id}, socket) do
    case Learning.remove_highlight(socket.assigns.current_user, id) do
      {:ok, _} -> {:noreply, socket |> refresh_collections() |> load_grids(true)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Highlight not found.")}
    end
  end

  def handle_event("show_delete_grid", %{"title" => title}, socket) do
    {:noreply, assign(socket, :graph_to_delete, title)}
  end

  def handle_event("cancel_delete_grid", _params, socket) do
    {:noreply, assign(socket, :graph_to_delete, nil)}
  end

  def handle_event("delete_grid", _params, %{assigns: %{graph_to_delete: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("delete_grid", _params, socket) do
    case Graphs.soft_delete_user_graph(
           socket.assigns.graph_to_delete,
           socket.assigns.current_user
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:graph_to_delete, nil)
         |> refresh_collections()
         |> load_grids(true)
         |> put_flash(:info, "Grid deleted.")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:graph_to_delete, nil)
         |> put_flash(:error, "You can only delete your own grids.")}
    end
  end

  def handle_event("toggle_visibility", %{"title" => title}, socket) do
    with %{} = graph <- Graphs.get_graph_by_title(title),
         {:ok, _} <- Graphs.toggle_graph_public(graph, socket.assigns.current_user) do
      {:noreply, load_grids(socket, true)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "You can only change sharing for your own grids.")}
    end
  end

  def handle_event("add_grid", %{"title" => title}, socket) do
    case Learning.add_grid(socket.assigns.current_user, collection_id(socket), title) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Grid added to #{socket.assigns.collection.name}.")
         |> refresh_collections()
         |> load_grids(true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "This grid or collection is no longer available.")}
    end
  end

  def handle_event("remove_grid", %{"title" => title}, socket) do
    case Learning.remove_grid(socket.assigns.current_user, collection_id(socket), title) do
      :ok ->
        {:noreply, socket |> refresh_collections() |> load_grids(true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Collection not found.")}
    end
  end

  def handle_event("load_more", _params, socket) do
    {:noreply, if(socket.assigns.more?, do: load_grids(socket, false), else: socket)}
  end

  defp refresh_collections(socket) do
    collections = Learning.list_collections(socket.assigns.current_user)

    socket
    |> assign(:collection_options, Enum.map(collections, &{&1.name, &1.id}))
    |> stream(:collections, collections, reset: true)
  end

  defp add_to_collection(socket, id, title) do
    case Learning.add_grid(socket.assigns.current_user, id, title || "") do
      {:ok, _} ->
        collection = Learning.get_collection(socket.assigns.current_user, id)

        {:noreply,
         socket
         |> assign(:organise_title, nil)
         |> refresh_collections()
         |> load_grids(true)
         |> put_flash(:info, "Grid added to #{collection.name}.")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Choose one of your collections and an available grid.")}
    end
  end

  defp load_grids(socket, reset?) do
    offset = if reset?, do: 0, else: socket.assigns.offset

    results =
      Learning.list_grids(socket.assigns.current_user,
        collection_id: if(socket.assigns.adding?, do: nil, else: collection_id(socket)),
        exclude_collection_id: if(socket.assigns.adding?, do: collection_id(socket)),
        search: socket.assigns.search,
        saved_kind: socket.assigns.saved_kind,
        limit: @page_size + 1,
        offset: offset
      )

    socket
    |> assign(more?: length(results) > @page_size, offset: offset + @page_size)
    |> stream(:grids, Enum.take(results, @page_size), reset: reset?)
  end

  defp collection_id(%{assigns: %{collection: %{id: id}}}), do: id
  defp collection_id(_socket), do: nil
  defp grid_id(grid), do: "learning-grid-" <> Base.url_encode64(grid.title, padding: false)

  defp filter_path(collection, kind) do
    params = if collection, do: %{collection: collection.id, saved: kind}, else: %{saved: kind}
    ~p"/my/learning?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.modal
        :if={@organise_title}
        id="learning-organise-modal"
        show
        on_cancel={JS.push("cancel_organise")}
      >
        <h2 id="learning-organise-modal-title" class="text-xl font-semibold">
          Add to a topic collection
        </h2>
        <p id="learning-organise-modal-description" class="mt-2 text-sm text-slate-600">
          {@organise_title}
        </p>
        <.form
          for={@organise_form}
          id="learning-organise-form"
          phx-submit="file_grid"
          class="mt-5 space-y-4"
        >
          <.input
            field={@organise_form[:collection_id]}
            id="learning-organise-target"
            type="select"
            label="Collection"
            options={@collection_options}
            prompt="Choose a collection"
            required
          />
          <p :if={@collection_options == []} class="text-sm text-slate-600">
            Create your first collection in the sidebar, then add this grid.
          </p>
          <button
            id="learning-file-grid"
            type="submit"
            disabled={@collection_options == []}
            class="rounded-md bg-teal-800 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          >Add grid</button>
        </.form>
      </.modal>
      <.modal
        :if={@graph_to_delete}
        id="learning-delete-modal"
        show
        on_cancel={JS.push("cancel_delete_grid")}
      >
        <h2 id="learning-delete-modal-title" class="text-xl font-semibold">Delete grid?</h2>
        <p id="learning-delete-modal-description" class="mt-3 text-sm leading-6 text-slate-600">
          Delete “{@graph_to_delete}” from your grids and collections?
        </p>
        <div class="mt-5 flex gap-4">
          <button
            id="learning-confirm-delete"
            type="button"
            phx-click="delete_grid"
            class="rounded-md bg-red-700 px-4 py-2 text-sm font-semibold text-white"
          >Delete grid</button>
          <button
            id="learning-cancel-delete"
            type="button"
            phx-click="cancel_delete_grid"
            class="text-sm font-semibold"
          >Cancel</button>
        </div>
      </.modal>
      <div id="learning-workspace" class="min-h-screen bg-[#f4f1e9] text-slate-950">
        <div id="learning-drag-controller" phx-hook="LearningDrag" phx-update="ignore"></div>
        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-8 sm:py-12">
          <header
            id="learning-header"
            class="flex flex-col gap-5 border-b border-stone-300 pb-8 sm:flex-row sm:items-end sm:justify-between"
          >
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.16em] text-teal-800">
                Your learning workspace
              </p>
              <h1 class="mt-3 font-serif text-4xl font-semibold sm:text-5xl">My Learning</h1>
              <p class="mt-3 max-w-xl text-base leading-7 text-slate-600">
                Find your grids, organise them by subject, and pick up where you left off.
              </p>
            </div>
            <.link
              id="learning-new-grid"
              href={
                if(@collection,
                  do: ~p"/?collection=#{@collection.id}&focus=grid#start-here",
                  else: ~p"/?focus=grid#start-here"
                )
              }
              class="inline-flex items-center justify-center gap-2 rounded-md bg-teal-800 px-5 py-3 font-semibold text-white hover:bg-teal-900"
            >
              <.icon name="hero-plus" class="h-5 w-5" />
              {if(@collection, do: "New grid in #{@collection.name}", else: "New grid")}
            </.link>
          </header>

          <div class="mt-8 grid gap-8 lg:grid-cols-[16rem_minmax(0,1fr)]">
            <aside id="learning-sidebar" class="space-y-6">
              <nav aria-label="Learning collections">
                <.link
                  id="learning-all-grids"
                  patch={filter_path(nil, @saved_kind)}
                  aria-current={if(is_nil(@collection), do: "page")}
                  class={[
                    "flex items-center gap-2 rounded-md px-3 py-3 font-semibold",
                    if(is_nil(@collection), do: "bg-slate-950 text-white", else: "hover:bg-white")
                  ]}
                >
                  <.icon name="hero-squares-2x2" class="h-5 w-5" /> All grids
                </.link>
                <h2 class="mb-2 mt-6 px-3 text-xs font-bold uppercase tracking-wider text-slate-500">
                  Topic collections
                </h2>
                <div id="learning-collections" phx-update="stream" class="space-y-1">
                  <p
                    id="learning-no-collections"
                    class="hidden px-3 py-2 text-sm leading-6 text-slate-600 only:block"
                  >
                    Create a collection for a subject you’re learning.
                  </p>
                  <.link
                    :for={{id, collection} <- @streams.collections}
                    id={id}
                    patch={filter_path(collection, @saved_kind)}
                    data-learning-drop={collection.id}
                    aria-current={if(@collection && @collection.id == collection.id, do: "page")}
                    class={[
                      "flex items-center gap-2 rounded-md px-3 py-3 text-sm data-[drag-over=true]:ring-2 data-[drag-over=true]:ring-teal-500",
                      if(@collection && @collection.id == collection.id,
                        do: "bg-teal-800 font-semibold text-white",
                        else: "hover:bg-white"
                      )
                    ]}
                  >
                    <.icon name="hero-folder" class="h-5 w-5 shrink-0" />
                    <span class="min-w-0 flex-1 break-words">{collection.name}</span>
                    <span
                      aria-label={"#{collection.grid_count} #{if(collection.grid_count == 1, do: "grid", else: "grids")}"}
                      class="text-xs tabular-nums"
                    >{collection.grid_count}</span>
                  </.link>
                </div>
              </nav>

              <details
                id="learning-create-panel"
                class="rounded-md border border-stone-300 bg-white p-4"
              >
                <summary class="cursor-pointer text-sm font-semibold text-teal-800">
                  + New collection
                </summary>
                <.form
                  for={@collection_form}
                  id="learning-create-collection"
                  phx-submit="create_collection"
                  class="mt-4 space-y-3"
                >
                  <.input
                    field={@collection_form[:name]}
                    id="learning-collection-name"
                    label="Collection name"
                    placeholder="e.g. Economics"
                    required
                    maxlength="80"
                  />
                  <.input
                    field={@collection_form[:description]}
                    id="learning-collection-description"
                    type="textarea"
                    label="Description (optional)"
                    maxlength="500"
                  />
                  <button
                    id="learning-create-submit"
                    type="submit"
                    phx-disable-with="Creating…"
                    class="rounded-md bg-teal-800 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-900"
                  >Create collection</button>
                </.form>
              </details>
              <p class="px-3 text-xs leading-5 text-slate-500">
                Your most common grid tags provide starter topics. Rename them or create your own.
                Collections are personal; grids keep their sharing settings.
              </p>
              <.link
                id="learning-activity-link"
                href={~p"/activity"}
                class="flex items-center gap-2 px-3 text-sm font-semibold text-teal-800"
              >
                <.icon name="hero-bell" class="h-4 w-4" /> Activity
              </.link>
              <.link
                id="learning-settings-link"
                href={~p"/users/settings"}
                class="flex items-center gap-2 px-3 text-sm font-semibold text-teal-800"
              >
                <.icon name="hero-cog-6-tooth" class="h-4 w-4" /> Settings
              </.link>
            </aside>

            <section id="learning-content" class="min-w-0">
              <div class="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <h2 id="learning-section-title" class="font-serif text-3xl font-semibold">
                    {if(@collection, do: @collection.name, else: "All your grids")}
                  </h2>
                  <p
                    :if={@collection && @collection.description}
                    id="learning-collection-summary"
                    class="mt-2 max-w-2xl whitespace-pre-line text-sm leading-6 text-slate-600"
                  >
                    {@collection.description}
                  </p>
                  <p :if={!@collection} class="mt-2 text-sm leading-6 text-slate-600">
                    Your own, saved, followed, and shared grids, with your bookmarks and highlights.
                  </p>
                </div>
                <div
                  :if={@collection}
                  class="flex flex-wrap gap-3 text-sm font-semibold text-teal-800"
                >
                  <.link
                    :if={!@adding?}
                    id="learning-add-existing"
                    patch={~p"/my/learning?collection=#{@collection.id}&add=true"}
                    class="rounded-md border border-teal-800 px-3 py-2 hover:bg-teal-50"
                  >Add existing grids</.link>
                  <.link
                    :if={@adding?}
                    id="learning-done-adding"
                    patch={~p"/my/learning?collection=#{@collection.id}"}
                    class="rounded-md border border-teal-800 px-3 py-2 hover:bg-teal-50"
                  >Done</.link>
                  <button id="learning-edit-button" type="button" phx-click="edit_collection">Edit collection</button>
                </div>
              </div>

              <nav
                id="learning-content-filters"
                aria-label="Learning content"
                class="mt-6 flex flex-wrap gap-2 border-b border-stone-300 pb-3"
              >
                <.link
                  :for={
                    {kind, label} <- [
                      {"all", "All grids"},
                      {"bookmarks", "Bookmarks"},
                      {"highlights", "Highlights"}
                    ]
                  }
                  id={"learning-filter-#{kind}"}
                  patch={filter_path(@collection, kind)}
                  aria-current={if(@saved_kind == kind, do: "page")}
                  class={[
                    "rounded-md px-4 py-2 text-sm font-semibold",
                    if(@saved_kind == kind,
                      do: "bg-slate-950 text-white",
                      else: "text-slate-600 hover:bg-white"
                    )
                  ]}
                >{label}</.link>
              </nav>
              <p id="learning-organise-hint" class="mt-3 text-xs leading-5 text-slate-500">
                Drag a grid’s grip onto a topic to add it, or choose Organise. Bookmarks and highlights stay with their grid.
              </p>

              <.form
                :if={@editing? && @edit_form}
                for={@edit_form}
                id="learning-edit-collection"
                phx-submit="save_collection"
                class="mt-5 space-y-3 rounded-md border border-stone-300 bg-white p-5"
              >
                <.input
                  field={@edit_form[:name]}
                  id="learning-edit-name"
                  label="Collection name"
                  required
                  maxlength="80"
                />
                <.input
                  field={@edit_form[:description]}
                  id="learning-edit-description"
                  type="textarea"
                  label="Description (optional)"
                  maxlength="500"
                />
                <div class="flex flex-wrap items-center gap-4 text-sm font-semibold">
                  <button
                    id="learning-save-collection"
                    type="submit"
                    class="rounded-md bg-teal-800 px-4 py-2 text-white"
                  >Save changes</button>
                  <button id="learning-cancel-edit" type="button" phx-click="cancel_edit">Cancel</button>
                  <button
                    id="learning-delete-collection"
                    type="button"
                    phx-click="delete_collection"
                    data-confirm="Delete this collection? Your grids will be kept."
                    class="text-red-700"
                  >Delete collection</button>
                </div>
              </.form>

              <p
                :if={@adding?}
                id="learning-adding-note"
                class="mt-5 rounded-md bg-teal-50 px-4 py-3 text-sm text-teal-900"
              >
                Choose grids to add to {@collection.name}. A grid can belong to more than one collection.
              </p>
              <.form
                for={@search_form}
                id="learning-search"
                phx-change="search"
                phx-submit="search"
                class="mt-6"
              >
                <.input
                  field={@search_form[:q]}
                  id="learning-search-input"
                  type="search"
                  label={
                    if(@adding? || !@collection,
                      do: "Find a grid",
                      else: "Find a grid in this collection"
                    )
                  }
                  placeholder="Search grid titles or tags…"
                  phx-debounce="300"
                  maxlength="200"
                />
              </.form>

              <div
                id="learning-grids"
                phx-update="stream"
                class="mt-5 divide-y divide-stone-200 overflow-hidden rounded-md border border-stone-300 bg-white"
              >
                <div id="learning-no-grids" class="hidden px-6 py-12 text-center only:block">
                  <.icon name="hero-folder-open" class="mx-auto h-8 w-8 text-teal-700" />
                  <%= cond do %>
                    <% @search != "" -> %>
                      <h3 class="mt-4 text-lg font-semibold">No matching grids</h3>
                      <p class="mt-2 text-sm leading-6 text-slate-600">
                        Try a different title or tag.
                      </p>
                    <% @adding? -> %>
                      <h3 class="mt-4 text-lg font-semibold">No more grids to add</h3>
                      <p class="mt-2 text-sm leading-6 text-slate-600">
                        Create a new grid, or bookmark a community grid to find it here.
                      </p>
                    <% @saved_kind != "all" -> %>
                      <h3 class="mt-4 text-lg font-semibold">No {@saved_kind} here yet</h3>
                      <p class="mt-2 text-sm leading-6 text-slate-600">
                        Open a grid and save an answer or highlight a passage. You’ll find it here with that grid.
                      </p>
                    <% @collection -> %>
                      <h3 class="mt-4 text-lg font-semibold">Start building this collection</h3>
                      <p class="mt-2 text-sm leading-6 text-slate-600">
                        Add an existing grid or start a new one on this subject.
                      </p>
                    <% true -> %>
                      <h3 class="mt-4 text-lg font-semibold">Your learning starts with a question</h3>
                      <p class="mt-2 text-sm leading-6 text-slate-600">
                        Start a grid above, or bookmark a grid from the community.
                      </p>
                  <% end %>
                </div>
                <article
                  :for={{id, grid} <- @streams.grids}
                  id={id}
                  class="px-5 py-6"
                >
                  <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                    <div class="min-w-0 flex-1">
                      <button
                        id={id <> "-drag"}
                        type="button"
                        draggable="true"
                        data-learning-drag
                        data-grid-title={grid.title}
                        phx-click="organise_grid"
                        phx-value-title={grid.title}
                        aria-label={"Organise #{grid.title}; drag to a topic or click to choose"}
                        title="Drag to a topic or click to organise"
                        class="mr-2 inline-flex cursor-grab rounded p-1 text-slate-400 hover:bg-teal-50 hover:text-teal-800 active:cursor-grabbing"
                      >
                        <.icon name="hero-bars-3" class="h-5 w-5" />
                      </button>
                      <.link
                        id={id <> "-open"}
                        href={graph_path(grid)}
                        class="break-words font-serif text-xl font-semibold leading-7 text-slate-950 hover:text-teal-800"
                      >{grid.title}</.link>
                      <p class="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500">
                        <span>Updated {Calendar.strftime(grid.updated_at, "%d %b %Y")}</span>
                        <span>{if(grid.is_public, do: "Public grid", else: "Private grid")}</span>
                      </p>
                      <p :if={grid.tags != [] && grid.tags != nil} class="mt-2 text-xs text-slate-600">
                        {Enum.map_join(grid.tags, " · ", &tag_label/1)}
                      </p>
                      <div :if={grid.collections != []} class="mt-3 flex flex-wrap gap-2">
                        <.link
                          :for={collection <- grid.collections}
                          id={id <> "-topic-#{collection.id}"}
                          patch={filter_path(collection, @saved_kind)}
                          class="rounded bg-teal-50 px-2 py-1 text-xs font-medium text-teal-800"
                        >{collection.name}</.link>
                      </div>
                    </div>
                    <div class="flex shrink-0 flex-wrap items-center gap-3">
                      <button
                        id={id <> "-organise"}
                        type="button"
                        phx-click="organise_grid"
                        phx-value-title={grid.title}
                        class="text-sm font-semibold text-teal-800"
                      >Organise</button>
                      <%= cond do %>
                        <% @adding? -> %>
                          <button
                            id={id <> "-add"}
                            type="button"
                            phx-click="add_grid"
                            phx-value-title={grid.title}
                            class="rounded-md border border-teal-800 px-3 py-2 text-sm font-semibold text-teal-800 hover:bg-teal-50"
                          >Add to collection</button>
                        <% @collection -> %>
                          <button
                            id={id <> "-remove"}
                            type="button"
                            phx-click="remove_grid"
                            phx-value-title={grid.title}
                            aria-label={"Remove #{grid.title} from #{@collection.name}"}
                            class="text-sm text-slate-500 hover:text-red-700"
                          >Remove from collection</button>
                        <% true -> %>
                          <.link
                            id={id <> "-continue"}
                            href={graph_path(grid)}
                            class="inline-flex items-center gap-2 text-sm font-semibold text-teal-800"
                          >Continue <.icon name="hero-arrow-right" class="h-4 w-4" /></.link>
                      <% end %>
                    </div>
                  </div>

                  <details
                    :if={grid.bookmarks != [] || grid.highlights != []}
                    id={id <> "-saved"}
                    open={@saved_kind != "all"}
                    class="mt-4 rounded-md border border-stone-200 bg-stone-50"
                  >
                    <summary class="cursor-pointer px-4 py-3 text-sm font-semibold text-slate-700">
                      Saved in this grid · {length(grid.bookmarks)} bookmarks · {length(
                        grid.highlights
                      )} highlights
                    </summary>
                    <div class="space-y-4 border-t border-stone-200 p-4">
                      <section
                        :if={@saved_kind != "highlights" && grid.bookmarks != []}
                        aria-label="Bookmarks"
                        class="space-y-3"
                      >
                        <div
                          :for={bookmark <- grid.bookmarks}
                          id={"learning-bookmark-#{bookmark.id}"}
                          class="flex items-start justify-between gap-3"
                        >
                          <.link
                            id={"learning-bookmark-#{bookmark.id}-open"}
                            href={graph_path(grid, bookmark.node_id)}
                            class="inline-flex items-start gap-2 text-sm font-semibold text-teal-800"
                          >
                            <.icon name="hero-bookmark" class="mt-0.5 h-4 w-4 shrink-0" /> {bookmark.title}
                          </.link>
                          <button
                            id={"learning-bookmark-#{bookmark.id}-remove"}
                            type="button"
                            phx-click="remove_bookmark"
                            phx-value-id={bookmark.id}
                            aria-label={"Remove bookmark: #{bookmark.title}"}
                            class="text-xs text-slate-500 hover:text-red-700"
                          >Remove</button>
                        </div>
                      </section>
                      <section
                        :if={@saved_kind != "bookmarks" && grid.highlights != []}
                        aria-label="Highlights"
                        class="space-y-3"
                      >
                        <div
                          :for={highlight <- grid.highlights}
                          id={"learning-highlight-#{highlight.id}"}
                          class="border-l-2 border-amber-400 pl-3"
                        >
                          <.link
                            id={"learning-highlight-#{highlight.id}-open"}
                            aria-label={"Open highlight: #{String.slice(highlight.selected_text_snapshot || "", 0, 120)}"}
                            href={graph_path(grid, highlight.node_id, highlight: highlight.id)}
                            class="block text-sm leading-6 text-slate-800 hover:text-teal-800"
                          >
                            <blockquote>{highlight.selected_text_snapshot}</blockquote>
                            <p
                              :if={highlight.note && highlight.note != ""}
                              class="mt-1 text-xs text-slate-500"
                            >
                              {highlight.note}
                            </p>
                          </.link>
                          <button
                            id={"learning-highlight-#{highlight.id}-remove"}
                            type="button"
                            phx-click="remove_highlight"
                            phx-value-id={highlight.id}
                            data-confirm="Remove this saved highlight?"
                            class="mt-1 text-xs text-slate-500 hover:text-red-700"
                          >Remove highlight</button>
                        </div>
                      </section>
                    </div>
                  </details>

                  <div
                    :if={grid.user_id == @current_user.id}
                    class="mt-4 flex flex-wrap items-center gap-4 border-t border-stone-100 pt-3 text-xs font-semibold"
                  >
                    <.link id={id <> "-edit"} href={graph_editor_path(grid)} class="text-teal-800">Open grid editor</.link>
                    <button
                      id={id <> "-visibility"}
                      type="button"
                      phx-click="toggle_visibility"
                      phx-value-title={grid.title}
                      data-confirm={
                        if(!grid.is_public,
                          do: "Make this grid public? Anyone will be able to view it."
                        )
                      }
                      class="text-slate-600"
                    >{if(grid.is_public, do: "Make private", else: "Make public")}</button>
                    <button
                      id={id <> "-delete"}
                      type="button"
                      phx-click="show_delete_grid"
                      phx-value-title={grid.title}
                      class="text-red-700"
                    >Delete grid</button>
                  </div>
                </article>
              </div>
              <button
                :if={@more?}
                id="learning-load-more"
                type="button"
                phx-click="load_more"
                class="mt-5 rounded-md border border-stone-400 px-4 py-2 text-sm font-semibold hover:bg-white"
              >Load more grids</button>
            </section>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
