defmodule Dialectic.Content.PromotionMaterial do
  @moduledoc false

  alias Dialectic.Content
  alias Dialectic.Content.{DraftGenerator, FollowUpQuestions}
  alias Dialectic.Highlights
  alias DialecticWeb.HighlightShare

  @default_include MapSet.new(~w(grid raw assets posts))
  @all_include @default_include

  def build(graph, opts \\ []) do
    include = opts |> Keyword.get(:include, @default_include) |> normalize_include()
    platforms = opts |> Keyword.get(:platforms, []) |> normalize_list()
    campaign = opts |> Keyword.get(:utm_campaign, "promotion_api") |> to_string()
    graph_url = graph_url(graph)

    first_answer = first_answer_node(graph)
    follow_up_questions = first_answer |> node_content() |> FollowUpQuestions.extract()
    highlights = Highlights.list_highlights(mudg_id: graph.title)
    raw = raw_material(graph, first_answer, follow_up_questions, highlights)

    %{}
    |> maybe_put(include, "grid", fn -> grid_material(graph, graph_url) end)
    |> maybe_put(include, "raw", fn -> raw end)
    |> maybe_put(include, "assets", fn ->
      asset_material(graph, highlights, follow_up_questions, first_answer)
    end)
    |> maybe_put(include, "posts", fn ->
      post_material(graph, platforms, follow_up_questions, graph_url, campaign)
    end)
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

  defp raw_material(graph, first_answer, follow_up_questions, highlights) do
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
      highlights: Enum.map(highlights, &highlight_material(graph, &1)),
      key_nodes: nodes
    }
  end

  defp asset_material(graph, highlights, follow_up_questions, first_answer) do
    graph_asset = %{
      kind: "grid_card",
      title: graph.title,
      mime_type: "image/svg+xml",
      url: HighlightShare.graph_image_url(graph),
      recommended_platforms: ~w(x linkedin substack bluesky)
    }

    highlight_assets =
      highlights
      |> Enum.take(6)
      |> Enum.map(fn highlight ->
        %{
          kind: "highlight_card",
          highlight_id: highlight.id,
          node_id: highlight.node_id,
          title: "Highlighted quote",
          text: Content.excerpt(highlight.selected_text_snapshot, 220),
          mime_type: "image/svg+xml",
          url: HighlightShare.image_url(graph, highlight),
          recommended_platforms: ~w(instagram linkedin x bluesky)
        }
      end)

    follow_up_assets =
      follow_up_questions
      |> Enum.with_index(1)
      |> Enum.map(fn {question, index} ->
        %{
          kind: "follow_up_question_card",
          index: index,
          question: question,
          mime_type: "image/svg+xml",
          url: follow_up_card_url(graph, first_answer, question),
          recommended_platforms: ~w(instagram linkedin x bluesky)
        }
      end)

    [graph_asset] ++ highlight_assets ++ follow_up_assets
  end

  defp post_material(_graph, [], _follow_up_questions, _graph_url, _campaign), do: []

  defp post_material(graph, platforms, follow_up_questions, graph_url, campaign) do
    {:ok, posts} =
      DraftGenerator.generate_pack(graph,
        platforms: platforms,
        follow_up_questions: follow_up_questions,
        url: graph_url,
        utm_campaign: campaign
      )

    Enum.map(posts, fn post ->
      %{
        platform: post.platform,
        format: post.format,
        title: post.title,
        body: post.body,
        excerpt: post.excerpt,
        asset_kinds: recommended_asset_kinds(post.platform)
      }
    end)
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

  defp follow_up_card_url(graph, first_answer, question) do
    node_id =
      case first_answer do
        nil -> "1"
        node -> Map.get(node, "id") || Map.get(node, :id) || "1"
      end

    DialecticWeb.Endpoint.url() <>
      "/g/#{graph_identifier(graph)}/follow-up-card.svg?" <>
      URI.encode_query(%{node: to_string(node_id), question: question})
  end

  defp graph_url(graph),
    do: DialecticWeb.Endpoint.url() <> DialecticWeb.GraphPathHelper.graph_path(graph)

  defp graph_identifier(%{slug: slug}) when is_binary(slug) and slug != "", do: slug

  defp graph_identifier(%{title: title}) do
    URI.encode(to_string(title), &URI.char_unreserved?/1)
  end

  defp first_answer_node(graph) do
    graph
    |> Content.graph_nodes()
    |> Enum.find(fn node ->
      node_class(node) == "answer" and not hidden_node?(node)
    end)
  end

  defp hidden_node?(node) do
    Map.get(node, "deleted") == true or Map.get(node, :deleted) == true or
      Map.get(node, "compound") == true or Map.get(node, :compound) == true
  end

  defp node_class(node), do: Map.get(node, "class") || Map.get(node, :class) || ""
  defp node_content(nil), do: ""
  defp node_content(node), do: Map.get(node, "content") || Map.get(node, :content) || ""

  defp normalize_include(value) do
    value
    |> normalize_list()
    |> case do
      [] -> @default_include
      values -> values |> Enum.filter(&MapSet.member?(@all_include, &1)) |> MapSet.new()
    end
  end

  defp normalize_list(nil), do: []

  defp normalize_list(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_list(value) when is_list(value) do
    value
    |> Enum.flat_map(&normalize_list/1)
    |> Enum.uniq()
  end

  defp normalize_list(value), do: [to_string(value)]

  defp maybe_put(map, include, key, fun) do
    if MapSet.member?(include, key), do: Map.put(map, key, fun.()), else: map
  end

  defp recommended_asset_kinds(platform) when platform in ["instagram"] do
    ~w(follow_up_question_card highlight_card grid_card)
  end

  defp recommended_asset_kinds(platform)
       when platform in ["linkedin", "x", "bluesky", "threads"] do
    ~w(follow_up_question_card grid_card highlight_card)
  end

  defp recommended_asset_kinds(_platform), do: ~w(grid_card highlight_card)

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso8601(value), do: to_string(value)
end
