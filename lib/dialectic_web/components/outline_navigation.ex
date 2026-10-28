defmodule DialecticWeb.OutlineNavigation do
  use DialecticWeb, :html

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :selected_id, :string, default: nil
  attr :expanded_ids, :any, required: true
  attr :comment_ids, :any, required: true
  attr :path_ids, :any, required: true
  attr :graph, :map, required: true
  attr :params, :list, default: []
  attr :can_focus, :boolean, default: false
  attr :focused, :boolean, default: false
  attr :mobile, :boolean, default: false

  def outline_navigation(assigns) do
    rows = annotate_rows(assigns.rows)
    assigns = assign(assigns, :navigation_rows, rows)

    ~H"""
    <nav id={@id} aria-label="Grid outline" class="space-y-1 p-3">
      <div
        :for={row <- @navigation_rows}
        id={"#{@id}-row-#{row.id}"}
        hidden={hidden_row?(row, @expanded_ids, @comment_ids)}
        style={"margin-left: #{min(row.indent, 5) * 0.5}rem;"}
      >
        <div class="flex items-start gap-1">
          <.link
            id={"#{@id}-node-#{row.id}"}
            patch={graph_path(@graph, row.id, @params)}
            phx-click={if(@mobile, do: JS.dispatch("close-mobile-outline", to: "#outline-layout"))}
            aria-current={if(@selected_id == row.id, do: "location")}
            data-outline-selected={to_string(@selected_id == row.id)}
            title={row.full_title}
            class={[
              "flex min-h-11 min-w-0 flex-1 items-start gap-2 rounded-lg border px-2.5 py-2.5 text-sm leading-5 transition",
              if(@selected_id == row.id,
                do: "border-teal-900 bg-teal-800 font-semibold text-white",
                else:
                  "border-transparent text-slate-800 hover:border-stone-300 hover:bg-white hover:text-slate-950"
              ),
              row.class == "user" && "text-xs"
            ]}
          >
            <.icon
              name={if(row.class == "user", do: "hero-chat-bubble-left", else: "hero-document-text")}
              class={[
                "mt-0.5 h-4 w-4 shrink-0",
                if(@selected_id == row.id, do: "text-teal-100", else: "text-slate-600")
              ]}
            />
            <span class="min-w-0 flex-1">
              <span class="line-clamp-2">{row.full_title}</span>
              <span
                :if={@selected_id == row.id}
                class="mt-0.5 block text-[10px] font-semibold uppercase tracking-wide text-teal-100"
              >You are here</span>
              <span
                :if={row.branch?}
                class={[
                  "mt-0.5 block text-[11px] font-normal",
                  if(@selected_id == row.id, do: "text-stone-200", else: "text-slate-600")
                ]}
              >{row.directions} directions to explore</span>
            </span>
          </.link>
          <button
            :if={row.has_children?}
            id={"#{@id}-branch-#{row.id}"}
            type="button"
            phx-click="toggle_outline_branch"
            phx-value-id={row.id}
            aria-expanded={to_string(MapSet.member?(@expanded_ids, row.id))}
            aria-label={"#{if(MapSet.member?(@expanded_ids, row.id), do: "Collapse", else: "Expand")} #{row.title}"}
            class="inline-flex h-11 w-8 shrink-0 items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 hover:text-slate-800"
          >
            <.icon
              name={
                if(MapSet.member?(@expanded_ids, row.id),
                  do: "hero-chevron-down",
                  else: "hero-chevron-right"
                )
              }
              class="h-3.5 w-3.5"
            />
          </button>
        </div>
        <button
          :if={row.comments > 0}
          id={"#{@id}-comments-#{row.id}"}
          type="button"
          phx-click="toggle_outline_comments"
          phx-value-id={row.id}
          aria-expanded={to_string(MapSet.member?(@comment_ids, row.id))}
          class="ml-8 inline-flex min-h-8 items-center gap-1.5 text-xs text-slate-500 hover:text-teal-800"
        >
          <.icon name="hero-chat-bubble-left" class="h-3.5 w-3.5" /> {row.comments} {if(
            row.comments == 1,
            do: "comment",
            else: "comments"
          )}
        </button>
        <button
          :if={@selected_id == row.id && @can_focus && !@focused}
          id={if(@mobile, do: "outline-mobile-choose-path", else: "outline-choose-path")}
          type="button"
          phx-click="choose_path"
          class="mb-2 ml-3 inline-flex min-h-9 items-center gap-1.5 px-2 text-xs font-medium text-teal-800 hover:underline"
        >
          <.icon name="hero-arrow-right-circle" class="h-3.5 w-3.5" /> Focus on this thread
        </button>
      </div>
    </nav>
    """
  end

  defp annotate_rows(rows) do
    {rows, _stack} =
      Enum.map_reduce(rows, [], fn row, stack ->
        ancestors = Enum.take_while(stack, fn {_id, indent} -> indent < row.indent end)

        parent_id =
          case List.last(ancestors) do
            {id, _} -> id
            _ -> nil
          end

        {Map.merge(row, %{ancestors: Enum.map(ancestors, &elem(&1, 0)), parent_id: parent_id}),
         ancestors ++ [{row.id, row.indent}]}
      end)

    children = Enum.group_by(rows, & &1.parent_id)

    Enum.map(rows, fn row ->
      direct = Map.get(children, row.id, [])
      comments = Enum.count(direct, &(&1.class == "user"))
      directions = length(direct) - comments

      Map.merge(row, %{
        has_children?: direct != [],
        comments: comments,
        directions: directions,
        branch?: directions > 1
      })
    end)
  end

  defp hidden_row?(row, expanded_ids, comment_ids) do
    Enum.any?(row.ancestors, &(not MapSet.member?(expanded_ids, &1))) ||
      (row.class == "user" && row.parent_id && !MapSet.member?(comment_ids, row.parent_id))
  end
end
