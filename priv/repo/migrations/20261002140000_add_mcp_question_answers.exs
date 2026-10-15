defmodule Dialectic.Repo.Migrations.AddMcpQuestionAnswers do
  use Ecto.Migration

  def change do
    alter table(:mcp_grid_actions) do
      add :answer_node_id, :string
    end
  end
end
