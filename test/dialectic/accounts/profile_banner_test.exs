defmodule Dialectic.Accounts.ProfileBannerTest do
  use ExUnit.Case, async: false

  alias Dialectic.Accounts.ProfileBanner

  @digested_banner_id "abstract-timekeeper-ba4dd5db8cf205ec5b0ee81a61517649"

  test "ignores Phoenix digested banner assets" do
    path = Path.join(File.cwd!(), "priv/static/images/profile-banners/#{@digested_banner_id}.svg")

    File.write!(path, ~S(<svg xmlns="http://www.w3.org/2000/svg"></svg>))
    on_exit(fn -> File.rm(path) end)

    ids = ProfileBanner.ids()
    options = ProfileBanner.options()

    assert "abstract-timekeeper" in ids
    refute @digested_banner_id in ids

    refute {"Abstract Timekeeper Ba4dd5db8cf205ec5b0ee81a61517649", @digested_banner_id} in options
  end
end
