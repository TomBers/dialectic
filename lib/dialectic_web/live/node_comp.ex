defmodule DialecticWeb.NodeComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.GraphHelpers
  alias DialecticWeb.GridCardComp

  @impl true
  def update(assigns, socket) do
    base_node =
      case Map.get(assigns, :node) do
        %{} = n -> n
        _ -> %{}
      end

    # Normalize required fields so template can use @node.id/content/children/parents directly
    node =
      base_node
      |> Map.put_new(:id, "")
      |> Map.put_new(:content, "")
      |> Map.put_new(:children, [])
      |> Map.put_new(:parents, [])

    node_id = Map.get(node, :id, "")

    {:ok,
     assign(socket,
       node_id: node_id,
       node: node,
       user: Map.get(assigns, :user, nil),
       form: Map.get(assigns, :form, nil),
       cut_off: Map.get(assigns, :cut_off, 500),
       ask_question: Map.get(assigns, :ask_question, true),
       graph_id: Map.get(assigns, :graph_id, ""),
       graph_struct: Map.get(assigns, :graph_struct, nil),
       graph_owner_id: Map.get(assigns, :graph_owner_id, nil),
       current_user: Map.get(assigns, :current_user, nil),
       can_edit: Map.get(assigns, :can_edit, true),
       menu_visible: Map.get(assigns, :menu_visible, true),
       streaming: Map.get(assigns, :streaming, false),
       presentation_mode: Map.get(assigns, :presentation_mode, :off),
       token: Map.get(assigns, :token, nil)
     )}
  end

  @regeneratable_classes [
    "thesis",
    "antithesis",
    "ideas",
    "answer",
    "explain",
    "synthesis",
    "clarify",
    "assumptions",
    "counterexample",
    "implications",
    "blind_spots",
    "says_who",
    "who_disagrees",
    "steel_man",
    "what_if"
  ]

  defp show_regenerate_cta?(%{id: id, class: class}) when is_binary(id) and is_binary(class) do
    id != "" and id != "start" and class in @regeneratable_classes
  end

  defp show_regenerate_cta?(_node), do: false

  defp node_title_size_class(%{content: content}) when is_binary(content) do
    case title_text_length(content) do
      length when length >= 96 -> "text-[15px] sm:text-base md:text-[1.05rem]"
      length when length >= 64 -> "text-base sm:text-[1.05rem] md:text-lg"
      _length -> "text-lg sm:text-[1.15rem] md:text-[1.35rem]"
    end
  end

  defp node_title_size_class(_node), do: "text-lg sm:text-[1.15rem] md:text-[1.35rem]"

  defp title_text_length(content) do
    content
    |> String.replace(~r/\r\n|\r/, "\n")
    |> String.trim_leading()
    |> String.split("\n", parts: 2)
    |> List.first()
    |> to_string()
    |> String.replace(~r/^\s*\#{1,6}\s*/, "")
    |> String.replace(~r/^\s*title\b\s*:?\s*/i, "")
    |> String.replace("**", "")
    |> String.trim()
    |> String.length()
  end

  defp existing_follow_up_questions_json(%{children: children}) when is_list(children) do
    children
    |> Enum.filter(fn child ->
      Map.get(child, :class) == "question" and not Map.get(child, :deleted, false)
    end)
    |> Enum.map(fn child ->
      child
      |> Map.get(:content, "")
      |> to_string()
      |> String.trim()
    end)
    |> Enum.reject(&(&1 == ""))
    |> Jason.encode!()
  end

  defp existing_follow_up_questions_json(_node), do: "[]"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full min-h-0">
      <div
        id={"node-menu-" <> @node_id}
        class="relative flex h-full min-h-0 flex-col"
        phx-hook={unless GraphHelpers.origin_branching_disabled?(@node), do: "TextSelectionHook"}
        data-node-id={@node.id}
        data-mudg-id={@graph_id}
        data-streaming={to_string(@streaming)}
        style="height: 100%; padding-bottom: env(safe-area-inset-bottom);"
      >
        <%= if @node.id == "start" do %>
          <.live_component module={DialecticWeb.StartTutorialComp} id="start-tutorial" />
        <% else %>
          <%!-- Thread View (Ancestor Chain) — hidden for now, revisit when full breadcrumb is implemented --%>

          <div
            class={[
              "min-h-0 flex-1 overflow-y-auto scroll-smooth px-3 pb-12 pt-3 sm:px-5 lg:px-6",
              String.length(@node.content) == 0 && "hidden"
            ]}
            id={"tt-node-" <> @node.id}
          >
            <div
              class="summary-content modal-responsive mx-auto w-full max-w-3xl"
              id={"tt-summary-content-" <> @node.id}
            >
              <div id={"node-content-#{@node.id}"}>
                <div id={"node-content-inner-#{@node.id}"}>
                  <article
                    class="prose prose-stone prose-base sm:prose-lg lg:prose-xl max-w-none w-full prose-headings:mt-0 prose-headings:tracking-tight prose-headings:text-gray-900 prose-p:text-gray-800 prose-li:text-gray-800 prose-p:leading-relaxed prose-li:leading-relaxed"
                    data-role="node-content"
                  >
                    <%!-- Client-side Markdown rendering via Markdown hook --%>
                    <% origin_meta? =
                      GraphHelpers.origin_branching_disabled?(@node) && is_map(@graph_struct) %>
                    <h2 class={[
                      "mt-0 flex items-start justify-between gap-4 font-serif leading-[1.15] tracking-tight text-gray-900",
                      node_title_size_class(@node),
                      if(origin_meta?,
                        do: "mb-2 pb-0",
                        else: "mb-3 border-b border-gray-200/90 pb-3"
                      )
                    ]}>
                      <span
                        class="flex-1"
                        phx-hook="Markdown"
                        id={"markdown-title-#{@node.id}"}
                        data-md={@node.content || ""}
                        data-title-only="true"
                      >
                      </span>
                      <span class="flex items-center gap-2">
                        <% noted? =
                          Enum.any?(Map.get(@node || %{}, :noted_by, []), fn u -> u == @user end) %>
                        <button
                          id={"graph-bookmark-node-#{@node.id}"}
                          type="button"
                          class={[
                            "inline-flex h-8 w-8 flex-none items-center justify-center rounded-full border transition-all",
                            if(noted?,
                              do: "border-amber-300 bg-amber-100 text-amber-800 hover:bg-amber-200",
                              else:
                                "border-slate-200 bg-white text-slate-500 hover:border-amber-300 hover:bg-amber-50 hover:text-amber-800"
                            )
                          ]}
                          phx-click={if noted?, do: "unnote", else: "note"}
                          phx-value-node={@node.id}
                          aria-label={if(noted?, do: "Remove bookmark", else: "Bookmark this node")}
                          aria-pressed={to_string(noted?)}
                          title={if(noted?, do: "Remove bookmark", else: "Bookmark this node")}
                        >
                          <.icon
                            name={if(noted?, do: "hero-bookmark-solid", else: "hero-bookmark")}
                            class="h-4 w-4"
                          />
                        </button>
                      </span>
                    </h2>
                    <div
                      :if={origin_meta?}
                      id={"origin-intro-subheading-#{@node.id}"}
                      class="not-prose mb-5 space-y-2.5 border-b border-gray-200/90 pb-4"
                    >
                      <p class="text-sm leading-6 text-slate-700">
                        {graph_preview(@graph_struct)}
                      </p>

                      <div class="flex flex-wrap gap-1.5">
                        <%= for tag <- graph_tags(@graph_struct) do %>
                          <span class={[
                            "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset",
                            GridCardComp.tag_pill_classes(tag)
                          ]}>
                            #{tag}
                          </span>
                        <% end %>
                      </div>
                    </div>

                    <div
                      class="selection-content w-full px-1 pb-2 sm:px-2"
                      data-children={length(@node.children)}
                      id={"list-detector-" <> @node.id}
                    >
                      <div
                        :if={!GraphHelpers.origin_branching_disabled?(@node)}
                        id={"branch-from-text-hint-#{@node.id}"}
                        phx-hook="DismissibleHint"
                        data-dismiss-key="rg:dismissed:branch-from-text:v1"
                        class="not-prose relative mb-5 mt-3 overflow-hidden rounded-xl border border-teal-200/90 bg-gradient-to-r from-teal-50 via-white to-amber-50/80 p-3.5 pr-11 shadow-[0_14px_32px_-24px_rgba(15,118,110,0.9)] ring-1 ring-teal-100/70"
                        hidden
                      >
                        <div class="flex items-center gap-2.5">
                          <span class="inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-teal-700 text-white shadow-sm ring-1 ring-teal-800/10">
                            <.icon name="hero-cursor-arrow-rays" class="h-3.5 w-3.5" />
                          </span>
                          <p class="min-w-0 text-sm font-semibold leading-5 text-slate-800">
                            Select a phrase to ask about it.
                          </p>
                        </div>
                        <button
                          id={"branch-from-text-hint-dismiss-#{@node.id}"}
                          type="button"
                          data-dismiss-hint
                          class="absolute right-2.5 top-2.5 inline-flex h-7 w-7 items-center justify-center rounded-full text-slate-500 transition hover:bg-white/90 hover:text-slate-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-600 focus-visible:ring-offset-2"
                          aria-label="Dismiss selection tip"
                          title="Dismiss tip"
                        >
                          <.icon name="hero-x-mark" class="h-4 w-4" />
                        </button>
                      </div>

                      <div
                        phx-hook="Markdown"
                        class="cursor-text selection:bg-amber-200/80 selection:text-slate-900"
                        id={"markdown-body-#{@node.id}"}
                        data-md={@node.content || ""}
                        data-grounding={DialecticWeb.MarkdownGrounding.encode(@node)}
                        data-body-only="true"
                        data-existing-follow-up-questions={existing_follow_up_questions_json(@node)}
                      >
                      </div>
                    </div>
                  </article>

                  <%= if GraphHelpers.origin_branching_disabled?(@node) do %>
                    <div
                      id={"origin-intro-#{@node.id}"}
                      class="mt-3 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-[0_14px_32px_rgba(15,23,42,0.05)]"
                      data-external="true"
                      data-role="origin-intro"
                    >
                      <div class="border-b border-slate-200 bg-slate-50/80 px-4 py-3 sm:px-5">
                        <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                          Start here
                        </p>
                        <h4 class="mt-1 text-base font-semibold leading-6 tracking-tight text-slate-950">
                          How to use the grid
                        </h4>
                      </div>

                      <div class="px-4 py-2.5 sm:px-5">
                        <.live_component
                          module={DialecticWeb.OriginOnboardingComp}
                          id={"origin-onboarding-#{@node.id}"}
                        />
                      </div>
                    </div>
                  <% else %>
                    <.live_component
                      module={DialecticWeb.ActionToolbarComp}
                      id={"action-toolbar-#{@node.id}"}
                      node={@node}
                      user={@user}
                      current_user={@current_user}
                      graph_id={@graph_id}
                      can_edit={@can_edit}
                    />
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%= if String.length(@node.content) == 0 do %>
            <div class="node relative mb-2 overflow-hidden rounded-[1.75rem] border border-indigo-100 bg-gradient-to-br from-white via-indigo-50/70 to-sky-50/60 p-6 shadow-[0_24px_70px_rgba(79,70,229,0.14)] sm:p-8">
              <div class="pointer-events-none absolute -right-16 -top-16 h-44 w-44 rounded-full bg-indigo-200/40 blur-3xl">
              </div>
              <div class="pointer-events-none absolute -bottom-20 left-6 h-36 w-36 rounded-full bg-sky-200/30 blur-3xl">
              </div>

              <div class="relative space-y-6">
                <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                  <div class="flex items-start gap-3">
                    <span class="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-indigo-600 text-white shadow-lg shadow-indigo-200/80">
                      <.icon name="hero-sparkles" class="h-5 w-5" />
                    </span>
                    <div class="min-w-0">
                      <p class="text-sm font-semibold uppercase tracking-[0.18em] text-indigo-500">
                        Generating response
                      </p>
                      <h3
                        id={"generation-status-#{@node.id}"}
                        phx-hook="GenerationStatus"
                        phx-update="ignore"
                        data-response-level={Map.get(@node, :response_level, "")}
                        class="mt-1 text-lg font-semibold tracking-tight text-slate-950 sm:text-xl"
                      >
                        <span data-generation-status>Preparing response</span>
                      </h3>
                    </div>
                  </div>

                  <div class="flex items-center gap-1.5 rounded-full border border-indigo-100 bg-white/80 px-3 py-1.5 shadow-sm backdrop-blur">
                    <span class="text-xs font-medium text-indigo-700">Thinking</span>
                    <span class="flex gap-0.5">
                      <span class="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-[typing_1.4s_ease-in-out_infinite]">
                      </span>
                      <span class="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-[typing_1.4s_ease-in-out_-0.16s_infinite]">
                      </span>
                      <span class="h-1.5 w-1.5 rounded-full bg-indigo-500 animate-[typing_1.4s_ease-in-out_-0.32s_infinite]">
                      </span>
                    </span>
                  </div>
                </div>

                <%!-- Animated shimmer skeleton lines --%>
                <div class="rounded-2xl border border-white/70 bg-white/65 p-4 shadow-inner shadow-indigo-100/40 backdrop-blur-sm">
                  <div class="space-y-4">
                    <div class="h-5 rounded-md w-3/4 bg-gradient-to-r from-indigo-100/70 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_infinite]">
                    </div>
                    <div class="space-y-2.5">
                      <div class="h-3.5 rounded-md w-full bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.1s_infinite]">
                      </div>
                      <div class="h-3.5 rounded-md w-5/6 bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.2s_infinite]">
                      </div>
                      <div class="h-3.5 rounded-md w-4/6 bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.3s_infinite]">
                      </div>
                    </div>
                    <div class="space-y-2.5 pt-2">
                      <div class="h-3.5 rounded-md w-full bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.4s_infinite]">
                      </div>
                      <div class="h-3.5 rounded-md w-2/3 bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.5s_infinite]">
                      </div>
                    </div>
                  </div>
                </div>

                <div
                  :if={@can_edit && show_regenerate_cta?(@node)}
                  class="thinking-regenerate-cta flex flex-col gap-3 rounded-2xl border border-indigo-200 bg-white/90 p-4 shadow-lg shadow-indigo-100/70 backdrop-blur sm:flex-row sm:items-center sm:justify-between"
                >
                  <div class="min-w-0">
                    <p class="text-sm font-semibold text-slate-900">Taking longer than expected?</p>
                    <p class="mt-0.5 text-sm text-slate-600">
                      You can safely replace this placeholder and try generating it again.
                    </p>
                  </div>

                  <button
                    id={"regenerate-thinking-node-#{@node.id}"}
                    type="button"
                    class="inline-flex shrink-0 items-center justify-center gap-2 rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-lg shadow-indigo-200/80 transition hover:bg-indigo-700 hover:shadow-indigo-300/80 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-indigo-200"
                    phx-click="node_regenerate"
                    phx-value-id={@node.id}
                    data-confirm="Try generating this node again? The stuck placeholder will be replaced."
                    title="Regenerate this stuck node"
                  >
                    <.icon name="hero-arrow-path" class="h-4 w-4" />
                    <span>Regenerate</span>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp graph_tags(%{} = graph) do
    graph
    |> Map.get(:tags, [])
    |> case do
      tags when is_list(tags) ->
        tags
        |> Enum.filter(&(is_binary(&1) and String.trim(&1) != ""))
        |> Enum.take(4)

      _other ->
        []
    end
  end

  defp graph_tags(_graph), do: []

  defp graph_preview(%{} = graph), do: GridCardComp.preview_sentence(graph)

  defp graph_preview(_graph), do: "A connected grid of ideas."
end
