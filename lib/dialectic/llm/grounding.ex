defmodule Dialectic.LLM.Grounding do
  @moduledoc false

  @sources_section ~r/^## Sources[ \t]*\n.*?(?=^##[ \t]|\z)/ims

  @spec merge(map() | nil, map()) :: map() | nil
  def merge(current, metadata) when is_map(metadata) do
    current = current || %{}
    provider_meta = fetch(metadata, :provider_meta) || metadata
    google_meta = fetch(provider_meta, :google) || %{}

    case fetch(google_meta, :grounding_metadata) do
      grounding_metadata when is_map(grounding_metadata) ->
        Map.update(
          current,
          "google",
          stringify_keys(grounding_metadata),
          &deep_merge(&1, stringify_keys(grounding_metadata))
        )

      _other ->
        empty_to_nil(current)
    end
  end

  def merge(current, _metadata), do: empty_to_nil(current || %{})

  @spec strip_sources(String.t()) :: String.t()
  def strip_sources(markdown) when is_binary(markdown) do
    markdown
    |> String.replace(@sources_section, "")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim_trailing()
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      deep_merge(left_value, right_value)
    end)
  end

  defp deep_merge(left, right) when is_list(left) and is_list(right),
    do: Enum.uniq(left ++ right)

  defp deep_merge(_left, right), do: right

  defp stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {to_string(key), stringify_keys(nested_value)}
    end)
  end

  defp stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  defp stringify_keys(value), do: value

  defp empty_to_nil(value) when value == %{}, do: nil
  defp empty_to_nil(value), do: value

  defp fetch(nil, _key), do: nil

  defp fetch(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp fetch(map, key) when is_map(map) and is_binary(key), do: Map.get(map, key)
  defp fetch(_value, _key), do: nil
end
