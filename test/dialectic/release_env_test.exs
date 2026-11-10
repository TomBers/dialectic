defmodule Dialectic.ReleaseEnvTest do
  use ExUnit.Case, async: true

  @script Path.expand("../../rel/env.sh.eex", __DIR__)

  test "release node names are independent of image tags and digests" do
    for image <- [
          "registry.fly.io/mudg:deployment-01M61V5T5AQMM0DWJM6D7DZVYZ",
          "registry.fly.io/mudg:mcp-integrated-20261110-v2",
          "registry.fly.io/mudg@sha256:" <> String.duplicate("a", 64),
          nil
        ] do
      assert release_node("e829429c060298", image) ==
               "mudg-e829429c060298@fdaa:0:2d4a:a7b:4a3:bf1:77b4:2"
    end
  end

  test "each machine has a distinct node name" do
    refute release_node("machine-one", "shared-image") ==
             release_node("machine-two", "shared-image")
  end

  test "non-Fly environments fall back to the hostname" do
    assert release_node(nil, "registry.fly.io/mudg@sha256:digest") ==
             "mudg-container-host@fdaa:0:2d4a:a7b:4a3:bf1:77b4:2"
  end

  defp release_node(machine_id, image) do
    {name, 0} =
      System.cmd("sh", ["-c", ~S(. "$1"; printf '%s' "$RELEASE_NODE"), "release-env", @script],
        env: [
          {"FLY_APP_NAME", "mudg"},
          {"FLY_MACHINE_ID", machine_id},
          {"FLY_PRIVATE_IP", "fdaa:0:2d4a:a7b:4a3:bf1:77b4:2"},
          {"FLY_IMAGE_REF", image},
          {"HOSTNAME", "container-host"}
        ]
      )

    name
  end
end
