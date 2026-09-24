defmodule Dialectic.LearningReview do
  alias Dialectic.Accounts.Graph
  alias DialecticWeb.Utils.NodeTitleHelper

  @reasons ~w(prepare_lesson revisit_gap tutor_request independent_practice)

  def build(notes, highlights, user) do
    items =
      (notes ++ highlights)
      |> Enum.map(&review_item(&1, user))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.saved_at, :desc)
      |> Enum.uniq_by(&{&1.graph.title, &1.node_id})
      |> Enum.take(3)
      |> List.to_tuple()

    %{
      items: items,
      index: 0,
      status: :ready,
      revealed?: false,
      understood: 0,
      revisit: 0,
      reason: nil
    }
  end

  def count(review), do: tuple_size(review.items)

  def current(%{items: items, index: index}) when index < tuple_size(items),
    do: elem(items, index)

  def current(_review), do: nil

  def reason_form(params \\ %{}) do
    {%{}, %{reason: :string}}
    |> Ecto.Changeset.cast(params, [:reason])
    |> Ecto.Changeset.validate_required([:reason])
    |> Ecto.Changeset.validate_inclusion(:reason, @reasons)
  end

  def answer_form(params \\ %{}) do
    {%{}, %{answer: :string}}
    |> Ecto.Changeset.cast(params, [:answer])
    |> Ecto.Changeset.validate_required([:answer])
    |> Ecto.Changeset.validate_length(:answer, max: 2000)
  end

  def start(%{status: :ready} = review, reason) when reason in @reasons do
    if count(review) > 0,
      do: {:ok, %{review | status: :practising, reason: reason}},
      else: {:error, :empty}
  end

  def start(_review, _reason), do: {:error, :invalid}

  def reveal(%{status: :practising} = review), do: %{review | revealed?: true}
  def reveal(review), do: review

  def rate(%{status: :practising, revealed?: true} = review, rating)
      when rating in ["understood", "revisit"] do
    review =
      case rating do
        "understood" -> %{review | understood: review.understood + 1}
        "revisit" -> %{review | revisit: review.revisit + 1}
      end

    %{review | status: :rated}
  end

  def rate(review, _rating), do: review

  def next(%{status: :rated} = review) do
    index = review.index + 1
    status = if index < count(review), do: :practising, else: :complete
    %{review | index: index, status: status, revealed?: false}
  end

  def next(review), do: review

  defp review_item(%{selected_text_snapshot: passage, mudg: graph} = highlight, user) do
    build_item(graph, highlight.node_id, passage, highlight.updated_at, user)
  end

  defp review_item(%{is_noted: true, graph: graph} = note, user) do
    node = find_node(graph, note.node_id)
    build_item(graph, note.node_id, node && node["content"], note.updated_at, user)
  end

  defp review_item(_item, _user), do: nil

  defp build_item(%Graph{} = graph, node_id, passage, saved_at, user)
       when is_binary(passage) do
    node = find_node(graph, node_id)

    if graph.is_deleted != true and (graph.is_public == true or graph.user_id == user.id) and
         is_binary(graph.slug) and graph.slug != "" and not is_nil(node) and
         String.trim(passage) != "" do
      %{
        graph: Map.take(graph, [:title, :slug, :is_public]),
        node_id: node_id,
        title: NodeTitleHelper.extract_node_title(node, max_length: 120),
        passage: String.slice(passage, 0, 6000),
        truncated?: String.length(passage) > 6000,
        saved_at: to_string(saved_at)
      }
    end
  end

  defp build_item(_graph, _node_id, _passage, _saved_at, _user), do: nil

  defp find_node(%Graph{data: %{"nodes" => nodes}}, node_id) when is_list(nodes) do
    Enum.find_value(nodes, fn entry ->
      node = Map.get(entry, "data", entry)

      if node["id"] == node_id and node["deleted"] != true and node["compound"] != true,
        do: node
    end)
  end

  defp find_node(_graph, _node_id), do: nil
end
