defmodule Dialectic.Repo.Migrations.AddPromptModeToGraphs do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :prompt_mode, :string, default: "university", null: false
    end
  end
end
