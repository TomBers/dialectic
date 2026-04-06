defmodule DialecticWeb.ComponentsSmokeTest do
  use DialecticWeb.ConnCase, async: true

  @moduledoc """
  Basic smoke tests for component modules to ensure they are compiled.
  Keeping this intentionally minimal to avoid brittleness.
  """

  @action_toolbar_mod DialecticWeb.ActionToolbarComp
  @document_menu_mod DialecticWeb.DocumentMenuComp

  describe "ActionToolbarComp smoke" do
    test "module loads" do
      assert Code.ensure_loaded?(@action_toolbar_mod)
    end
  end

  describe "DocumentMenuComp smoke" do
    test "module loads" do
      assert Code.ensure_loaded?(@document_menu_mod)
    end
  end
end
