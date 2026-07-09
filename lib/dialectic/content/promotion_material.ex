defmodule Dialectic.Content.PromotionMaterial do
  @moduledoc false

  alias Dialectic.Content
  alias Dialectic.Content.FollowUpQuestions
  alias Dialectic.Highlights
  alias DialecticWeb.HighlightShare

  def build(graph, _opts \\ []) do
    graph_url = graph_url(graph)
    first_answer = first_answer_node(graph)
    follow_up_questions = first_answer |> node_content() |> FollowUpQuestions.extract()
    key_questions = key_questions(graph, first_answer, follow_up_questions)
    highlights = Highlights.list_highlights(mudg_id: graph.title)
    raw = raw_material(graph, first_answer, follow_up_questions, key_questions, highlights)

    %{
      "grid" => grid_material(graph, graph_url),
      "raw" => raw,
      "assets" => asset_material(graph, highlights, key_questions)
    }
  end

  defp grid_material(graph, graph_url) do
    nodes = Content.graph_nodes(graph)

    %{
      title: graph.title,
      slug: graph.slug,
      url: graph_url,
      graph_url:
        DialecticWeb.Endpoint.url() <> DialecticWeb.GraphPathHelper.graph_editor_path(graph),
      tags: graph.tags || [],
      node_count: Enum.count(nodes, &(not hidden_node?(&1))),
      inserted_at: iso8601(graph.inserted_at),
      updated_at: iso8601(graph.updated_at)
    }
  end

  defp raw_material(graph, first_answer, follow_up_questions, key_questions, highlights) do
    nodes =
      graph
      |> Content.graph_nodes()
      |> Enum.reject(&hidden_node?/1)
      |> Enum.map(&Content.node_summary/1)
      |> Enum.sort_by(fn node -> {node.sort_class, node.title} end)
      |> Enum.take(12)

    %{
      origin_question: origin_question(graph, nodes),
      first_answer: first_answer_summary(first_answer),
      follow_up_questions: follow_up_questions,
      key_questions: key_questions,
      highlights: Enum.map(highlights, &highlight_material(graph, &1)),
      key_nodes: nodes
    }
  end

  defp asset_material(graph, highlights, key_questions) do
    graph_asset_url = HighlightShare.graph_image_url(graph)

    graph_asset = %{
      kind: "grid_card",
      title: graph.title,
      mime_type: "image/svg+xml",
      url: graph_asset_url,
      image_svg_url: graph_asset_url,
      preview_url: graph_asset_url
    }

    highlight_assets =
      highlights
      |> Enum.take(6)
      |> Enum.map(fn highlight ->
        image_url = HighlightShare.image_url(graph, highlight)

        %{
          kind: "highlight_card",
          highlight_id: highlight.id,
          node_id: highlight.node_id,
          title: "Highlighted quote",
          text: Content.excerpt(highlight.selected_text_snapshot, 220),
          mime_type: "image/svg+xml",
          url: image_url,
          image_svg_url: image_url,
          preview_url: image_url
        }
      end)

    key_question_assets =
      key_questions
      |> Enum.with_index(1)
      |> Enum.map(fn {question, index} ->
        image_url = question_card_url(graph, question.node_id, question.question)

        %{
          kind: "key_question_card",
          source: question.source,
          index: index,
          node_id: question.node_id,
          title: "Key question",
          text: question.question,
          question: question.question,
          mime_type: "image/svg+xml",
          url: image_url,
          image_svg_url: image_url,
          preview_url: image_url
        }
      end)

    [graph_asset] ++ highlight_assets ++ key_question_assets
  end

  defp highlight_material(graph, highlight) do
    %{
      id: highlight.id,
      node_id: highlight.node_id,
      text: highlight.selected_text_snapshot,
      note: highlight.note,
      share_url: HighlightShare.share_url(graph, highlight),
      image_svg_url: HighlightShare.image_url(graph, highlight)
    }
  end

  defp key_questions(graph, first_answer, follow_up_questions) do
    follow_up_items =
      follow_up_questions
      |> Enum.with_index(1)
      |> Enum.map(fn {question, index} ->
        %{
          source: "first_answer_follow_up",
          index: index,
          node_id: node_id(first_answer) || "1",
          question: question
        }
      end)

    user_question_items =
      graph
      |> Content.graph_nodes()
      |> Enum.reject(&hidden_node?/1)
      |> Enum.filter(&(node_class(&1) == "question"))
      |> Enum.map(fn node ->
        %{
          source: "user_question",
          node_id: node_id(node),
          question: question_text(node)
        }
      end)

    (follow_up_items ++ user_question_items)
    |> Enum.map(&clean_question_item/1)
    |> Enum.reject(&is_nil/1)
    |> uniq_by_question()
  end

  defp clean_question_item(%{question: question} = item) do
    question = question |> Content.excerpt(500) |> String.trim()

    if question != "" and String.ends_with?(question, "?") do
      %{item | question: question, node_id: to_string(item.node_id || "1")}
    end
  end

  defp uniq_by_question(items) do
    {_seen, items} =
      Enum.reduce(items, {MapSet.new(), []}, fn item, {seen, acc} ->
        key = item.question |> String.downcase() |> String.replace(~r/\s+/, " ")

        if MapSet.member?(seen, key) do
          {seen, acc}
        else
          {MapSet.put(seen, key), [item | acc]}
        end
      end)

    Enum.reverse(items)
  end

  defp question_text(node) do
    node
    |> node_content()
    |> Content.excerpt(500)
    |> String.trim()
  end

  defp node_id(nil), do: nil
  defp node_id(node), do: Map.get(node, "id") || Map.get(node, :id)

  defp first_answer_summary(nil), do: nil

  defp first_answer_summary(node) do
    node
    |> Content.node_summary()
    |> Map.take([:id, :title, :class, :excerpt])
    |> Map.put(:content, node_content(node))
  end

  defp origin_question(graph, nodes) do
    nodes
    |> Enum.find(&(&1.class == "origin"))
    |> case do
      nil -> graph.title
      node -> node.title
    end
  end

  defp question_card_url(graph, node_id, question) do
    DialecticWeb.Endpoint.url() <>
      "/g/#{graph_identifier(graph)}/follow-up-card.svg?" <>
      URI.encode_query(%{node: to_string(node_id || "1"), question: question})
  end

  defp graph_url(graph),
    do: DialecticWeb.Endpoint.url() <> DialecticWeb.GraphPathHelper.graph_path(graph)

  defp graph_identifier(%{slug: slug}) when is_binary(slug) and slug != "", do: slug

  defp graph_identifier(%{title: title}) do
    URI.encode(to_string(title), &URI.char_unreserved?/1)
  end

  defp first_answer_node(graph) do
    nodes = graph |> Content.graph_nodes() |> Enum.reject(&hidden_node?/1)
    nodes_by_id = Map.new(nodes, &{to_string(node_id(&1)), &1})

    origin_id =
      nodes
      |> Enum.find(&(node_class(&1) == "origin"))
      |> node_id()
      |> to_string()

    graph
    |> graph_edges()
    |> Enum.find_value(fn edge ->
      with %{from: ^origin_id, to: target_id} <- edge,
           %{} = node <- Map.get(nodes_by_id, target_id),
           true <- node_class(node) == "answer" do
        node
      else
        _ -> nil
      end
    end) ||
      Enum.find(nodes, &(node_class(&1) == "answer"))
  end

  defp hidden_node?(node) do
    Map.get(node, "deleted") == true or Map.get(node, :deleted) == true or
      Map.get(node, "compound") == true or Map.get(node, :compound) == true
  end

  defp graph_edges(graph) do
    graph
    |> get_in_data("edges")
    |> Enum.map(&graph_edge/1)
    |> Enum.reject(&is_nil/1)
  end

  defp graph_edge(%{"data" => %{"source" => source, "target" => target}})
       when not is_nil(source) and not is_nil(target) do
    %{from: to_string(source), to: to_string(target)}
  end

  defp graph_edge(_edge), do: nil

  defp get_in_data(%{data: data}, key) when is_map(data) do
    case Map.get(data, key) do
      value when is_list(value) -> value
      _ -> []
    end
  end

  defp get_in_data(_graph, _key), do: []

  defp node_class(node), do: Map.get(node, "class") || Map.get(node, :class) || ""
  defp node_content(nil), do: ""
  defp node_content(node), do: Map.get(node, "content") || Map.get(node, :content) || ""

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso8601(value), do: to_string(value)
end
