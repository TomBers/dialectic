defmodule DialecticWeb.Plugs.AuthReturn do
  import Plug.Conn

  def init(opts), do: opts

  def call(%{method: "GET"} = conn, _opts) do
    conn = fetch_query_params(conn)

    case conn.query_params["return_to"] do
      path when is_binary(path) and byte_size(path) <= 4096 ->
        uri = URI.parse(path)

        if is_nil(uri.scheme) && is_nil(uri.host) &&
             Regex.match?(~r{\A/g/[a-zA-Z0-9_-]+(?:/graph)?\z}, uri.path || "") &&
             !Regex.match?(~r/[\\\x00-\x20\x7f]/, path) do
          put_session(conn, :user_return_to, path)
        else
          conn
        end

      _ ->
        conn
    end
  end

  def call(conn, _opts), do: conn
end
