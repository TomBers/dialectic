defmodule DialecticWeb.StartTutorialComp do
  @moduledoc """
  A simple, easily editable LiveComponent that renders the placeholder content
  shown on a brand-new (blank) graph.

  Usage (in a LiveView or another component):

      <.live_component module={DialecticWeb.StartTutorialComp} id="start-tutorial" />

  You can freely edit the HTML below to adjust copy, layout, and images.
  """
  use DialecticWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, Map.new(assigns))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full h-full">
      <article class="prose prose-stone prose-md max-w-none px-4 sm:px-6 md:px-8 py-4">
        <h2 class="mb-2 flex items-center gap-2">
          <.icon name="hero-sparkles" class="w-5 h-5 text-amber-500" />
          Welcome! Let’s build your first idea map
        </h2>

        <p class="text-stone-600">
          Start with a single question or thought. We’ll turn it into a node you can expand,
          connect, and explore.
        </p>

        <ol class="list-decimal pl-6 space-y-2">
          <li>Type a question in the box below to create your first node.</li>
          <li>Drag to pan, scroll or pinch to zoom. Click any node to center it.</li>
          <li>
            Open a node’s toolbar to Save, Read, Explore related ideas, compare Pros/Cons, Translate, Combine, Deep Dive, or Delete.
          </li>
        </ol>

        <div class="mt-6">
          <p class="text-sm text-stone-700">
            Not sure where to start? <span class="font-semibold">Click “Inspire me”</span>
            below for a fresh starter question.
          </p>
        </div>

        <div class="mt-6 flex flex-col items-center justify-center gap-2">
          <.link
            navigate={~p"/inspiration"}
            class="inline-flex items-center gap-2 rounded-full bg-gradient-to-r from-fuchsia-500 via-rose-500 to-amber-500 px-5 py-2.5 text-white text-sm font-semibold shadow-md hover:shadow-lg hover:opacity-95 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-rose-300 transition"
            title="Inspire me"
          >
            Inspire me
          </.link>
        </div>

        <div class="mt-8 rounded-xl border border-stone-200 bg-stone-50 p-4 text-sm">
          <div class="font-semibold mb-1">Tips</div>
          <ul class="list-disc pl-5 space-y-1 text-stone-700">
            <li>Drag to pan, scroll or pinch to zoom.</li>
            <li>Click any node to center it.</li>
            <li>Use keyboard controls to move between nodes.</li>
            <li>
              Use the node toolbar to Save, Read, Explore related ideas, compare Pros/Cons, Translate, Combine, Deep Dive, or Delete.
            </li>
          </ul>
        </div>
      </article>
    </div>
    """
  end
end
