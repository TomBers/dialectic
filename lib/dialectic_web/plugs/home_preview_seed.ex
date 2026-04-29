defmodule DialecticWeb.Plugs.HomePreviewSeed do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    put_session(conn, :home_preview_seed, conn.assigns[:request_id] || default_seed())
  end

  defp default_seed do
    System.unique_integer([:positive, :monotonic]) |> Integer.to_string()
  end
end
