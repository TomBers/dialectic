defmodule DialecticWeb.ReadingStylesTest do
  use ExUnit.Case, async: true

  alias Dialectic.Accounts.User
  alias DialecticWeb.ReadingStyles

  test "classifies missing and invalid preferences using the rendered defaults" do
    for value <- [nil, "", "invalid"] do
      assert ReadingStyles.reading_style(%User{reading_font: value, reading_density: value}) ==
               "book"

      assert ReadingStyles.reading_style(%User{reading_font: "sans", reading_density: value}) ==
               "screen"
    end

    assert ReadingStyles.reading_style(nil) == "book"
  end

  test "preserves valid presets and custom combinations" do
    for {font, density, style} <- [
          {"serif", "comfortable", "book"},
          {"sans", "comfortable", "screen"},
          {"sans", "large", "large_print"},
          {"sans", "compact", "compact"},
          {"serif", "large", "custom"},
          {"serif", "compact", "custom"}
        ] do
      assert ReadingStyles.reading_style(%User{reading_font: font, reading_density: density}) ==
               style
    end
  end
end
