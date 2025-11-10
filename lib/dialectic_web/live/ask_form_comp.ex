defmodule DialecticWeb.AskFormComp do
  use DialecticWeb, :live_component
  alias Dialectic.Responses.ModeServer

  @moduledoc """
  LiveComponent that renders the bottom ask/comment form used by GraphLive.

  Assigns:
  - `id` (string, optional): DOM id for the form. Defaults to `"ask-form"`.
  - `form` (Phoenix.Component.Form, required): The form generated via `to_form/2` in the parent.
  - `ask_question` (boolean, optional): When true, uses the ask flow; otherwise comment flow. Defaults to `true`.
  - `graph_id` (string | nil, optional): Used to tailor the placeholder and hint for the empty graph state.
  - `submit_event` (string, optional): Overrides the default submit event. Defaults to `"reply-and-answer"` when `ask_question` is true,
    otherwise `"answer"`.
  - `submit_label` (string, optional): Overrides the button label. Defaults to `"Ask"` or `"Post"`.
  - `input_id` (string, optional): DOM id for the text input. Defaults to `"global-chat-input"`.
  - `placeholder` (string, optional): Placeholder text for the input. Will be derived from `graph_id`/`ask_question` if not provided.
  - `show_hint` (boolean, optional): When true and `graph_id` is nil, show a hint above the input. Defaults to `true`.
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
      |> assign_new(:submit_label, fn -> nil end)
      |> assign_new(:input_id, fn -> "global-chat-input" end)
      |> assign_new(:show_hint, fn -> true end)
      |> assign_new(:prompt_mode, fn ->
        gid = assigns[:graph_id]
        mode = if is_binary(gid), do: ModeServer.get_mode(gid), else: :structured
        Atom.to_string(mode)
      end)
      |> then(fn s ->
        if Map.has_key?(assigns, :placeholder) and not is_nil(assigns[:placeholder]) do
          assign(s, :placeholder, assigns[:placeholder])
        else
          assign(
            s,
            :placeholder,
            placeholder_for(s.assigns[:ask_question], s.assigns[:prompt_mode])
          )
        end
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("cycle_prompt_mode", _params, socket) do
    gid = socket.assigns[:graph_id]

    if is_binary(gid) do
      current = ModeServer.get_mode(gid)

      next =
        case current do
          :structured -> :creative
          _ -> :structured
        end

      :ok = ModeServer.set_mode(gid, next)

      send_update(
        DialecticWeb.RightPanelComp,
        id: "right-panel-comp",
        prompt_mode: Atom.to_string(next)
      )

      new_mode = Atom.to_string(next)
      ask_q = Map.get(socket.assigns, :ask_question, true)

      placeholder = placeholder_for(ask_q, new_mode)

      {:noreply, assign(socket, prompt_mode: new_mode, placeholder: placeholder)}
    else
      {:noreply, socket}
    end
  end

  defp placeholder_for(ask_q, mode) do
    if ask_q,
      do: "Ask a " <> (mode || "structured") <> " question…",
      else: "Add a comment…"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full min-w-0">
      <.form
        for={@form}
        phx-submit={@submit_event || if(@ask_question, do: "reply-and-answer", else: "answer")}
        id={@id}
        class="w-full min-w-0"
      >
        <div class="flex items-center gap-2 w-full">
          <button
            type="button"
            phx-click="toggle_ask_question"
            class={"px-2 py-1 text-xs rounded-full flex-none " <> if @ask_question, do: "bg-blue-50 text-blue-600 border border-blue-200", else: "bg-emerald-50 text-emerald-600 border border-emerald-200"}
            title="Toggle ask/comment"
          >
            {if @ask_question, do: "Ask", else: "Comment"}
          </button>

          <button
            type="button"
            phx-click="cycle_prompt_mode"
            phx-target={@myself}
            class="bg-white border border-gray-300 text-gray-700 text-xs leading-none px-2 h-8 rounded-full hover:bg-gray-50 flex-none"
            title="Cycle LLM mode"
          >
            {String.capitalize(@prompt_mode || "structured")}
          </button>

          <div class="relative min-w-0 flex-1 overflow-hidden rounded-full transition-shadow focus-within:ring-2 focus-within:ring-indigo-400 focus-within:ring-offset-1 focus-within:ring-offset-white">
            <.input
              field={@form[:content]}
              type="text"
              id={@input_id}
              placeholder={@placeholder}
              class="box-border w-full h-10 rounded-full pl-3 pr-28 text-sm border border-gray-300 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-400 focus:ring-opacity-50 focus:outline-none"
            />

            <button
              type="submit"
              class="absolute right-2 inset-y-0 my-auto bg-indigo-600 hover:bg-indigo-700 text-white text-sm leading-none px-2.5 h-8 rounded-full font-medium"
            >
              {if @submit_label, do: @submit_label, else: if(@ask_question, do: "Ask", else: "Post")}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
