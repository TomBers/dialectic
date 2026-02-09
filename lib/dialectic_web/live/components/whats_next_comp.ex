defmodule DialecticWeb.WhatsNextComp do
  use DialecticWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="WhatsNext"
      class="hidden mb-4 rounded-lg bg-indigo-50 border border-indigo-100 p-4 relative shadow-sm"
    >
      <button
        type="button"
        class="absolute top-2 right-2 p-1 rounded-md text-indigo-400 hover:text-indigo-600 hover:bg-indigo-100 transition-colors"
        phx-click={JS.dispatch("dismiss", to: "##{@id}")}
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
          <span>
            <strong>Content</strong>: The focused node. <strong>Select any text</strong>
            to instantly create related ideas, questions, or notes.
          </span>
        </li>
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-emerald-600 text-xs font-bold ring-2 ring-offset-2 ring-emerald-500">
            2
          </span>
          <span>
            <strong>Ask / Comment</strong>: Direct the conversation. Ask the AI to elaborate or add your own insights.
          </span>
        </li>
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-orange-600 text-xs font-bold ring-2 ring-offset-2 ring-orange-500">
            3
          </span>
          <span>
            <strong>Explore tools</strong>: Expand the discussion. Generate related ideas <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-orange-100 text-orange-600 align-text-bottom mx-0.5"><svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-3.5 h-3.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              ><path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
              /></svg></span>,
            compare pros/cons <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-gradient-to-r from-emerald-100 to-rose-100 text-emerald-700 align-text-bottom mx-0.5"><svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-3.5 h-3.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              ><path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
              /></svg></span>,
            or combine nodes <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-violet-100 text-violet-600 align-text-bottom mx-0.5"><svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-3.5 h-3.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              ><path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0 0 12 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c1.01.143 2.01.317 3 .52m-3-.52 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.988 5.988 0 0 1-2.031.352 5.988 5.988 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L18.75 4.971Zm-16.5.52c.99-.203 1.99-.377 3-.52m0 0 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.989 5.989 0 0 1-2.031.352 5.989 5.989 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L5.25 4.971Z"
              /></svg></span>.
          </span>
        </li>
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-purple-600 text-xs font-bold ring-2 ring-offset-2 ring-purple-500">
            4
          </span>
          <span>
            <strong>Reading & remembering</strong>: Save nodes
            <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-yellow-100 text-yellow-600 align-text-bottom mx-0.5">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-3.5 h-3.5"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z"
                  clip-rule="evenodd"
                />
              </svg>
            </span>
            to your collection, switch to linear reading mode <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-gray-100 text-gray-600 align-text-bottom mx-0.5"><svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-3.5 h-3.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              ><path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z"
              /></svg></span>,
            or translate content <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-gray-100 text-gray-600 align-text-bottom mx-0.5"><svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-3.5 h-3.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              ><circle cx="12" cy="12" r="9" /><path d="M3 12h18" /><path d="M12 3a15 15 0 0 1 0 18" /><path d="M12 3a15 15 0 0 0 0 18" /></svg></span>.
          </span>
        </li>
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-pink-600 text-xs font-bold ring-2 ring-offset-2 ring-pink-500">
            5
          </span>
          <span>
            <strong>Settings</strong>: Customize your view <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-gray-100 text-gray-600 align-text-bottom mx-0.5"><.icon
                name="hero-eye"
                class="w-3.5 h-3.5"
              /></span>,
            access saved highlights <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-gray-100 text-gray-600 align-text-bottom mx-0.5"><.icon
                name="hero-bookmark"
                class="w-3.5 h-3.5"
              /></span>,
            or adjust settings <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-gray-100 text-gray-600 align-text-bottom mx-0.5"><.icon
                name="hero-adjustments-horizontal"
                class="w-3.5 h-3.5"
              /></span>.
          </span>
        </li>
        <li class="flex gap-2 items-start">
          <span class="flex-none flex items-center justify-center w-5 h-5 rounded-full bg-white text-indigo-600 text-xs font-bold ring-2 ring-offset-2 ring-indigo-500">
            6
          </span>
          <span>
            <strong>Share</strong>: Invite others. Share the URL so many people can work on the same page at the same time <span class="inline-flex items-center justify-center p-0.5 rounded-sm bg-indigo-100 text-indigo-600 align-text-bottom mx-0.5"><svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-3.5 h-3.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              ><path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5"
              /></svg></span>.
          </span>
        </li>
      </ul>

      <div class="flex flex-wrap gap-2 text-sm">
        <button
          type="button"
          class="font-medium text-white bg-indigo-600 hover:bg-indigo-700 px-3 py-1.5 rounded-md shadow-sm transition-colors flex items-center gap-1"
          phx-click={JS.dispatch("trigger-related", to: "##{@id}")}
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
