defmodule DialecticWeb.McpOAuthController do
  use DialecticWeb, :controller

  alias Dialectic.Integrations.OAuth

  plug :no_cache

  def metadata(conn, _params) do
    json(conn, %{
      issuer: DialecticWeb.Endpoint.url(),
      authorization_endpoint: url(~p"/oauth/authorize"),
      token_endpoint: url(~p"/oauth/token"),
      revocation_endpoint: url(~p"/oauth/revoke"),
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code"],
      token_endpoint_auth_methods_supported: ["none"],
      code_challenge_methods_supported: ["S256"],
      authorization_response_iss_parameter_supported: true,
      scopes_supported: OAuth.scopes()
    })
  end

  def authorize(conn, params) do
    case OAuth.validate_request(params) do
      {:ok, request} ->
        consent =
          Phoenix.Token.sign(
            DialecticWeb.Endpoint,
            "mcp-consent",
            {conn.assigns.current_user.id, params}
          )

        render(conn, :authorize,
          client_name: request.client_name,
          scopes: String.split(request.scope),
          form: Phoenix.Component.to_form(%{"consent" => consent}, as: :authorization)
        )

      {:error, _} ->
        oauth_error(conn, :invalid_request)
    end
  end

  def decide(conn, %{"authorization" => %{"consent" => consent}, "decision" => decision}) do
    with {:ok, {user_id, params}} <-
           Phoenix.Token.verify(DialecticWeb.Endpoint, "mcp-consent", consent, max_age: 600),
         true <- user_id == conn.assigns.current_user.id,
         {:ok, request} <- OAuth.validate_request(params) do
      case decision do
        "allow" ->
          case OAuth.authorize(conn.assigns.current_user, request) do
            {:ok, code} -> redirect_callback(conn, request, %{"code" => code})
            _ -> oauth_error(conn, :server_error)
          end

        "deny" ->
          redirect_callback(conn, request, %{"error" => "access_denied"})

        _ ->
          oauth_error(conn, :invalid_request)
      end
    else
      _ -> oauth_error(conn, :invalid_request)
    end
  end

  def decide(conn, _params), do: oauth_error(conn, :invalid_request)

  def token(conn, params) do
    case OAuth.exchange(params) do
      {:ok, token} -> json(conn, token)
      {:error, error} -> oauth_error(conn, error)
    end
  end

  def revoke(conn, params) do
    OAuth.revoke_token(params["token"], params["client_id"])
    send_resp(conn, :ok, "")
  end

  def connections(conn, _params) do
    connections =
      Enum.map(OAuth.list_connections(conn.assigns.current_user), fn grant ->
        %{
          id: grant.id,
          name: get_in(OAuth.clients(), [grant.client_id, :name]) || "Connected app"
        }
      end)

    render(conn, :connections, connections: connections)
  end

  def disconnect(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {number, ""} -> OAuth.revoke_connection(conn.assigns.current_user, number)
      _ -> :ok
    end

    redirect(conn, to: ~p"/users/connections")
  end

  defp redirect_callback(conn, request, result) do
    uri = URI.parse(request.redirect_uri)

    query =
      URI.decode_query(uri.query || "")
      |> Map.merge(result)
      |> Map.merge(%{"state" => request.state, "iss" => DialecticWeb.Endpoint.url()})
      |> URI.encode_query()

    redirect(conn, external: URI.to_string(%{uri | query: query}))
  end

  defp oauth_error(conn, error), do: conn |> put_status(:bad_request) |> json(%{error: error})

  defp no_cache(conn, _opts),
    do:
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("pragma", "no-cache")
end
