defmodule DialecticWeb.NewGridForm do
  use DialecticWeb, :live_component

  @moduledoc """
  LiveComponent that renders a simplified input form for starting new ideas.

  Assigns:
  - `id` (string, optional): DOM id for the form.
  - `form` (Phoenix.Component.Form, required): The form generated via `to_form/2` in the parent.
  - `placeholder` (string, optional): Placeholder text for the input.
  - `submit_label` (string, optional): Label for the submit button. Defaults to "Ask".
  """

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:placeholder, fn -> "Ask a question or name a topic" end)
     |> assign_new(:label, fn -> "Create a grid" end)
     |> assign_new(:context, fn -> nil end)
     |> assign_new(:busy, fn -> false end)
     |> assign_new(:resume_draft, fn -> false end)
     |> assign_new(:selected_mode, fn -> "high_school" end)
     |> assign_new(:content, fn %{form: form} -> form[:content].value || "" end)}
  end

  @impl true
  def handle_event("restore_draft", %{"content" => content, "mode" => mode}, socket)
      when is_binary(content) and mode in ["high_school", "university", "expert"] do
    if socket.assigns.resume_draft do
      {:reply, %{restored: true}, assign(socket, content: content, selected_mode: mode)}
    else
      {:reply, %{restored: false}, socket}
    end
  end

  def handle_event("restore_draft", _params, socket), do: {:reply, %{restored: false}, socket}

  @impl true
  def handle_event("update_content", %{"vertex" => params}, socket) do
    {:noreply,
     assign(socket,
       content: Map.get(params, "content", socket.assigns.content),
       selected_mode: Map.get(params, "mode", socket.assigns.selected_mode)
     )}
  end

  @impl true
  def handle_event("submit_prompt", %{"vertex" => params}, socket) do
    content = String.trim(params["content"] || "")
    mode = Map.get(params, "mode", socket.assigns.selected_mode)

    if content != "" && !socket.assigns.busy do
      send(self(), {:submit_new_grid, content, mode})
    end

    {:noreply, assign(socket, content: content, selected_mode: mode)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id <> "-panel"} class="w-full">
      <div class="flex items-center gap-2 text-teal-800">
        <.icon name="hero-plus-circle" class="h-5 w-5" />
        <h2 class="text-xl font-semibold text-slate-950">{@label}</h2>
      </div>
      <p
        id={@id <> "-privacy"}
        class="mt-2 flex max-w-xl items-start gap-2 text-sm leading-6 text-slate-600"
      >
        <.icon name="hero-lock-closed" class="mt-1 h-4 w-4 shrink-0" />
        <span><strong class="font-medium text-slate-700">Visibility:</strong>
        Only you can access it until you choose to share it or make it public.</span>
      </p>
      <p :if={@context} id={@id <> "-context"} class="mt-3 text-sm font-medium text-teal-800">
        {@context}
      </p>
      <.form
        for={@form}
        id={@id}
        phx-submit="submit_prompt"
        phx-change="update_content"
        phx-target={@myself}
        phx-hook="NewGridDraft"
        data-resume-draft={to_string(@resume_draft)}
        data-selected-mode={@selected_mode}
        class="mt-5"
      >
        <fieldset id={@id <> "-fields"} disabled={@busy} class="min-w-0 space-y-4">
          <.input
            field={@form[:content]}
            id="new-idea-input"
            type="textarea"
            value={@content}
            label="What would you like to learn?"
            placeholder={@placeholder}
            rows="3"
            required
            autocomplete="off"
            class="block min-h-28 w-full resize-y rounded-md border border-stone-400 bg-white px-4 py-3 text-base leading-6 text-slate-950 placeholder:text-slate-500 focus:border-teal-700 focus:outline-none focus:ring-2 focus:ring-teal-700/20"
          />
          <div class="flex min-w-0 flex-wrap items-center gap-2 border-t border-stone-300 pt-3">
            <button
              id="new-idea-create-submit"
              type="submit"
              phx-disable-with="Creating your grid…"
              data-analytics-event="grid_creation_requested"
              data-analytics-location="my_learning"
              class="inline-flex min-h-12 items-center justify-center gap-2 rounded-md bg-teal-800 px-5 py-3 text-base font-semibold text-white hover:bg-teal-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700 disabled:cursor-wait disabled:opacity-60"
            >
              Create a grid <.icon name="hero-arrow-right" class="h-4 w-4" />
            </button>
            <DialecticWeb.WorkspaceBarComp.answer_level_dropdown
              id={@id <> "-answer-level"}
              field={@form[:mode]}
              prompt_mode={@selected_mode}
              current_user={@current_user}
              heading="First AI answer"
              hint="Sets the detail of your first AI answer. You can change it later."
            />
          </div>
          <p class="text-xs leading-5 text-slate-500">
            AI will help you get started. You can ask follow-up questions, add your own thoughts and change the answer detail later.
          </p>
        </fieldset>
      </.form>
      <p
        :if={@busy}
        id={@id <> "-progress"}
        role="status"
        class="mt-4 flex items-center gap-2 text-sm font-medium text-teal-800"
      >
        <.icon name="hero-arrow-path" class="h-4 w-4 animate-spin motion-reduce:animate-none" />
        Creating your grid…
      </p>
    </div>
    """
  end
end
