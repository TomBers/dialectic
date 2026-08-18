defmodule DialecticWeb.MarkdownGrounding do
  @moduledoc false

  def encode(%{grounding_metadata: metadata}) when is_map(metadata) and map_size(metadata) > 0,
    do: Jason.encode!(metadata)

  def encode(_node), do: nil
end
