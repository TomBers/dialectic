defmodule DialecticWeb.ComponentsSmokeTest do
  use DialecticWeb.ConnCase, async: true

  @moduledoc """
  Basic smoke tests for component modules to ensure they are compiled.
  Keeping this intentionally minimal to avoid brittleness.
  """

  @action_toolbar_mod DialecticWeb.ActionToolbarComp
  @node_menu_mod DialecticWeb.NodeMenuComp

  describe "ActionToolbarComp smoke" do
    test "module loads" do
      assert Code.ensure_loaded?(@action_toolbar_mod)
    end
  end

  describe "NodeMenuComp smoke" do
    test "module loads" do
      assert Code.ensure_loaded?(@node_menu_mod)
    end
  end
end
