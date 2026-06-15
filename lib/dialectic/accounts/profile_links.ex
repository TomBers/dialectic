defmodule Dialectic.Accounts.ProfileLinks do
  @moduledoc false

  @max_links 20
  @max_label_length 60
  @max_value_length 500
  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  def empty_row, do: %{"label" => "", "value" => ""}

  def form_rows(profile_links) do
    case display_links(profile_links) do
      [] -> [empty_row()]
      links -> Enum.map(links, &%{"label" => &1.label, "value" => &1.value})
    end
  end

  def rows_from_params(%{"links" => links}), do: rows_from_params(links)

  def rows_from_params(links) when is_map(links) do
    links
    |> Enum.sort_by(fn {index, _row} -> parse_index(index) end)
    |> Enum.map(fn {_index, row} -> normalize_row_shape(row) end)
  end

  def rows_from_params(links) when is_list(links), do: Enum.map(links, &normalize_row_shape/1)
  def rows_from_params(_), do: []

  def prepare_for_storage(rows) do
    with {:ok, links} <- normalize_rows(rows) do
      {:ok, %{"links" => links}}
    end
  end

  def validate_storage(%{"links" => links}) do
    case normalize_rows(links) do
      {:ok, _links} -> :ok
      {:error, message} -> {:error, message}
    end
  end

  def validate_storage(_), do: {:error, "must be a valid profile links object"}

  def display_links(%{"links" => links}) when is_list(links) do
    links
    |> Enum.map(&normalize_link_for_display/1)
    |> Enum.reject(&is_nil/1)
  end

  def display_links(_), do: []

  defp normalize_rows(rows) do
    rows =
      rows
      |> Enum.map(&normalize_row_shape/1)
      |> Enum.reject(&blank_row?/1)

    cond do
      length(rows) > @max_links ->
        {:error, "You can add up to #{@max_links} profile links."}

      true ->
        rows
        |> Enum.reduce_while({:ok, []}, fn row, {:ok, acc} ->
          case normalize_input_row(row) do
            {:ok, link} -> {:cont, {:ok, [link | acc]}}
            {:error, message} -> {:halt, {:error, message}}
          end
        end)
        |> case do
          {:ok, links} -> {:ok, Enum.reverse(links)}
          error -> error
        end
    end
  end

  defp normalize_input_row(%{"label" => label, "value" => value}) do
    label = normalize_string(label)
    value = normalize_string(value)

    cond do
      label == "" ->
        {:error, "Each profile link needs a label."}

      value == "" ->
        {:error, "Each profile link needs a URL or email address."}

      String.length(label) > @max_label_length ->
        {:error, "Profile link labels must be #{@max_label_length} characters or fewer."}

      String.length(value) > @max_value_length ->
        {:error, "Profile links must be #{@max_value_length} characters or fewer."}

      true ->
        case normalize_href(value) do
          {:ok, href, kind, display_value} ->
            {:ok, %{"label" => label, "value" => display_value, "href" => href, "kind" => kind}}

          {:error, message} ->
            {:error, message}
        end
    end
  end

  defp normalize_input_row(_),
    do: {:error, "Each profile link needs a label and URL or email address."}

  defp normalize_link_for_display(row) do
    case normalize_input_row(row) do
      {:ok, %{"label" => label, "value" => value, "href" => href, "kind" => kind}} ->
        %{label: label, value: value, href: href, kind: kind}

      {:error, _message} ->
        nil
    end
  end

  defp normalize_href("mailto:" <> email) do
    email = normalize_string(email)

    if Regex.match?(@email_regex, email) do
      {:ok, "mailto:" <> email, "email", email}
    else
      {:error, "Email profile links must be valid email addresses."}
    end
  end

  defp normalize_href(value) do
    cond do
      Regex.match?(@email_regex, value) ->
        {:ok, "mailto:" <> value, "email", value}

      true ->
        normalize_url(value)
    end
  end

  defp normalize_url(value) do
    value = maybe_add_scheme(value)
    uri = URI.parse(value)

    cond do
      uri.scheme not in ["http", "https"] ->
        {:error, "Profile links must be HTTP(S) URLs or email addresses."}

      is_nil(uri.host) or uri.host == "" ->
        {:error, "Profile links must include a valid host."}

      String.contains?(value, [" ", "\n", "\t"]) ->
        {:error, "Profile links cannot contain spaces."}

      true ->
        {:ok, URI.to_string(uri), "url", URI.to_string(uri)}
    end
  end

  defp maybe_add_scheme(value) do
    uri = URI.parse(value)

    if is_nil(uri.scheme) do
      "https://" <> value
    else
      value
    end
  end

  defp normalize_row_shape(row) when is_map(row) do
    %{
      "label" => row["label"] || row[:label] || "",
      "value" => row["value"] || row[:value] || row["url"] || row[:url] || ""
    }
  end

  defp normalize_row_shape(_), do: empty_row()

  defp blank_row?(%{"label" => label, "value" => value}) do
    normalize_string(label) == "" and normalize_string(value) == ""
  end

  defp normalize_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize_string(_), do: ""

  defp parse_index(index) when is_integer(index), do: index

  defp parse_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {integer, _rest} -> integer
      :error -> 0
    end
  end

  defp parse_index(_), do: 0
end
