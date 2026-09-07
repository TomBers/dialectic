defmodule DialecticWeb.QuestionCards do
  use DialecticWeb, :html

  attr :id, :string, required: true
  attr :pages, :any, required: true
  attr :has_pages, :boolean, required: true

  def cards(assigns) do
    ~H"""
    <section id={@id} class="my-6">
      <h2 :if={@has_pages} class="mb-3 font-serif text-2xl text-slate-950">
        Questions to think through
      </h2>
      <div id={@id <> "-list"} phx-update="stream" class="divide-y divide-stone-300">
        <.link
          :for={{id, page} <- @pages}
          id={id}
          href={~p"/questions/#{page.slug}"}
          class="block py-4 text-teal-900 hover:text-teal-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-teal-700"
        >
          <span class="block font-serif text-xl">{page.title}</span>
          <span class="mt-2 block max-w-3xl text-sm leading-6 text-slate-600">{String.slice(
            page.summary,
            0,
            220
          )}</span>
          <span class="mt-2 inline-flex items-center gap-2 text-sm font-semibold">Read the answer and explore the evidence
          <.icon name="hero-arrow-right" class="h-4 w-4" /></span>
        </.link>
      </div>
    </section>
    """
  end
end
