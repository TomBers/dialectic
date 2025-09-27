defmodule DialecticWeb.Utils.UserUtils do
  @moduledoc """
  Shared user normalization and ownership helper functions.

  This module centralizes common logic used across LiveViews and components for:
  - Normalizing arbitrary user-related fields to stable strings
  - Deriving the current identity string for presence/tracking
  - Checking node ownership consistently

  Conventions:
  - Normalization trims whitespace and lowercases strings for stable comparison
  - Empty or missing values normalize to an empty string (""), except `current_identity/1`
    which falls back to "Anon" for display/presence when nothing else is available
  """

  alias Dialectic.Accounts.User

  @anon "Anon"

  @doc """
  Normalizes any term into a comparable string.

  - Converts non-binaries via `to_string/1`
  - Trims leading/trailing whitespace
  - Lowercases
  - `nil` becomes `""`

  Examples:
    iex> normalize("  Alice@example.com ")
    "alice@example.com"

    iex> normalize(nil)
    ""
  """
  @spec normalize(term()) :: String.t()
  def normalize(nil), do: ""
  def normalize(term) when is_binary(term), do: term |> String.trim() |> String.downcase()
  def normalize(term), do: term |> to_string() |> String.trim() |> String.downcase()

  @doc """
  Normalizes an ID-like value to a stable string for equality checks.

  - Keeps original casing (IDs may be case-sensitive)
  - Trims whitespace
  - `nil` becomes `""`

  Examples:
    iex> normalize_id(123)
    "123"

    iex> normalize_id("  ABC-123  ")
    "ABC-123"
  """
  @spec normalize_id(term()) :: String.t()
  def normalize_id(nil), do: ""
  def normalize_id(id) when is_binary(id), do: String.trim(id)
  def normalize_id(id), do: id |> to_string() |> String.trim()

  @doc """
  Returns the preferred identity string (downcased email if present, otherwise the user-supplied
  `:user` assign, otherwise \"Anon\").

  Accepts a map of assigns that may include:
  - `:current_user` (a `%Dialectic.Accounts.User{}` or similar)
  - `:user` (free-form string identity)

  This is appropriate for presence tracking and display labels that previously used
  `String.downcase(current_user.email) || "Anon"`.
  """
  @spec current_identity(map()) :: String.t()
  def current_identity(assigns) when is_map(assigns) do
    email =
      case Map.get(assigns, :current_user) do
        %User{email: e} when is_binary(e) -> normalize(e)
        _ -> ""
      end

    user_assign = assigns |> Map.get(:user) |> normalize()

    cond do
      email != "" -> email
      user_assign != "" -> user_assign
      true -> @anon
    end
  end

  @doc """
  Determines whether the given `assigns` correspond to the owner of a node.

  Ownership rules (aligned with existing UI constraints):
  - If the node's `:user` field is blank, the current user is considered the owner
    when they have a non-blank email or a non-blank `:user` assign.
  - Otherwise, the node's `:user` must match one of:
    - current user's email (downcased)
    - current user's id (string)
    - the `:user` assign (downcased)

  Accepted node shape:
  - Map with a `:user` field (can be a string or nil)

  Accepted assigns:
  - Map including `:current_user` (a `%Dialectic.Accounts.User{}` or nil)
  - May include `:user` (free-form string identity)

  Returns true if the current user is considered the owner, false otherwise.
  """
  @spec owner?(map() | nil, map()) :: boolean()
  def owner?(nil, assigns) when is_map(assigns), do: false

  def owner?(node, assigns) when is_map(node) and is_map(assigns) do
    node_user = node |> Map.get(:user) |> normalize()

    current_user = Map.get(assigns, :current_user)

    current_email =
      case current_user do
        %User{email: e} when is_binary(e) -> normalize(e)
        _ -> ""
      end

    current_id =
      case current_user do
        %User{id: id} -> normalize_id(id)
        _ -> ""
      end

    user_assign_norm = assigns |> Map.get(:user) |> normalize()

    (node_user == "" and (current_email != "" or user_assign_norm != "")) or
      node_user == current_email or
      (current_id != "" and node_user == current_id) or
      node_user == user_assign_norm
  end
end
