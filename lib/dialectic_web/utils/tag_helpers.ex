defmodule DialecticWeb.Utils.TagHelpers do
  def tag_label(tag) when is_binary(tag) do
    tag
    |> String.trim()
    |> String.replace(~r/(^|[\s-])\p{Ll}/u, &String.upcase/1)
  end

  def tag_label(_tag), do: ""
end
