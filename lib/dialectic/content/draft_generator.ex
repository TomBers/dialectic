defmodule Dialectic.Content.DraftGenerator do
  @moduledoc false

  alias Dialectic.Content
  alias Dialectic.Highlights

  @default_platforms []

  @platforms [
    %{
      id: "x",
      label: "X",
      format: "short_post",
      goal: "A concise hook using one sharp question or tension."
    },
    %{
      id: "instagram",
      label: "Instagram",
      format: "carousel_script",
      goal: "A text-first carousel script with 5 short slides and a contribution CTA."
    },
    %{
      id: "linkedin",
      label: "LinkedIn",
      format: "short_post",
      goal: "A thoughtful professional post with 2-4 short paragraphs and a question at the end."
    },
    %{
      id: "substack",
      label: "Substack",
      format: "newsletter",
      goal: "A long-form newsletter draft with title, sections, open questions, and CTA."
    },
    %{
      id: "bluesky",
      label: "Bluesky",
      format: "short_post",
      goal: "A conversational short post that invites replies and additions."
    },
    %{
      id: "threads",
      label: "Threads",
      format: "thread",
      goal: "A short thread with a hook, 2-4 follow-up posts, and a contribution CTA."
    },
    %{
      id: "reddit",
      label: "Reddit",
      format: "discussion_prompt",
      goal:
        "A non-promotional discussion prompt asking for the strongest missing argument or source."
    },
    %{
      id: "mastodon",
      label: "Mastodon",
      format: "short_post",
      goal: "A public-interest short post with a clear question and invitation to contribute."
    }
  ]

  def default_platforms, do: @default_platforms
  def platform_options, do: @platforms

  def platform_label(platform) do
    @platforms
    |> Enum.find(%{label: platform}, &(&1.id == platform))
    |> Map.fetch!(:label)
  end

  def platform_format(platform) do
    @platforms
    |> Enum.find(%{format: "short_post"}, &(&1.id == platform))
    |> Map.fetch!(:format)
  end

  def generate_pack(graph, opts \\ []) do
    platforms = opts |> Keyword.get(:platforms, @default_platforms) |> valid_platforms()
    post_type = opts |> Keyword.get(:post_type, "contribution_prompt") |> to_string()
    node_id = opts[:node_id]
    base_url = Keyword.fetch!(opts, :url)
    campaign = Keyword.get(opts, :utm_campaign, "content_studio")
    follow_up_questions = opts |> Keyword.get(:follow_up_questions, []) |> clean_questions()

    source = build_source(graph, node_id, follow_up_questions)

    drafts =
      platforms
      |> output_specs(base_url, campaign)
      |> Enum.map(&draft_for_platform(&1, graph, source, post_type, node_id))

    {:ok, drafts}
  end

  defp clean_questions(questions) do
    questions
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.ends_with?(&1, "?"))
    |> Enum.uniq()
    |> Enum.take(8)
  end

  defp valid_platforms(platforms) do
    valid = @platforms |> Enum.map(& &1.id) |> MapSet.new()

    platforms
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.filter(&MapSet.member?(valid, &1))
  end

  defp output_specs(platforms, base_url, campaign) do
    Enum.map(platforms, fn platform ->
      %{
        platform: platform,
        label: platform_label(platform),
        format: platform_format(platform),
        url: append_utm(base_url, platform, campaign)
      }
    end)
  end

  defp build_source(graph, node_id, follow_up_questions) do
    nodes =
      graph
      |> Content.graph_nodes()
      |> Enum.reject(&node_hidden?/1)

    selected_node = selected_node(nodes, node_id)
    summaries = Enum.map(nodes, &Content.node_summary/1)
    origin = Enum.find(summaries, &(&1.class == "origin")) || List.first(summaries)

    highlights =
      [mudg_id: graph.title]
      |> Highlights.list_highlights()
      |> Enum.map(&highlight_summary/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
      |> Enum.take(5)

    question =
      [selected_node && Content.node_summary(selected_node), origin | summaries]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.title)
      |> Enum.find(&questionish?/1) ||
        List.first(follow_up_questions) || graph.title

    key_points =
      summaries
      |> Enum.reject(&(&1.excerpt == ""))
      |> Enum.reject(&(&1.title == question))
      |> Enum.take(5)

    %{
      question: question,
      graph_title: graph.title,
      tags: graph.tags || [],
      origin: origin,
      selected_node: selected_node && Content.node_summary(selected_node),
      key_points: key_points,
      highlights: highlights,
      follow_up_questions: follow_up_questions
    }
  end

  defp draft_for_platform(spec, graph, source, post_type, node_id) do
    body =
      case spec.platform do
        "x" -> x_body(source, spec.url, post_type)
        "instagram" -> instagram_body(source, spec.url, post_type)
        "linkedin" -> linkedin_body(source, spec.url, post_type)
        "substack" -> substack_body(source, spec.url, post_type)
        "bluesky" -> bluesky_body(source, spec.url, post_type)
        "threads" -> threads_body(source, spec.url, post_type)
        "reddit" -> reddit_body(source, spec.url, post_type)
        "mastodon" -> mastodon_body(source, spec.url, post_type)
        _ -> x_body(source, spec.url, post_type)
      end

    %{
      graph_title: graph.title,
      node_id: blank_to_nil(node_id),
      platform: spec.platform,
      platform_label: spec.label,
      format: spec.format,
      title: draft_title(spec.platform, source, post_type),
      body: body,
      excerpt: excerpt_for(source, post_type),
      status: "draft",
      utm_source: spec.platform,
      utm_campaign: utm_campaign_from_url(spec.url),
      metadata: %{
        "post_type" => post_type,
        "source" => "template",
        "signals" => source_signals(source)
      }
    }
  end

  defp x_body(source, url, post_type) do
    if source.follow_up_questions != [] do
      [
        "A key follow-up question from this RationalGrid topic:",
        smart_quote(truncate(List.first(source.follow_up_questions), 210)),
        follow_up_cta(source, post_type),
        url
      ]
      |> compact_join("\n\n")
    else
      [
        short_hook(source, post_type),
        maybe_quote(source, 170),
        cta(post_type),
        url
      ]
      |> compact_join("\n\n")
    end
  end

  defp bluesky_body(source, url, post_type) do
    question = List.first(source.follow_up_questions) || source.question

    [
      "A question I’d like more perspectives on:",
      smart_quote(truncate(question, 220)),
      follow_up_cta(source, post_type),
      url
    ]
    |> compact_join("\n\n")
  end

  defp mastodon_body(source, url, post_type) do
    question = List.first(source.follow_up_questions) || source.question

    [
      "I’m collecting careful arguments around this question:",
      smart_quote(truncate(question, 220)),
      first_highlight_sentence(source),
      follow_up_cta(source, post_type),
      url
    ]
    |> compact_join("\n\n")
  end

  defp linkedin_body(source, url, post_type) do
    branches = bullet_points(source.key_points, 4)
    follow_ups = source.follow_up_questions |> Enum.take(3) |> bullet_lines()

    [
      "I’m mapping a question on RationalGrid:",
      smart_quote(source.question),
      if(branches != "", do: "Some branches already worth testing:\n#{branches}"),
      if(follow_ups != "", do: "The key follow-up questions are:\n#{follow_ups}"),
      maybe_quote(source, 260),
      follow_up_cta(source, post_type),
      url
    ]
    |> compact_join("\n\n")
  end

  defp instagram_body(source, url, _post_type) do
    first_point = source.key_points |> List.first() |> point_text()
    follow_ups = source.follow_up_questions |> Enum.take(2) |> numbered_lines()
    quote = source.highlights |> List.first()

    [
      "Instagram carousel draft",
      "Slide 1: #{truncate(source.question, 110)}",
      if(first_point, do: "Slide 2: One branch\n#{truncate(first_point, 160)}"),
      if(quote, do: "Slide 3: Highlight\n#{smart_quote(truncate(quote, 150))}"),
      if(follow_ups != "", do: "Slide 4: Questions still open\n#{follow_ups}"),
      "Slide 5: What perspective, source, objection, or example should be added next?",
      "Link / CTA: #{url}"
    ]
    |> compact_join("\n\n")
  end

  defp threads_body(source, url, post_type) do
    branches = source.key_points |> Enum.take(3) |> Enum.map(&point_text/1)
    follow_ups = source.follow_up_questions |> Enum.take(3) |> numbered_lines()

    highlighted_point = first_highlight_sentence(source)

    [
      "A question worth mapping: #{truncate(source.question, 190)}",
      if(follow_ups != "", do: "Key follow-up questions:\n#{follow_ups}"),
      if(highlighted_point, do: "A highlighted point: #{truncate(highlighted_point, 220)}"),
      if(branches != [], do: "Branches so far:\n#{numbered_lines(branches)}"),
      "#{follow_up_cta(source, post_type)}\n#{url}"
    ]
    |> Enum.reject(&blank?/1)
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {post, index} -> "#{index}/ #{post}" end)
  end

  defp reddit_body(source, url, _post_type) do
    branches = bullet_points(source.key_points, 5)
    follow_ups = source.follow_up_questions |> Enum.take(3) |> bullet_lines()

    [
      "I’m trying to map the strongest arguments around this question:",
      smart_quote(source.question),
      if(branches != "", do: "So far, the map includes:\n#{branches}"),
      if(follow_ups != "", do: "Open follow-up questions:\n#{follow_ups}"),
      "What is the strongest argument, source, objection, or lived example missing here?",
      "For context, I’m collecting it here: #{url}"
    ]
    |> compact_join("\n\n")
  end

  defp substack_body(source, url, post_type) do
    branches = bullet_points(source.key_points, 6)
    highlights = source.highlights |> Enum.take(3) |> Enum.map(&smart_quote/1) |> bullet_lines()
    follow_ups = source.follow_up_questions |> Enum.take(5) |> bullet_lines()

    [
      "Title: #{source.question}",
      "Subtitle: A live RationalGrid topic collecting questions, answers, objections, and missing perspectives.",
      "## The question\n#{source.question}",
      if(branches != "", do: "## Branches already in the topic\n#{branches}"),
      if(highlights != "", do: "## Highlighted lines\n#{highlights}"),
      if(follow_ups != "", do: "## Follow-up questions\n#{follow_ups}"),
      "## What I’m looking for\n#{cta(post_type)}",
      "I’m continuing to map this publicly on RationalGrid. If you have a source, objection, lived experience, or better framing, add it here:\n#{url}"
    ]
    |> compact_join("\n\n")
  end

  defp short_hook(source, "unresolved_disagreement") do
    case Enum.take(source.key_points, 2) do
      [a, b | _] ->
        "Two ideas I’m trying to reconcile:\n\n1. #{truncate(a.title, 120)}\n2. #{truncate(b.title, 120)}"

      _ ->
        "A tension worth mapping:"
    end
  end

  defp short_hook(_source, "quote_excerpt"), do: "A highlighted line from a RationalGrid topic:"
  defp short_hook(_source, "expert_invitation"), do: "Looking for people who know this area:"

  defp short_hook(_source, "argument_summary"),
    do: "I’m mapping the main branches around this question:"

  defp short_hook(_source, _post_type), do: "A question worth mapping:"

  defp cta("expert_invitation") do
    "If you know the field, what source, objection, or lived example belongs here?"
  end

  defp cta("quote_excerpt") do
    "What does this line miss, clarify, or get wrong?"
  end

  defp cta("argument_summary") do
    "What branch of the argument is missing?"
  end

  defp cta("unresolved_disagreement") do
    "What would help resolve the tension, or make it sharper?"
  end

  defp cta(_post_type) do
    "What perspective, source, objection, or example should be added next?"
  end

  defp follow_up_cta(%{follow_up_questions: []}, post_type), do: cta(post_type)

  defp follow_up_cta(_source, _post_type) do
    "Which of these questions is most important to answer next — and what should be added?"
  end

  defp maybe_quote(%{highlights: [highlight | _]}, max_length) do
    smart_quote(truncate(highlight, max_length))
  end

  defp maybe_quote(%{question: question}, max_length),
    do: smart_quote(truncate(question, max_length))

  defp first_highlight_sentence(%{highlights: [highlight | _]}) do
    truncate(highlight, 220)
  end

  defp first_highlight_sentence(_source), do: nil

  defp draft_title("substack", source, _post_type), do: source.question

  defp draft_title(platform, source, post_type),
    do:
      "#{platform_label(platform)} · #{human_post_type(post_type)} · #{truncate(source.question, 72)}"

  defp excerpt_for(source, "quote_excerpt") do
    source.highlights |> List.first() |> Kernel.||(source.question) |> truncate(180)
  end

  defp excerpt_for(source, _post_type), do: truncate(source.question, 180)

  defp source_signals(source) do
    %{
      "highlights" => length(source.highlights),
      "follow_up_questions" => length(source.follow_up_questions),
      "key_points" => length(source.key_points)
    }
  end

  defp selected_node(_nodes, node_id) when node_id in [nil, ""], do: nil

  defp selected_node(nodes, node_id) do
    Enum.find(nodes, fn node ->
      to_string(Map.get(node, "id") || Map.get(node, :id)) == to_string(node_id)
    end)
  end

  defp node_hidden?(node) do
    Map.get(node, "deleted") == true or Map.get(node, :deleted) == true or
      Map.get(node, "compound") == true or Map.get(node, :compound) == true
  end

  defp highlight_summary(highlight) do
    [highlight.selected_text_snapshot, highlight.note]
    |> Enum.reject(&blank?/1)
    |> Enum.join(" — ")
    |> Content.excerpt(260)
  end

  defp questionish?(text) do
    text = to_string(text)

    String.ends_with?(text, "?") or
      String.match?(text, ~r/^(what|why|how|should|can|could|is|are|does|do)\b/i)
  end

  defp bullet_points(points, limit) do
    points
    |> Enum.take(limit)
    |> Enum.map(&point_text/1)
    |> bullet_lines()
  end

  defp point_text(nil), do: nil
  defp point_text(%{title: title, excerpt: excerpt}) when excerpt in [nil, ""], do: title
  defp point_text(%{title: title, excerpt: excerpt}), do: "#{title}: #{excerpt}"
  defp point_text(text), do: to_string(text)

  defp bullet_lines(items) do
    items
    |> Enum.reject(&blank?/1)
    |> Enum.map_join("\n", &"- #{&1}")
  end

  defp numbered_lines(items) do
    items
    |> Enum.reject(&blank?/1)
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {item, index} -> "#{index}. #{item}" end)
  end

  defp smart_quote(text), do: "“#{text}”"

  defp compact_join(items, separator) do
    items
    |> Enum.reject(&blank?/1)
    |> Enum.join(separator)
  end

  defp append_utm(url, source, campaign) do
    separator = if String.contains?(url, "?"), do: "&", else: "?"

    url <>
      separator <>
      URI.encode_query(%{
        utm_source: source,
        utm_medium: "content",
        utm_campaign: campaign
      })
  end

  defp utm_campaign_from_url(url) do
    case URI.parse(url) do
      %{query: query} when is_binary(query) ->
        query |> URI.decode_query() |> Map.get("utm_campaign", "content_studio")

      _ ->
        "content_studio"
    end
  end

  defp human_post_type(post_type) do
    post_type
    |> to_string()
    |> String.replace("_", " ")
  end

  defp truncate(text, max_length) do
    text = to_string(text)

    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: to_string(value)

  defp blank?(false), do: true
  defp blank?(value), do: value in [nil, ""] or String.trim(to_string(value)) == ""
end
