defmodule DialecticWeb.OriginOnboardingComp do
  @moduledoc """
  A LiveComponent that renders onboarding instructions for the origin node.

  This component is displayed when users view the first node (id "1") of a grid,
  providing guidance on how to use RationalGrid's features.

  ## Required Assigns
  - `:id` - Component ID (required by LiveComponent)
  """
  use DialecticWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-6 rounded-xl bg-gradient-to-br from-indigo-50 via-white to-amber-50 border border-indigo-100 p-5 shadow-sm">
      <h4 class="font-bold text-gray-900 text-sm uppercase tracking-wider mb-3 flex items-center gap-2">
        <span class="text-lg">👋</span> Welcome to RationalGrid
      </h4>
      <p class="text-sm text-gray-700 mb-3">
        You're looking at the <strong>origin node</strong>
        of this grid — the starting point for exploring an idea. Unlike traditional chat, RationalGrid turns every response into a
        <strong>node</strong>
        in a visual knowledge grid that you can branch, connect, and explore in any direction.
      </p>
      <p class="text-sm text-gray-600 mb-4">
        <strong>How it works:</strong>
        Read this node, then use the <strong>Grid Tools</strong>
        below to expand the conversation. You can also type a follow-up question in the input box, or click any node on the graph (right side) to focus it.
      </p>

      <h5 class="font-bold text-gray-900 text-xs uppercase tracking-wider mb-3 flex items-center gap-2 pt-3 border-t border-gray-200">
        <span class="text-base">🛠️</span> Grid Tools
      </h5>
      <p class="text-xs text-gray-500 mb-3">
        These tools help you grow your grid in different ways:
      </p>
      <ul class="space-y-3 text-sm text-gray-700">
        <li class="flex gap-3 items-start">
          <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-gradient-to-r from-emerald-500 to-rose-500 text-white">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3.5 w-3.5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
              />
            </svg>
          </span>
          <span>
            <strong class="text-gray-900">Pro | Con</strong>
            — Generates two child nodes: one arguing <em>for</em>
            the current idea and one arguing <em>against</em>. Great for exploring both sides of any claim.
          </span>
        </li>
        <li class="flex gap-3 items-start">
          <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-violet-500 text-white">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3.5 w-3.5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0 0 12 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c1.01.143 2.01.317 3 .52m-3-.52 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.988 5.988 0 0 1-2.031.352 5.988 5.988 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L18.75 4.971Zm-16.5.52c.99-.203 1.99-.377 3-.52m0 0 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.989 5.989 0 0 1-2.031.352 5.989 5.989 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L5.25 4.971Z"
              />
            </svg>
          </span>
          <span>
            <strong class="text-gray-900">Blend</strong>
            — Select two nodes to synthesize into one. The AI finds common ground, contrasts, or creates a unified perspective from both ideas.
          </span>
        </li>
        <li class="flex gap-3 items-start">
          <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-orange-500 text-white">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3.5 w-3.5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
              />
            </svg>
          </span>
          <span>
            <strong class="text-gray-900">Related</strong>
            — Spawns new nodes with related concepts, questions, or angles you might not have considered. Expands your thinking in unexpected directions.
          </span>
        </li>
        <li class="flex gap-3 items-start">
          <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-gradient-to-r from-fuchsia-500 via-rose-500 to-amber-500 text-white">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3.5 w-3.5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z"
              />
            </svg>
          </span>
          <span>
            <strong class="text-gray-900">Explore</strong>
            — Takes every bullet point or key idea in the current node and creates a child node for each, letting you dive deep on multiple fronts at once.
          </span>
        </li>
        <li class="flex gap-3 items-start">
          <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-red-500/80 text-white">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-3.5 w-3.5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6M9 7h6m-7 0a1 1 0 01-1-1V5a1 1 0 011-1h2a2 2 0 012-2h0a2 2 0 012 2h2a1 1 0 011 1v1" />
            </svg>
          </span>
          <span>
            <strong class="text-gray-900">Delete</strong>
            — Removes a node you created (only works on leaf nodes with no children).
          </span>
        </li>
      </ul>
      <div class="mt-4 pt-3 border-t border-gray-200">
        <h5 class="font-bold text-gray-900 text-xs uppercase tracking-wider mb-3 flex items-center gap-2">
          <span class="text-base">✨</span> Pro Tip: Select Text for Precision
        </h5>
        <p class="text-xs text-gray-600 mb-3">
          Want to dive deeper into a specific phrase or concept? Simply
          <strong>select any text</strong>
          in a node and a menu appears with options to explore just that selection:
        </p>
        <%!-- Visual demonstration of text selection --%>
        <div class="rounded-lg bg-white border border-gray-200 p-3 mb-3 shadow-inner">
          <p class="text-sm text-gray-700 leading-relaxed">
            The theory of
            <span class="bg-blue-200 text-blue-900 px-0.5 rounded">
              cognitive dissonance
            </span>
            suggests that people experience discomfort when holding conflicting beliefs...
          </p>
          <%!-- Mock selection tooltip (non-interactive for demonstration) --%>
          <div
            class="mt-2 inline-flex items-center gap-1 bg-gray-800 text-white text-xs rounded-lg px-2 py-1.5 shadow-lg"
            aria-hidden="true"
          >
            <span class="flex items-center gap-1 px-2 py-0.5 rounded">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M8.625 12a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0H8.25m4.125 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0H12m4.125 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 0 1-2.555-.337A5.972 5.972 0 0 1 5.41 20.97a5.969 5.969 0 0 1-.474-.065 4.48 4.48 0 0 0 .978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25Z"
                />
              </svg>
              Ask
            </span>
            <span class="text-gray-500">|</span>
            <span class="flex items-center gap-1 px-2 py-0.5 rounded">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
                />
              </svg>
              Pro/Con
            </span>
            <span class="text-gray-500">|</span>
            <span class="flex items-center gap-1 px-2 py-0.5 rounded">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                />
              </svg>
              Related
            </span>
          </div>
        </div>
        <p class="text-xs text-gray-500">
          This lets you get <strong>precise, focused answers</strong>
          about specific terms, claims, or ideas without losing context from the original node.
        </p>
      </div>

      <div class="mt-4 pt-3 border-t border-gray-200 space-y-2">
        <p class="text-xs text-gray-500">
          💡 <strong>Quick Tips:</strong>
        </p>
        <ul class="text-xs text-gray-500 space-y-1 pl-4 list-disc">
          <li>
            <strong>Navigate:</strong>
            Drag to pan, scroll to zoom. Click any node on the graph to focus it.
          </li>
          <li>
            <strong>Star nodes</strong> you want to revisit — find them later in your profile.
          </li>
          <li>
            <strong>Share your grid</strong>
            with others — they can explore and add their own thoughts.
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
