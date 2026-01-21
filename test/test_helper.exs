ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Dialectic.Repo, :manual)

# Set up encryption key for tests
Application.put_env(:dialectic, Dialectic.Encrypted.Binary,
  encryption_key: "test_encryption_key_for_oauth_tokens_32bytes_long_string"
)
