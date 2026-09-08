defmodule DialecticWeb.KeyboardComponents do
  use DialecticWeb, :html

  attr :key, :string, default: "Enter"
  attr :modifier, :string, values: ["primary", "alt"], default: "primary"
  attr :shift, :boolean, default: false
  attr :dark, :boolean, default: false
  attr :prominent, :boolean, default: false

  def shortcut_keycap(assigns) do
    ~H"""
    <kbd
      aria-hidden="true"
      class={[
        "ml-1 inline-flex shrink-0 items-center rounded border border-b-2 font-mono font-medium leading-none shadow-sm",
        if(@prominent,
          do: "h-7 gap-1 px-2 text-sm",
          else: "h-5 gap-0.5 px-1 text-[11px]"
        ),
        if(@dark,
          do: "border-slate-500 bg-slate-800 text-slate-100",
          else: "border-slate-300 bg-white text-slate-700"
        )
      ]}
    >
      <span class="hidden [[data-shortcut-platform=mac]_&]:inline">{if(@modifier == "alt",
        do: "⌥",
        else: "⌘"
      )}</span>
      <span class="[[data-shortcut-platform=mac]_&]:hidden">{if(@modifier == "alt",
        do: "Alt",
        else: "Ctrl"
      )}</span>
      <.icon :if={@shift} name="hero-arrow-up" class={if(@prominent, do: "h-4 w-4", else: "h-3 w-3")} />
      <%= if @key == "Enter" do %>
        <.icon name="hero-arrow-uturn-left" class={if(@prominent, do: "h-4 w-4", else: "h-3 w-3")} />
      <% else %>
        {String.upcase(@key)}
      <% end %>
    </kbd>
    """
  end
end
