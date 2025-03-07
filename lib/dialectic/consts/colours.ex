defmodule Dialectic.Consts.Colours do
  def graph_cols do
    %{
      thesis: %{
        # Green
        border: "#4ade80",
        background: "white",
        text: "#4ade80"
      },
      antithesis: %{
        # Red
        border: "#f84b71",
        background: "white",
        text: "#f84b71"
      },
      synthesis: %{
        # Purple
        border: "#c084fc",
        background: "white",
        text: "#c084fc"
      },
      answer: %{
        # BLue
        border: "#60a5fa",
        background: "white",
        text: "#60a5fa"
      },
      user: %{
        border: "#d1d5db",
        background: "white",
        text: "#374151"
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
