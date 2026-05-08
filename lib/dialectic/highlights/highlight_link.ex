defmodule Dialectic.Highlights.HighlightLink do
  @moduledoc """
  A link between a highlight and a node in the graph.

  This allows a single highlight to be associated with multiple nodes
  of different types (explanations, questions, pros/cons, related ideas, etc.)
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Dialectic.Highlights.Highlight

  @derive {Jason.Encoder,
           only: [
             :id,
             :highlight_id,
             :node_id,
             :link_type,
             :inserted_at
           ]}

  schema "highlight_links" do
    belongs_to :highlight, Highlight
    field :node_id, :string
    field :link_type, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @valid_link_types ~w(
    explain
    question
    pro
    con
    related_idea
    comment
    clarify
    assumptions
    counterexample
    implications
    blind_spots
    says_who
    who_disagrees
    analogy
    steel_man
    what_if
    simplify
    second_order
  )

  @doc """
  Valid link types for highlights:
  - `explain`: An explanation/answer node for the selected text
  - `question`: A custom question answer node
  - `pro`: A supporting argument (thesis) node
  - `con`: A counter argument (antithesis) node
  - `related_idea`: A related ideas node
  - `comment`: A user comment on the selection
  - `clarify`: A conceptual clarification of the selection
  - `assumptions`: Assumptions surfaced from the selection
  - `counterexample`: A test/counterexample for the selection
  - `implications`: Implications traced from the selection
  - `blind_spots`: Missing perspectives related to the selection
  - `says_who`: Source/evidence examination of the selection
  - `who_disagrees`: Dissenting perspectives on the selection
  - `analogy`: An analogy built from the selection
  - `steel_man`: The strongest reading of the selection
  - `what_if`: A counterfactual applied to the selection
  - `simplify`: A plain-language rewrite of the selection
  - `second_order`: Second-order effects derived from the selection
  """
  def valid_link_types, do: @valid_link_types

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:highlight_id, :node_id, :link_type])
    |> validate_required([:highlight_id, :node_id, :link_type])
    |> validate_inclusion(:link_type, @valid_link_types)
    |> foreign_key_constraint(:highlight_id)
    |> unique_constraint([:highlight_id, :node_id],
      name: :highlight_links_highlight_id_node_id_index,
      message: "This highlight is already linked to this node"
    )
  end
end
