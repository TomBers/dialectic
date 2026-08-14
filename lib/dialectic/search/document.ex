defmodule Dialectic.Search.Document do
  use Ecto.Schema

  schema "graph_search_documents" do
    field :graph_title, :string
    field :kind, :string
    field :node_id, :string
    field :content, :string
    field :source_text, :string
    field :search_text, :string
  end
end
