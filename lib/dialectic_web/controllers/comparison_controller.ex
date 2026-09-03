defmodule DialecticWeb.ComparisonController do
  use DialecticWeb, :controller

  @pages %{
    "chatgpt" => %{
      template: :chatgpt,
      page_title: "A ChatGPT Alternative for Structured Research",
      page_description:
        "Looking for a ChatGPT alternative for research? Compare quick AI chat with RationalGrid's connected questions, challenges, evidence, and sources."
    },
    "kialo" => %{
      template: :kialo,
      page_title: "A Free Kialo Alternative for Exploring Arguments",
      page_description:
        "Looking for a free Kialo alternative? Compare RationalGrid and Kialo for AI-assisted inquiry, structured discussion, evidence, and classroom debate."
    },
    "mind-maps" => %{
      template: :mind_maps,
      page_title: "Argument Map vs Mind Map for Complex Questions",
      page_description:
        "Argument map or mind map? Compare RationalGrid with conventional mind maps for brainstorming, research, evidence, and connected reasoning."
    }
  }

  def index(conn, _params) do
    render(conn, :index,
      page_title: "Compare RationalGrid with Other Research and Mapping Tools",
      page_description:
        "Compare RationalGrid with ChatGPT, Kialo, and conventional mind maps to find the right format for research, debate, and complex questions."
    )
  end

  def show(conn, %{"slug" => slug}) do
    case Map.fetch(@pages, slug) do
      {:ok, page} ->
        render(conn, page.template,
          page_title: page.page_title,
          page_description: page.page_description
        )

      :error ->
        raise Phoenix.Router.NoRouteError, conn: conn, router: DialecticWeb.Router
    end
  end

  def slugs, do: Map.keys(@pages) |> Enum.sort()
end
