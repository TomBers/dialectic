defmodule DialecticWeb.StaticAssets do
  @behaviour Plug

  @immutable "public, max-age=31536000, immutable"

  @impl true
  def init(opts) do
    %{
      regular: Plug.Static.init(opts),
      fingerprinted:
        opts
        |> Keyword.merge(
          cache_control_for_etags: @immutable,
          cache_control_for_vsn_requests: @immutable
        )
        |> Plug.Static.init()
    }
  end

  @impl true
  def call(conn, opts) do
    options = if fingerprinted?(conn.request_path), do: opts.fingerprinted, else: opts.regular
    Plug.Static.call(conn, options)
  end

  defp fingerprinted?(path) do
    String.starts_with?(path, ["/assets/", "/images/", "/fonts/"]) and
      (Regex.match?(~r/-[a-f0-9]{32}\.[^\/]+$/, path) or
         Regex.match?(~r"^/assets/chunks/[^/]+-[A-Z0-9]{8}\.js$", path))
  end
end
