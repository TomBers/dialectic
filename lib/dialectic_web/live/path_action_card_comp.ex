defmodule DialecticWeb.PathActionCardComp do
  use DialecticWeb, :html

  attr :id, :string, required: true
  attr :patch, :string, required: true
  attr :title, :string, required: true
  attr :node_class, :string, required: true
  attr :action_label, :string, default: "Read this path"

  def path_action_card(assigns) do
    ~H"""
    <.link
      id={@id}
      patch={@patch}
      aria-label={"#{@action_label}: #{@title}"}
      data-path-action-card
      class="group flex h-full flex-col rounded-[1.35rem] border border-sky-200/80 bg-gradient-to-br from-white via-white to-sky-50/80 p-4 shadow-sm ring-1 ring-sky-950/[0.035] transition duration-200 active:scale-[0.995] hover:-translate-y-0.5 hover:border-sky-300 hover:shadow-[0_20px_38px_-24px_rgba(14,116,144,0.3)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-600 sm:rounded-2xl sm:p-5"
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
          class="mt-4 font-serif text-xl font-semibold leading-6 tracking-tight text-slate-950 transition group-hover:text-sky-950"
        >
          {@title}
        </p>
      </div>

      <div
        data-path-action
        class="mt-5 flex items-center justify-between rounded-xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white shadow-sm transition group-hover:bg-sky-800 group-hover:shadow-md"
      >
        <span>{@action_label}</span>
        <span class="inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-white/10 text-white transition group-hover:translate-x-0.5 group-hover:bg-white/15">
          <.icon name="hero-arrow-right" class="h-4 w-4" />
        </span>
      </div>
    </.link>
    """
  end
end
