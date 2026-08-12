defmodule DialecticWeb.InspirationLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "preference updates" do
    test "accepts nested preference params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inspiration")

      render_hook(view, "update_preferences", %{
        "preferences" => %{"reality" => "10", "timeframe" => "20", "depth" => "30"}
      })

      assert_slider_values(view, "10", "20", "30")
    end

    test "accepts flat preference params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inspiration")

      render_hook(view, "update_preferences", %{
        "reality" => "70",
        "timeframe" => "80",
        "depth" => "90"
      })

      assert_slider_values(view, "70", "80", "90")
    end
  end

  defp assert_slider_values(view, reality, timeframe, depth) do
    assert has_element?(
             view,
             ~s(input[name="preferences[reality]"][value="#{reality}"])
           )

    assert has_element?(
             view,
             ~s(input[name="preferences[timeframe]"][value="#{timeframe}"])
           )

    assert has_element?(
             view,
             ~s(input[name="preferences[depth]"][value="#{depth}"])
           )
  end
end
