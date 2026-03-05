defmodule Dialectic.Accounts.GravatarCacheTest do
  use ExUnit.Case, async: false

  alias Dialectic.Accounts.GravatarCache

  @empty_profile %{avatar_url: nil, header_image_url: nil, verified_accounts: [], location: nil}

  setup do
    # Ensure the cache is clean before each test
    GravatarCache.clear()
    :ok
  end

  describe "fetch/1" do
    test "returns empty profile data for nil or blank input" do
      assert {:ok, @empty_profile} = GravatarCache.fetch(nil)
      assert {:ok, @empty_profile} = GravatarCache.fetch("")
    end

    test "returns data for a valid gravatar_id (cache miss hits API)" do
      # We can't control the external API in unit tests, but we can verify
      # the function returns {:ok, map} with the expected shape
      {:ok, data} = GravatarCache.fetch("nonexistent-slug-that-wont-exist-xyz123")

      assert is_map(data)
      assert Map.has_key?(data, :avatar_url)
      assert Map.has_key?(data, :header_image_url)
      assert Map.has_key?(data, :verified_accounts)
      assert Map.has_key?(data, :location)
    end
  end

  describe "invalidate/1" do
    test "returns :ok for nil or blank input" do
      assert :ok = GravatarCache.invalidate(nil)
      assert :ok = GravatarCache.invalidate("")
    end

    test "returns :ok for a valid gravatar_id" do
      assert :ok = GravatarCache.invalidate("some-id")
    end

    test "removes a cached entry so the next fetch is a cache miss" do
      # Manually insert an entry into the ETS table to simulate a cache hit
      now = System.monotonic_time(:millisecond)

      fake_data = %{
        avatar_url: "https://example.com/avatar.jpg",
        header_image_url: nil,
        verified_accounts: [],
        location: nil
      }

      :ets.insert(:gravatar_cache, {"test-invalidate-id", fake_data, now})

      # Verify it's cached
      {:ok, cached} = GravatarCache.fetch("test-invalidate-id")
      assert cached.avatar_url == "https://example.com/avatar.jpg"

      # Invalidate
      assert :ok = GravatarCache.invalidate("test-invalidate-id")

      # The entry should be gone — next fetch will hit the API
      # and return empty data for a nonexistent slug
      {:ok, fresh} = GravatarCache.fetch("test-invalidate-id")
      assert fresh.avatar_url == nil
    end
  end

  describe "clear/0" do
    test "removes all cached entries" do
      now = System.monotonic_time(:millisecond)

      fake_data = %{
        avatar_url: "https://example.com/avatar1.jpg",
        header_image_url: nil,
        verified_accounts: [],
        location: nil
      }

      :ets.insert(:gravatar_cache, {"clear-id-1", fake_data, now})
      :ets.insert(:gravatar_cache, {"clear-id-2", fake_data, now})

      assert :ets.info(:gravatar_cache, :size) >= 2

      GravatarCache.clear()

      assert :ets.info(:gravatar_cache, :size) == 0
    end
  end

  describe "cache hit behavior" do
    test "serves cached data without re-fetching when TTL is not expired" do
      now = System.monotonic_time(:millisecond)

      fake_data = %{
        avatar_url: "https://example.com/cached-avatar.jpg",
        header_image_url: "https://example.com/cached-header.jpg",
        verified_accounts: [
          %{
            service_type: "github",
            service_label: "GitHub",
            service_icon: "https://example.com/gh.png",
            url: "https://github.com/test"
          }
        ],
        location: "London"
      }

      :ets.insert(:gravatar_cache, {"cached-slug", fake_data, now})

      {:ok, result} = GravatarCache.fetch("cached-slug")

      assert result.avatar_url == "https://example.com/cached-avatar.jpg"
      assert result.header_image_url == "https://example.com/cached-header.jpg"
      assert length(result.verified_accounts) == 1
      assert result.location == "London"
    end

    test "treats entry with nil avatar_url as cache miss" do
      now = System.monotonic_time(:millisecond)

      empty_data = %{
        avatar_url: nil,
        header_image_url: nil,
        verified_accounts: [],
        location: nil
      }

      :ets.insert(:gravatar_cache, {"empty-cached-slug", empty_data, now})

      # Even though there's a cached entry, avatar_url is nil so it should
      # attempt a fresh fetch (which will also return nil for nonexistent slugs)
      {:ok, result} = GravatarCache.fetch("empty-cached-slug")
      assert is_map(result)
    end

    test "serves stale data when TTL is expired but refresh fails" do
      # Insert an entry that's already expired (timestamp far in the past)
      stale_time = System.monotonic_time(:millisecond) - :timer.minutes(60)

      stale_data = %{
        avatar_url: "https://example.com/stale-avatar.jpg",
        header_image_url: nil,
        verified_accounts: [],
        location: nil
      }

      # Use a slug that won't exist on Gravatar so the refresh "fails"
      # (returns nil avatar_url, so it won't be cached)
      :ets.insert(:gravatar_cache, {"stale-nonexistent-xyz999", stale_data, stale_time})

      {:ok, result} = GravatarCache.fetch("stale-nonexistent-xyz999")

      # Should fall back to the stale data since the refresh returned nil avatar
      assert result.avatar_url == "https://example.com/stale-avatar.jpg"
    end
  end
end
