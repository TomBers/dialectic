defmodule DialecticWeb.ComparisonController do
  use DialecticWeb, :controller

  @pages %{
    "chatgpt" => %{
      template: :chatgpt,
      page_title: "ChatGPT Alternative for Research | RationalGrid",
      page_description:
        "Looking for a ChatGPT alternative for research? Compare quick AI conversations with connected maps of questions, challenges, evidence and sources."
    },
    "elicit" => %{
      template: :elicit,
      page_title: "Elicit Alternative for Argument Mapping | RationalGrid",
      page_description:
        "Compare Elicit's scientific literature search and extraction workflows with RationalGrid's connected maps of questions, challenges, evidence and sources."
    },
    "kialo" => %{
      template: :kialo,
      page_title: "Free Kialo Alternative | RationalGrid",
      page_description:
        "Looking for a free Kialo alternative? Compare Kialo's structured debates with RationalGrid's AI-assisted maps of questions, evidence and sources."
    },
    "mind-maps" => %{
      template: :mind_maps,
      page_title: "Argument Map vs Mind Map | RationalGrid",
      page_description:
        "Argument map or mind map? Compare free-form visual brainstorming with structured questions, challenges, evidence and source connections."
    },
    "notebooklm" => %{
      template: :notebooklm,
      page_title: "NotebookLM Alternative for Argument Mapping | RationalGrid",
      page_description:
        "Compare NotebookLM's source-grounded document workspace with RationalGrid's connected maps of questions, challenges, evidence and competing views."
    },
    "notion-obsidian" => %{
      template: :notion_obsidian,
      page_title: "Notion and Obsidian Research Workflow | RationalGrid",
      page_description:
        "Explore a research question in RationalGrid, then export it as Markdown and continue organising, linking, and writing in Notion or Obsidian."
    }
  }

  def index(conn, _params) do
    render(conn, :index,
      page_title: "Compare Research and Argument-Mapping Tools | RationalGrid",
      page_title_suffix: "",
      page_description:
        "Compare RationalGrid with ChatGPT, Elicit, Kialo, NotebookLM and mind maps, or explore a workflow with Notion and Obsidian."
    )
  end

  def show(conn, %{"slug" => slug}) do
    case Map.fetch(@pages, slug) do
      {:ok, page} ->
        render(conn, page.template,
          page_title: page.page_title,
          page_title_suffix: "",
          page_description: page.page_description
        )

      :error ->
        raise Phoenix.Router.NoRouteError, conn: conn, router: DialecticWeb.Router
    end
  end

  def slugs, do: Map.keys(@pages) |> Enum.sort()
end
