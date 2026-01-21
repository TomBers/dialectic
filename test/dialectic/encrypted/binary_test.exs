defmodule Dialectic.Encrypted.BinaryTest do
  use Dialectic.DataCase

  alias Dialectic.Encrypted.Binary

  describe "type/0" do
    test "returns :binary" do
      assert Binary.type() == :binary
    end
  end

  describe "cast/1" do
    test "casts binary values" do
      assert {:ok, "test"} = Binary.cast("test")
      assert {:ok, "secret_token"} = Binary.cast("secret_token")
    end

    test "casts nil" do
      assert {:ok, nil} = Binary.cast(nil)
    end

    test "rejects non-binary values" do
      assert :error = Binary.cast(123)
      assert :error = Binary.cast(%{})
      assert :error = Binary.cast([])
    end
  end

  describe "dump/1 and load/1" do
    setup do
      # Set up encryption key for tests
      Application.put_env(:dialectic, Dialectic.Encrypted.Binary,
        encryption_key: "test_key_for_encryption_#{System.unique_integer()}"
      )

      on_exit(fn ->
        Application.delete_env(:dialectic, Dialectic.Encrypted.Binary)
      end)

      :ok
    end

    test "encrypts and decrypts data correctly" do
      plaintext = "my_secret_oauth_token"

      # Dump should encrypt
      assert {:ok, encrypted} = Binary.dump(plaintext)
      assert is_binary(encrypted)
      refute encrypted == plaintext

      # Load should decrypt
      assert {:ok, decrypted} = Binary.load(encrypted)
      assert decrypted == plaintext
    end

    test "handles nil values" do
      assert {:ok, nil} = Binary.dump(nil)
      assert {:ok, nil} = Binary.load(nil)
    end

    test "encrypted data is different each time (uses different IV)" do
      plaintext = "same_token"

      assert {:ok, encrypted1} = Binary.dump(plaintext)
      assert {:ok, encrypted2} = Binary.dump(plaintext)

      # Even with same plaintext, encrypted values should differ due to random IV
      refute encrypted1 == encrypted2

      # But both should decrypt to the same value
      assert {:ok, ^plaintext} = Binary.load(encrypted1)
      assert {:ok, ^plaintext} = Binary.load(encrypted2)
    end

    test "rejects invalid encrypted data" do
      assert :error = Binary.load("not_encrypted_data")
      assert :error = Binary.load(<<1, 2, 3>>)
    end

    test "rejects non-binary values in dump" do
      assert :error = Binary.dump(123)
      assert :error = Binary.dump(%{})
    end

    test "works with empty strings" do
      assert {:ok, encrypted} = Binary.dump("")
      assert {:ok, ""} = Binary.load(encrypted)
    end

    test "works with long strings" do
      plaintext = String.duplicate("a", 1000)
      assert {:ok, encrypted} = Binary.dump(plaintext)
      assert {:ok, ^plaintext} = Binary.load(encrypted)
    end

    test "works with special characters and unicode" do
      plaintext = "Token™🔐密码"
      assert {:ok, encrypted} = Binary.dump(plaintext)
      assert {:ok, ^plaintext} = Binary.load(encrypted)
    end
  end

  describe "encryption key configuration" do
    test "raises when encryption key is not configured" do
      Application.delete_env(:dialectic, Dialectic.Encrypted.Binary)

      assert_raise RuntimeError, ~r/Encryption key not configured/, fn ->
        Binary.dump("test")
      end
    end
  end

  describe "integration with Ecto schema" do
    test "encrypted fields work in changeset operations" do
      # This test verifies that the encrypted type works with actual Ecto operations
      attrs = %{
        email: "oauth_test@example.com",
        provider: "google",
        provider_id: "test_123",
        provider_token: "access_token_abc",
        provider_refresh_token: "refresh_token_xyz"
      }

      # Set up encryption key
      Application.put_env(:dialectic, Dialectic.Encrypted.Binary,
        encryption_key: "test_key_#{System.unique_integer()}"
      )

      changeset =
        Dialectic.Accounts.User.oauth_registration_changeset(%Dialectic.Accounts.User{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :provider_token) == "access_token_abc"
      assert Ecto.Changeset.get_change(changeset, :provider_refresh_token) == "refresh_token_xyz"

      Application.delete_env(:dialectic, Dialectic.Encrypted.Binary)
    end
  end
end
