defmodule DialecticWeb.OriginOnboardingComp do
  @moduledoc """
  A LiveComponent that renders onboarding instructions for using a grid page.

  ## Required Assigns
  - `:id` - Component ID (required by LiveComponent)
  """
  use DialecticWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <h4 class="font-bold text-gray-900 text-sm uppercase tracking-wider mb-3 flex items-center gap-2">
        <span class="text-lg">👋</span> Welcome to RationalGrid
      </h4>
      <p class="text-sm text-gray-700 mb-3">
        You're exploring a <strong>box</strong>
        in this grid. Unlike a linear chat, RationalGrid turns each response into a
        <strong>box</strong>
        in a visual map you can branch, connect, and revisit from different angles.
      </p>
      <p class="text-sm text-gray-600 mb-4">
        <strong>How it works:</strong>
        Read the current box, then use <strong>Grid Tools</strong>
        to grow the discussion. You can also type in the bottom input to ask a question or post your own comment.
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
            <.icon name="hero-scale" class="h-3.5 w-3.5" />
          </span>
          <span>
            <strong class="text-gray-900">Add Pro/Con</strong>
            — Generates two child boxes: one arguing <em>for</em>
            the current idea and one arguing <em>against</em>. Great for exploring both sides of any claim.
          </span>
        </li>
        <li class="flex gap-3 items-start">
          <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-violet-500 text-white">
            <.icon name="hero-arrows-pointing-in" class="h-3.5 w-3.5" />
          </span>
          <span>
            <strong class="text-gray-900">Blend</strong>
            — Select two boxes to synthesize into one. The AI finds common ground, contrasts, or creates a unified perspective from both ideas.
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
            <strong class="text-gray-900">Find related</strong>
            — Spawns new boxes with related concepts, questions, or angles you might not have considered. Expands your thinking in unexpected directions.
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
            <strong class="text-gray-900">Expand box</strong>
            — Takes every bullet point or key idea in the current box and creates a child box for each, letting you dive deep on multiple fronts at once.
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
            <strong class="text-gray-900">Delete box</strong>
            — Removes a box you created (only works on leaf boxes with no children).
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
          in a box and a menu appears with options to explore just that selection:
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
              <.icon name="hero-scale" class="h-3 w-3" /> Add Pro/Con
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
              Find related
            </span>
          </div>
        </div>
        <p class="text-xs text-gray-500">
          This lets you get <strong>precise, focused answers</strong>
          about specific terms, claims, or ideas without losing context from the original box.
        </p>
      </div>

      <div class="mt-4 pt-3 border-t border-gray-200 space-y-2">
        <p class="text-xs text-gray-500">
          💡 <strong>Quick Tips:</strong>
        </p>
        <ul class="text-xs text-gray-500 space-y-1 pl-4 list-disc">
          <li>
            <strong>Navigate:</strong>
            Drag to pan, scroll to zoom. Click any box on the grid to focus it.
          </li>
          <li>
            <strong>Star boxes</strong> you want to revisit — find them later in your profile.
          </li>
          <li>
            <strong>Share your grid</strong>
            with others — they can explore and add their own thoughts.
          </li>
        </ul>
      </div>

      <h5 class="font-bold text-gray-900 text-xs uppercase tracking-wider mb-3 flex items-center gap-2 pt-3 border-t border-gray-200">
        <span class="text-base">🎨</span> Node Colors
      </h5>
      <p class="text-xs text-gray-500 mb-3">
        Each box type has a distinct color to help you navigate the grid:
      </p>
      <div class="grid grid-cols-2 gap-2.5">
        <div class="flex items-start gap-2">
          <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("question") <> " ring-sky-400"}>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-medium text-gray-800">
              {DialecticWeb.ColUtils.node_type_label("question")}
            </div>
            <div class="text-[10px] text-gray-500 leading-tight">Your questions</div>
          </div>
        </div>
        <div class="flex items-start gap-2">
          <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("user") <> " ring-green-400"}>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-medium text-gray-800">
              {DialecticWeb.ColUtils.node_type_label("user")}
            </div>
            <div class="text-[10px] text-gray-500 leading-tight">Your comments</div>
          </div>
        </div>
        <div class="flex items-start gap-2">
          <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("answer") <> " ring-gray-400"}>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-medium text-gray-800">
              {DialecticWeb.ColUtils.node_type_label("answer")}
            </div>
            <div class="text-[10px] text-gray-500 leading-tight">AI responses</div>
          </div>
        </div>
        <div class="flex items-start gap-2">
          <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("thesis") <> " ring-green-400"}>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-medium text-gray-800">
              {DialecticWeb.ColUtils.node_type_label("thesis")}
            </div>
            <div class="text-[10px] text-gray-500 leading-tight">Supporting points</div>
          </div>
        </div>
        <div class="flex items-start gap-2">
          <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("antithesis") <> " ring-red-400"}>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-medium text-gray-800">
              {DialecticWeb.ColUtils.node_type_label("antithesis")}
            </div>
            <div class="text-[10px] text-gray-500 leading-tight">Counterpoints</div>
          </div>
        </div>
        <div class="flex items-start gap-2">
          <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("synthesis") <> " ring-purple-400"}>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-medium text-gray-800">
              {DialecticWeb.ColUtils.node_type_label("synthesis")}
            </div>
            <div class="text-[10px] text-gray-500 leading-tight">Balanced views</div>
          </div>
        </div>
        <div class="flex items-start gap-2">
          <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("ideas") <> " ring-amber-400"}>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-medium text-gray-800">
              {DialecticWeb.ColUtils.node_type_label("ideas")}
            </div>
            <div class="text-[10px] text-gray-500 leading-tight">Related concepts</div>
          </div>
        </div>
      </div>

      <h5 class="font-bold text-gray-900 text-xs uppercase tracking-wider mb-3 flex items-center gap-2 pt-3 mt-4 border-t border-gray-200">
        <span class="text-base">⌨️</span> Keyboard Shortcuts
      </h5>
      <div class="space-y-1.5">
        <div class="flex items-center justify-between py-1">
          <span class="text-xs text-gray-600">Pan graph</span>
          <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
            Space + Drag
          </kbd>
        </div>
        <div class="flex items-center justify-between py-1">
          <span class="text-xs text-gray-600">Zoom</span>
          <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
            ⌘/Ctrl + Scroll
          </kbd>
        </div>
        <div class="flex items-center justify-between py-1">
          <span class="text-xs text-gray-600">Scroll pan</span>
          <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
            Scroll
          </kbd>
        </div>
        <div class="flex items-center justify-between py-1">
          <span class="text-xs text-gray-600">Parent/child</span>
          <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
            ↑ / ↓
          </kbd>
        </div>
        <div class="flex items-center justify-between py-1">
          <span class="text-xs text-gray-600">Prev/next</span>
          <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
            ← / →
          </kbd>
        </div>
        <div class="flex items-center justify-between py-1">
          <span class="text-xs text-gray-600">Expand children</span>
          <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
            E
          </kbd>
        </div>
        <div class="flex items-center justify-between py-1">
          <span class="text-xs text-gray-600">Collapse children</span>
          <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
            C
          </kbd>
        </div>
        <div class="flex items-center justify-between py-1">
          <span class="text-xs text-gray-600">Open node</span>
          <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
            Enter
          </kbd>
        </div>
      </div>
    </div>
    """
  end
end
