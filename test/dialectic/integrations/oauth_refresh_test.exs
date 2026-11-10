defmodule Dialectic.Integrations.OAuthRefreshTest do
  use Dialectic.DataCase, async: false
  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Integrations.{Authorization, OAuth, RefreshToken}

  setup :configure_mcp

  test "rotates hashed refresh tokens, preserves scope and revokes a replayed token family" do
    user = user_fixture()
    {params, verifier} = authorization_params()
    {:ok, request} = OAuth.validate_request(params)
    {:ok, code} = OAuth.authorize(user, request)
    {:ok, original} = OAuth.exchange(token_params(params, verifier, code))
    assert Repo.one!(RefreshToken).token_hash == :crypto.hash(:sha256, original.refresh_token)

    refresh = %{
      "grant_type" => "refresh_token",
      "client_id" => params["client_id"],
      "resource" => params["resource"],
      "refresh_token" => original.refresh_token
    }

    assert {:error, :invalid_grant} = OAuth.exchange(%{refresh | "client_id" => "unknown"})

    assert {:error, :invalid_grant} =
             OAuth.exchange(%{refresh | "resource" => "https://other.example/mcp"})

    assert {:error, :invalid_scope} = OAuth.exchange(Map.put(refresh, "scope", "grids:append"))
    assert {:ok, rotated} = OAuth.exchange(refresh)
    assert rotated.scope == original.scope
    refute rotated.refresh_token == original.refresh_token
    assert {:error, :invalid_token} = OAuth.authenticate(original.access_token, "grids:read")
    assert {:ok, _} = OAuth.authenticate(rotated.access_token, "grids:read")
    assert {:error, :invalid_grant} = OAuth.exchange(refresh)
    assert {:error, :invalid_token} = OAuth.authenticate(rotated.access_token, "grids:read")

    assert {:error, :invalid_grant} =
             OAuth.exchange(%{refresh | "refresh_token" => rotated.refresh_token})

    assert Repo.one!(Authorization).revoked_at
  end

  test "refresh grants stay visible after access expiry and can be disconnected or revoked" do
    user = user_fixture()
    {params, verifier} = authorization_params()
    {:ok, request} = OAuth.validate_request(params)
    {:ok, code} = OAuth.authorize(user, request)
    {:ok, token} = OAuth.exchange(token_params(params, verifier, code))
    grant = Repo.one!(Authorization)

    grant
    |> Ecto.Changeset.change(
      token_expires_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-1)
    )
    |> Repo.update!()

    assert [%{id: id}] = OAuth.list_connections(user)
    assert id == grant.id
    OAuth.revoke_token(token.refresh_token, params["client_id"])
    assert [] == OAuth.list_connections(user)

    assert {:error, :invalid_grant} =
             OAuth.exchange(%{
               "grant_type" => "refresh_token",
               "client_id" => params["client_id"],
               "refresh_token" => token.refresh_token
             })
  end

  test "dynamic public clients require safe exact redirects and PKCE consent" do
    assert {:ok, client} =
             OAuth.register_client(%{
               "client_name" => "My MCP client",
               "redirect_uris" => ["https://client.example/callback"]
             })

    {params, _} = authorization_params()

    params = %{
      params
      | "client_id" => client.client_id,
        "redirect_uri" => "https://client.example/callback"
    }

    assert {:ok, %{client_name: "My MCP client"}} = OAuth.validate_request(params)

    assert {:error, :invalid_request} =
             OAuth.validate_request(%{params | "redirect_uri" => "https://client.example/other"})

    assert {:error, :invalid_request} =
             OAuth.validate_request(%{params | "code_challenge_method" => "plain"})

    for redirect <- [
          "http://remote.example/callback",
          "javascript:alert(1)",
          "https://user:pass@client.example/cb",
          "https://client.example/cb#fragment",
          "https://client.example:bad/cb",
          nil
        ] do
      assert {:error, :invalid_client_metadata} =
               OAuth.register_client(%{"redirect_uris" => [redirect]})
    end

    assert {:ok, _} =
             OAuth.register_client(%{"redirect_uris" => ["http://127.0.0.1:6274/callback"]})
  end
end
