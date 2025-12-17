defmodule DialecticWeb.Utils.UserUtils do
  @moduledoc """
  Utilities for handling user identity and permissions in LiveViews.
  """

  @doc """
  Returns the identifier for the current user (email) or "anonymous".
  """
  def current_identity(assigns) do
    case assigns[:current_user] do
      %{email: email} -> email
      _ -> "anonymous"
    end
  end

  @doc """
  Checks if the current user is the owner of the given node.
  """
  def owner?(node, assigns) do
    identity = current_identity(assigns)

    case identity do
      "anonymous" -> false
      email -> Map.get(node, :user) == email
    end
  end
end
