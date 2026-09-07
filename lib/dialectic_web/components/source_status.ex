defmodule DialecticWeb.SourceStatus do
  @moduledoc false
  use DialecticWeb, :html

  attr :node, :map, required: true
  attr :id, :string, required: true

  def source_status(assigns) do
    count = length(Dialectic.LLM.Grounding.sources(Map.get(assigns.node, :grounding_metadata)))

    visible? =
      Map.get(assigns.node, :class) not in ["origin", "question", "user", "learning_plan"] and
        String.trim(Map.get(assigns.node, :content) || "") != ""

    assigns = assign(assigns, count: count, visible?: visible?)

    ~H"""
    <p
      :if={@visible?}
      id={@id}
      data-source-status={if @count > 0, do: "links_returned", else: "no_links"}
      class="mt-3 text-xs leading-5 text-slate-600"
    >
      <%= if @count > 0 do %>
        <strong>{@count} source {if @count == 1, do: "link", else: "links"} returned.</strong>
        Claims have not been independently verified.
      <% else %>
        <strong>No source links recorded for this answer.</strong>
      <% end %>
    </p>
    """
  end

  attr :node, :map, required: true
  attr :id, :string, required: true

  def action_targets(assigns) do
    targets =
      assigns.node
      |> Map.get(:guided_plan)
      |> Dialectic.Responses.GuidedLearningPlan.actions()
      |> Enum.map(&Map.get(&1, :target))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.node_id)

    assigns = assign(assigns, :targets, targets)

    ~H"""
    <div :if={@targets != []} id={@id} class="mt-3 text-sm text-slate-600">
      <p :for={target <- @targets}>Actions apply to: <strong>{target.title}</strong></p>
    </div>
    """
  end
end
