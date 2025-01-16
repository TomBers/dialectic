defmodule DialecticWeb.PageController do
  use DialecticWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    dat = Dialectic.Graph.Sample.run() |> Jason.encode!()
    render(conn, :home, data: dat, layout: false)
  end
end
