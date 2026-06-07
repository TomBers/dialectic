defmodule Dialectic.Accounts.ProfileBanner do
  @moduledoc false

  @banner_path "/images/profile-banners"
  @featured_order [
    "liquid-cheese",
    "diagonal-stripes",
    "rose-petals",
    "endless-constellation",
    "bermuda-diamond"
  ]

  def all do
    banner_files()
    |> Enum.map(&banner_from_path/1)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(&sort_key/1)
  end

  def ids, do: Enum.map(all(), & &1.id)

  def options do
    [{"Theme gradient", ""} | Enum.map(all(), &{&1.name, &1.id})]
  end

  def url(id) when is_binary(id) and id != "" do
    case Enum.find(all(), &(&1.id == id)) do
      %{path: path} -> path
      _ -> nil
    end
  end

  def url(_), do: nil

  def next_id(current_id) do
    case ids() do
      [] -> nil
      [first | _] = ids -> next_id(ids, current_id, first)
    end
  end

  defp next_id(ids, current_id, first) when is_binary(current_id) and current_id != "" do
    case Enum.find_index(ids, &(&1 == current_id)) do
      nil -> first
      index -> Enum.at(ids, rem(index + 1, length(ids)))
    end
  end

  defp next_id(_ids, _current_id, first), do: first

  defp banner_files do
    [
      :dialectic
      |> :code.priv_dir()
      |> to_string()
      |> Path.join("static#{@banner_path}/*.svg"),
      Path.join(File.cwd!(), "priv/static#{@banner_path}/*.svg")
    ]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
  end

  defp banner_from_path(path) do
    id = path |> Path.basename(".svg")

    %{
      id: id,
      name: humanize(id),
      path: "#{@banner_path}/#{id}.svg"
    }
  end

  defp humanize(id) do
    id
    |> String.split("-", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp sort_key(%{id: id, name: name}) do
    case Enum.find_index(@featured_order, &(&1 == id)) do
      nil -> {1, name}
      index -> {0, index}
    end
  end
end
