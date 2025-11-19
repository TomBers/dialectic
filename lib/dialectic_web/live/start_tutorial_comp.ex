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
        <h2 class="mb-2">Getting Started:</h2>

        <ol class="list-decimal pl-6 space-y-2">
          <li>
            Ask a question in the box below to create your first node.
          </li>

          <li>
            Drag to pan, scroll or pinch to zoom. Click any node to center it. Use keyboard controls to move between nodes.
          </li>

          <li>
            Click a node and use the toolbar to add:
            <ul class="list-disc pl-6 mt-1">
              <li>Save (add to your saved notes)</li>
              <li>Reader (a distraction free view with readability controls)</li>
              <li>Related Ideas (adjacent concepts)</li>
              <li>Pros/Cons (compare arguments)</li>
              <li>Combine (merge with another node)</li>
              <li>Deep Dive (detailed exploration)</li>
              <li>Translate (open translation options)</li>
              <li>Explore (open a modal of key bullet points extracted from the node)</li>
              <li>Delete (remove this node)</li>
            </ul>
          </li>
        </ol>

        <div class="mt-8 flex items-center justify-center gap-3">
          <button
            type="button"
            class="inline-flex items-center gap-2 rounded-full bg-gradient-to-r from-fuchsia-500 via-rose-500 to-amber-500 px-5 py-2.5 text-white text-sm font-semibold shadow-md hover:shadow-lg hover:opacity-95 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-rose-300 transition"
            title="Inspire me"
            onclick="(async()=>{try{const r=await fetch('/api/random_question',{headers:{'Accept':'application/json'}});if(!r.ok)throw new Error('HTTP '+r.status);const d=await r.json();const q=(d&&d.question)||'';const el=document.getElementById('global-chat-input');if(el){el.value=q||el.value;el.focus();el.dispatchEvent(new Event('input',{bubbles:true}));}}catch(_e){const el=document.getElementById('global-chat-input');if(el){el.focus();}}})();"
          >
            Inspire me
          </button>
        </div>
      </article>
    </div>
    """
  end
end
