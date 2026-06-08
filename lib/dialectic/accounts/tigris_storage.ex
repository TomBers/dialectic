defmodule Dialectic.Accounts.TigrisStorage do
  @moduledoc false

  @service "s3"
  @algorithm "AWS4-HMAC-SHA256"

  def configured? do
    case config() do
      {:ok, _config} -> true
      :error -> false
    end
  end

  def put_object(key, bytes, content_type) do
    with {:ok, config} <- config(),
         {:ok, _response} <- request(:put, config, key, bytes, content_type) do
      {:ok, public_url(config, key)}
    end
  end

  def delete_object(key) when is_binary(key) and key != "" do
    with {:ok, config} <- config() do
      case request(:delete, config, key, "", "application/octet-stream") do
        {:ok, _response} -> :ok
        {:error, _reason} -> :ok
      end
    else
      :error -> :ok
    end
  end

  def delete_object(_), do: :ok

  def object_key_from_public_url(public_url) when is_binary(public_url) do
    with {:ok, config} <- config(),
         true <- String.starts_with?(public_url, public_base_url(config) <> "/") do
      public_url
      |> String.replace_prefix(public_base_url(config) <> "/", "")
      |> URI.decode()
      |> then(&{:ok, &1})
    else
      _ -> :error
    end
  end

  def object_key_from_public_url(_), do: :error

  defp request(method, config, key, body, content_type) do
    url = object_url(config, key)
    headers = signed_headers(method, config, key, body, content_type)

    req_options = Keyword.get(config, :req_options, [])

    request = Req.new(req_options)

    opts = [
      url: url,
      body: body,
      headers: [
        {"authorization", headers.authorization},
        {"content-type", content_type},
        {"x-amz-content-sha256", headers.payload_hash},
        {"x-amz-date", headers.amz_date}
      ]
    ]

    result =
      case method do
        :put -> Req.put(request, opts)
        :delete -> Req.delete(request, opts)
      end

    case result do
      {:ok, %{status: status} = response} when status in 200..299 -> {:ok, response}
      {:ok, %{status: 404} = response} when method == :delete -> {:ok, response}
      {:ok, %{status: status, body: body}} -> {:error, {:unexpected_status, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp signed_headers(method, config, key, body, content_type) do
    now = Keyword.get(config, :signing_datetime) || DateTime.utc_now()
    amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
    date = Calendar.strftime(now, "%Y%m%d")
    payload_hash = sha256_hex(body)
    host = endpoint_host(config)
    canonical_uri = canonical_uri(config, key)

    canonical_headers =
      "content-type:#{content_type}\n" <>
        "host:#{host}\n" <>
        "x-amz-content-sha256:#{payload_hash}\n" <>
        "x-amz-date:#{amz_date}\n"

    signed_headers = "content-type;host;x-amz-content-sha256;x-amz-date"

    canonical_request =
      method
      |> method_name()
      |> then(fn method_name ->
        [
          method_name,
          canonical_uri,
          "",
          canonical_headers,
          signed_headers,
          payload_hash
        ]
      end)
      |> Enum.join("\n")

    credential_scope = "#{date}/#{config[:region]}/#{@service}/aws4_request"

    string_to_sign =
      [@algorithm, amz_date, credential_scope, sha256_hex(canonical_request)]
      |> Enum.join("\n")

    signature =
      config[:secret_access_key]
      |> signing_key(date, config[:region])
      |> hmac(string_to_sign)
      |> Base.encode16(case: :lower)

    authorization =
      "#{@algorithm} " <>
        "Credential=#{config[:access_key_id]}/#{credential_scope}, " <>
        "SignedHeaders=#{signed_headers}, " <>
        "Signature=#{signature}"

    %{
      authorization: authorization,
      amz_date: amz_date,
      payload_hash: payload_hash
    }
  end

  defp config do
    opts = Application.get_env(:dialectic, :profile_image_storage, [])

    tigris =
      opts
      |> Keyword.get(:tigris, [])
      |> Map.new()

    config = %{
      access_key_id: value(tigris, :access_key_id),
      secret_access_key: value(tigris, :secret_access_key),
      region: value(tigris, :region) || "auto",
      endpoint_url: value(tigris, :endpoint_url),
      bucket: value(tigris, :bucket),
      public_base_url: value(tigris, :public_base_url),
      req_options: Map.get(tigris, :req_options, []),
      signing_datetime: Map.get(tigris, :signing_datetime)
    }

    if Enum.all?(
         [:access_key_id, :secret_access_key, :endpoint_url, :bucket],
         &present?(config[&1])
       ) do
      {:ok, Enum.into(config, [])}
    else
      :error
    end
  end

  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp present?(value), do: is_binary(value) and value != ""

  defp object_url(config, key) do
    config
    |> api_base_url()
    |> URI.merge("/#{config[:bucket]}/#{encode_key(key)}")
    |> URI.to_string()
  end

  defp public_url(config, key) do
    public_base_url(config) <> "/" <> encode_key(key)
  end

  defp public_base_url(config) do
    case config[:public_base_url] do
      url when is_binary(url) and url != "" -> String.trim_trailing(url, "/")
      _ -> api_base_url(config) <> "/" <> config[:bucket]
    end
  end

  defp api_base_url(config), do: config[:endpoint_url] |> String.trim_trailing("/")

  defp endpoint_host(config) do
    config
    |> api_base_url()
    |> URI.parse()
    |> Map.fetch!(:host)
  end

  defp canonical_uri(config, key) do
    "/#{config[:bucket]}/#{encode_key(key)}"
  end

  defp encode_key(key) do
    key
    |> String.split("/", trim: true)
    |> Enum.map_join("/", fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
  end

  defp method_name(:put), do: "PUT"
  defp method_name(:delete), do: "DELETE"

  defp sha256_hex(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end

  defp signing_key(secret_access_key, date, region) do
    ("AWS4" <> secret_access_key)
    |> hmac(date)
    |> hmac(region)
    |> hmac(@service)
    |> hmac("aws4_request")
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
end
