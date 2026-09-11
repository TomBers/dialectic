defmodule DialecticWeb.ReadingStyles do
  @moduledoc false

  def reading_style(user) do
    preferences = Dialectic.Accounts.User.appearance_preferences(user)

    case {preferences.reading_font, preferences.reading_density} do
      {"serif", "comfortable"} -> "book"
      {"sans", "comfortable"} -> "screen"
      {"sans", "large"} -> "large_print"
      {"sans", "compact"} -> "compact"
      _ -> "custom"
    end
  end

  def apply_reading_style(params) do
    case params["reading_style"] do
      "book" ->
        {"book",
         Map.merge(params, %{"reading_font" => "serif", "reading_density" => "comfortable"})}

      "screen" ->
        {"screen",
         Map.merge(params, %{"reading_font" => "sans", "reading_density" => "comfortable"})}

      "compact" ->
        {"compact",
         Map.merge(params, %{"reading_font" => "sans", "reading_density" => "compact"})}

      "large_print" ->
        {"large_print",
         Map.merge(params, %{"reading_font" => "sans", "reading_density" => "large"})}

      _ ->
        {"custom", params}
    end
  end
end
