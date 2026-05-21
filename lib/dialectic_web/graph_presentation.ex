defmodule DialecticWeb.GraphPresentation do
  @moduledoc """
  Shared helpers for graph presentation mode.
  """

  alias Dialectic.Graph.GraphActions

  def slides(graph_id, ids) when is_list(ids) do
    ids
    |> Enum.reduce([], fn id, acc ->
      case GraphActions.find_node(graph_id, id) do
        nil -> acc
        node -> [node | acc]
      end
    end)
    |> Enum.reverse()
  end

  def active_slide([], _node), do: nil

  def active_slide(slides, %{id: current_id}) do
    Enum.find(slides, &(&1.id == current_id)) || List.first(slides)
  end

  def active_slide(slides, _node), do: List.first(slides)

  def slide_position([], _slide_id), do: nil
  def slide_position(_slides, nil), do: nil

  def slide_position(slides, slide_id) do
    case Enum.find_index(slides, &(&1.id == slide_id)) do
      nil -> nil
      idx -> idx + 1
    end
  end

  def adjacent_slide([], _slide_id, _direction), do: nil

  def adjacent_slide(slides, slide_id, direction)
      when direction in ["next", "previous"] do
    current_index =
      Enum.find_index(slides, &(&1.id == slide_id)) || 0

    offset = if(direction == "next", do: 1, else: -1)
    target_index = current_index + offset

    if target_index < 0 do
      nil
    else
      Enum.at(slides, target_index)
    end
  end

  def body_markdown(%{content: content}) when is_binary(content) do
    case String.split(content, "\n", parts: 2) do
      [_title, body] -> String.trim(body)
      _ -> ""
    end
  end

  def body_markdown(_), do: ""

  def parent_slides(nil, _slides), do: []

  def parent_slides(active_slide, slides) do
    filter_related_slides(active_slide.parents, slides)
  end

  def child_slides(nil, _slides), do: []

  def child_slides(active_slide, slides) do
    filter_related_slides(active_slide.children, slides)
  end

  def type_label(node_class) do
    case to_string(node_class) do
      "question" -> "Question"
      "thesis" -> "Thesis"
      "antithesis" -> "Counterargument"
      "synthesis" -> "Synthesis"
      "ideas" -> "Related Ideas"
      "deepdive" -> "Deep Dive"
      "origin" -> "Stream"
      "user" -> "Comment"
      "answer" -> "Response"
      "explain" -> "Explanation"
      "blind_spots" -> "Blind Spots"
      "steel_man" -> "Steel Man"
      "says_who" -> "Source Lens"
      other -> other |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp filter_related_slides(related_nodes, slides) when is_list(related_nodes) do
    slide_id_set =
      slides
      |> Enum.map(& &1.id)
      |> MapSet.new()

    Enum.filter(related_nodes, &MapSet.member?(slide_id_set, &1.id))
  end

  defp filter_related_slides(_, _slides), do: []
end
