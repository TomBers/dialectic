defmodule DialecticWeb.KeyboardComponents do
  use DialecticWeb, :html

  attr :key, :string, default: "Enter"
  attr :modifier, :string, values: ["primary", "alt"], default: "primary"
  attr :shift, :boolean, default: false
  attr :dark, :boolean, default: false
  attr :prominent, :boolean, default: false
  attr :quiet, :boolean, default: false
  attr :always_visible, :boolean, default: false

  def shortcut_keycap(assigns) do
    assigns =
      assigns
      |> assign(
        :mac_keys,
        Enum.join(
          Enum.reject(
            [
              if(assigns.modifier == "alt", do: "⌥", else: "⌘"),
              if(assigns.shift, do: "⇧"),
              if(assigns.key == "Enter", do: "↵", else: String.upcase(assigns.key))
            ],
            &is_nil/1
          ),
          " "
        )
      )
      |> assign(
        :other_keys,
        Enum.join(
          Enum.reject(
            [
              if(assigns.modifier == "alt", do: "Alt", else: "Ctrl"),
              if(assigns.shift, do: "Shift"),
              if(assigns.key == "Enter", do: "Enter", else: String.upcase(assigns.key))
            ],
            &is_nil/1
          ),
          "+"
        )
      )

    ~H"""
    <kbd
      aria-hidden="true"
      class={[
        "ml-1 shrink-0 items-center font-mono font-medium leading-none",
        if(@always_visible, do: "inline-flex", else: "hidden md:inline-flex"),
        if(@quiet,
          do:
            "text-slate-500 transition-colors group-hover/tool:text-slate-700 group-focus-visible/tool:text-slate-700",
          else: "rounded border border-b-2 shadow-sm"
        ),
        if(@prominent,
          do: "h-7 gap-1 px-2 text-sm",
          else: "h-5 gap-0.5 px-1 text-[11px]"
        ),
        !@quiet &&
          if(@dark,
            do: "border-slate-500 bg-slate-800 text-slate-100",
            else: "border-slate-300 bg-white text-slate-700"
          )
      ]}
    >
      <span data-shortcut-label="mac">{@mac_keys}</span>
      <span data-shortcut-label="other">{@other_keys}</span>
    </kbd>
    """
  end
end
