defmodule DialecticWeb.NewIdeaFormComp do
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
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:id, fn -> "new-idea-form" end)
      |> assign_new(:placeholder, fn ->
        "Ask a question, name a topic, or frame a tension"
      end)
      |> assign_new(:submit_label, fn -> "Next" end)
      |> assign_new(:selected_mode, fn -> "high_school" end)
      |> assign_new(:show_level_prompt, fn -> false end)
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
    {:noreply,
     assign(socket,
       content: content,
       show_level_prompt: socket.assigns.show_level_prompt and String.trim(content) != ""
     )}
  end

  @impl true
  def handle_event("submit_prompt", %{"vertex" => %{"content" => content}}, socket) do
    trimmed_content = String.trim(content)

    cond do
      trimmed_content == "" ->
        {:noreply, assign(socket, content: content, show_level_prompt: false)}

      socket.assigns.show_level_prompt ->
        send(self(), {:submit_new_grid, trimmed_content, socket.assigns.selected_mode})

        {:noreply, assign(socket, content: trimmed_content, show_level_prompt: false)}

      true ->
        {:noreply, assign(socket, content: content, show_level_prompt: true)}
    end
  end

  @impl true
  def handle_event("edit_prompt", _params, socket) do
    {:noreply, assign(socket, :show_level_prompt, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.form
        for={@form}
        phx-submit="submit_prompt"
        phx-target={@myself}
        id={@id}
        class="w-full relative"
      >
        <div class="flex flex-col gap-1.5">
          <div class="relative min-h-[3.2rem]">
            <textarea
              name={@form[:content].name}
              id="new-idea-input"
              placeholder={@placeholder}
              phx-hook="AutoExpandTextarea"
              phx-change="update_content"
              phx-target={@myself}
              rows="1"
              class={[
                "box-border block w-full overflow-hidden rounded-2xl bg-white text-slate-950 shadow-[inset_0_1px_2px_rgba(15,23,42,0.05)] sm:rounded-[1.6rem]",
                "border border-slate-300/90",
                "focus:border-indigo-400 focus:ring-4 focus:ring-indigo-100 focus:outline-none resize-none",
                "text-[0.95rem] leading-[1.45] sm:text-[1.05rem] sm:leading-[1.5]",
                "placeholder:text-slate-500",
                "px-3.5 sm:pl-5 sm:pr-28",
                "py-2.5 sm:py-2.5",
                "min-h-[3rem] sm:min-h-[3.2rem]"
              ]}
              autocomplete="off"
              required
            >{@content}</textarea>
            <div class="absolute right-2 top-2 bottom-2 hidden w-24 items-start justify-center sm:flex">
              <button
                type="submit"
                id="new-idea-submit"
                phx-disable-with={if @show_level_prompt, do: "Starting...", else: "Next..."}
                class="inline-flex min-h-[2.35rem] w-full items-center justify-center rounded-full border border-transparent bg-slate-900 px-0 py-1.5 text-sm font-semibold leading-none text-white shadow-sm transition hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {if @show_level_prompt, do: "Create", else: @submit_label}
              </button>
            </div>
          </div>

          <div class="sm:hidden">
            <button
              type="submit"
              id="new-idea-submit-mobile"
              phx-disable-with={if @show_level_prompt, do: "Starting...", else: "Next..."}
              class="inline-flex w-full items-center justify-center gap-2 rounded-xl border border-transparent bg-slate-900 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition-transform active:scale-[0.98] hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <.icon name="hero-arrow-right" class="h-4 w-4" />
              {if @show_level_prompt, do: "Create grid", else: @submit_label}
            </button>
          </div>

          <%= if !@show_level_prompt do %>
            <div class="flex flex-col gap-1 px-1 text-xs text-slate-600 sm:flex-row sm:items-center sm:justify-between">
              <p>Step 1 of 2: describe the grid you want to start.</p>
              <p class="hidden sm:block">You’ll choose the level of detail next.</p>
            </div>
          <% end %>
        </div>

        <%= if @show_level_prompt do %>
          <div
            id="new-idea-level-step"
            class="mt-3 rounded-2xl border border-indigo-200 bg-indigo-50/80 px-3 py-3 shadow-sm ring-1 ring-indigo-100 animate-fade-in-up"
          >
            <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
              <div class="space-y-1">
                <p class="text-[11px] font-semibold uppercase tracking-[0.16em] text-indigo-800">
                  Step 2 of 2
                </p>
                <p class="text-sm font-semibold text-slate-900">
                  Choose the starting level for the first draft.
                </p>
                <p class="text-xs text-slate-600">
                  This only shapes the opening pass. You can refine the grid after it loads.
                </p>
              </div>
              <button
                type="button"
                phx-click="edit_prompt"
                phx-target={@myself}
                class="inline-flex items-center text-xs font-medium text-slate-600 transition hover:text-slate-900"
              >
                Edit prompt
              </button>
            </div>

            <div class="mt-3 w-full sm:w-auto">
              <div class="mx-auto flex w-full rounded-xl border border-indigo-200 bg-white/80 p-0.5 shadow-inner sm:inline-flex sm:w-auto">
                <%= for {mode, label} <- [{"simple", "Simple"}, {"high_school", "High School"}, {"university", "University"}, {"expert", "Expert"}] do %>
                  <button
                    type="button"
                    phx-click="select_mode"
                    phx-value-mode={mode}
                    phx-target={@myself}
                    class={[
                      "flex-1 rounded-lg px-2.5 py-1.5 text-center text-xs font-medium transition-colors duration-150 sm:flex-initial sm:px-3 sm:py-1.5",
                      if @selected_mode == mode do
                        "border border-slate-900 bg-slate-900 text-white shadow-sm"
                      else
                        "text-slate-600 hover:bg-white hover:text-slate-900 active:bg-white"
                      end
                    ]}
                  >
                    {label}
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </.form>
    </div>
    """
  end
end
