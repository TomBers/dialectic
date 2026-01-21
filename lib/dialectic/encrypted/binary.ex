defmodule Dialectic.Encrypted.Binary do
  @moduledoc """
  An Ecto type for encrypting/decrypting binary data at rest.

  This type encrypts data before storing it in the database and decrypts it when loading.
  It uses AES-256-GCM encryption for secure storage of sensitive data like OAuth tokens.

  ## Usage

      schema "users" do
        field :provider_token, Dialectic.Encrypted.Binary
        field :provider_refresh_token, Dialectic.Encrypted.Binary
      end

  ## Configuration

  The encryption key must be set in your runtime configuration:

      config :dialectic, Dialectic.Encrypted.Binary,
        encryption_key: System.fetch_env!("ENCRYPTION_KEY")

  Generate a secure encryption key with:

      mix phx.gen.secret 32

  """

  use Ecto.Type

  def type, do: :binary

  @doc """
  Casts the value to a string for changeset operations.
  """
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @doc """
  Converts from the database binary to a decrypted string.
  """
  def load(nil), do: {:ok, nil}

  def load(encrypted_data) when is_binary(encrypted_data) do
    case decrypt(encrypted_data) do
      {:ok, decrypted} -> {:ok, decrypted}
      :error -> :error
    end
  end

  def load(_), do: :error

  @doc """
  Converts a string to encrypted binary for database storage.
  """
  def dump(nil), do: {:ok, nil}

  def dump(plaintext) when is_binary(plaintext) do
    case encrypt(plaintext) do
      {:ok, encrypted} -> {:ok, encrypted}
      :error -> :error
    end
  end

  def dump(_), do: :error

  # Encryption implementation using AES-256-GCM
  defp encrypt(plaintext) do
    key = get_encryption_key()
    iv = :crypto.strong_rand_bytes(16)

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, "", 16, true) do
      {ciphertext, tag} ->
        # Store: version (1 byte) || iv (16 bytes) || tag (16 bytes) || ciphertext
        encrypted = <<1::8, iv::binary-16, tag::binary-16, ciphertext::binary>>
        {:ok, encrypted}

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  defp decrypt(<<1::8, iv::binary-16, tag::binary-16, ciphertext::binary>>) do
    key = get_encryption_key()

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, "", tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp decrypt(_), do: :error

  defp get_encryption_key do
    key =
      Application.get_env(:dialectic, __MODULE__)
      |> Keyword.get(:encryption_key)

    unless key do
      raise """
      Encryption key not configured for #{__MODULE__}.

      Add to your config/runtime.exs:

          config :dialectic, Dialectic.Encrypted.Binary,
            encryption_key: System.fetch_env!("ENCRYPTION_KEY")

      Generate a key with: mix phx.gen.secret 32
      """
    end

    # Ensure the key is 32 bytes for AES-256
    case Base.decode64(key) do
      {:ok, decoded} when byte_size(decoded) == 32 ->
        decoded

      _ ->
        # If not base64 or wrong size, hash it to get 32 bytes
        :crypto.hash(:sha256, key)
    end
  end
end
