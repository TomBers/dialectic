defmodule Dialectic.Repo do
  use Ecto.Repo,
    otp_app: :dialectic,
    adapter: Ecto.Adapters.Postgres
end
