defmodule DialecticWeb.ContentPanelComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.Live.TextUtils

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:content_mode, fn -> "conversation" end)
      |> assign_new(:conv_path, fn -> [] end)
      |> assign_new(:node, fn -> %{} end)
      |> assign_new(:ask_question, fn -> true end)
      |> assign_new(:sending_message, fn -> false end)
      |> assign_new(:form, fn -> nil end)
      |> assign_new(:user, fn -> nil end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:graph_id, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <div class="flex items-center justify-end gap-2 px-2 py-2 border-b border-gray-200">
        <button
          type="button"
          phx-click="set_content_mode"
          phx-value-mode="conversation"
          class={[
            "inline-flex items-center gap-1 px-2 py-1 rounded-md border text-xs",
            @content_mode == "conversation" &&
              "bg-indigo-50 text-indigo-700 border-indigo-200",
            @content_mode != "conversation" &&
              "bg-white text-gray-700 border-gray-200 hover:bg-gray-50"
          ]}
          title="Conversation view"
          aria-label="Conversation view"
        >
          <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
          <span class="hidden sm:inline">Conversation</span>
        </button>
        <button
          type="button"
          phx-click="set_content_mode"
          phx-value-mode="discrete"
          class={[
            "inline-flex items-center gap-1 px-2 py-1 rounded-md border text-xs",
            @content_mode == "discrete" && "bg-indigo-50 text-indigo-700 border-indigo-200",
            @content_mode != "discrete" &&
              "bg-white text-gray-700 border-gray-200 hover:bg-gray-50"
          ]}
          title="Discrete view"
          aria-label="Discrete view"
        >
          <.icon name="hero-document-text" class="h-4 w-4" />
          <span class="hidden sm:inline">Discrete</span>
        </button>
      </div>

      <%= if @content_mode == "conversation" do %>
        <div
          class="chat-messages flex-1 overflow-y-auto overflow-x-hidden scroll-smooth pt-2 pb-4 px-3 sm:px-4 md:px-6"
          id="chat-messages"
          phx-hook="ChatScroll"
        >
          <%= for {node, _idx} <- Enum.with_index(@conv_path || []) |> Enum.filter(fn {n, _} -> (n.content || "") != "" end) do %>
            <div
              class={message_wrapper_class(node.class)}
              id={"conv-com-" <> node.id}
              phx-hook="TextSelectionHook"
              data-node-id={@node && @node.id}
            >
              <div class="message-bubble max-w-[92vw] sm:max-w-[80%]">
                <div class="message-content">
                  <div class={article_classes(userish?(node.class))}>
                    <h3 class={heading_classes(userish?(node.class))}>
                      {TextUtils.render_content(node.content || "") |> Map.get(:title)}
                    </h3>
                    {TextUtils.render_content(node.content || "") |> Map.get(:body_html)}
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <%= if @sending_message do %>
            <div class="message-wrapper assistant">
              <div class="message-bubble typing max-w-[92vw] sm:max-w-[80%]">
                <div class="typing-indicator">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
                <div class="message-meta flex items-center">
                  <span class="typing-text text-gray-500 text-xs">AI is thinking...</span>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div
          class="flex-1 overflow-y-auto scroll-smooth pt-2 pb-4 px-3 sm:px-4 md:px-6"
          id="content-messages"
        >
          <%= if @node && String.length(@node.content || "") > 0 do %>
            <div class="w-full min-w-full text-base sm:text-lg p-2" id={"discrete-node-" <> @node.id}>
              <article class="prose prose-stone prose-lg md:prose-xl max-w-none selection-content w-full prose-headings:mt-0 prose-p:leading-relaxed prose-li:leading-relaxed">
                <h3 class="mt-0 text-lg sm:text-xl md:text-2xl mb-2 sm:mb-3 pb-2 border-b border-gray-200">
                  {TextUtils.render_content(@node.content || "") |> Map.get(:title)}
                </h3>
                {TextUtils.render_content(@node.content || "") |> Map.get(:body_html)}
              </article>
            </div>
          <% else %>
            <div class="node mb-2 p-4">
              <div class="flex flex-col space-y-4 animate-pulse">
                <div class="h-6 bg-gray-200 rounded-md w-3/4"></div>
                <div class="space-y-2">
                  <div class="h-4 bg-gray-200 rounded-md w-full"></div>
                  <div class="h-4 bg-gray-200 rounded-md w-5/6"></div>
                  <div class="h-4 bg-gray-200 rounded-md w-4/6"></div>
                </div>
                <div class="flex items-center space-x-2 mt-2">
                  <div class="h-8 w-8 bg-gray-200 rounded-full"></div>
                  <div class="h-3 bg-gray-200 rounded-md w-24"></div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <div class="border-t border-gray-200 px-3 py-2">
        <div class="flex items-center gap-2">
          <div class="flex items-center gap-1">
            <button
              type="button"
              phx-click="toggle_ask_question"
              class={"px-2 py-1 text-xs rounded-full " <> if @ask_question, do: "bg-blue-50 text-blue-600 border border-blue-200", else: "text-gray-600 hover:bg-gray-50 border border-transparent"}
            >
              Ask
            </button>
            <button
              type="button"
              phx-click="toggle_ask_question"
              class={"px-2 py-1 text-xs rounded-full " <> if !@ask_question, do: "bg-emerald-50 text-emerald-600 border border-emerald-200", else: "text-gray-600 hover:bg-gray-50 border border-transparent"}
            >
              Comment
            </button>
          </div>

          <.form
            for={@form}
            phx-submit={if @ask_question, do: "reply-and-answer", else: "answer"}
            id={"content-panel-chat-form-" <> to_string(@node.id || "root")}
            class="flex-1 relative"
          >
            <div class="relative">
              <.input
                field={@form[:content]}
                type="text"
                id={"content-panel-chat-input-" <> to_string(@node.id || "root")}
                placeholder={if @ask_question, do: "Ask a question…", else: "Add a comment…"}
                class="w-full rounded-full pl-3 pr-24 border-gray-300 focus:border-indigo-400 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              />
              <button
                type="submit"
                class="absolute right-1 top-1/2 -translate-y-1/2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm px-3 py-1.5 rounded-full font-medium"
              >
                {if @ask_question, do: "Ask", else: "Post"}
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  # Helpers

  defp message_wrapper_class(class) do
    base = "message-wrapper relative group"
    role = if userish?(class), do: "user", else: "assistant"
    "#{base} #{role}"
  end

  defp article_classes(is_userish) do
    base =
      "overflow-x-auto break-words prose prose-stone prose-sm sm:prose-base md:prose max-w-none " <>
        "prose-headings:mt-0 prose-pre:bg-gray-900 prose-pre:text-white prose-code:text-rose-600"

    if is_userish, do: base <> " prose-invert", else: base
  end

  defp heading_classes(is_userish) do
    base = "mt-0 text-base sm:text-lg md:text-xl mb-1 sm:mb-2 pb-1 border-b"
    if is_userish, do: base <> " border-white/70", else: base <> " border-gray-200/70"
  end

  defp userish?(class) do
    case class do
      c when c in ["user", "question", "origin"] -> true
      _ -> false
    end
  end
end
