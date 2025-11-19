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
          <div class="mb-2 text-sm font-semibold text-stone-700">Try one:</div>
          <div class="flex flex-wrap gap-2">
            <button
              type="button"
              class="rounded-full bg-stone-900/90 text-white text-xs px-3 py-1.5 hover:bg-stone-900 transition"
              onclick="(()=>{const el=document.getElementById('global-chat-input');if(el){el.value='Explain CRDTs in simple terms';el.focus();el.dispatchEvent(new Event('input',{bubbles:true}));}})();"
            >
              Explain CRDTs in simple terms
            </button>

            <button
              type="button"
              class="rounded-full bg-stone-900/90 text-white text-xs px-3 py-1.5 hover:bg-stone-900 transition"
              onclick="(()=>{const el=document.getElementById('global-chat-input');if(el){el.value='What are the tradeoffs of server-side rendering vs. client-side rendering?';el.focus();el.dispatchEvent(new Event('input',{bubbles:true}));}})();"
            >
              SSR vs CSR tradeoffs
            </button>

            <button
              type="button"
              class="rounded-full bg-stone-900/90 text-white text-xs px-3 py-1.5 hover:bg-stone-900 transition"
              onclick="(()=>{const el=document.getElementById('global-chat-input');if(el){el.value='Brainstorm 5 novel product ideas for mindful note-taking';el.focus();el.dispatchEvent(new Event('input',{bubbles:true}));}})();"
            >
              Brainstorm product ideas
            </button>

            <button
              type="button"
              class="rounded-full bg-stone-900/90 text-white text-xs px-3 py-1.5 hover:bg-stone-900 transition"
              onclick="(()=>{const el=document.getElementById('global-chat-input');if(el){el.value='Summarize the main arguments for and against universal basic income';el.focus();el.dispatchEvent(new Event('input',{bubbles:true}));}})();"
            >
              Summarize an argument
            </button>
          </div>
        </div>

        <div class="mt-6 flex items-center justify-center gap-3">
          <button
            type="button"
            class="inline-flex items-center gap-2 rounded-full bg-gradient-to-r from-fuchsia-500 via-rose-500 to-amber-500 px-5 py-2.5 text-white text-sm font-semibold shadow-md hover:shadow-lg hover:opacity-95 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-rose-300 transition"
            title="Inspire me"
            onclick="(async()=>{try{const r=await fetch('/api/random_question',{headers:{'Accept':'application/json'}});if(!r.ok)throw new Error('HTTP '+r.status);const d=await r.json();const q=(d&&d.question)||'';const el=document.getElementById('global-chat-input');if(el){el.value=q||el.value;el.focus();el.dispatchEvent(new Event('input',{bubbles:true}));}}catch(_e){const el=document.getElementById('global-chat-input');if(el){el.focus();}}})();"
          >
            Inspire me
          </button>
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
