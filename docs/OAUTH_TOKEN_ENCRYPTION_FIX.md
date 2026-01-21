# OAuth Token Encryption Fix Summary

**Date:** January 21, 2026  
**Issue:** OAuth tokens stored in database causing load errors  
**Status:** ✅ Resolved

## Problem Description

When attempting to load OAuth users from the database, the application encountered the following error:

```
** (ArgumentError) cannot load `"ya29.a0AUMWg_KQE..."` as type Dialectic.Encrypted.Binary
```

This error occurred because:
1. OAuth tokens were initially stored as plain text in the database
2. The schema was later updated to use `Dialectic.Encrypted.Binary` type
3. The database columns were still configured as `:text` instead of `:binary`
4. Existing plain-text tokens couldn't be loaded by the encryption type handler

## Root Causes

### 1. Database Column Type Mismatch
- Migration file specified `:binary` type for token columns
- Database actually had `:text` (character varying) columns
- This happened because the migration was likely edited after initial deployment

### 2. No Migration Path for Existing Data
- Existing OAuth tokens were stored as plain text
- No mechanism to handle or migrate legacy unencrypted data
- `Encrypted.Binary.load/1` only expected encrypted binary format

### 3. Missing Development Configuration
- Encryption key was only configured for production environment
- Development environment had no default encryption key
- Tests worked because `test_helper.exs` configured the key

## Solutions Implemented

### 1. Added Legacy Data Fallback in `Encrypted.Binary`

**File:** `lib/dialectic/encrypted/binary.ex`

Added graceful handling for legacy unencrypted OAuth tokens:

```elixir
def load(encrypted_data) when is_binary(encrypted_data) do
  case decrypt(encrypted_data) do
    {:ok, decrypted} ->
      {:ok, decrypted}

    :error ->
      # Fallback: if decryption fails, check if this might be legacy unencrypted data
      case is_legacy_unencrypted?(encrypted_data) do
        true -> {:ok, encrypted_data}
        false -> :error
      end
  end
end

defp is_legacy_unencrypted?(<<1::8, _rest::binary>>), do: false
defp is_legacy_unencrypted?(data) when is_binary(data) do
  String.valid?(data) and String.printable?(data)
end
```

**Why this works:**
- Encrypted data always starts with version byte `1`
- Legacy OAuth tokens are printable ASCII/UTF-8 strings
- The function safely detects and returns legacy data as-is
- Users can continue using the app; tokens will be re-encrypted on next update

### 2. Created Column Type Migration

**File:** `priv/repo/migrations/20260121163853_alter_oauth_token_columns_to_binary.exs`

Migrated database columns from `:text` to `:binary` (bytea):

```elixir
def up do
  # Clear existing OAuth tokens before changing column type
  execute "UPDATE users SET provider_token = NULL, provider_refresh_token = NULL 
           WHERE provider_token IS NOT NULL OR provider_refresh_token IS NOT NULL"

  # Alter columns from text to binary (bytea)
  execute "ALTER TABLE users ALTER COLUMN provider_token TYPE bytea USING NULL"
  execute "ALTER TABLE users ALTER COLUMN provider_refresh_token TYPE bytea USING NULL"
end
```

**Why we clear tokens:**
- PostgreSQL cannot automatically cast text with data to bytea
- OAuth tokens are short-lived (typically 1 hour)
- Users can simply re-authenticate to get new tokens
- This is safer than attempting complex data migration during type change

### 3. Added Development Encryption Key

**File:** `config/dev.exs`

```elixir
# Configure encryption key for development
# This is a fixed key for development only - NEVER use this in production
config :dialectic, Dialectic.Encrypted.Binary,
  encryption_key: "dev_encryption_key_32_bytes_long!!"
```

**Security Note:**
- Production uses `ENCRYPTION_KEY` environment variable (in `config/runtime.exs`)
- Development uses fixed key for convenience
- Test environment uses fixed key (in `test_helper.exs`)
- The fixed dev key is safe because dev databases contain no real user data

### 4. Updated Tests

**File:** `test/dialectic/encrypted/binary_test.exs`

Updated test expectations to reflect new legacy data handling:

```elixir
test "handles legacy unencrypted data and rejects invalid encrypted data" do
  # Legacy unencrypted data (printable strings) are accepted for migration purposes
  assert {:ok, "legacy_oauth_token"} = Binary.load("legacy_oauth_token")

  # Invalid encrypted data is still rejected
  assert :error = Binary.load(<<1, 2, 3>>)
  assert :error = Binary.load(<<255, 254, 253, 0, 1, 2>>)
end
```

## Migration Strategy

### For Development
1. ✅ Run `mix ecto.migrate` to update column types
2. ✅ Existing OAuth sessions are cleared (users re-authenticate)
3. ✅ New tokens are automatically encrypted

### For Production

**Before Deploying:**
1. Generate secure encryption key: `mix phx.gen.secret 32`
2. Set `ENCRYPTION_KEY` environment variable
3. Test OAuth flow in staging environment

**During Deployment:**
1. Run migrations: `mix ecto.migrate`
2. Existing OAuth sessions will be invalidated
3. Users will need to re-authenticate via Google OAuth
4. New tokens will be encrypted automatically

**Post-Deployment:**
1. Monitor for any load errors in logs
2. Verify OAuth authentication works correctly
3. Confirm tokens are being encrypted (check database with `\x` in psql)

## Security Improvements

### Before
- ❌ OAuth tokens stored as plain text in database
- ❌ Database backups contained readable access tokens
- ❌ SQL injection or database breach would expose tokens

### After
- ✅ OAuth tokens encrypted at rest using AES-256-GCM
- ✅ Encryption key stored in environment variable
- ✅ Each encrypted value has unique IV and authentication tag
- ✅ Database backups contain only encrypted data
- ✅ Legacy data handled gracefully during transition

## Testing Results

All tests passing:
```
Finished in 1.3 seconds (0.5s async, 0.8s sync)
269 tests, 0 failures
```

Key test coverage:
- ✅ OAuth token encryption/decryption
- ✅ Legacy unencrypted data handling
- ✅ AuthController OAuth flows
- ✅ User creation and token storage
- ✅ Account linking scenarios

## Database Schema Verification

After migration:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name LIKE 'provider%';

-- Results:
-- provider_refresh_token | bytea
-- provider_token         | bytea
-- provider              | character varying
-- provider_id           | character varying
```

## Environment Configuration

### Development (`config/dev.exs`)
```elixir
config :dialectic, Dialectic.Encrypted.Binary,
  encryption_key: "dev_encryption_key_32_bytes_long!!"
```

### Production (`config/runtime.exs`)
```elixir
if encryption_key = System.get_env("ENCRYPTION_KEY") do
  config :dialectic, Dialectic.Encrypted.Binary, 
    encryption_key: encryption_key
end
```

### Testing (`test/test_helper.exs`)
```elixir
Application.put_env(:dialectic, Dialectic.Encrypted.Binary,
  encryption_key: "test_encryption_key_for_oauth_tokens_32bytes_long_string"
)
```

## User Impact

### Immediate Impact
- Existing OAuth users will be logged out
- Users must re-authenticate via Google OAuth
- Session is brief (1-2 minutes)

### Long-term Benefits
- Enhanced security for OAuth credentials
- Protection against database breaches
- Compliance with data protection best practices
- Automatic token rotation on each authentication

## Rollback Plan

If issues occur in production:

1. **Immediate Rollback:**
   ```bash
   # Rollback the migration
   mix ecto.rollback --step 1
   ```

2. **Restore Service:**
   - Remove `ENCRYPTION_KEY` environment variable
   - Redeploy previous version
   - OAuth will work with plain text tokens

3. **Investigate:**
   - Check logs for specific errors
   - Verify encryption key is set correctly
   - Test OAuth flow in staging

## Future Improvements

1. **Automatic Token Re-encryption:**
   - Create background job to re-encrypt legacy tokens
   - Run after deployment to clean up any remaining plain-text tokens

2. **Key Rotation:**
   - Implement encryption key rotation strategy
   - Support multiple keys during transition period

3. **Monitoring:**
   - Add metrics for encryption/decryption operations
   - Alert on encryption failures
   - Track legacy data access

## References

- Original PR: https://github.com/TomBers/dialectic/pull/221
- Ecto Custom Types: https://hexdocs.pm/ecto/Ecto.Type.html
- AES-GCM Encryption: https://en.wikipedia.org/wiki/Galois/Counter_Mode
- PostgreSQL bytea: https://www.postgresql.org/docs/current/datatype-binary.html