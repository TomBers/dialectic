defmodule Dialectic.Repo.Migrations.BackfillShareTokens do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # Fetch all graphs that don't have a share_token
    query = from(g in "graphs", where: is_nil(g.share_token), select: g.title)

    Dialectic.Repo.all(query)
    |> Enum.each(fn title ->
      token = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

      from(g in "graphs", where: g.title == ^title)
      |> Dialectic.Repo.update_all(set: [share_token: token])
    end)
  end

  def down do
    # No specific data rollback required
  end
end
