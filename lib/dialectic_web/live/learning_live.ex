defmodule DialecticWeb.LearningLive do
  use DialecticWeb, :live_view

  alias Dialectic.Learning
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.Creator
  alias Dialectic.Learning.CollectionGrid
  alias DialecticWeb.LearningComponents

  @page_size 24

  @impl true
  def mount(_params, session, socket) do
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
       new_grid_form: to_form(new_grid_changeset(), as: :vertex),
       creating_grid?: false,
       new_grid_requested?: false,
       show_new_grid?: false,
       llm_actor_id: session["llm_actor_id"] || "learning:#{socket.id}",
       collection_form: to_form(Learning.change_collection()),
       folder_form: to_form(Learning.change_collection(), as: :folder),
       creating_folder?: false,
       expanded_folders: MapSet.new(),
       folder_count: 0,
       include_subfolders?: false,
       scope_form: to_form(%{"include_subfolders" => false}, as: :scope),
       moving_folder?: false,
       move_options: [],
       move_form: to_form(%{"parent_id" => "root"}, as: :move),
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
     |> stream(:topics, [])
     |> stream_configure(:collections, dom_id: &"collection-row-#{&1.id}")
     |> stream(:folders, [])
     |> stream(:breadcrumbs, [])
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
         new_grid_requested?: params["new"] == "true",
         include_subfolders?:
           params["include_subfolders"] == "true" and not is_nil(collection) and
             collection.origin == :manual,
         scope_form:
           to_form(%{"include_subfolders" => params["include_subfolders"] == "true"}, as: :scope),
         creating_folder?: false,
         folder_form: to_form(Learning.change_collection(), as: :folder),
         moving_folder?: false,
         saved_kind:
           if(params["saved"] in ["bookmarks", "highlights"], do: params["saved"], else: "all"),
         adding?: not is_nil(collection) and params["add"] == "true",
         editing?: false,
         edit_form: if(collection, do: to_form(Learning.change_collection(collection))),
         search: search,
         search_form: to_form(%{"q" => search})
       )
       |> refresh_collections(true)
       |> load_grids(true)}
    end
  end

  @impl true
  def handle_event("new_folder", _params, socket),
    do: {:noreply, assign(socket, creating_folder?: true, editing?: false)}

  def handle_event("cancel_folder", _params, socket),
    do: {:noreply, assign(socket, :creating_folder?, false)}

  def handle_event("create_folder", %{"folder" => params}, socket) do
    case socket.assigns.collection &&
           Learning.create_collection(socket.assigns.current_user, params, collection_id(socket)) do
      {:ok, folder} ->
        {:noreply, push_patch(socket, to: filter_path(folder, "all"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :folder_form, to_form(changeset, as: :folder))}

      _ ->
        {:noreply, put_flash(socket, :error, "Choose a collection or folder first.")}
    end
  end

  def handle_event("toggle_folder", %{"id" => id}, socket) do
    case Learning.get_collection(socket.assigns.current_user, id) do
      %{origin: :manual, id: id} ->
        expanded = socket.assigns.expanded_folders

        expanded =
          if MapSet.member?(expanded, id),
            do: MapSet.delete(expanded, id),
            else: MapSet.put(expanded, id)

        {:noreply, socket |> assign(:expanded_folders, expanded) |> refresh_collections()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_subfolders", %{"scope" => %{"include_subfolders" => value}}, socket) do
    params = %{
      saved: socket.assigns.saved_kind,
      q: socket.assigns.search,
      include_subfolders: value == "true"
    }

    params =
      if socket.assigns.collection,
        do: Map.put(params, :collection, collection_id(socket)),
        else: params

    {:noreply, push_patch(socket, to: ~p"/my/learning?#{params}")}
  end

  def handle_event("move_folder", _params, %{assigns: %{collection: %{origin: :manual}}} = socket) do
    {:noreply,
     assign(socket,
       moving_folder?: true,
       move_form:
         to_form(
           %{
             "parent_id" => socket.assigns.collection.parent_id || "root"
           },
           as: :move
         )
     )}
  end

  def handle_event("move_folder", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_move_folder", _params, socket),
    do: {:noreply, assign(socket, :moving_folder?, false)}

  def handle_event("save_folder_move", %{"move" => %{"parent_id" => parent_id}}, socket) do
    move_folder(socket, collection_id(socket), parent_id)
  end

  def handle_event("drop_folder", %{"collection_id" => id, "parent_id" => parent_id}, socket) do
    move_folder(socket, id, parent_id)
  end

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
    {:noreply, assign(socket, editing?: true, creating_folder?: false)}
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
         |> refresh_collections()
         |> load_grids(true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Collection not found.")}
    end
  end

  def handle_event("delete_collection", _params, socket) do
    case Learning.delete_collection(socket.assigns.current_user, collection_id(socket)) do
      {:ok, collection} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "#{String.capitalize(group_kind(collection))} deleted. Your grids have been kept."
         )
         |> push_patch(
           to:
             if(collection.parent_id,
               do: ~p"/my/learning?collection=#{collection.parent_id}",
               else: ~p"/my/learning"
             )
         )}

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
      if socket.assigns.include_subfolders?,
        do: Map.put(params, :include_subfolders, true),
        else: params

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
         |> put_flash(:info, "Grid filed in #{socket.assigns.collection.name}.")
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

  defp move_folder(socket, id, parent_id) do
    case Learning.move_collection(socket.assigns.current_user, id, parent_id) do
      {:ok, folder} ->
        socket =
          if socket.assigns.collection && socket.assigns.collection.id == folder.id,
            do: assign(socket, :collection, folder),
            else: socket

        {:noreply,
         socket
         |> assign(:moving_folder?, false)
         |> refresh_collections(true)
         |> load_grids(true)
         |> put_flash(:info, "Folder moved.")}

      {:error, :cycle} ->
        {:noreply,
         put_flash(socket, :error, "A folder cannot be moved inside itself or its subfolders.")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "A folder with that name already exists there.")}

      _ ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Choose one of your collections or folders as the destination."
         )}
    end
  end

  defp refresh_collections(socket, expand_selected? \\ false) do
    {topics, collections} =
      socket.assigns.current_user
      |> Learning.list_collections()
      |> Enum.split_with(&(&1.origin == :tags))

    all = topics ++ collections
    by_id = Map.new(all, &{&1.id, &1})

    collections =
      Enum.sort_by(collections, fn folder ->
        Enum.map(folder.ancestor_ids ++ [folder.id], &String.downcase(by_id[&1].name))
      end)

    options =
      [{"Collections", collections}, {"Topics", topics}]
      |> Enum.reject(fn {_label, items} -> items == [] end)
      |> Enum.map(fn {label, items} -> {label, Enum.map(items, &{&1.path, &1.id})} end)

    selected = Enum.find(all, &(&1.id == collection_id(socket)))
    ancestors = if selected, do: selected.ancestor_ids, else: []

    expanded =
      if expand_selected?,
        do: Enum.reduce(ancestors, socket.assigns.expanded_folders, &MapSet.put(&2, &1)),
        else: socket.assigns.expanded_folders

    children =
      Enum.filter(
        collections,
        &(&1.parent_id == collection_id(socket) and not is_nil(&1.parent_id))
      )

    parent_ids = MapSet.new(collections, & &1.parent_id)

    visible =
      collections
      |> Enum.filter(&Enum.all?(&1.ancestor_ids, fn id -> MapSet.member?(expanded, id) end))
      |> Enum.map(
        &Map.merge(&1, %{
          expanded?: MapSet.member?(expanded, &1.id),
          has_children?: MapSet.member?(parent_ids, &1.id)
        })
      )

    breadcrumbs =
      if selected,
        do: [
          %{id: "root", name: "My Learning"}
          | Enum.map(ancestors ++ [selected.id], &Map.fetch!(by_id, &1))
        ],
        else: []

    destinations =
      Enum.reject(
        collections,
        &(&1.id == collection_id(socket) or collection_id(socket) in &1.ancestor_ids)
      )

    socket
    |> assign(
      collection_options: options,
      expanded_folders: expanded,
      folder_count: length(children),
      move_options: [
        {"Collections (top level)", "root"} | Enum.map(destinations, &{&1.path, &1.id})
      ]
    )
    |> stream(:folders, children, reset: true)
    |> stream(:breadcrumbs, breadcrumbs, reset: true)
    |> stream(:topics, topics, reset: true)
    |> stream(:collections, visible, reset: true)
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
         |> put_flash(:info, "Grid filed in #{collection.name}.")}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Choose one of your topics or collections and an available grid."
         )}
    end
  end

  @impl true
  def handle_info(
        {:submit_new_grid, _content, _mode},
        %{assigns: %{creating_grid?: true}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_info({:submit_new_grid, content, mode}, socket) do
    changeset = new_grid_changeset(%{"content" => content, "mode" => mode})

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, %{content: question, mode: mode}} ->
        user = socket.assigns.current_user
        actor_id = socket.assigns.llm_actor_id
        collection_id = collection_id(socket)

        mode =
          %{"high_school" => :high_school, "university" => :university, "expert" => :expert}[mode]

        {:noreply,
         socket
         |> assign(:creating_grid?, true)
         |> start_async(:create_private_grid, fn ->
           case Creator.create(question, user, user.email,
                  is_public: false,
                  mode: mode,
                  actor_id: actor_id
                ) do
             {:ok, title} -> {:ok, title, collection_id}
             error -> error
           end
         end)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Please enter a question and choose an answer depth.")}
    end
  end

  @impl true
  def handle_async(:create_private_grid, {:ok, {:ok, title, collection_id}}, socket) do
    case Graphs.get_graph_by_title(title) do
      nil ->
        private_grid_creation_failed(socket)

      graph ->
        {:noreply,
         socket
         |> file_new_grid(collection_id, graph)
         |> redirect(to: learning_grid_path(graph))}
    end
  end

  def handle_async(:create_private_grid, _result, socket) do
    private_grid_creation_failed(socket)
  end

  defp private_grid_creation_failed(socket) do
    {:noreply,
     socket
     |> assign(:creating_grid?, false)
     |> put_flash(:error, "Could not finish creating your private grid. Please try again.")}
  end

  defp file_new_grid(socket, nil, _graph), do: socket

  defp file_new_grid(socket, collection_id, graph) do
    case Learning.add_grid(socket.assigns.current_user, collection_id, graph.title) do
      {:ok, _membership} ->
        socket

      {:error, _reason} ->
        put_flash(
          socket,
          :error,
          "Your private grid was created, but could not be added to that topic or collection. Find it in My Learning."
        )
    end
  end

  defp new_grid_changeset(params \\ %{}) do
    {%{content: "", mode: "high_school"}, %{content: :string, mode: :string}}
    |> Ecto.Changeset.cast(params, [:content, :mode])
    |> Ecto.Changeset.update_change(:content, &String.trim(&1 || ""))
    |> Ecto.Changeset.validate_required([:content, :mode])
    |> Ecto.Changeset.validate_inclusion(:mode, ["high_school", "university", "expert"])
  end

  defp load_grids(socket, reset?) do
    offset = if reset?, do: 0, else: socket.assigns.offset

    results =
      Learning.list_grids(socket.assigns.current_user,
        collection_id: if(socket.assigns.adding?, do: nil, else: collection_id(socket)),
        exclude_collection_id: if(socket.assigns.adding?, do: collection_id(socket)),
        search: socket.assigns.search,
        saved_kind: socket.assigns.saved_kind,
        include_subfolders: socket.assigns.include_subfolders? and not socket.assigns.adding?,
        limit: @page_size + 1,
        offset: offset
      )

    socket
    |> assign(
      more?: length(results) > @page_size,
      offset: offset + @page_size,
      show_new_grid?:
        socket.assigns.new_grid_requested? or
          (reset? and results == [] and socket.assigns.saved_kind == "all" and
             String.trim(socket.assigns.search) == "" and not socket.assigns.adding? and
             socket.assigns.folder_count == 0)
    )
    |> stream(:grids, Enum.take(results, @page_size), reset: reset?)
  end

  defp collection_id(%{assigns: %{collection: %{id: id}}}), do: id
  defp collection_id(_socket), do: nil
  defp grid_id(grid), do: "learning-grid-" <> Base.url_encode64(grid.title, padding: false)

  defp learning_grid_path(grid, node \\ nil, params \\ []) do
    graph_path(%{slug: grid.slug}, node, params)
  end

  defp group_kind(%{origin: :tags}), do: "topic"
  defp group_kind(%{parent_id: id}) when not is_nil(id), do: "folder"
  defp group_kind(_collection), do: "collection"

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :hint, :string, required: true
  attr :empty_message, :string, required: true
  attr :icon, :string, required: true
  attr :items, :any, required: true
  attr :selected, :any, required: true
  attr :saved_kind, :string, required: true

  defp learning_group_list(assigns) do
    ~H"""
    <section aria-labelledby={@id <> "-heading"}>
      <h2
        id={@id <> "-heading"}
        class="mb-1 mt-6 px-3 text-xs font-bold uppercase tracking-wider text-slate-500"
      >
        {@title}
      </h2>
      <p class="mb-2 px-3 text-xs text-slate-500">{@hint}</p>
      <div id={@id} phx-update="stream" class="space-y-1">
        <p
          id={@id <> "-empty"}
          class="hidden px-3 py-2 text-sm leading-6 text-slate-600 only:block"
        >
          {@empty_message}
        </p>
        <.link
          :for={{id, collection} <- @items}
          id={id}
          patch={filter_path(collection, @saved_kind)}
          data-learning-drop={collection.id}
          aria-current={if(@selected && @selected.id == collection.id, do: "page")}
          class={[
            "flex items-center gap-2 rounded-md px-3 py-3 text-sm data-[drag-over=true]:ring-2 data-[drag-over=true]:ring-teal-500",
            if(@selected && @selected.id == collection.id,
              do: "bg-teal-800 font-semibold text-white",
              else: "hover:bg-white"
            )
          ]}
        >
          <.icon name={@icon} class="h-5 w-5 shrink-0" />
          <span class="min-w-0 flex-1 break-words">{collection.name}</span>
          <span
            aria-label={"#{collection.grid_count} #{if(collection.grid_count == 1, do: "grid", else: "grids")}"}
            class="text-xs tabular-nums"
          >{collection.grid_count}</span>
        </.link>
      </div>
    </section>
    """
  end

  defp filter_path(collection, kind, include_subfolders? \\ false, search \\ "") do
    params = if collection, do: %{collection: collection.id, saved: kind}, else: %{saved: kind}

    params =
      if collection && include_subfolders?,
        do: Map.put(params, :include_subfolders, true),
        else: params

    params = if search != "", do: Map.put(params, :q, search), else: params
    ~p"/my/learning?#{params}"
  end

  defp new_grid_path(collection) do
    params = if collection, do: %{collection: collection.id, new: true}, else: %{new: true}
    ~p"/my/learning?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.modal
        :if={@moving_folder?}
        id="learning-move-folder-modal"
        show
        on_cancel={JS.push("cancel_move_folder")}
      >
        <h2 id="learning-move-folder-modal-title" class="text-xl font-semibold">
          Move “{@collection.name}”
        </h2>
        <p id="learning-move-folder-modal-description" class="mt-2 text-sm text-slate-600">
          Choose its new location.
        </p>
        <.form
          for={@move_form}
          id="learning-move-folder-form"
          phx-submit="save_folder_move"
          class="mt-5 space-y-4"
        >
          <.input
            field={@move_form[:parent_id]}
            id="learning-move-folder-parent"
            type="select"
            label="Destination"
            options={@move_options}
          />
          <div class="flex items-center gap-4">
            <button
              id="learning-confirm-folder-move"
              type="submit"
              class="rounded-md bg-teal-800 px-4 py-2 font-semibold text-white"
            >Move here</button>
            <button
              id="learning-cancel-folder-move"
              type="button"
              phx-click="cancel_move_folder"
              class="text-sm font-semibold text-slate-600"
            >Cancel</button>
          </div>
        </.form>
      </.modal>
      <.modal
        :if={@organise_title}
        id="learning-organise-modal"
        show
        on_cancel={JS.push("cancel_organise")}
      >
        <h2 id="learning-organise-modal-title" class="text-xl font-semibold">
          Organise grid
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
            label="Destination"
            options={@collection_options}
            prompt="Choose a topic, collection or folder"
            required
          />
          <p :if={@collection_options == []} class="text-sm text-slate-600">
            Create your first collection in the sidebar, then add this grid.
          </p>
          <p :if={@collection_options != []} id="learning-filing-hint" class="text-sm text-slate-600">
            Within a collection, this moves the grid to its new folder. Other collections and topics keep it.
          </p>
          <div class="flex items-center gap-4">
            <button
              id="learning-file-grid"
              type="submit"
              disabled={@collection_options == []}
              class="rounded-md bg-teal-800 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            >File grid</button>
            <button
              id="learning-cancel-organise"
              type="button"
              phx-click="cancel_organise"
              class="text-sm font-semibold text-slate-600"
            >Cancel</button>
          </div>
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
            class="border-b border-stone-300 pb-8"
          >
            <h1 id="learning-title" class="font-serif text-4xl font-semibold sm:text-5xl">
              My Learning
            </h1>
          </header>

          <div class="mt-8 grid gap-8 lg:grid-cols-[16rem_minmax(0,1fr)]">
            <aside id="learning-sidebar" class="space-y-6">
              <nav aria-label="Topics and collections">
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
                <LearningComponents.folder_tree
                  items={@streams.collections}
                  selected={@collection}
                  saved_kind={@saved_kind}
                />
                <.learning_group_list
                  id="learning-topics"
                  title="Topics"
                  hint="Started from your grid tags"
                  empty_message="Topics appear when your grids have tags."
                  icon="hero-tag"
                  items={@streams.topics}
                  selected={@collection}
                  saved_kind={@saved_kind}
                />
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
                Topics and collections are personal. Grids keep their sharing settings.
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
              <nav :if={@collection} aria-label="Folder location" class="mb-4">
                <ol
                  id="learning-breadcrumbs"
                  phx-update="stream"
                  class="flex flex-wrap items-center gap-2 text-sm text-teal-800"
                >
                  <li
                    :for={{id, folder} <- @streams.breadcrumbs}
                    id={id}
                    class="inline-flex items-center gap-2"
                  >
                    <.icon :if={folder.id != "root"} name="hero-chevron-right" class="h-3 w-3" />
                    <.link
                      patch={
                        if(folder.id == "root",
                          do: ~p"/my/learning",
                          else: filter_path(folder, @saved_kind)
                        )
                      }
                      aria-current={if(folder.id == @collection.id, do: "page")}
                    >{folder.name}</.link>
                  </li>
                </ol>
              </nav>
              <div :if={@collection} class="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <h2 id="learning-section-title" class="font-serif text-3xl font-semibold">
                    {@collection.name}
                  </h2>
                  <p
                    id="learning-collection-origin"
                    data-origin={@collection.origin}
                    class="mt-2 text-xs font-semibold text-teal-800"
                  >
                    {if(@collection.origin == :tags,
                      do: "Topic · From your grid tags",
                      else: "#{String.capitalize(group_kind(@collection))} · Created by you"
                    )}
                  </p>
                  <p
                    :if={@collection.description}
                    id="learning-collection-summary"
                    class="mt-2 max-w-2xl whitespace-pre-line text-sm leading-6 text-slate-600"
                  >
                    {@collection.description}
                  </p>
                </div>
                <div class="flex flex-wrap gap-3 text-sm font-semibold text-teal-800">
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
                  <button id="learning-edit-button" type="button" phx-click="edit_collection">Edit {group_kind(
                    @collection
                  )}</button>
                  <button
                    :if={@collection.origin == :manual}
                    id="learning-new-folder"
                    type="button"
                    phx-click="new_folder"
                  >New folder</button>
                </div>
              </div>

              <nav
                id="learning-content-filters"
                aria-label="Learning content"
                class={[
                  "flex flex-wrap gap-2 border-b border-stone-300 pb-3",
                  @collection && "mt-6"
                ]}
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
                  patch={filter_path(@collection, kind, @include_subfolders?, @search)}
                  aria-current={if(@saved_kind == kind and !@show_new_grid?, do: "page")}
                  class={[
                    "rounded-md px-4 py-2 text-sm font-semibold",
                    if(@saved_kind == kind and !@show_new_grid?,
                      do: "bg-slate-950 text-white",
                      else: "text-slate-600 hover:bg-white"
                    )
                  ]}
                >{label}</.link>
                <.link
                  id="learning-new-grid-tab"
                  patch={new_grid_path(@collection)}
                  aria-current={if(@show_new_grid?, do: "page")}
                  class={[
                    "inline-flex items-center gap-2 rounded-md px-4 py-2 text-sm font-semibold",
                    if(@show_new_grid?,
                      do: "bg-slate-950 text-white",
                      else: "text-slate-600 hover:bg-white"
                    )
                  ]}
                >
                  <.icon name="hero-plus" class="h-4 w-4" /> New grid
                </.link>
              </nav>

              <.form
                :if={@creating_folder? && @collection && @collection.origin == :manual}
                for={@folder_form}
                id="learning-create-folder"
                phx-submit="create_folder"
                phx-mounted={JS.focus(to: "#learning-folder-name")}
                class="mt-5 space-y-3 rounded-md border border-stone-300 bg-white p-5"
              >
                <.input
                  field={@folder_form[:name]}
                  id="learning-folder-name"
                  label="Folder name"
                  placeholder="e.g. Macroeconomics"
                  required
                  maxlength="80"
                />
                <div class="flex items-center gap-4">
                  <button
                    id="learning-create-folder-submit"
                    type="submit"
                    class="rounded-md bg-teal-800 px-4 py-2 font-semibold text-white"
                  >Create folder</button>
                  <button
                    id="learning-cancel-folder"
                    type="button"
                    phx-click={JS.push("cancel_folder") |> JS.focus(to: "#learning-new-folder")}
                  >Cancel</button>
                </div>
              </.form>

              <div
                :if={@folder_count > 0 && !@adding? && !@new_grid_requested? && @search == ""}
                class="mt-5"
              >
                <h3 class="mb-3 text-sm font-semibold">Folders</h3>
                <div id="learning-folders" phx-update="stream" class="grid gap-3 sm:grid-cols-2">
                  <.link
                    :for={{id, folder} <- @streams.folders}
                    id={id}
                    patch={filter_path(folder, @saved_kind)}
                    draggable="true"
                    data-learning-folder-drag={folder.id}
                    data-learning-folder-drop={folder.id}
                    data-learning-drop={folder.id}
                    class="flex items-center gap-3 rounded-md border border-stone-300 bg-white p-4 text-sm font-semibold hover:bg-teal-50 data-[drag-over=true]:ring-2 data-[drag-over=true]:ring-teal-500"
                  >
                    <.icon name="hero-folder" class="h-5 w-5 text-teal-800" /> {folder.name}
                  </.link>
                </div>
              </div>

              <div
                :if={@show_new_grid?}
                hidden={@creating_folder? || @editing?}
                id="learning-create-grid"
                class="mt-6 max-w-xl"
              >
                <.live_component
                  module={DialecticWeb.NewGridForm}
                  id="learning-new-grid-form"
                  form={@new_grid_form}
                  label="Start a private grid"
                  context={@collection && "Added to #{group_kind(@collection)}: #{@collection.name}"}
                  busy={@creating_grid?}
                  placeholder="Ask a question or name a topic"
                  submit_label="Continue"
                  create_label="Create private grid"
                  minimal={true}
                  authenticated={true}
                />
              </div>

              <.form
                :if={@editing? && @edit_form}
                for={@edit_form}
                id="learning-edit-collection"
                phx-submit="save_collection"
                phx-mounted={JS.focus(to: "#learning-edit-name")}
                class="mt-5 space-y-3 rounded-md border border-stone-300 bg-white p-5"
              >
                <.input
                  field={@edit_form[:name]}
                  id="learning-edit-name"
                  label={"#{String.capitalize(group_kind(@collection))} name"}
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
                  <button
                    id="learning-cancel-edit"
                    type="button"
                    phx-click={JS.push("cancel_edit") |> JS.focus(to: "#learning-edit-button")}
                  >Cancel</button>
                  <button
                    :if={@collection.origin == :manual}
                    id="learning-move-folder"
                    type="button"
                    phx-click="move_folder"
                    class="text-teal-800"
                  >Move {group_kind(@collection)}</button>
                  <button
                    id="learning-delete-collection"
                    type="button"
                    phx-click="delete_collection"
                    data-confirm={"Delete this #{group_kind(@collection)} and any subfolders? Your grids will be kept."}
                    class="text-red-700"
                  >Delete {group_kind(@collection)}</button>
                </div>
              </.form>

              <div :if={!@show_new_grid?} id="learning-grid-browser">
                <.form
                  :if={
                    @collection && @collection.origin == :manual && !@adding? &&
                      (@folder_count > 0 || @include_subfolders?)
                  }
                  for={@scope_form}
                  id="learning-subfolder-scope"
                  phx-change="toggle_subfolders"
                  class="mt-4"
                >
                  <.input
                    field={@scope_form[:include_subfolders]}
                    id="learning-include-subfolders"
                    type="checkbox"
                    label="Include subfolders"
                  />
                </.form>
                <p
                  :if={@adding?}
                  id="learning-adding-note"
                  class="mt-5 rounded-md bg-teal-50 px-4 py-3 text-sm text-teal-900"
                >
                  Choose grids to add to {@collection.name}. A grid can belong to multiple topics and collections.
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
                        else: "Find a grid in this #{group_kind(@collection)}"
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
                      <% @folder_count > 0 && !@include_subfolders? -> %>
                        <h3 id="learning-folder-empty-title" class="mt-4 text-lg font-semibold">
                          Browse a folder above
                        </h3>
                        <p class="mt-2 text-sm leading-6 text-slate-600">
                          Select Include subfolders to see their grids together.
                        </p>
                      <% @collection -> %>
                        <h3 class="mt-4 text-lg font-semibold">
                          Start building this {group_kind(@collection)}
                        </h3>
                        <p class="mt-2 text-sm leading-6 text-slate-600">
                          Add an existing grid or start a new one on this subject.
                        </p>
                      <% true -> %>
                        <h3 class="mt-4 text-lg font-semibold">
                          Your learning starts with a question
                        </h3>
                        <p class="mt-2 text-sm leading-6 text-slate-600">
                          Choose New grid, or bookmark a grid from the community.
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
                          aria-label={"Organise #{grid.title}; drag to a topic or collection, or click to choose"}
                          title="Drag to a topic or collection, or click to organise"
                          class="mr-2 inline-flex cursor-grab rounded p-1 text-slate-400 hover:bg-teal-50 hover:text-teal-800 active:cursor-grabbing"
                        >
                          <.icon name="hero-bars-3" class="h-5 w-5" />
                        </button>
                        <.link
                          id={id <> "-open"}
                          href={learning_grid_path(grid)}
                          class="break-words font-serif text-xl font-semibold leading-7 text-slate-950 hover:text-teal-800"
                        >{grid.title}</.link>
                        <p class="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500">
                          <span>Updated {Calendar.strftime(grid.updated_at, "%d %b %Y")}</span>
                          <span>{if(grid.is_public, do: "Public grid", else: "Private grid")}</span>
                        </p>
                        <p
                          :if={grid.tags != [] && grid.tags != nil}
                          class="mt-2 text-xs text-slate-600"
                        >
                          {Enum.map_join(grid.tags, " · ", &tag_label/1)}
                        </p>
                        <div :if={grid.collections != []} class="mt-3 flex flex-wrap gap-2">
                          <.link
                            :for={collection <- grid.collections}
                            id={id <> "-topic-#{collection.id}"}
                            patch={filter_path(collection, @saved_kind)}
                            class="rounded bg-teal-50 px-2 py-1 text-xs font-medium text-teal-800"
                          >{collection.path}</.link>
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
                            >Add to {@collection.name}</button>
                          <% @collection && Enum.any?(grid.collections, &(&1.id == @collection.id)) -> %>
                            <button
                              id={id <> "-remove"}
                              type="button"
                              phx-click="remove_grid"
                              phx-value-title={grid.title}
                              aria-label={"Remove #{grid.title} from #{@collection.name}"}
                              class="text-sm text-slate-500 hover:text-red-700"
                            >Remove from {group_kind(@collection)}</button>
                          <% true -> %>
                            <.link
                              id={id <> "-continue"}
                              href={learning_grid_path(grid)}
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
                              href={learning_grid_path(grid, bookmark.node_id)}
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
                              href={
                                learning_grid_path(grid, highlight.node_id, highlight: highlight.id)
                              }
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

                    <details
                      :if={grid.user_id == @current_user.id}
                      id={id <> "-manage"}
                      class="mt-4 border-t border-stone-100 pt-3 text-xs font-semibold"
                    >
                      <summary id={id <> "-manage-toggle"} class="cursor-pointer text-slate-500">
                        Manage grid
                      </summary>
                      <div class="mt-3 flex flex-wrap items-center gap-4">
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
                    </details>
                  </article>
                </div>
                <button
                  :if={@more?}
                  id="learning-load-more"
                  type="button"
                  phx-click="load_more"
                  class="mt-5 rounded-md border border-stone-400 px-4 py-2 text-sm font-semibold hover:bg-white"
                >Load more grids</button>
              </div>
            </section>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
