defmodule DialecticWeb.AskFormComp do
  use DialecticWeb, :live_component
  import DialecticWeb.KeyboardComponents
  alias DialecticWeb.Utils.NodeTitleHelper

  @moduledoc """
  LiveComponent that renders the bottom ask/comment form used by GraphLive.

  Instead of a modal toggle between Ask and Comment modes, this component
  renders two submit buttons side-by-side — "Ask" (AI responds) and "Post"
  (no AI). The user types once and picks the action at submit time.

  When "Post" is clicked, a hidden `submit_action=post` param is included
  in the form data so the parent LiveView can route to the correct handler.

  Assigns:
  - `id` (string, optional): DOM id for the form. Defaults to `"ask-form"`.
  - `form` (Phoenix.Component.Form, required): The form generated via `to_form/2` in the parent.
  - `ask_question` (boolean, optional): Legacy assign, accepted but ignored. Kept for caller compatibility.
  - `graph_id` (string | nil, optional): Used to tailor the placeholder and hint for the empty graph state.
  - `submit_event` (string, optional): Overrides the default submit event. Defaults to `"reply-and-answer"`.
  - `input_id` (string, optional): DOM id for the text input. Defaults to `"global-chat-input"`.
  - `placeholder` (string, optional): Placeholder text for the input.
  - `show_hint` (boolean, optional): When true and `graph_id` is nil, show a hint above the input. Defaults to `true`.
  - `prompt_mode` (string, optional): Current AI mode ("structured" or "creative"). Used for display only.
  - `node` (map | nil, optional): The currently active node. Used to display current node indicator.
  """

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:id, fn -> "ask-form" end)
      |> assign_new(:ask_question, fn -> true end)
      |> assign_new(:graph_id, fn -> nil end)
      |> assign_new(:submit_event, fn -> nil end)
      |> assign_new(:input_id, fn -> "global-chat-input" end)
      |> assign_new(:show_hint, fn -> true end)
      |> assign_new(:prompt_mode, fn -> "structured" end)
      |> assign_new(:node, fn -> nil end)
      |> assign_new(:context, fn -> :node end)
      |> assign_new(:guided_learning?, fn -> true end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:show_context, fn -> true end)
      |> assign_new(:embedded, fn -> false end)
      |> assign_new(:show_tools, fn -> false end)
      |> assign_new(:tools_open, fn -> false end)
      |> assign_new(:tools_target, fn -> nil end)
      |> assign_new(:tools_button_id, fn -> nil end)
      |> assign_new(:tools_menu_id, fn -> nil end)
      |> assign_new(:inner_block, fn -> [] end)
      |> assign_new(:quick_actions, fn -> [] end)
      |> assign_new(:query_origin, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
      |> then(fn s ->
        cond do
          Map.has_key?(assigns, :placeholder) and not is_nil(assigns[:placeholder]) ->
            assign(s, :placeholder, assigns[:placeholder])

          s.assigns.disabled ->
            assign(s, :placeholder, "Choose an existing response to continue the grid...")

          true ->
            assign(s, :placeholder, "Ask a question or share a thought…")
        end
      end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full min-w-0" data-role="ask-form-container">
      <.form
        for={@form}
        phx-submit={if(@context == :node, do: @submit_event || "reply-and-answer")}
        phx-change={if(@context == :node, do: "validate_inquiry")}
        data-selection-input-form={@context in [:selection, :answer]}
        data-composer-context={@context}
        id={@id}
        class="group/shortcuts w-full min-w-0"
        aria-disabled={@disabled}
        phx-hook="AskFormShortcuts"
      >
        <input
          :if={@query_origin}
          id={"#{@id}-query-origin"}
          type="hidden"
          name="query_origin"
          value={@query_origin}
        />
        <%!-- Compact Replying-to indicator --%>
        <%= if @show_context && @node && @node.id do %>
          <div
            id={"#{@id}-context"}
            class="mb-2 rounded-lg bg-slate-50 px-3 py-2 text-xs leading-5 text-slate-600"
          >
            <span class="block font-semibold text-slate-800">Responding to</span>
            <p class="break-words">{NodeTitleHelper.extract_node_title(@node, max_length: 180)}</p>
          </div>
        <% end %>

        <div class="flex items-center gap-2 w-full">
          <%!-- Input Field --%>
          <div class="relative min-w-0 flex-1">
            <.input
              field={@form[:content]}
              id={@input_id}
              type="textarea"
              aria-label="Your thought or question"
              aria-describedby={if(@embedded, do: "#{@id}-sharing-hint")}
              data-selection-input={@context in [:selection, :answer]}
              rows="1"
              placeholder={@placeholder}
              phx-hook="AutoExpandTextarea"
              phx-debounce="300"
              disabled={@disabled}
              class={
                Enum.join(
                  [
                    "box-border w-full text-base sm:text-sm focus:outline-none focus:ring-0 resize-none",
                    if(@embedded,
                      do: "min-h-[4.5rem] border-0 bg-transparent px-1 py-2",
                      else: "h-10 min-h-[2.5rem] rounded-3xl border py-2.5 pl-4 pr-[17rem]"
                    ),
                    if(@disabled,
                      do:
                        "cursor-not-allowed border-slate-200 bg-slate-100 text-slate-500 placeholder:text-slate-400",
                      else:
                        if(@embedded,
                          do: "text-slate-800 placeholder:text-slate-400",
                          else: "border-gray-300 bg-white focus:border-indigo-500"
                        )
                    )
                  ],
                  " "
                )
              }
            />

            <div
              :if={@embedded && !@disabled && @guided_learning?}
              id={"#{@id}-learning-options"}
              class="mt-1"
            >
              <%= if @current_user do %>
                <.input
                  type="checkbox"
                  id={"#{@id}-guided-learning"}
                  name="guided_learning"
                  value={Map.get(@form.params, "guided_learning", false)}
                  variant="learning_plan"
                  label="Add a learning plan"
                />
              <% else %>
                <.link
                  :if={@context == :answer}
                  id={"#{@id}-guided-learning-login"}
                  href={~p"/users/log_in"}
                  class="inline-flex min-h-11 items-center rounded-lg px-1 text-xs font-semibold text-indigo-700 underline-offset-4 hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-indigo-500"
                >
                  Sign in for a learning plan
                </.link>
                <button
                  :if={@context == :node}
                  id={"#{@id}-guided-learning-signup"}
                  type="button"
                  phx-click="show_login_required"
                  class="inline-flex min-h-11 items-center gap-2 rounded-lg px-1 text-left text-xs font-semibold text-indigo-700 hover:bg-indigo-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400 focus-visible:ring-offset-2"
                >
                  <.icon name="hero-sparkles" class="h-4 w-4" /> Sign in for a learning plan
                </button>
              <% end %>

              <button
                :if={@context == :node}
                id="mobile-inquiry-settings"
                type="button"
                phx-click={
                  Phoenix.LiveView.JS.dispatch("toggle-panel",
                    to: "#graph-layout",
                    detail: %{id: "right-panel"}
                  )
                  |> Phoenix.LiveView.JS.push("open_prompt_settings")
                }
                class="mt-2 inline-flex min-h-11 items-center gap-2 rounded-lg border border-slate-200 px-3 text-xs font-semibold text-slate-700 md:hidden"
              >
                Answer settings
              </button>
            </div>

            <%!-- Two submit buttons inside the input --%>
            <div class={[
              "relative flex items-center gap-1.5",
              if(@embedded,
                do:
                  "mt-1 flex-wrap items-center gap-2 border-t border-slate-100 pb-1 pt-2 md:flex-nowrap",
                else: "absolute right-1.5 top-0 bottom-1.5 items-center gap-1.5 justify-end"
              )
            ]}>
              <div class={
                if(@embedded,
                  do: "ml-auto flex w-full min-w-0 items-center gap-2 md:w-auto md:flex-1",
                  else: "ml-auto flex items-center gap-1"
                )
              }>
                <%!-- Ask button — default submit (no name, so no submit_action param) --%>
                <button
                  id={"#{@id}-ask"}
                  data-shortcut-action="ask"
                  data-selection-input-submit={@context in [:selection, :answer]}
                  data-selection-submit-action={
                    if(@context in [:selection, :answer], do: "ask_question")
                  }
                  aria-keyshortcuts="Control+Enter Meta+Enter"
                  phx-disable-with="Asking AI…"
                  type="submit"
                  disabled={@disabled}
                  class={[
                    "inline-flex items-center font-semibold transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
                    if(@embedded,
                      do:
                        "h-11 min-w-0 flex-auto justify-center gap-1 whitespace-nowrap rounded-lg border border-sky-700 px-3 text-sm md:h-10 md:text-xs",
                      else: "h-8 gap-1 rounded-full px-3 text-xs leading-none shadow-sm"
                    ),
                    if(@disabled,
                      do: "bg-slate-300 text-white shadow-none",
                      else: "bg-sky-700 text-white hover:bg-sky-800"
                    )
                  ]}
                  title={
                    if(@disabled,
                      do: "Choose an existing response to continue",
                      else: "Ask and get an AI response"
                    )
                  }
                >
                  <span>Ask AI</span>
                  <.shortcut_keycap dark />
                </button>
                <%!-- Post button — adds submit_action=post to form params --%>
                <button
                  id={"#{@id}-comment"}
                  type="submit"
                  data-shortcut-action="comment"
                  data-selection-input-submit={@context in [:selection, :answer]}
                  data-selection-submit-action={if(@context in [:selection, :answer], do: "comment")}
                  aria-keyshortcuts="Control+Shift+Enter Meta+Shift+Enter"
                  name="submit_action"
                  value="post"
                  phx-disable-with="Posting…"
                  disabled={@disabled || DialecticWeb.GraphHelpers.origin_node?(@node)}
                  class={[
                    "inline-flex items-center font-semibold transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
                    if(@embedded,
                      do:
                        "h-11 min-w-0 flex-auto justify-center gap-1 whitespace-nowrap rounded-lg border border-slate-300 px-3 text-sm md:h-10 md:text-xs",
                      else: "h-8 gap-1 rounded-full px-2.5 text-xs leading-none"
                    ),
                    if(@disabled,
                      do: "bg-slate-100 text-slate-400",
                      else: "bg-white text-slate-700 hover:bg-slate-100"
                    )
                  ]}
                  title={
                    if(@disabled,
                      do: "Choose an existing response to continue",
                      else: "Post your thought to the shared discussion"
                    )
                  }
                >
                  <span class="inline-flex items-center gap-2">
                    <.icon
                      name="hero-chat-bubble-left-ellipsis"
                      class={if(@embedded, do: "hidden", else: "h-3.5 w-3.5")}
                    />
                    <span>Post thought</span>
                  </span>
                  <.shortcut_keycap shift />
                </button>
              </div>
            </div>
          </div>
        </div>

        <p
          :if={@embedded}
          id={"#{@id}-sharing-hint"}
          class="mt-1 px-1 text-xs leading-5 text-slate-500"
        >
          Shared with everyone in this discussion.
        </p>
        <p
          :if={@context in [:selection, :answer]}
          id={"#{@id}-status"}
          data-selection-status
          role="status"
          aria-live="polite"
          class="mt-2 px-1 text-sm text-slate-700 empty:hidden"
        >
        </p>
        <div
          :if={@show_tools}
          id={"#{@id}-tools-toolbar"}
          class="inquiry-tools-toolbar mt-2 grid min-w-0 max-w-full grid-cols-2 items-stretch gap-1.5 border-t border-slate-100 pt-2"
        >
          {render_slot(@quick_actions)}
        </div>
        <div :if={@show_tools} id={"#{@id}-more-tools-row"} class="mt-1 flex">
          <button
            id={@tools_button_id}
            type="button"
            phx-click={if(@context == :node, do: "toggle_advanced_tools")}
            data-selection-advanced-toggle={@context in [:selection, :answer]}
            data-reader-shortcut="t"
            data-reader-shortcut-modifier="none"
            aria-keyshortcuts="T"
            phx-target={@tools_target}
            aria-expanded={to_string(@tools_open)}
            aria-controls={@tools_menu_id}
            class={[
              "inquiry-disclosure py-1.5 pl-1.5 pr-3",
              !@embedded && "min-h-8 text-xs"
            ]}
          >
            <span
              data-tools-closed
              class={["inline-flex items-center gap-2.5", @tools_open && "hidden"]}
            >
              <span class="inquiry-disclosure-icon">
                <.icon name="hero-plus" class="h-4 w-4" />
              </span>
              More tools
            </span>
            <span
              data-tools-open
              class={["inline-flex items-center gap-2.5", !@tools_open && "hidden"]}
            >
              <span class="inquiry-disclosure-icon">
                <.icon name="hero-chevron-up" class="h-4 w-4" />
              </span>
              Hide tools
            </span>
            <.shortcut_keycap key="T" modifier="none" />
          </button>
        </div>

        {render_slot(@inner_block)}
      </.form>
    </div>
    """
  end
end
