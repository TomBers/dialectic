defmodule DialecticWeb.NewIdeaLive do
  use DialecticWeb, :live_view

  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex
  alias DialecticWeb.Utils.UserUtils

  @impl true
  def mount(params, _session, socket) do
    user = UserUtils.current_identity(socket.assigns)
    initial_content = params["initial_prompt"]

    changeset =
      GraphActions.create_new_node(user)
      |> Vertex.changeset(if initial_content, do: %{content: initial_content}, else: %{})

    prompt_mode =
      case params do
        %{"mode" => mode} when is_binary(mode) ->
          case String.downcase(mode) do
            "creative" -> "creative"
            _ -> "structured"
          end

        _ ->
          "structured"
      end

    {:ok,
     assign(socket,
       page_title: "New Idea",
       user: user,
       form: to_form(changeset),
       prompt_mode: prompt_mode,
       ask_question: true,
       graph_id: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-4rem)] flex flex-col items-center justify-center overflow-hidden">
      <!-- Background Video with Overlay -->
      <div class="absolute inset-0 z-0">
        <video
          autoplay
          muted
          playsinline
          preload="none"
          class="absolute inset-0 h-full w-full object-cover opacity-40"
          aria-hidden="true"
        >
          <source src={~p"/images/FractalBranchingTree.mp4"} type="video/mp4" />
        </video>
        <div class="absolute inset-0 bg-gradient-to-r from-[#3a0ca3]/90 to-[#4361ee]/90 mix-blend-multiply">
        </div>
      </div>

      <div class="relative z-10 w-full max-w-2xl px-6 flex flex-col items-center space-y-8">
        <div class="text-center space-y-4">
          <h1 class="text-4xl font-bold tracking-tight text-white sm:text-5xl">
            Start a new thought process
          </h1>
          <p class="text-lg text-indigo-100">
            Ask a question or state a premise to begin exploring a new dialectic map.
          </p>
        </div>

        <div class="w-full bg-white/80 backdrop-blur-md rounded-2xl shadow-xl border border-gray-200 p-6">
          <.live_component module={DialecticWeb.NewIdeaFormComp} id="new-idea-form" form={@form} />
        </div>

        <div class="flex items-center gap-8 text-sm font-medium">
          <.link
            navigate={~p"/inspiration"}
            class="flex items-center gap-2 text-indigo-100 hover:text-white transition-colors group"
          >
            <span class="p-1.5 rounded-lg bg-indigo-500/30 group-hover:bg-indigo-500/50 transition-colors">
              <.icon name="hero-sparkles" class="w-4 h-4" />
            </span>
            Inspire me
          </.link>
          <.link
            navigate={~p"/intro/how"}
            class="flex items-center gap-2 text-indigo-100 hover:text-white transition-colors group"
          >
            <span class="p-1.5 rounded-lg bg-indigo-500/30 group-hover:bg-indigo-500/50 transition-colors">
              <.icon name="hero-book-open" class="w-4 h-4" />
            </span>
            Read the guide
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}}, socket) do
    title = sanitize_graph_title(answer)

    case Graphs.create_new_graph(title, socket.assigns[:user]) do
      {:ok, _graph} ->
        mode_q = socket.assigns[:prompt_mode] || "structured"

        {:noreply,
         socket
         |> redirect(to: ~p"/#{title}?node=1&ask=#{URI.encode_www_form(answer)}&mode=#{mode_q}")}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Error creating graph")}
    end
  end

  # Helpers

  defp sanitize_graph_title(title) do
    title
    |> String.slice(0, 100)
    |> String.trim()
    |> String.replace(~r/[^a-zA-Z0-9\s-_]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.downcase()
  end
end
