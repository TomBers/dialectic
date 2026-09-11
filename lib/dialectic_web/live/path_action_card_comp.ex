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
      class="group flex h-full min-w-0 flex-col rounded-xl border border-slate-200 bg-slate-50/60 p-4 transition-colors hover:border-teal-300 hover:bg-teal-50/60 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700 sm:p-5"
    >
      <div class="min-w-0 flex-1">
        <span class={[
          "inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-semibold",
          DialecticWeb.ColUtils.badge_class(@node_class)
        ]}>
          {DialecticWeb.ColUtils.node_type_label(@node_class)}
        </span>

        <p
          data-path-title
          class="reader-heading mt-3 text-[length:var(--rg-read-font-size)] font-semibold leading-snug text-slate-900 [overflow-wrap:anywhere]"
        >
          {@title}
        </p>
        <span
          :if={@loading}
          id={"#{@id}-loading"}
          role="status"
          class="mt-3 inline-flex items-center gap-2 text-sm font-medium text-indigo-700"
        >
          Generating response <DialecticWeb.GenerationComponents.thinking_dots />
        </span>
      </div>

      <div
        data-path-action
        class="mt-4 flex items-center justify-between gap-3 border-t border-slate-200 pt-3 text-sm font-medium text-teal-800"
      >
        <span>{@action_label}</span>
        <span class="inline-flex h-6 w-6 shrink-0 items-center justify-center text-teal-700">
          <.icon name="hero-arrow-right" class="h-4 w-4" />
        </span>
      </div>
    </.link>
    """
  end
end
