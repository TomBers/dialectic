defmodule Dialectic.RoundRobin do
  @moduledoc """
  Provides round-robin selection functionality over a list of leaf_nodes.
  """

  defstruct leaf_nodes: [], current_index: 0

  @doc """
  Creates a new RoundRobin selector with the given list of leaf_nodes.
  """
  def new(leaf_nodes) when is_list(leaf_nodes) do
    %__MODULE__{leaf_nodes: leaf_nodes, current_index: 0}
  end

  @doc """
  Returns the current leaf node.
  """
  def current(%__MODULE__{leaf_nodes: leaf_nodes, current_index: index}) do
    Enum.at(leaf_nodes, index)
  end

  @doc """
  Advances to the next leaf node in a round-robin fashion.
  Returns a tuple with the new leaf node and updated state.
  """
  def next(%__MODULE__{leaf_nodes: leaf_nodes, current_index: index} = rr) do
    len = length(leaf_nodes)
    new_index = rem(index + 1, max(len, 1))
    {Enum.at(leaf_nodes, new_index), %{rr | current_index: new_index}}
  end
  
  @doc """
  Moves to the previous leaf node in a round-robin fashion.
  Returns a tuple with the new leaf node and updated state.
  """
  def previous(%__MODULE__{leaf_nodes: leaf_nodes, current_index: index} = rr) do
    len = length(leaf_nodes)
    new_index = rem(index - 1 + len, max(len, 1))
    {Enum.at(leaf_nodes, new_index), %{rr | current_index: new_index}}
  end
end