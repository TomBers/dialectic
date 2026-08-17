defmodule DialecticWeb.ActionToolbarComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.Utils.UserUtils

  @moduledoc """
  Node-level action toolbar for graph operations.

  ## Required Assigns
  - `:node` - The current node being operated on
  - `:user` - The user ID (for ownership checks)
  - `:current_user` - The current user struct
  - `:graph_id` - The graph ID
  - `:can_edit` - Boolean indicating if editing is allowed
  """

  defp delete_info(assigns) do
    node = assigns[:node]
    children = (node && (node.children || [])) || []
    live_children = Enum.reject(children, &Map.get(&1, :deleted, false))
    owner? = UserUtils.owner?(node, %{current_user: assigns[:current_user], user: assigns[:user]})
    locked? = assigns[:can_edit] == false
    deletable? = owner? && live_children == [] && !locked?

    title =
      cond do
        deletable? -> "Delete this node"
        locked? -> "Cannot delete: graph is locked"
        not owner? -> "Cannot delete: you are not the author"
        true -> "Cannot delete: this node has dependent responses"
      end

    %{deletable?: deletable?, title: title}
  end

  @impl true
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="relative mt-3 min-w-0 break-words sm:mt-4"
      data-external="true"
      data-role="action-toolbar"
    >
      <% delete = delete_info(assigns) %>

      <.live_component
        module={DialecticWeb.InquiryActionsComp}
        id={"node-inquiry-actions-#{@node.id}"}
        context={:node}
        node={@node}
        graph_id={@graph_id}
        can_edit={@can_edit}
        form={@form}
        prompt_mode={@prompt_mode}
        ask_question={@ask_question}
      />

      <div class="mt-1 flex items-center justify-end px-1">
        <button
          id={"delete-node-#{@graph_id}-#{@node.id}"}
          type="button"
          disabled={!delete.deletable?}
          phx-click={if(delete.deletable?, do: "delete_node")}
          phx-value-node={@node.id}
          data-confirm={if(delete.deletable?, do: "Are you sure you want to delete this node?")}
          aria-disabled={not delete.deletable?}
          data-disabled={not delete.deletable?}
          class="inline-flex items-center gap-1.5 rounded-lg px-2 py-1.5 text-xs font-medium text-rose-700 transition hover:bg-rose-50 disabled:cursor-not-allowed disabled:text-slate-400 disabled:hover:bg-transparent"
          title={delete.title}
        >
          <.icon name="hero-trash" class="h-3.5 w-3.5" />
          <span>Delete node</span>
        </button>

        <span
          :if={@can_edit == false}
          class="ml-1.5 inline-flex items-center gap-1 text-[11px] font-medium text-amber-700"
          title="Graph is locked; editing is disabled"
        >
          <.icon name="hero-lock-closed" class="h-3 w-3" /> Locked
        </span>
      </div>
    </div>
    """
  end
end
