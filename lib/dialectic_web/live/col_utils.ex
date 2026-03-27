defmodule DialecticWeb.ColUtils do
  @moduledoc """
  Centralizes the color schemes and Tailwind classes for different node types.
  Uses static strings to ensure Tailwind CSS generation.
  """

  # Backward compatibility alias
  def message_border_class(type), do: border_class(type)

  @doc """
  Returns the border class for the node card.
  """
  def border_class("origin"), do: "border-gray-900"
  def border_class("question"), do: "border-sky-500"
  def border_class("user"), do: "border-sky-500"
  def border_class("answer"), do: "border-gray-400"
  def border_class("thesis"), do: "border-emerald-500"
  def border_class("antithesis"), do: "border-red-500"
  def border_class("synthesis"), do: "border-violet-500"
  def border_class("ideas"), do: "border-orange-500"
  def border_class("deepdive"), do: "border-cyan-500"
  # Cluster 1 — Core Inquiry
  def border_class("clarify"), do: "border-teal-500"
  def border_class("assumptions"), do: "border-amber-500"
  def border_class("counterexample"), do: "border-red-500"
  def border_class("implications"), do: "border-indigo-500"
  def border_class("blind_spots"), do: "border-purple-500"
  # Cluster 2 — Context & Expansion
  def border_class("says_who"), do: "border-sky-500"
  def border_class("who_disagrees"), do: "border-rose-500"
  def border_class("analogy"), do: "border-emerald-500"
  def border_class("steel_man"), do: "border-yellow-500"
  def border_class("what_if"), do: "border-fuchsia-500"
  # Cluster 3 — Clarity
  def border_class("simplify"), do: "border-orange-400"
  def border_class(_), do: "border-gray-200"

  @doc """
  Returns the class string for the badge (pill) in the node header.
  Includes background, text color, and ring.
  """
  def badge_class("origin"), do: "bg-gray-900 text-gray-100 ring-1 ring-gray-900/10"
  def badge_class("question"), do: "bg-sky-50 text-sky-700 ring-1 ring-sky-600/10"
  def badge_class("user"), do: "bg-sky-50 text-sky-700 ring-1 ring-sky-600/10"
  def badge_class("answer"), do: "bg-gray-100 text-gray-700 ring-1 ring-gray-600/10"
  def badge_class("thesis"), do: "bg-emerald-50 text-emerald-700 ring-1 ring-emerald-600/10"
  def badge_class("antithesis"), do: "bg-red-50 text-red-700 ring-1 ring-red-600/10"
  def badge_class("synthesis"), do: "bg-violet-50 text-violet-700 ring-1 ring-violet-600/10"
  def badge_class("ideas"), do: "bg-orange-50 text-orange-700 ring-1 ring-orange-600/10"
  def badge_class("deepdive"), do: "bg-cyan-50 text-cyan-700 ring-1 ring-cyan-600/10"
  # Cluster 1 — Core Inquiry
  def badge_class("clarify"), do: "bg-teal-50 text-teal-700 ring-1 ring-teal-600/10"
  def badge_class("assumptions"), do: "bg-amber-50 text-amber-700 ring-1 ring-amber-600/10"
  def badge_class("counterexample"), do: "bg-red-50 text-red-700 ring-1 ring-red-600/10"
  def badge_class("implications"), do: "bg-indigo-50 text-indigo-700 ring-1 ring-indigo-600/10"
  def badge_class("blind_spots"), do: "bg-purple-50 text-purple-700 ring-1 ring-purple-600/10"
  # Cluster 2 — Context & Expansion
  def badge_class("says_who"), do: "bg-sky-50 text-sky-700 ring-1 ring-sky-600/10"
  def badge_class("who_disagrees"), do: "bg-rose-50 text-rose-700 ring-1 ring-rose-600/10"
  def badge_class("analogy"), do: "bg-emerald-50 text-emerald-700 ring-1 ring-emerald-600/10"
  def badge_class("steel_man"), do: "bg-yellow-50 text-yellow-700 ring-1 ring-yellow-600/10"
  def badge_class("what_if"), do: "bg-fuchsia-50 text-fuchsia-700 ring-1 ring-fuchsia-600/10"
  # Cluster 3 — Clarity
  def badge_class("simplify"), do: "bg-orange-50 text-orange-700 ring-1 ring-orange-600/10"
  def badge_class(_), do: "bg-gray-100 text-gray-600 ring-1 ring-gray-500/10"

  @doc """
  Returns the class string for the small colored dot in the minimap/tree view.
  """
  def dot_class("origin"), do: "bg-gray-900"
  def dot_class("question"), do: "bg-sky-500"
  def dot_class("user"), do: "bg-sky-500"
  def dot_class("answer"), do: "bg-gray-400"
  def dot_class("thesis"), do: "bg-emerald-500"
  def dot_class("antithesis"), do: "bg-red-500"
  def dot_class("synthesis"), do: "bg-violet-500"
  def dot_class("ideas"), do: "bg-orange-500"
  def dot_class("deepdive"), do: "bg-cyan-500"
  # Cluster 1 — Core Inquiry
  def dot_class("clarify"), do: "bg-teal-500"
  def dot_class("assumptions"), do: "bg-amber-500"
  def dot_class("counterexample"), do: "bg-red-500"
  def dot_class("implications"), do: "bg-indigo-500"
  def dot_class("blind_spots"), do: "bg-purple-500"
  # Cluster 2 — Context & Expansion
  def dot_class("says_who"), do: "bg-sky-500"
  def dot_class("who_disagrees"), do: "bg-rose-500"
  def dot_class("analogy"), do: "bg-emerald-500"
  def dot_class("steel_man"), do: "bg-yellow-500"
  def dot_class("what_if"), do: "bg-fuchsia-500"
  # Cluster 3 — Clarity
  def dot_class("simplify"), do: "bg-orange-400"
  def dot_class(_), do: "bg-gray-300"

  @doc """
  Returns a human-readable label for a node type.
  """
  def node_type_label("origin"), do: "Origin"
  def node_type_label("question"), do: "Question"
  def node_type_label("user"), do: "User Comment"
  def node_type_label("answer"), do: "Answer"
  def node_type_label("thesis"), do: "Pro / Supporting Point"
  def node_type_label("antithesis"), do: "Con / Counterpoint"
  def node_type_label("synthesis"), do: "Synthesis / Balanced View"
  def node_type_label("ideas"), do: "Related Ideas"
  def node_type_label("deepdive"), do: "Deep Dive"
  # Cluster 1 — Core Inquiry
  def node_type_label("clarify"), do: "Clarify"
  def node_type_label("assumptions"), do: "Assumptions"
  def node_type_label("counterexample"), do: "Counterexample"
  def node_type_label("implications"), do: "Implications"
  def node_type_label("blind_spots"), do: "Blind Spots"
  # Cluster 2 — Context & Expansion
  def node_type_label("says_who"), do: "Source Check"
  def node_type_label("who_disagrees"), do: "Disagreement"
  def node_type_label("analogy"), do: "Analogy"
  def node_type_label("steel_man"), do: "Steel Man"
  def node_type_label("what_if"), do: "What If"
  # Cluster 3 — Clarity
  def node_type_label("simplify"), do: "Simplify"
  def node_type_label(_), do: "Node"

  @doc """
  Returns a description explaining the node type and its color.
  """
  def node_type_description("origin"), do: "The starting point of the conversation (Black)"
  def node_type_description("question"), do: "A question posed to the AI (Blue)"
  def node_type_description("user"), do: "A comment or thought from a user (Blue)"
  def node_type_description("answer"), do: "An AI-generated response (Gray)"
  def node_type_description("thesis"), do: "A supporting argument or pro point (Green)"
  def node_type_description("antithesis"), do: "A counterargument or con point (Red)"

  def node_type_description("synthesis"),
    do: "A balanced synthesis of multiple perspectives (Purple)"

  def node_type_description("ideas"), do: "Related ideas and connections (Orange)"
  def node_type_description("deepdive"), do: "An in-depth exploration of a topic (Cyan)"
  # Cluster 1 — Core Inquiry
  def node_type_description("clarify"),
    do: "Conceptual clarification — What do you mean by…? (Teal)"

  def node_type_description("assumptions"),
    do: "Hidden assumptions — What has to be true? (Amber)"

  def node_type_description("counterexample"),
    do: "Counterexample testing — Is that always true? (Red)"

  def node_type_description("implications"), do: "Implication tracing — So what? (Indigo)"
  def node_type_description("blind_spots"), do: "Blind-spot detection — What's missing? (Purple)"
  # Cluster 2 — Context & Expansion
  def node_type_description("says_who"), do: "Source and authority check — Says who? (Sky)"

  def node_type_description("who_disagrees"),
    do: "Perspective challenge — Who would disagree? (Rose)"

  def node_type_description("analogy"), do: "Analogical reasoning — What is this like? (Emerald)"

  def node_type_description("steel_man"),
    do: "Charitable reconstruction of the opposing view (Yellow)"

  def node_type_description("what_if"), do: "Thought experiments and scenario testing (Fuchsia)"
  # Cluster 3 — Clarity
  def node_type_description("simplify"), do: "Clarity test — Rewrite for a 10-year-old (Orange)"
  def node_type_description(_), do: "A node in the conversation"
end
