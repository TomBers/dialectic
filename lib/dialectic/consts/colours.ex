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

  def get_tailwind_class(class) do
    case class do
      "user" -> "border-l-4 border-red-400 bg-white"
      "answer" -> "border-l-4 border-green-400 bg-white"
      "thesis" -> "border-l-4 border-green-600 bg-white"
      "antithesis" -> "border-l-4 border-blue-600 bg-white"
      "synthesis" -> "border-l-4 border-purple-600 bg-white"
      _ -> "border border-gray-200 bg-white"
    end
  end
end
