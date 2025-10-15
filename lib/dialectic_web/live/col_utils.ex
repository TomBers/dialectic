defmodule DialecticWeb.ColUtils do
  # Add this helper function to handle message border styling
  def message_border_class(class) do
    case class do
      "user" -> "border-blue-200"
      "answer" -> "border-gray-200"
      "thesis" -> "border-green-400"
      "antithesis" -> "border-red-400"
      "synthesis" -> "border-purple-600"
      "question" -> "border-blue-200"
      "ideas" -> "border-orange-200"
      "deepdive" -> "border-cyan-500"
      _ -> "border-gray-200"
    end
  end
end
