defmodule DialecticWeb.GenerationComponents do
  use DialecticWeb, :html

  attr :id, :string, required: true
  attr :status_id, :string, required: true
  attr :response_level, :string, default: nil
  attr :label, :string, default: "Generating response"
  attr :class, :string, default: nil
  slot :inner_block

  def response_placeholder(assigns) do
    ~H"""
    <div
      id={@id}
      role="status"
      class={[
        "relative overflow-hidden rounded-[1.75rem] border border-indigo-100 bg-gradient-to-br from-white via-indigo-50/70 to-sky-50/60 p-6 shadow-[0_24px_70px_rgba(79,70,229,0.14)] sm:p-8",
        @class
      ]}
    >
      <div class="pointer-events-none absolute -right-16 -top-16 h-44 w-44 rounded-full bg-indigo-200/40 blur-3xl">
      </div>
      <div class="pointer-events-none absolute -bottom-20 left-6 h-36 w-36 rounded-full bg-sky-200/30 blur-3xl">
      </div>

      <div class="relative space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div class="flex items-start gap-3">
            <span class="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-indigo-600 text-white shadow-lg shadow-indigo-200/80">
              <.icon name="hero-sparkles" class="h-5 w-5" />
            </span>
            <div class="min-w-0">
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-indigo-500">
                {@label}
              </p>
              <h3
                id={@status_id}
                phx-hook="GenerationStatus"
                phx-update="ignore"
                data-response-level={@response_level}
                class="mt-1 text-lg font-semibold tracking-tight text-slate-950 sm:text-xl"
              >
                <span data-generation-status>Preparing response</span>
              </h3>
            </div>
          </div>

          <div class="flex items-center gap-1.5 rounded-full border border-indigo-100 bg-white/80 px-3 py-1.5 shadow-sm backdrop-blur">
            <span class="text-xs font-medium text-indigo-700">Thinking</span>
            <.thinking_dots />
          </div>
        </div>

        <%!-- Animated shimmer skeleton lines --%>
        <div
          aria-hidden="true"
          class="rounded-2xl border border-white/70 bg-white/65 p-4 shadow-inner shadow-indigo-100/40 backdrop-blur-sm"
        >
          <div class="space-y-4">
            <div class="motion-reduce:animate-none h-5 rounded-md w-3/4 bg-gradient-to-r from-indigo-100/70 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_infinite]">
            </div>
            <div class="space-y-2.5">
              <div class="motion-reduce:animate-none h-3.5 rounded-md w-full bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.1s_infinite]">
              </div>
              <div class="motion-reduce:animate-none h-3.5 rounded-md w-5/6 bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.2s_infinite]">
              </div>
              <div class="motion-reduce:animate-none h-3.5 rounded-md w-4/6 bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.3s_infinite]">
              </div>
            </div>
            <div class="space-y-2.5 pt-2">
              <div class="motion-reduce:animate-none h-3.5 rounded-md w-full bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.4s_infinite]">
              </div>
              <div class="motion-reduce:animate-none h-3.5 rounded-md w-2/3 bg-gradient-to-r from-slate-100 via-white to-indigo-100/70 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.5s_infinite]">
              </div>
            </div>
          </div>
        </div>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  def thinking_dots(assigns) do
    ~H"""
    <span aria-hidden="true" class="flex gap-0.5">
      <span class="motion-reduce:animate-none h-1.5 w-1.5 rounded-full bg-indigo-500 animate-[typing_1.4s_ease-in-out_infinite]"></span>
      <span class="motion-reduce:animate-none h-1.5 w-1.5 rounded-full bg-indigo-500 animate-[typing_1.4s_ease-in-out_-0.16s_infinite]"></span>
      <span class="motion-reduce:animate-none h-1.5 w-1.5 rounded-full bg-indigo-500 animate-[typing_1.4s_ease-in-out_-0.32s_infinite]"></span>
    </span>
    """
  end
end
