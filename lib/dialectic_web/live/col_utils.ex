defmodule DialecticWeb.ColUtils do
  @moduledoc """
  Centralizes the color schemes and Tailwind classes for different node types.
  """

  # Map node types to their base Tailwind color palette name
  @colors %{
    "question" => "sky",
    "user" => "sky",
    "answer" => "gray",
    "thesis" => "emerald",
    "antithesis" => "red",
    "synthesis" => "violet",
    "ideas" => "orange",
    "deepdive" => "cyan",
    "origin" => "gray",
    # Fallback
    "default" => "gray"
  }

  # Backward compatibility alias
  def message_border_class(type), do: border_class(type)

  @doc """
  Returns the border class for the node card.
  """
  def border_class(type) do
    color = Map.get(@colors, type, "gray")

    case {type, color} do
      {"origin", _} -> "border-gray-900"
      {"answer", _} -> "border-gray-400"
      {_, "gray"} -> "border-gray-200"
      _ -> "border-#{color}-500"
    end
  end

  @doc """
  Returns the class string for the badge (pill) in the node header.
  Includes background, text color, and ring.
  """
  def badge_class(type) do
    color = Map.get(@colors, type, "gray")

    case {type, color} do
      {"origin", _} ->
        "bg-gray-900 text-gray-100 ring-1 ring-gray-900/10"

      {_, "gray"} when type != "answer" ->
        "bg-gray-100 text-gray-600 ring-1 ring-gray-500/10"

      _ ->
        "bg-#{color}-50 text-#{color}-700 ring-1 ring-#{color}-600/10"
    end
  end

  @doc """
  Returns the class string for the small colored dot in the minimap/tree view.
  """
  def dot_class(type) do
    color = Map.get(@colors, type, "gray")

    case {type, color} do
      {"origin", _} -> "bg-gray-900"
      {_, "gray"} when type != "answer" -> "bg-gray-300"
      _ -> "bg-#{color}-500"
    end
  end
end
