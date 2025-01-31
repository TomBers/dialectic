defmodule Dialectic.Consts.Colours do
  def graph_cols do
    %{
      thesis: %{
        border: "#34d399",
        background: "#f0fdf4"
      },
      antithesis: %{
        border: "#60a5fa",
        background: "#eff6ff"
      },
      synthesis: %{
        border: "#c084fc",
        background: "#faf5ff"
      },
      answer: %{
        border: "#4ade80",
        background: "#f0fdf4"
      },
      user: %{
        border: "#f87171",
        background: "#fef2f2"
      }
    }
  end

  # For some reason this doens't work, but does work as a func in the comp!!
  # def get_tailwind_class(class) do
  #   case class do
  #     "user" -> "border-red-400"
  #     "answer" -> "border-green-400"
  #     "thesis" -> "border-green-600"
  #     "antithesis" -> "border-blue-600"
  #     "synthesis" -> "border-purple-600"
  #     _ -> "border-gray-200"
  #   end
  # end
end
