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
  def dot_class(_), do: "bg-gray-300"
end
