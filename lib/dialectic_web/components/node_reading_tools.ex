defmodule DialecticWeb.NodeReadingTools do
  use DialecticWeb, :html

  alias DialecticWeb.Utils.NodeTitleHelper

  attr :prefix, :string, required: true
  attr :node_id, :string, required: true
  attr :bookmarked?, :boolean, required: true
  attr :highlight_count, :integer, required: true
  attr :open?, :boolean, required: true
  attr :toggle_target, :any, default: nil
  attr :dark, :boolean, default: false
  attr :bookmark_description, :string, default: nil
  attr :shortcut, :boolean, default: false

  def node_actions(assigns) do
    assigns =
      assign(assigns,
        actions_id:
          if(assigns.prefix == "reader",
            do: "reader-reading-tools-#{assigns.node_id}",
            else: "graph-node-actions-#{assigns.node_id}"
          ),
        bookmark_label:
          assigns.bookmark_description ||
            if(assigns.bookmarked?, do: "Remove bookmark", else: "Save for later")
      )

    ~H"""
    <div
      id={@actions_id}
      role="group"
      aria-label="Node actions"
      class="node-reading-actions"
      data-tone={if(@dark, do: "dark")}
    >
      <button
        id={"#{@prefix}-bookmark-node-#{@node_id}"}
        type="button"
        phx-click={if(@bookmarked?, do: "unnote", else: "note")}
        phx-value-node={@node_id}
        data-reader-shortcut={if(@shortcut, do: "b")}
        aria-keyshortcuts={if(@shortcut, do: "Alt+Shift+B")}
        aria-label={@bookmark_label}
        aria-pressed={to_string(@bookmarked?)}
        title={@bookmark_label}
        class="node-menu-action node-save-action"
      >
        <.icon
          name={if(@bookmarked?, do: "hero-bookmark-solid", else: "hero-bookmark")}
          class="h-4 w-4 shrink-0"
        />
        <span>{if(@bookmarked?, do: "Saved", else: "Save for later")}</span>
      </button>
      <button
        id={"#{@prefix}-node-#{@node_id}-highlights"}
        type="button"
        phx-click="toggle_node_highlights"
        phx-value-node-id={@node_id}
        phx-target={@toggle_target}
        aria-expanded={to_string(@open?)}
        aria-controls={"#{@prefix}-node-#{@node_id}-highlight-list"}
        aria-label={"#{if(@open?, do: "Hide", else: "Show")} #{@highlight_count} highlights"}
        class="node-menu-action node-highlights-action"
      >
        <.icon name="hero-pencil" class="h-4 w-4 shrink-0" /> Highlights
        <span class="node-highlight-count">{@highlight_count}</span>
        <span class={["inline-flex transition-transform", @open? && "rotate-180"]}><.icon
          name="hero-chevron-down"
          class="h-3 w-3"
        /></span>
      </button>
    </div>
    """
  end

  attr :prefix, :string, required: true
  attr :node_id, :string, required: true
  attr :graph_id, :string, required: true
  attr :highlights, :list, required: true
  attr :open?, :boolean, required: true

  def node_highlights(assigns) do
    ~H"""
    <ol :if={@open?} id={"#{@prefix}-node-#{@node_id}-highlight-list"} class="node-highlight-list">
      <li :if={@highlights == []} class="py-3 text-xs leading-5 text-slate-700">
        Select text in this answer to save a highlighted passage.
      </li>
      <li
        :for={{highlight, index} <- Enum.with_index(@highlights, 1)}
        class="grid grid-cols-[1.5rem_minmax(0,1fr)] items-start gap-2 py-3"
      >
        <span class="pt-0.5 text-right text-xs font-semibold leading-5 text-amber-900">{index}.</span>
        <div class="min-w-0">
          <button
            id={"#{@prefix}-highlight-link-#{highlight.id}"}
            type="button"
            phx-click={
              JS.push("highlight_clicked",
                value: %{id: highlight.id, node_id: @node_id, source: "node_list"}
              )
            }
            class="w-full rounded-md text-left text-sm italic leading-5 text-slate-950 hover:text-teal-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
            title="Jump to this highlighted passage"
          >{highlight_excerpt(highlight)}</button>
          <div
            :if={highlight.links && highlight.links != []}
            class="mt-2 flex flex-wrap items-center gap-1.5"
          >
            <span class="text-[10px] font-semibold uppercase tracking-[0.12em] text-teal-900">Connected ideas</span>
            <button
              :for={link <- highlight.links}
              id={"#{@prefix}-highlight-link-#{highlight.id}-node-#{link.node_id}"}
              type="button"
              phx-click="navigate_to_node"
              phx-value-node_id={link.node_id}
              class="inline-flex max-w-full items-start gap-1.5 rounded-md border border-stone-300 bg-white px-2.5 py-1.5 text-left text-xs font-medium leading-4 text-teal-900 hover:border-teal-700 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
              title="Open connected idea"
            >
              <.icon name="hero-link" class="mt-0.5 h-3 w-3 shrink-0" />
              <span class="min-w-0 whitespace-normal break-words">{highlight_link_title(
                @graph_id,
                link.node_id
              )}</span>
            </button>
          </div>
        </div>
      </li>
    </ol>
    """
  end

  defp highlight_excerpt(%{selected_text_snapshot: text}) when is_binary(text) do
    case String.trim(text) do
      "" -> "Highlighted passage"
      trimmed -> trimmed
    end
  end

  defp highlight_excerpt(_highlight), do: "Highlighted passage"

  defp highlight_link_title(graph_id, node_id) do
    case GraphManager.find_node_by_id(graph_id, node_id) do
      nil -> "Connected idea"
      node -> NodeTitleHelper.extract_node_title(node, max_length: 160)
    end
  end
end
