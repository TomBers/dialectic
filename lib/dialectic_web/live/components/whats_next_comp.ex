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
      <p class="text-base text-zinc-700 mb-6">
        New here? Explore ideas by growing a shared whiteboard of questions and answers. Start by reading the focused node, then ask, branch, or add your own thoughts.
      </p>

      <div class="space-y-6 mb-6">
        <div>
          <h4 class="font-bold text-zinc-900 text-xs uppercase tracking-wider mb-2 border-b border-zinc-200 pb-1 ml-1">
            Star · Read · Share
          </h4>
          <ul class="space-y-3 text-base text-zinc-700 list-none pl-3">
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-yellow-500">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                  />
                </svg>
              </span>
              <span>
                <strong>Star</strong> — save nodes for later reference.
              </span>
            </li>
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-gray-700">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z"
                  />
                </svg>
              </span>
              <span>
                <strong>Read</strong>
                — open the linear reader to follow the conversation as a document.
              </span>
            </li>
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-indigo-500">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5"
                  />
                </svg>
              </span>
              <span>
                <strong>Share</strong>
                — share the link so others can jump in and build the graph with you.
              </span>
            </li>
          </ul>
        </div>

        <div>
          <h4 class="font-bold text-zinc-900 text-xs uppercase tracking-wider mb-2 border-b border-zinc-200 pb-1 ml-1">
            Ideas · Pro/Con · Combine · Explore · Delete
          </h4>
          <ul class="space-y-3 text-base text-zinc-700 list-none pl-3">
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-orange-500">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                  />
                </svg>
              </span>
              <span>
                <strong>Ideas</strong> — generate related thoughts branching from the focused node.
              </span>
            </li>
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-emerald-500">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
                  />
                </svg>
              </span>
              <span>
                <strong>Pro/Con</strong> — weigh both sides of an argument.
              </span>
            </li>
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-violet-500">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0 0 12 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c1.01.143 2.01.317 3 .52m-3-.52 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.988 5.988 0 0 1-2.031.352 5.988 5.988 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L18.75 4.971Zm-16.5.52c.99-.203 1.99-.377 3-.52m0 0 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.989 5.989 0 0 1-2.031.352 5.989 5.989 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L5.25 4.971Z"
                  />
                </svg>
              </span>
              <span>
                <strong>Combine</strong> — merge two nodes together.
              </span>
            </li>
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-fuchsia-500">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z"
                  />
                </svg>
              </span>
              <span>
                <strong>Explore</strong> — expand every point at once.
              </span>
            </li>
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-red-500">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6M9 7h6m-7 0a1 1 0 01-1-1V5a1 1 0 011-1h2a2 2 0 012-2h0a2 2 0 012 2h2a1 1 0 011 1v1" />
                </svg>
              </span>
              <span>
                <strong>Delete</strong> — remove a node you own (only when it has no children).
              </span>
            </li>
          </ul>
        </div>

        <div>
          <h4 class="font-bold text-zinc-900 text-xs uppercase tracking-wider mb-2 border-b border-zinc-200 pb-1 ml-1">
            Views · Highlights · Settings
          </h4>
          <ul class="space-y-3 text-base text-zinc-700 list-none pl-3">
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-sky-500">
                <.icon name="hero-eye" class="w-5 h-5" />
              </span>
              <span>
                <strong>Views</strong> — change the graph layout and navigation.
              </span>
            </li>
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-amber-500">
                <.icon name="hero-bookmark" class="w-5 h-5" />
              </span>
              <span>
                <strong>Highlights</strong> — review key moments in the graph.
              </span>
            </li>
            <li class="flex gap-2.5 items-start">
              <span class="flex-none w-6 h-6 flex items-center justify-center text-gray-600">
                <.icon name="hero-adjustments-horizontal" class="w-5 h-5" />
              </span>
              <span>
                <strong>Settings</strong> — adjust preferences, including Translate.
              </span>
            </li>
          </ul>
        </div>
      </div>

      <%!-- Footer actions removed to keep the node content visible --%>
    </div>
    """
  end
end
