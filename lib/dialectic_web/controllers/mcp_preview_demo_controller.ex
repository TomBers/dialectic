defmodule DialecticWeb.McpPreviewDemoController do
  use DialecticWeb, :controller

  @preview_dir Path.expand("../../../mcp/dist", __DIR__)

  def index(conn, _params), do: serve(conn, "demo.html")
  def widget(conn, _params), do: serve(conn, "preview.html")

  defp serve(conn, filename) do
    policy =
      conn
      |> get_resp_header("content-security-policy")
      |> Enum.join("; ")
      |> String.replace(~r/frame-src[^;]*/, "frame-src 'self'")

    conn =
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("content-security-policy", policy)

    case File.read(Path.join(@preview_dir, filename)) do
      {:ok, content} ->
        html(conn, content)

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> text("Build the local preview first: npm --prefix mcp run build:ui")
    end
  end
end
