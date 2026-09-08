defmodule Dialectic.Security.DecimalAdvisoryTest do
  use ExUnit.Case, async: true

  test "the audit exception is limited to the verified Hex release" do
    lock = Mix.Dep.Lock.read()
    decimal = Map.fetch!(lock, :decimal)

    assert Dialectic.MixProject.hex_config(lock) ==
             [ignore_advisories: ["EEF-CVE-2026-32686"]]

    for version <- ["2.4.1", "3.0.0", "3.1.0", "3.1.2", "4.0.0"] do
      assert Dialectic.MixProject.hex_config(%{decimal: put_elem(decimal, 2, version)}) == []
    end

    assert Dialectic.MixProject.hex_config(%{}) == []
    assert Dialectic.MixProject.hex_config(%{decimal: {:git, "example", "ref", []}}) == []
  end

  test "Decimal and Ecto reject oversized positive and negative exponents" do
    for value <- ["1e1000000000", "1e-1000000000", "1e" <> String.duplicate("9", 100)] do
      assert Decimal.parse(value) == :error
      assert Decimal.cast(value) == :error
      assert Ecto.Type.cast(:decimal, value) == :error
    end
  end

  test "ordinary decimal inputs remain supported" do
    expected = Decimal.new("123.45")
    assert Decimal.parse("123.45") == {expected, ""}
    assert Decimal.cast("123.45") == {:ok, expected}
    assert Ecto.Type.cast(:decimal, "123.45") == {:ok, expected}
  end
end
