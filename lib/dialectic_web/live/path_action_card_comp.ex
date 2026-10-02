defmodule DialecticWeb.PathActionCardComp do
  use DialecticWeb, :html

  attr :id, :string, required: true
  attr :patch, :string, required: true
  attr :title, :string, required: true
  attr :node_class, :string, required: true
  attr :loading, :boolean, default: false
  attr :action_label, :string, default: "Read this path"

  def path_action_card(assigns) do
    ~H"""
    <.link
      id={@id}
      patch={@patch}
      aria-label={"#{@action_label}: #{@title}"}
      data-path-action-card
      class="group flex min-h-14 min-w-0 items-center gap-3 px-3 py-3 transition-colors hover:bg-teal-50/60 focus-visible:outline focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-teal-700 sm:px-4"
    >
      <div class="flex min-w-0 flex-1 flex-col items-start gap-2 sm:flex-row sm:items-center sm:gap-4">
        <span class={[
          "inline-flex shrink-0 items-center justify-center rounded-full px-2.5 py-1 text-[11px] font-semibold sm:w-28",
          DialecticWeb.ColUtils.badge_class(@node_class)
        ]}>
          {DialecticWeb.ColUtils.node_type_label(@node_class)}
        </span>

        <div class="min-w-0 flex-1">
          <p
            data-path-title
            class="reader-heading text-base font-medium leading-snug text-slate-900 [overflow-wrap:anywhere]"
          >
            {@title}
          </p>
          <span
            :if={@loading}
            id={"#{@id}-loading"}
            role="status"
            class="mt-1 inline-flex items-center gap-2 text-sm font-medium text-indigo-700"
          >
            Generating response <DialecticWeb.GenerationComponents.thinking_dots />
          </span>
        </div>
      </div>

      <span data-path-action class="sr-only">{@action_label}</span>
      <.icon
        name="hero-arrow-right"
        class="h-4 w-4 shrink-0 text-slate-400 transition-colors group-hover:text-teal-700"
      />
    </.link>
    """
  end
end
