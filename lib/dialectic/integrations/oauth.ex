defmodule Dialectic.Integrations.OAuth do
  import Ecto.Query

  alias Dialectic.Accounts.User
  alias Dialectic.Integrations.Authorization
  alias Dialectic.Repo

  @scopes ~w(grids:create grids:read)

  def resource do
    Application.get_env(:dialectic, :mcp_resource, "http://127.0.0.1:4001/mcp")
  end

  def clients, do: Application.get_env(:dialectic, :mcp_oauth_clients, %{})
  def scopes, do: @scopes

  def validate_request(params) when is_map(params) do
    client = clients()[params["client_id"]]

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

        authorization
        |> Ecto.Changeset.change(%{
          code_hash: nil,
          token_hash: hash(token),
          token_expires_at: DateTime.add(now(), 3600, :second)
        })
        |> Repo.update!()

        {:ok,
         %{
           access_token: token,
           token_type: "Bearer",
           expires_in: 3600,
           scope: authorization.scope
         }}
      else
        {:error, :invalid_grant}
      end
    end)
  end

  def exchange(_params), do: {:error, :invalid_grant}

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
        if required_scope in String.split(scope),
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
        where: grant.token_expires_at > ^now(),
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
    from(grant in Authorization,
      where: grant.token_hash == ^hash(token) and grant.client_id == ^client_id
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
      Map.has_key?(clients(), authorization.client_id) and
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
