defmodule Dialectic.McpFixtures do
  alias Dialectic.Integrations.OAuth

  def configure_mcp(_context) do
    previous =
      Keyword.take(Application.get_all_env(:dialectic), [:mcp_resource, :mcp_oauth_clients])

    Application.put_env(:dialectic, :mcp_resource, "http://127.0.0.1:4001/mcp")

    Application.put_env(:dialectic, :mcp_oauth_clients, %{
      "test-client" => %{
        name: "Test app",
        redirect_uris: ["http://localhost:6274/oauth/callback"]
      }
    })

    ExUnit.Callbacks.on_exit(fn ->
      for key <- [:mcp_resource, :mcp_oauth_clients] do
        case Keyword.fetch(previous, key) do
          {:ok, value} -> Application.put_env(:dialectic, key, value)
          :error -> Application.delete_env(:dialectic, key)
        end
      end
    end)

    :ok
  end

  def authorization_params(scope \\ "grids:create grids:read") do
    verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    {%{
       "client_id" => "test-client",
       "redirect_uri" => "http://localhost:6274/oauth/callback",
       "response_type" => "code",
       "resource" => OAuth.resource(),
       "scope" => scope,
       "code_challenge" => challenge,
       "code_challenge_method" => "S256",
       "state" => "test-state"
     }, verifier}
  end

  def token_params(params, verifier, code) do
    params
    |> Map.take(~w(client_id redirect_uri resource))
    |> Map.merge(%{
      "grant_type" => "authorization_code",
      "code_verifier" => verifier,
      "code" => code
    })
  end

  def issue_token(user, scope \\ "grids:create grids:read") do
    {params, verifier} = authorization_params(scope)
    {:ok, request} = OAuth.validate_request(params)
    {:ok, code} = OAuth.authorize(user, request)
    {:ok, token} = OAuth.exchange(token_params(params, verifier, code))
    token.access_token
  end

  def grid_draft do
    %{
      "request_id" => Ecto.UUID.generate(),
      "title" => "Ideas from our chat",
      "tags" => ["reasoning"],
      "nodes" => [
        %{"id" => "question", "content" => "What would change our minds?", "kind" => "origin"},
        %{"id" => "idea", "content" => "Look for counterexamples", "kind" => "counterexample"}
      ],
      "edges" => [%{"from" => "question", "to" => "idea"}]
    }
  end
end
