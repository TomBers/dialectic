defmodule Dialectic.Integrations.OAuthTest do
  use Dialectic.DataCase, async: false

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Integrations.{Authorization, OAuth}

  setup :configure_mcp

  test "requires a registered client, exact redirect, audience, scopes, and S256 PKCE" do
    {params, _verifier} = authorization_params()
    assert {:ok, _} = OAuth.validate_request(params)

    for {field, value} <- [
          {"client_id", "unknown"},
          {"redirect_uri", "https://attacker.example"},
          {"redirect_uri", params["redirect_uri"] <> "?attacker=1"},
          {"resource", "https://other.example/mcp"},
          {"scope", "grids:delete"},
          {"scope", ""},
          {"code_challenge_method", "plain"},
          {"code_challenge", "invalid"},
          {"response_type", "token"},
          {"state", ["bad"]}
        ] do
      assert {:error, :invalid_request} = OAuth.validate_request(Map.put(params, field, value))
    end
  end

  test "codes are short lived, bound to PKCE and client, and consumed exactly once" do
    user = user_fixture()
    {params, verifier} = authorization_params()
    {:ok, request} = OAuth.validate_request(params)
    {:ok, code} = OAuth.authorize(user, request)
    token_request = token_params(params, verifier, code)

    for {field, value} <- [
          {"code_verifier", String.duplicate("x", 43)},
          {"client_id", "unknown"},
          {"resource", "https://other.example/mcp"},
          {"redirect_uri", "https://attacker.example"}
        ] do
      assert {:error, :invalid_grant} = OAuth.exchange(Map.put(token_request, field, value))
    end

    assert {:ok, token} = OAuth.exchange(token_request)
    assert token.expires_in == 3600
    assert {:ok, authenticated} = OAuth.authenticate(token.access_token, "grids:create")
    assert authenticated.id == user.id
    assert {:error, :invalid_grant} = OAuth.exchange(token_request)
    authorization = Repo.one!(Authorization)
    assert authorization.code_hash == nil
    assert authorization.token_hash == :crypto.hash(:sha256, token.access_token)
    refute authorization.token_hash == token.access_token
  end

  test "expired codes cannot become access tokens" do
    {params, verifier} = authorization_params()
    {:ok, request} = OAuth.validate_request(params)
    {:ok, code} = OAuth.authorize(user_fixture(), request)
    Repo.one!(Authorization) |> Ecto.Changeset.change(code_expires_at: ago()) |> Repo.update!()
    assert {:error, :invalid_grant} = OAuth.exchange(token_params(params, verifier, code))
  end

  test "scopes, expiration, resource and user-scoped revocation are enforced" do
    user = user_fixture()
    token = issue_token(user, "grids:create")
    grant = Repo.one!(Authorization)
    assert {:error, :insufficient_scope} = OAuth.authenticate(token, "grids:read")
    assert {:error, :invalid_token} = OAuth.authenticate("invalid", "grids:create")
    OAuth.revoke_connection(user_fixture(), grant.id)
    assert {:ok, _} = OAuth.authenticate(token, "grids:create")
    assert [connection] = OAuth.list_connections(user)
    assert connection.id == grant.id
    OAuth.revoke_connection(user, grant.id)
    assert {:error, :invalid_token} = OAuth.authenticate(token, "grids:create")
    assert [] == OAuth.list_connections(user)

    fresh_token = issue_token(user)
    fresh_grant = Repo.get_by!(Authorization, token_hash: :crypto.hash(:sha256, fresh_token))
    fresh_grant |> Ecto.Changeset.change(token_expires_at: ago()) |> Repo.update!()
    assert {:error, :invalid_token} = OAuth.authenticate(fresh_token, "grids:create")

    other_token = issue_token(user)
    Application.put_env(:dialectic, :mcp_resource, "https://different.example/mcp")
    assert {:error, :invalid_token} = OAuth.authenticate(other_token, "grids:create")
  end

  defp ago, do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-1, :second)
end
