defmodule Dialectic.Repo.Migrations.CreateContentDrafts do
  use Ecto.Migration

  def change do
    create table(:content_drafts) do
      add :graph_title,
          references(:graphs, column: :title, type: :string, on_delete: :delete_all),
          null: false

      add :node_id, :string
      add :created_by_id, references(:users, on_delete: :nilify_all)
      add :platform, :string, null: false
      add :format, :string, null: false
      add :title, :string
      add :body, :text, null: false
      add :excerpt, :text
      add :status, :string, null: false, default: "draft"
      add :scheduled_at, :utc_datetime
      add :published_at, :utc_datetime
      add :external_url, :string
      add :utm_source, :string
      add :utm_campaign, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:content_drafts, [:graph_title])
    create index(:content_drafts, [:platform, :status])
    create index(:content_drafts, [:inserted_at])
  end
end
