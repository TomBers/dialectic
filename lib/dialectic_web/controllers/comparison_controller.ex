defmodule DialecticWeb.ComparisonController do
  use DialecticWeb, :controller

  @pages %{
    "chatgpt" => %{
      template: :chatgpt,
      page_title: "ChatGPT Alternative for Research | RationalGrid",
      page_description:
        "Compare ChatGPT's chats and projects with connected grids you can organise, search and build on with others in RationalGrid."
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
    "miro" => %{
      template: :miro,
      page_title: "RationalGrid and Miro: Compare Ways to Explore Ideas | RationalGrid",
      page_description:
        "Compare Miro's collaborative canvas and AI Sidekicks with RationalGrid's connected questions, challenges and sources, organised for returning to an idea."
    },
    "notebooklm" => %{
      template: :notebooklm,
      page_title: "NotebookLM Alternative: Gemini Notebook | RationalGrid",
      page_description:
        "Compare Gemini Notebook (formerly NotebookLM) and its source-grounded workspace with RationalGrid's maps of questions, challenges and evidence."
    },
    "notion-obsidian" => %{
      template: :notion_obsidian,
      page_title: "Notion and Obsidian Research Workflow | RationalGrid",
      page_description:
        "Explore and organise ideas in RationalGrid's My Learning workspace, with bookmarks, highlights and optional Markdown export to Notion or Obsidian."
    }
  }

  def index(conn, _params) do
    render(conn, :index,
      page_title: "Compare Research and Argument-Mapping Tools | RationalGrid",
      page_title_suffix: "",
      page_description:
        "Compare RationalGrid with ChatGPT, Miro and other research tools. Find the workflow that helps you explore ideas, organise your work and return to it."
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
