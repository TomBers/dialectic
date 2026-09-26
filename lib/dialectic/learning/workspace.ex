defmodule Dialectic.Learning.Workspace do
  use Ecto.Schema

  @primary_key false
  schema "learning_workspaces" do
    belongs_to :user, Dialectic.Accounts.User, primary_key: true
    field :topics_initialized_at, :utc_datetime
  end
end
