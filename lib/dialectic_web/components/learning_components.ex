defmodule DialecticWeb.LearningComponents do
  use DialecticWeb, :html

  attr :items, :any, required: true
  attr :selected, :any, required: true
  attr :saved_kind, :string, required: true
  slot :inner_block

  def folder_tree(assigns) do
    ~H"""
    <section id="learning-collections-group" aria-labelledby="learning-collections-heading">
      <h2
        id="learning-collections-heading"
        data-learning-folder-drop="root"
        class="mb-1 mt-6 rounded px-3 py-2 text-xs font-bold uppercase tracking-wider text-slate-500 data-[drag-over=true]:ring-2 data-[drag-over=true]:ring-teal-500"
      >
        Collections
      </h2>
      <p class="mb-2 px-3 text-xs text-slate-500">Created by you</p>
      <div id="learning-collections" phx-update="stream" class="space-y-1">
        <p id="learning-collections-empty" class="hidden px-3 py-2 text-sm text-slate-600 only:block">
          Create a collection to group your grids.
        </p>
        <div
          :for={{id, folder} <- @items}
          id={id}
          class="flex items-center"
          style={"padding-left: #{folder.depth * 0.75}rem"}
        >
          <button
            :if={folder.has_children?}
            id={"learning-expand-#{folder.id}"}
            type="button"
            phx-click="toggle_folder"
            phx-value-id={folder.id}
            aria-expanded={to_string(folder.expanded?)}
            aria-label={"#{if(folder.expanded?, do: "Collapse", else: "Expand")} #{folder.name}"}
            class="shrink-0 rounded p-1 text-slate-500 hover:bg-white"
          >
            <.icon
              name={if(folder.expanded?, do: "hero-chevron-down", else: "hero-chevron-right")}
              class="h-4 w-4"
            />
          </button>
          <.link
            id={"collections-#{folder.id}"}
            patch={~p"/my/learning?#{%{collection: folder.id, saved: @saved_kind}}"}
            draggable="true"
            data-learning-folder-drag={folder.id}
            data-learning-drop={folder.id}
            data-learning-folder-drop={folder.id}
            aria-current={if(@selected && @selected.id == folder.id, do: "page")}
            title={folder.path}
            class={[
              "flex min-w-0 flex-1 items-center gap-2 rounded-md px-3 py-3 text-sm data-[drag-over=true]:ring-2 data-[drag-over=true]:ring-teal-500",
              if(@selected && @selected.id == folder.id,
                do: "bg-teal-800 font-semibold text-white",
                else: "hover:bg-white"
              )
            ]}
          >
            <.icon name="hero-folder" class="h-5 w-5 shrink-0" />
            <span class="min-w-0 flex-1 break-words">{folder.name}</span>
            <span
              aria-label={"#{folder.grid_count} #{if(folder.grid_count == 1, do: "grid", else: "grids")}"}
              class="text-xs tabular-nums"
            >{folder.grid_count}</span>
          </.link>
        </div>
      </div>
      {render_slot(@inner_block)}
    </section>
    """
  end
end
