defmodule DialecticWeb.HighlightJSON do
  alias Dialectic.Highlights.Highlight

  @doc """
  Renders a list of highlights.
  """
  def index(%{highlights: highlights}) do
    %{data: for(highlight <- highlights, do: data(highlight))}
  end

  @doc """
  Renders a single highlight.
  """
  def show(%{highlight: highlight}) do
    %{data: data(highlight)}
  end

  defp data(%Highlight{} = highlight) do
    %{
      id: highlight.id,
      mudg_id: highlight.mudg_id,
      node_id: highlight.node_id,
      text_source_type: highlight.text_source_type,
      text_source_id: highlight.text_source_id,
      selection_start: highlight.selection_start,
      selection_end: highlight.selection_end,
      selected_text_snapshot: highlight.selected_text_snapshot,
      note: highlight.note,
      linked_node_id: highlight.linked_node_id,
      link_type: highlight.link_type,
      created_by_user_id: highlight.created_by_user_id,
      created_at: highlight.inserted_at,
      updated_at: highlight.updated_at
    }
  end
end
