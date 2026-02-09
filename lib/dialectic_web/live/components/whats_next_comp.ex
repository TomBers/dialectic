defmodule DialecticWeb.WhatsNextComp do
  use DialecticWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="whats-next-panel"
      phx-hook="WhatsNext"
      class="hidden mb-4 rounded-lg bg-indigo-50 border border-indigo-100 p-4 relative shadow-sm"
    >
      <button
        type="button"
        class="absolute top-2 right-2 p-1 rounded-md text-indigo-400 hover:text-indigo-600 hover:bg-indigo-100 transition-colors"
        phx-click={JS.dispatch("dismiss", to: "#whats-next-panel")}
        aria-label="Dismiss"
      >
        <.icon name="hero-x-mark" class="w-4 h-4" />
      </button>

      <h3 class="font-semibold text-indigo-900 mb-2 flex items-center gap-2">
        <span class="text-xl">👋</span> What's Next?
      </h3>

      <ul class="space-y-3 text-sm text-indigo-800 mb-4 list-none">
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-blue-600 text-xs font-bold ring-2 ring-offset-2 ring-blue-500">
            1
          </span>
          <span><strong>Content</strong>: Read the focused node details here.</span>
        </li>
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-emerald-600 text-xs font-bold ring-2 ring-offset-2 ring-emerald-500">
            2
          </span>
          <span><strong>Ask / Comment</strong>: Chat with AI or add notes below.</span>
        </li>
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-orange-600 text-xs font-bold ring-2 ring-offset-2 ring-orange-500">
            3
          </span>
          <span><strong>Actions</strong>: Branch, explore related ideas, and compare pros/cons.</span>
        </li>
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-purple-600 text-xs font-bold ring-2 ring-offset-2 ring-purple-500">
            4
          </span>
          <span><strong>Tools</strong>: Star to save, Reader View, and Translation.</span>
        </li>
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-pink-600 text-xs font-bold ring-2 ring-offset-2 ring-pink-500">
            5
          </span>
          <span><strong>Settings</strong>: Access view options and highlights on the right.</span>
        </li>
      </ul>

      <div class="flex flex-wrap gap-2 text-sm">
        <button
          type="button"
          class="font-medium text-white bg-indigo-600 hover:bg-indigo-700 px-3 py-1.5 rounded-md shadow-sm transition-colors flex items-center gap-1"
          phx-click={JS.dispatch("trigger-related", to: "#whats-next-panel")}
        >
          Try "Related ideas"
        </button>

        <.link
          navigate={~p"/intro/how"}
          class="font-medium text-indigo-700 hover:text-indigo-900 px-3 py-1.5 rounded-md hover:bg-indigo-100 transition-colors"
        >
          Read the guide
        </.link>
      </div>
    </div>
    """
  end
end
