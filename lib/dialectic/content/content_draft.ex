defmodule Dialectic.Content.ContentDraft do
  use Ecto.Schema
  import Ecto.Changeset

  @platforms ~w(x instagram linkedin substack bluesky threads reddit mastodon)
  @formats ~w(short_post thread carousel_script newsletter essay_outline discussion_prompt)
  @statuses ~w(draft used archived scheduled posted failed cancelled)

  schema "content_drafts" do
    belongs_to :graph, Dialectic.Accounts.Graph,
      foreign_key: :graph_title,
      references: :title,
      type: :string

    belongs_to :created_by, Dialectic.Accounts.User

    field :node_id, :string
    field :platform, :string
    field :format, :string
    field :title, :string
    field :body, :string
    field :excerpt, :string
    field :status, :string, default: "draft"
    field :scheduled_at, :utc_datetime
    field :published_at, :utc_datetime
    field :external_url, :string
    field :utm_source, :string
    field :utm_campaign, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def platforms, do: @platforms
  def formats, do: @formats
  def statuses, do: @statuses

  def create_changeset(draft, attrs, created_by) do
    draft
    |> cast(attrs, [
      :graph_title,
      :node_id,
      :platform,
      :format,
      :title,
      :body,
      :excerpt,
      :status,
      :scheduled_at,
      :published_at,
      :external_url,
      :utm_source,
      :utm_campaign,
      :metadata
    ])
    |> put_created_by(created_by)
    |> validate_required([:graph_title, :platform, :format, :body, :status])
    |> validate_length(:title, max: 255)
    |> validate_length(:platform, max: 64)
    |> validate_length(:format, max: 64)
    |> validate_length(:status, max: 64)
    |> validate_inclusion(:platform, @platforms)
    |> validate_inclusion(:format, @formats)
    |> validate_inclusion(:status, @statuses)
    |> assoc_constraint(:graph)
  end

  def update_changeset(draft, attrs) do
    draft
    |> cast(attrs, [
      :node_id,
      :platform,
      :format,
      :title,
      :body,
      :excerpt,
      :status,
      :scheduled_at,
      :published_at,
      :external_url,
      :utm_source,
      :utm_campaign,
      :metadata
    ])
    |> validate_required([:platform, :format, :body, :status])
    |> validate_length(:title, max: 255)
    |> validate_inclusion(:platform, @platforms)
    |> validate_inclusion(:format, @formats)
    |> validate_inclusion(:status, @statuses)
  end

  defp put_created_by(changeset, %{id: id}) when is_integer(id) do
    put_change(changeset, :created_by_id, id)
  end

  defp put_created_by(changeset, _created_by), do: changeset
end
