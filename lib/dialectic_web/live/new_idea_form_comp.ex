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
      |> assign_new(:submit_label, fn -> "Start" end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.form for={@form} phx-submit="reply-and-answer" id={@id} class="w-full relative">
        <div class="relative">
          <textarea
            name={@form[:content].name}
            id="new-idea-input"
            placeholder={@placeholder}
            phx-hook="AutoExpandTextarea"
            rows="1"
            class="box-border w-full h-[3.5rem] min-h-[3.5rem] overflow-hidden pl-6 pr-32 py-2.5 text-black text-lg rounded-full border-2 border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-0 focus:outline-none resize-none"
            autocomplete="off"
            required
          >{Phoenix.HTML.Form.normalize_value("text", @form[:content].value)}</textarea>
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
      </.form>
    </div>
    """
  end
end
