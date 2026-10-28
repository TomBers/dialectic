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
        <div
          :if={@show_context && @node && @node.id}
          id={"#{@id}-context"}
          class="mb-2 rounded-lg bg-slate-50 px-3 py-2 text-xs leading-5 text-slate-600"
        >
          <span class="block font-semibold text-slate-800">Responding to</span>
          <p class="break-words">{NodeTitleHelper.extract_node_title(@node, max_length: 180)}</p>
        </div>

        <div
          id={"#{@id}-primary-actions"}
          class="min-w-0 rounded-xl border border-stone-400 bg-white p-3 focus-within:border-teal-800 focus-within:ring-2 focus-within:ring-teal-700/20"
        >
          <.input
            field={@form[:content]}
            id={@input_id}
            type="textarea"
            aria-label="Your thought or question"
            aria-describedby={"#{@id}-sharing-hint"}
            data-selection-input={@context in [:selection, :answer]}
            rows="2"
            placeholder={@placeholder}
            phx-hook="AutoExpandTextarea"
            phx-debounce="300"
            disabled={@disabled}
            class={
              Enum.join(
                [
                  "box-border min-h-[4.5rem] w-full resize-none border-0 bg-transparent px-1 py-2 text-base text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-0 sm:text-sm",
                  if(@disabled, do: "cursor-not-allowed bg-slate-100 text-slate-600", else: "")
                ],
                " "
              )
            }
          />
          <div class="mt-2 flex flex-wrap items-stretch gap-2 border-t border-stone-300 pt-3">
            <div class="contents">
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
                class="inline-flex min-h-11 min-w-28 items-center justify-center gap-2 rounded-lg bg-teal-800 px-5 text-sm font-semibold text-white hover:bg-teal-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-800 disabled:cursor-not-allowed disabled:opacity-50"
                title={
                  if(@disabled,
                    do: "Choose an existing response to continue",
                    else: "Ask and get an AI response"
                  )
                }
              >
                <span>Ask AI</span><.shortcut_keycap dark />
              </button>
              <DialecticWeb.WorkspaceBarComp.answer_level_dropdown
                :if={@graph_id && !@disabled}
                id={@id <> "-answer-level"}
                prompt_mode={@prompt_mode}
                current_user={@current_user}
              />
            </div>
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
              class="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold text-slate-950 hover:bg-stone-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-800 disabled:cursor-not-allowed disabled:opacity-50"
              title="Post your thought to the shared discussion"
            >
              <span>Post thought</span><.shortcut_keycap shift />
            </button>
          </div>

          <p
            :if={@context in [:selection, :answer]}
            id={"#{@id}-status"}
            data-selection-status
            role="status"
            aria-live="polite"
            class="mt-2 px-1 text-sm text-slate-700 empty:hidden"
          >
          </p>
        </div>

        <p
          :if={!@current_user && @context in [:node, :answer]}
          id={"#{@id}-guest-access"}
          class="mt-3 text-xs leading-5 text-slate-600"
        >
          Reading is available without an account.
          <.link
            href={~p"/users/log_in"}
            class="font-semibold text-teal-800 underline underline-offset-2"
          >Log in</.link>
          or
          <.link
            href={~p"/users/register"}
            class="font-semibold text-teal-800 underline underline-offset-2"
          >create an account</.link>
          to ask questions, post thoughts, save bookmarks and highlight passages.
        </p>

        <section
          :if={@embedded && !@disabled && @guided_learning?}
          id={"#{@id}-learning-options"}
          aria-labelledby={"#{@id}-learning-heading"}
          class="mt-4 rounded-xl border border-stone-300 border-l-4 border-l-teal-800 bg-[#f4f1e9] p-3"
        >
          <h3
            id={"#{@id}-learning-heading"}
            class="flex items-center gap-2 text-sm font-semibold text-slate-900"
          >
            <.icon name="hero-academic-cap" class="h-4 w-4 text-teal-800" /> Guide my thinking
            <span class="text-xs font-normal text-slate-600">Optional</span>
          </h3>
          <p id={"#{@id}-learning-description"} class="mt-1 text-xs leading-5 text-slate-600">
            Get key questions to explore next, helping you examine the idea and develop your understanding.
          </p>
          <%= if @current_user do %>
            <.input
              type="checkbox"
              id={"#{@id}-guided-learning"}
              name="guided_learning"
              value={Map.get(@form.params, "guided_learning", false)}
              variant="learning_plan"
              label="Add a learning plan"
              description=""
              aria-describedby={"#{@id}-learning-description"}
            />
          <% else %>
            <.link
              :if={@context == :answer}
              id={"#{@id}-guided-learning-login"}
              href={~p"/users/log_in"}
              class="mt-2 inline-flex min-h-11 items-center text-xs font-semibold text-teal-900 underline underline-offset-4"
            >Sign in for a learning plan</.link>
            <button
              :if={@context == :node}
              id={"#{@id}-guided-learning-signup"}
              type="button"
              phx-click="show_login_required"
              class="mt-2 inline-flex min-h-11 items-center gap-2 rounded-lg text-xs font-semibold text-teal-900"
            ><.icon name="hero-sparkles" class="h-4 w-4" />Sign in for a learning plan</button>
          <% end %>
        </section>

        <section
          :if={@show_tools}
          id={"#{@id}-thinking-tools"}
          class="mt-4 border-t border-stone-300 pt-3"
        >
          <div id={"#{@id}-more-tools-row"}>
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
              class="inquiry-disclosure w-full py-2 pl-2 pr-3 text-left"
            >
              <span class="inquiry-disclosure-icon"><.icon name="hero-light-bulb" class="h-4 w-4" /></span>
              <span class="min-w-0 flex-1">
                <span data-tools-closed class={[@tools_open && "hidden"]}>Show thinking tools</span>
                <span data-tools-open class={[!@tools_open && "hidden"]}>Hide thinking tools</span>
              </span>
              <.shortcut_keycap key="T" modifier="none" />
            </button>
          </div>
          <div
            id={@tools_menu_id}
            role="group"
            aria-label="Critical thinking tools"
            phx-hook={if(@context == :node, do: "ToolsMenu")}
            phx-update={if(@context in [:selection, :answer], do: "ignore")}
            hidden={@context in [:selection, :answer] || !@tools_open}
            data-open={to_string(@tools_open)}
            data-selection-advanced-tools={@context in [:selection, :answer]}
            data-thinking-tools-panel
            data-trigger-id={@tools_button_id}
            phx-target={@tools_target}
            class="min-w-0 pt-3"
          >
            <div
              id={"#{@id}-tools-toolbar"}
              class="inquiry-tools-toolbar mb-3 grid min-w-0 max-w-full grid-cols-1 items-stretch gap-1.5 sm:grid-cols-2"
            >
              {render_slot(@quick_actions)}
            </div>
            {render_slot(@inner_block)}
            <button
              id={"#{@tools_menu_id}-done"}
              type="button"
              data-tools-close
              class="mt-3 inline-flex min-h-11 items-center gap-2 rounded-lg px-2 text-xs font-semibold text-teal-800"
            ><.icon name="hero-chevron-up" class="h-4 w-4" />Hide thinking tools</button>
          </div>
        </section>
      </.form>
    </div>
    """
  end
end
