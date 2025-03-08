defmodule Dialectic.Accounts.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chats" do
    field :message, :string

    belongs_to :user, Dialectic.Accounts.User

    belongs_to :graph, Dialectic.Accounts.Graph,
      references: :title,
      type: :string,
      foreign_key: :graph_title

    timestamps()
  end

  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:message, :graph_title, :user_id])
    |> validate_required([:message, :graph_title, :user_id])
  end
end
