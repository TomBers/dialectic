defmodule Dialectic.LLM.Providers.GoogleTest do
  use ExUnit.Case, async: true

  alias Dialectic.LLM.Providers.Google

  describe "Google provider configuration" do
    test "returns google as provider id" do
      assert Google.id() == :google
    end

    test "returns gemini-3-flash-preview as model" do
      assert Google.model() == "gemini-3-flash-preview"
    end

    test "returns GOOGLE_API_KEY from environment" do
      # API key should be nil or a string depending on environment
      api_key = Google.api_key()
      assert is_nil(api_key) or is_binary(api_key)
    end
  end

  describe "thinking level configuration" do
    test "defaults to 'low' (2048 tokens) when GEMINI_THINKING_LEVEL is not set" do
      # Clear any existing env var
      System.delete_env("GEMINI_THINKING_LEVEL")

      provider_options = Google.provider_options()

      assert Keyword.has_key?(provider_options, :google_thinking_budget)
      assert provider_options[:google_thinking_budget] == 2048
    end

    test "uses minimal thinking budget (512) when GEMINI_THINKING_LEVEL is set to 'minimal'" do
      System.put_env("GEMINI_THINKING_LEVEL", "minimal")

      provider_options = Google.provider_options()

      assert provider_options[:google_thinking_budget] == 512

      # Clean up
      System.delete_env("GEMINI_THINKING_LEVEL")
    end

    test "uses low thinking budget (2048) when GEMINI_THINKING_LEVEL is set to 'low'" do
      System.put_env("GEMINI_THINKING_LEVEL", "low")

      provider_options = Google.provider_options()

      assert provider_options[:google_thinking_budget] == 2048

      # Clean up
      System.delete_env("GEMINI_THINKING_LEVEL")
    end

    test "uses medium thinking budget (8192) when GEMINI_THINKING_LEVEL is set to 'medium'" do
      System.put_env("GEMINI_THINKING_LEVEL", "medium")

      provider_options = Google.provider_options()

      assert provider_options[:google_thinking_budget] == 8192

      # Clean up
      System.delete_env("GEMINI_THINKING_LEVEL")
    end

    test "uses dynamic thinking budget (-1) when GEMINI_THINKING_LEVEL is set to 'high'" do
      System.put_env("GEMINI_THINKING_LEVEL", "high")

      provider_options = Google.provider_options()

      assert provider_options[:google_thinking_budget] == -1

      # Clean up
      System.delete_env("GEMINI_THINKING_LEVEL")
    end

    test "falls back to low (2048) for unknown thinking level values" do
      System.put_env("GEMINI_THINKING_LEVEL", "invalid")

      provider_options = Google.provider_options()

      assert provider_options[:google_thinking_budget] == 2048

      # Clean up
      System.delete_env("GEMINI_THINKING_LEVEL")
    end

    test "provider_options returns a keyword list with google_thinking_budget" do
      provider_options = Google.provider_options()

      assert is_list(provider_options)
      assert Keyword.keyword?(provider_options)
      assert Keyword.has_key?(provider_options, :google_thinking_budget)
    end

    test "google_thinking_budget is an integer" do
      provider_options = Google.provider_options()
      thinking_budget = provider_options[:google_thinking_budget]

      assert is_integer(thinking_budget)
    end
  end
end
