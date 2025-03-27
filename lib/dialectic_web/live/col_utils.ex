defmodule DialecticWeb.ColUtils do
  # Add this helper function to handle message border styling
  def message_border_class(class) do
    case class do
      # "user" -> "border-red-400"
      "answer" -> "border-blue-400"
      "thesis" -> "border-green-400"
      "antithesis" -> "border-red-400"
      "synthesis" -> "border-purple-600"
      _ -> "border border-gray-200 bg-white"
    end
  end
end
