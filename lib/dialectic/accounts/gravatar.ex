defmodule Dialectic.Accounts.Gravatar do
  @moduledoc """
  Client for the Gravatar Profiles API.

  Given a Gravatar profile slug (e.g. "phenomenal1a25bedd6b"), fetches the
  user's profile data (avatar URL, header image, verified accounts, etc.)
  from the public API at `https://api.gravatar.com/v3/profiles/:slug`.

  Uses the `:req` HTTP client which is already included in the project.
  """

  require Logger

  @base_url "https://api.gravatar.com/v3/profiles"
  @timeout_ms 10_000

  @doc """
  Fetches the full Gravatar profile for the given slug.

  Returns `{:ok, profile_map}` on success where `profile_map` contains the
  raw JSON response from the Gravatar API, or `{:error, reason}` on failure.

  ## Examples

      iex> Dialectic.Accounts.Gravatar.fetch_profile("phenomenal1a25bedd6b")
      {:ok, %{"avatar_url" => "https://...", "header_image" => "url('https://...') ...", ...}}

      iex> Dialectic.Accounts.Gravatar.fetch_profile("nonexistent-slug-xyz")
      {:error, :not_found}
  """
  def fetch_profile(gravatar_id) when is_binary(gravatar_id) and gravatar_id != "" do
    slug = gravatar_id |> String.trim() |> String.downcase()
    url = "#{@base_url}/#{slug}"

    case Req.get(url, receive_timeout: @timeout_ms, connect_options: [timeout: @timeout_ms]) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, decoded} when is_map(decoded) ->
            {:ok, decoded}

          {:ok, decoded} ->
            Logger.error(
              "Gravatar API returned non-map JSON body for slug #{slug}: #{inspect(decoded)}"
            )

            {:error, :invalid_response}

          {:error, reason} ->
            Logger.error(
              "Gravatar API returned invalid JSON for slug #{slug}: #{inspect(reason)}"
            )

            {:error, {:decode_failed, reason}}
        end

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Gravatar API returned status #{status} for slug #{slug}")
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.error("Gravatar API request failed for slug #{slug}: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  def fetch_profile(_), do: {:error, :invalid_slug}

  @doc """
  Fetches the avatar URL for the given Gravatar profile slug.

  Returns `{:ok, avatar_url}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> Dialectic.Accounts.Gravatar.fetch_avatar_url("phenomenal1a25bedd6b")
      {:ok, "https://0.gravatar.com/avatar/e12484d0137f7a75e47708cc244818bb7d45d2e8b0e1d2aa82659ca4177234aa"}

      iex> Dialectic.Accounts.Gravatar.fetch_avatar_url("nonexistent-slug-xyz")
      {:error, :not_found}
  """
  def fetch_avatar_url(gravatar_id) when is_binary(gravatar_id) and gravatar_id != "" do
    case fetch_profile(gravatar_id) do
      {:ok, body} ->
        case Map.get(body, "avatar_url") do
          url when is_binary(url) and url != "" ->
            {:ok, url}

          _ ->
            slug = gravatar_id |> String.trim() |> String.downcase()
            Logger.warning("Gravatar profile #{slug} has no avatar_url in response")
            {:error, :no_avatar}
        end

      error ->
        error
    end
  end

  def fetch_avatar_url(_), do: {:error, :invalid_slug}

  @doc """
  Fetches the avatar URL and returns it directly, or nil on any failure.

  This is a convenience wrapper around `fetch_avatar_url/1` for cases where
  you just want the URL or nothing.

  ## Examples

      iex> Dialectic.Accounts.Gravatar.get_avatar_url("phenomenal1a25bedd6b")
      "https://0.gravatar.com/avatar/e12484d0137f7a75e47708cc244818bb7d45d2e8b0e1d2aa82659ca4177234aa"

      iex> Dialectic.Accounts.Gravatar.get_avatar_url("nonexistent")
      nil
  """
  def get_avatar_url(gravatar_id) do
    case fetch_avatar_url(gravatar_id) do
      {:ok, url} -> url
      _ -> nil
    end
  end

  @doc """
  Fetches profile data from a single Gravatar API call.

  Returns a map with:
    - `:avatar_url` — the user's avatar image URL (or nil)
    - `:header_image_url` — the user's header/banner image URL (or nil)
    - `:verified_accounts` — list of verified account maps, each with
      `:service_type`, `:service_label`, `:service_icon`, `:url` keys
      (visible accounts only; empty list on failure)
    - `:location` — the user's location string (or nil)

  ## Examples

      iex> Dialectic.Accounts.Gravatar.get_profile_data("phenomenal1a25bedd6b")
      %{
        avatar_url: "https://...",
        header_image_url: "https://...",
        verified_accounts: [
          %{service_type: "twitter", service_label: "X", service_icon: "https://...", url: "https://..."},
          ...
        ],
        location: "London"
      }

      iex> Dialectic.Accounts.Gravatar.get_profile_data("nonexistent")
      %{avatar_url: nil, header_image_url: nil, verified_accounts: [], location: nil}
  """
  def get_profile_data(gravatar_id) when is_binary(gravatar_id) and gravatar_id != "" do
    case fetch_profile(gravatar_id) do
      {:ok, body} ->
        avatar_url =
          case Map.get(body, "avatar_url") do
            url when is_binary(url) and url != "" -> url
            _ -> nil
          end

        header_image_url = extract_header_image_url(body)
        verified_accounts = extract_verified_accounts(body)

        location =
          case Map.get(body, "location") do
            loc when is_binary(loc) and loc != "" -> loc
            _ -> nil
          end

        %{
          avatar_url: avatar_url,
          header_image_url: header_image_url,
          verified_accounts: verified_accounts,
          location: location
        }

      _ ->
        %{avatar_url: nil, header_image_url: nil, verified_accounts: [], location: nil}
    end
  end

  def get_profile_data(_),
    do: %{avatar_url: nil, header_image_url: nil, verified_accounts: [], location: nil}

  # The Gravatar API returns header_image as a CSS background shorthand string, e.g.:
  #   "url('https://1.gravatar.com/userimage/...?size=1024') no-repeat 50% 1% / 100%"
  # We need to extract the actual image URL from inside url('...').
  # It can also be a map with a "url" key, or absent/nil.
  defp extract_header_image_url(body) do
    case Map.get(body, "header_image") do
      %{"url" => url} when is_binary(url) and url != "" ->
        url

      css when is_binary(css) and css != "" ->
        case Regex.run(~r/url\(['"]?(https?:\/\/[^'")\s]+)['"]?\)/, css) do
          [_, url] -> url
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # Extracts visible verified accounts from the Gravatar profile response.
  # Each account is normalized to a map with atom keys for consistency.
  defp extract_verified_accounts(body) do
    case Map.get(body, "verified_accounts") do
      accounts when is_list(accounts) ->
        accounts
        |> Enum.reject(fn acct -> Map.get(acct, "is_hidden", false) end)
        |> Enum.map(fn acct ->
          %{
            service_type: Map.get(acct, "service_type", ""),
            service_label: Map.get(acct, "service_label", ""),
            service_icon: Map.get(acct, "service_icon", ""),
            url: Map.get(acct, "url", "")
          }
        end)

      _ ->
        []
    end
  end
end
