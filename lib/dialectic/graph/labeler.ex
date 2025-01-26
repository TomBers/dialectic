defmodule Labeler do
  # Define our allowed letters (excluding B, C, and S)
  @allowed_letters ~w(A D E F G H I J K L M N O P Q R T U V W X Y Z)s
  # Precompute all 2-letter prefixes in a list

  def prefixes do
    for a <- @allowed_letters, b <- @allowed_letters, do: String.downcase(a <> b)
  end

  @doc """
  Returns the custom label for the nth item.

  1..9 => "1".."9"
  10..4770 => two-letter prefix (skipping B, C, S) + digit
  """
  def label(n) when n < 1 or n > 4770 do
    raise ArgumentError,
          "Label out of range. Must be between 1 and 4770 (inclusive). Got: #{n}"
  end

  def label(n) when n >= 1 and n <= 9 do
    # For 1..9, just return that digit as a string
    Integer.to_string(n)
  end

  def label(n) do
    # For 10..4770, calculate which prefix + digit
    # zero-based offset for all 2-letter+digit labels
    offset = n - 10
    prefix_index = div(offset, 9)
    digit_index = rem(offset, 9)

    prefix = Enum.at(prefixes(), prefix_index)
    digit = Integer.to_string(digit_index + 1)

    prefix <> digit
  end
end
