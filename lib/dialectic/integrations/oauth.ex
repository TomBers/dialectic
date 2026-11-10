defmodule Dialectic.Integrations.OAuth do
  import Ecto.Query

  alias Dialectic.Accounts.User
  alias Dialectic.Integrations.{Authorization, OAuthClient, RefreshToken}
  alias Dialectic.Repo

  @scopes ~w(grids:create grids:read grids:append)

  def resource do
    Application.get_env(:dialectic, :mcp_resource, "http://127.0.0.1:4001/mcp")
  end

  def clients, do: Application.get_env(:dialectic, :mcp_oauth_clients, %{})
  def scopes, do: @scopes

  def client(id) when is_binary(id) and byte_size(id) in 1..255,
    do: clients()[id] || Repo.get_by(OAuthClient, client_id: id)

  def client(_), do: nil

  def register_client(params) do
    redirects = params["redirect_uris"]
    name = Map.get(params, "client_name", "MCP app")
    grants = Map.get(params, "grant_types", ["authorization_code"])

    with true <- is_binary(name) and String.length(String.trim(name)) in 1..100,
         true <- is_list(redirects) and length(redirects) in 1..10,
         true <- Enum.all?(redirects, &valid_redirect?/1),
         true <- Map.get(params, "token_endpoint_auth_method", "none") == "none",
         true <- Map.get(params, "response_types", ["code"]) == ["code"],
         true <-
           is_list(grants) and "authorization_code" in grants and
             Enum.all?(grants, &(&1 in ["authorization_code", "refresh_token"])),
         {:ok, client} <-
           Repo.insert(%OAuthClient{
             client_id: Ecto.UUID.generate(),
             name: String.trim(name),
             redirect_uris: Enum.uniq(redirects)
           }) do
      {:ok,
       %{
         client_id: client.client_id,
         client_name: client.name,
         redirect_uris: client.redirect_uris,
         token_endpoint_auth_method: "none",
         grant_types: ["authorization_code", "refresh_token"],
         response_types: ["code"]
       }}
    else
      _ -> {:error, :invalid_client_metadata}
    end
  end

  defp valid_redirect?(value) when is_binary(value) and byte_size(value) in 1..2048 do
    with {:ok, uri} <- URI.new(value) do
      is_binary(uri.host) and uri.host != "" and is_nil(uri.userinfo) and is_nil(uri.fragment) and
        (uri.scheme == "https" or
           (uri.scheme == "http" and uri.host in ["localhost", "127.0.0.1", "::1"]))
    else
      _ -> false
    end
  end

  defp valid_redirect?(_), do: false

  def validate_request(params) when is_map(params) do
    client = client(params["client_id"])

    with true <- is_map(client),
         true <- params["redirect_uri"] in client.redirect_uris,
         true <- params["response_type"] == "code",
         true <- params["resource"] == resource(),
         true <- params["code_challenge_method"] == "S256",
         challenge when is_binary(challenge) <- params["code_challenge"],
         true <- Regex.match?(~r/\A[A-Za-z0-9_-]{43}\z/, challenge),
         scope when is_binary(scope) and byte_size(scope) <= 256 <- params["scope"],
         requested_scopes when requested_scopes != [] <- String.split(scope),
         true <- Enum.all?(requested_scopes, &(&1 in @scopes)),
         state when is_binary(state) and byte_size(state) <= 1024 <- params["state"] || "" do
      {:ok,
       %{
         client_id: params["client_id"],
         redirect_uri: params["redirect_uri"],
         resource: resource(),
         scope: requested_scopes |> Enum.uniq() |> Enum.sort() |> Enum.join(" "),
         code_challenge: challenge,
         state: state,
         client_name: client.name
       }}
    else
      _ -> {:error, :invalid_request}
    end
  end

  def authorize(%User{} = user, request) do
    code = random_token()

    authorization = %Authorization{
      user_id: user.id,
      client_id: request.client_id,
      redirect_uri: request.redirect_uri,
      resource: request.resource,
      scope: request.scope,
      code_challenge: request.code_challenge,
      code_hash: hash(code),
      code_expires_at: DateTime.add(now(), 300, :second)
    }

    with {:ok, _authorization} <- Repo.insert(authorization), do: {:ok, code}
  end

  def exchange(%{"grant_type" => "authorization_code", "code" => code} = params)
      when is_binary(code) and byte_size(code) <= 256 do
    Repo.transact(fn ->
      authorization =
        Repo.one(
          from grant in Authorization, where: grant.code_hash == ^hash(code), lock: "FOR UPDATE"
        )

      if valid_exchange?(authorization, params) do
        token = random_token()

        authorization =
          authorization
          |> Ecto.Changeset.change(%{
            code_hash: nil,
            token_hash: hash(token),
            token_expires_at: DateTime.add(now(), 3600, :second)
          })
          |> Repo.update!()

        refresh = new_refresh_token(authorization, DateTime.add(now(), 30, :day))
        {:ok, token_response(authorization, token, refresh)}
      else
        {:error, :invalid_grant}
      end
    end)
  end

  def exchange(%{"grant_type" => "refresh_token", "refresh_token" => token} = params)
      when is_binary(token) and byte_size(token) in 1..256 do
    Repo.transact(fn ->
      refresh = Repo.get_by(RefreshToken, token_hash: hash(token))

      authorization =
        if refresh,
          do:
            Repo.one(
              from grant in Authorization,
                where: grant.id == ^refresh.authorization_id,
                lock: "FOR UPDATE"
            )

      refresh = if refresh, do: Repo.get!(RefreshToken, refresh.id)

      result =
        cond do
          is_nil(authorization) ->
            {:error, :invalid_grant}

          authorization.client_id != params["client_id"] or
              is_nil(client(authorization.client_id)) ->
            {:error, :invalid_grant}

          authorization.resource != Map.get(params, "resource", authorization.resource) or
              authorization.resource != resource() ->
            {:error, :invalid_grant}

          not is_nil(authorization.revoked_at) or
              DateTime.compare(refresh.expires_at, now()) != :gt ->
            {:error, :invalid_grant}

          not is_nil(refresh.used_at) ->
            authorization |> Ecto.Changeset.change(revoked_at: now()) |> Repo.update!()
            {:error, :invalid_grant}

          Map.has_key?(params, "scope") and params["scope"] != authorization.scope ->
            {:error, :invalid_scope}

          true ->
            refresh |> Ecto.Changeset.change(used_at: now()) |> Repo.update!()
            access = random_token()

            authorization =
              authorization
              |> Ecto.Changeset.change(
                token_hash: hash(access),
                token_expires_at: DateTime.add(now(), 3600, :second)
              )
              |> Repo.update!()

            next = new_refresh_token(authorization, refresh.expires_at)
            {:ok, token_response(authorization, access, next)}
        end

      {:ok, result}
    end)
    |> case do
      {:ok, result} -> result
      error -> error
    end
  end

  def exchange(_params), do: {:error, :invalid_grant}

  defp new_refresh_token(authorization, expires_at) do
    token = random_token()

    Repo.insert!(%RefreshToken{
      authorization_id: authorization.id,
      token_hash: hash(token),
      expires_at: expires_at
    })

    token
  end

  defp token_response(authorization, access, refresh),
    do: %{
      access_token: access,
      refresh_token: refresh,
      token_type: "Bearer",
      expires_in: 3600,
      scope: authorization.scope
    }

  def authenticate(token, required_scope) when is_binary(token) and byte_size(token) <= 256 do
    authorization =
      Repo.one(
        from grant in Authorization,
          where: grant.token_hash == ^hash(token),
          where: is_nil(grant.revoked_at) and grant.token_expires_at > ^now(),
          where: grant.resource == ^resource(),
          preload: [:user]
      )

    case authorization do
      %Authorization{user: %User{} = user, scope: scope} ->
        if Enum.all?(String.split(required_scope), &(&1 in String.split(scope))),
          do: {:ok, user},
          else: {:error, :insufficient_scope}

      _ ->
        {:error, :invalid_token}
    end
  end

  def authenticate(_token, _scope), do: {:error, :invalid_token}

  def list_connections(%User{id: user_id}) do
    Repo.all(
      from grant in Authorization,
        where: grant.user_id == ^user_id and is_nil(grant.revoked_at),
        where:
          grant.token_expires_at > ^now() or
            grant.id in subquery(
              from refresh in RefreshToken,
                where: refresh.expires_at > ^now() and is_nil(refresh.used_at),
                select: refresh.authorization_id
            ),
        order_by: [desc: grant.inserted_at]
    )
  end

  def revoke_connection(%User{id: user_id}, id) do
    from(grant in Authorization, where: grant.user_id == ^user_id and grant.id == ^id)
    |> Repo.update_all(set: [revoked_at: now()])

    :ok
  end

  def revoke_token(token, client_id)
      when is_binary(token) and byte_size(token) <= 256 and is_binary(client_id) and
             byte_size(client_id) <= 255 do
    token_hash = hash(token)

    from(grant in Authorization,
      where: grant.client_id == ^client_id,
      where:
        grant.token_hash == ^token_hash or
          grant.id in subquery(
            from refresh in RefreshToken,
              where: refresh.token_hash == ^token_hash,
              select: refresh.authorization_id
          )
    )
    |> Repo.update_all(set: [revoked_at: now()])

    :ok
  end

  def revoke_token(_token, _client_id), do: :ok

  defp valid_exchange?(nil, _params), do: false

  defp valid_exchange?(authorization, params) do
    verifier = params["code_verifier"]

    is_binary(verifier) and Regex.match?(~r/\A[A-Za-z0-9._~-]{43,128}\z/, verifier) and
      authorization.client_id == params["client_id"] and
      not is_nil(client(authorization.client_id)) and
      authorization.redirect_uri == params["redirect_uri"] and
      authorization.resource == params["resource"] and
      authorization.resource == resource() and
      is_nil(authorization.revoked_at) and
      DateTime.compare(authorization.code_expires_at, now()) == :gt and
      Plug.Crypto.secure_compare(
        authorization.code_challenge,
        Base.url_encode64(hash(verifier), padding: false)
      )
  end

  defp random_token, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  defp hash(value), do: :crypto.hash(:sha256, value)
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
