defmodule DialecticWeb.QuestionLive do
  use DialecticWeb, :live_view

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Does AI make us better thinkers? | RationalGrid",
       page_title_suffix: "",
       page_description:
         "AI can improve an answer without improving its author. Explore three studies, their limits, and how to use AI while keeping your own judgement.",
       canonical_url:
         DialecticWeb.Endpoint.url() <> ~p"/questions/does-ai-make-us-better-thinkers",
       og_type: "article"
     ), layout: false}
  end
end
