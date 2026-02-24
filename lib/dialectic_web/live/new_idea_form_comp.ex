defmodule DialecticWeb.NewIdeaFormComp do
  use DialecticWeb, :live_component

  @moduledoc """
  LiveComponent that renders a simplified input form for starting new ideas.

  Assigns:
  - `id` (string, optional): DOM id for the form.
  - `form` (Phoenix.Component.Form, required): The form generated via `to_form/2` in the parent.
  - `placeholder` (string, optional): Placeholder text for the input.
  - `submit_label` (string, optional): Label for the submit button. Defaults to "Start".
  """

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:id, fn -> "new-idea-form" end)
      |> assign_new(:placeholder, fn ->
        "Ask a question to begin exploring a new topic."
      end)
      |> assign_new(:submit_label, fn -> "Ask" end)
      |> assign_new(:selected_mode, fn -> "university" end)
      |> assign_new(:content, fn %{form: form} ->
        Phoenix.HTML.Form.normalize_value("text", form[:content].value)
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, selected_mode: mode)}
  end

  @impl true
  def handle_event("update_content", %{"vertex" => %{"content" => content}}, socket) do
    {:noreply, assign(socket, :content, content)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.form for={@form} phx-submit="reply-and-answer" id={@id} class="w-full relative">
        <input type="hidden" name="mode" value={@selected_mode} />

        <div class="relative">
          <textarea
            name={@form[:content].name}
            id="new-idea-input"
            placeholder={@placeholder}
            phx-hook="AutoExpandTextarea"
            phx-change="update_content"
            phx-target={@myself}
            rows="1"
            class="box-border w-full h-[3.5rem] min-h-[3.5rem] overflow-hidden pl-6 pr-32 py-2.5 text-black text-lg rounded-full border border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-0 focus:outline-none resize-none"
            autocomplete="off"
            required
          >{@content}</textarea>
          <div class="absolute top-1/2 right-2 -translate-y-1/2 -mt-0.5">
            <button
              type="submit"
              phx-disable-with="Starting..."
              class="inline-flex items-center justify-center px-6 py-2 border border-transparent text-base font-medium rounded-full shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {@submit_label}
            </button>
          </div>
        </div>

        <div class="mt-4 flex items-center justify-center gap-3 animate-fade-in-up">
          <span class="text-xs font-semibold text-indigo-200/80 uppercase tracking-wide">
            Level
          </span>
          <div class="inline-flex rounded-lg bg-white/10 p-1 border border-white/5 backdrop-blur-sm">
            <%= for {mode, label} <- [{"simple", "Simple"}, {"high_school", "High School"}, {"university", "University"}, {"expert", "Expert"}] do %>
              <button
                type="button"
                phx-click="select_mode"
                phx-value-mode={mode}
                phx-target={@myself}
                class={[
                  "px-3 py-1.5 text-xs font-medium rounded-md transition-all duration-200",
                  if @selected_mode == mode do
                    "bg-white text-[#3a0ca3] shadow-sm scale-105"
                  else
                    "text-white/70 hover:text-white hover:bg-white/5"
                  end
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
