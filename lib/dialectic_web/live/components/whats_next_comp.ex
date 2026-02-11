defmodule DialecticWeb.WhatsNextComp do
  use DialecticWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="WhatsNext"
      class="hidden mb-6 rounded-xl bg-zinc-50 border border-zinc-200 p-5 relative shadow-md"
    >
      <button
        type="button"
        class="absolute top-3 right-3 p-1 rounded-md text-zinc-400 hover:text-zinc-600 hover:bg-zinc-200 transition-colors"
        phx-click={JS.dispatch("dismiss", to: "##{@id}")}
        aria-label="Dismiss"
      >
        <.icon name="hero-x-mark" class="w-4 h-4" />
      </button>

      <h3 class="font-bold text-zinc-900 mb-4 flex items-center gap-2">
        <span class="text-xl">👋</span> What's Next?
      </h3>
      <p class="text-sm text-zinc-700 mb-6">
        New here? Dialectic helps you explore ideas by growing a shared graph of questions and answers. Start by reading the focused node, then ask, branch, or add your own take.
      </p>

      <div class="space-y-6 mb-6">
        <div>
          <h4 class="font-bold text-zinc-900 text-xs uppercase tracking-wider mb-2 border-b border-zinc-200 pb-1 ml-1">
            Reading & Personal
          </h4>
          <ul class="space-y-3 text-sm text-zinc-700 list-none pl-3">
            <li class="flex gap-2 items-start">
              <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-blue-600 text-xs font-bold ring-2 ring-offset-2 ring-blue-500">
                1
              </span>
              <span>
                <strong>Start here</strong>: highlight a sentence to spin off related ideas, questions, or notes.
              </span>
            </li>
            <li class="flex gap-2 items-start">
              <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-purple-600 text-xs font-bold ring-2 ring-offset-2 ring-purple-500">
                2
              </span>
              <span>
                <strong>Reading & personal tools</strong>: save favorites, switch to linear view, or translate what you’re reading.
              </span>
            </li>
          </ul>
        </div>

        <div>
          <h4 class="font-bold text-zinc-900 text-xs uppercase tracking-wider mb-2 border-b border-zinc-200 pb-1 ml-1">
            Exploring
          </h4>
          <ul class="space-y-3 text-sm text-zinc-700 list-none pl-3">
            <li class="flex gap-2 items-start">
              <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-emerald-600 text-xs font-bold ring-2 ring-offset-2 ring-emerald-500">
                3
              </span>
              <span>
                <strong>Ask / Comment</strong>: ask the AI to expand, or drop your own thought right into the graph.
              </span>
            </li>
            <li class="flex gap-2 items-start">
              <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-orange-600 text-xs font-bold ring-2 ring-offset-2 ring-orange-500">
                4
              </span>
              <span>
                <strong>Explore tools</strong>: pull related ideas, compare pros/cons, or combine nodes to go deeper.
              </span>
            </li>
          </ul>
        </div>

        <div>
          <h4 class="font-bold text-zinc-900 text-xs uppercase tracking-wider mb-2 border-b border-zinc-200 pb-1 ml-1">
            Collaborating & Settings
          </h4>
          <ul class="space-y-3 text-sm text-zinc-700 list-none pl-3">
            <li class="flex gap-2 items-start">
              <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-indigo-600 text-xs font-bold ring-2 ring-offset-2 ring-indigo-500">
                5
              </span>
              <span>
                <strong>Collaboration</strong>: share the link so others can jump in and build the graph with you.
              </span>
            </li>
            <li class="flex gap-2 items-start">
              <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-pink-600 text-xs font-bold ring-2 ring-offset-2 ring-pink-500">
                6
              </span>
              <span>
                <strong>Settings</strong>: tweak your view, jump to highlights, and adjust preferences anytime.
              </span>
            </li>
          </ul>
        </div>
      </div>

      <div class="flex flex-wrap gap-2 text-sm pl-3">
        <button
          type="button"
          class="font-medium text-white bg-zinc-900 hover:bg-zinc-700 px-4 py-2 rounded-lg shadow-sm transition-colors flex items-center gap-1"
          phx-click={JS.dispatch("trigger-related", to: "##{@id}")}
        >
          Try "Related ideas"
        </button>

        <.link
          navigate={~p"/intro/how"}
          class="font-medium text-zinc-700 hover:text-zinc-900 px-4 py-2 rounded-lg hover:bg-zinc-200 transition-colors"
        >
          Read the guide
        </.link>
      </div>
    </div>
    """
  end
end
