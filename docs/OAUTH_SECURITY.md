# OAuth Security Implementation

This document describes the OAuth implementation in Dialectic and the security measures in place to protect user data.

## Overview

Dialectic supports OAuth authentication via Google. When users sign in with OAuth, their access tokens and refresh tokens are encrypted at rest in the database using AES-256-GCM encryption.

## Security Measures

### 1. Token Encryption

OAuth access tokens and refresh tokens are encrypted before being stored in the database using the `Dialectic.Encrypted.Binary` Ecto type.

**Encryption Details:**
- Algorithm: AES-256-GCM (Galois/Counter Mode)
- Key size: 256 bits (32 bytes)
- Authentication: Built-in authenticated encryption with AEAD
- IV (Initialization Vector): Randomly generated 16 bytes per encryption
- Tag: 16 bytes for authentication

**Benefits:**
- Even if an attacker gains database access, they cannot read the OAuth tokens
- Each encryption uses a unique IV, preventing pattern analysis
- AEAD provides both confidentiality and authenticity

### 2. Configuration

The encryption key must be set as an environment variable:

```bash
# Generate a secure encryption key (32 bytes recommended)
mix phx.gen.secret 32

# Set as environment variable
export ENCRYPTION_KEY="your-generated-key-here"
```

In production, configure in `config/runtime.exs`:

```elixir
config :dialectic, Dialectic.Encrypted.Binary,
  encryption_key: System.fetch_env!("ENCRYPTION_KEY")
```

### 3. OAuth Credentials

Google OAuth credentials are loaded at runtime (not compile time) to ensure they can be updated without recompilation:

```bash
export GOOGLE_CLIENT_ID="your-client-id"
export GOOGLE_CLIENT_SECRET="your-client-secret"
```

### 4. Schema Redaction

The `provider_token` and `provider_refresh_token` fields use the `Dialectic.Encrypted.Binary` type, which automatically handles encryption/decryption. The encrypted data is stored as binary in the database.

### 5. Password-less OAuth Users

Users who sign in via OAuth do not have a password. The `hashed_password` column is nullable to support this:

- OAuth-only users: `hashed_password` is `NULL`
- Linked accounts: Users can have both password and OAuth authentication
- Email confirmation: OAuth users are automatically confirmed

## Implementation Details

### Database Schema

```sql
-- OAuth fields in users table
provider VARCHAR          -- e.g., "google"
provider_id VARCHAR       -- Unique ID from OAuth provider
provider_token BINARY     -- Encrypted access token
provider_refresh_token BINARY  -- Encrypted refresh token

-- Unique constraint ensures one OAuth account per provider
CREATE UNIQUE INDEX users_provider_provider_id_index 
  ON users (provider, provider_id);
```

### Account Linking

When a user signs in with OAuth using an email that already exists:

1. If the email belongs to an existing password-based account, the OAuth provider is linked to that account
2. The user can then sign in using either password or OAuth
3. If the account was unconfirmed, it gets automatically confirmed

### User Flow

1. **New OAuth User:**
   - User clicks "Sign in with Google"
   - Redirected to Google for authentication
   - Returns to app with OAuth credentials
   - New user created with encrypted tokens
   - Automatically confirmed

2. **Existing OAuth User:**
   - User signs in with same provider
   - Tokens are updated with new values
   - User is logged in

3. **Account Linking:**
   - User with existing password account signs in with OAuth
   - Same email detected
   - OAuth credentials linked to existing account
   - User can use either method to sign in

## Security Best Practices

### Key Management

1. **Generate Strong Keys:**
   ```bash
   # Use Phoenix's built-in secret generator
   mix phx.gen.secret 32
   ```

2. **Never Commit Keys:**
   - Keep encryption keys out of version control
   - Use environment variables or secret management systems
   - Rotate keys periodically

3. **Key Rotation:**
   - When rotating encryption keys, decrypt with old key and re-encrypt with new key
   - Plan for zero-downtime key rotation in production

### Deployment

1. **Environment Variables:**
   - Set `ENCRYPTION_KEY` in production environment
   - Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`
   - Use secret management services (AWS Secrets Manager, HashiCorp Vault, etc.)

2. **Testing:**
   - Test suite sets temporary encryption keys
   - Never use production keys in test environment
   - Clean up test keys after tests complete

3. **Monitoring:**
   - Monitor failed OAuth attempts
   - Alert on unusual token refresh patterns
   - Track OAuth sign-in success/failure rates

## Migration Safety

The OAuth fields migration includes safety measures:

```elixir
# Up: Add OAuth support
- Makes hashed_password nullable
- Adds OAuth fields as binary columns
- Creates unique index on (provider, provider_id)

# Down: Rollback with data safety
- Sets placeholder password for OAuth users before making NOT NULL
- Prevents constraint violations during rollback
- Removes OAuth fields and indexes
```

## Testing

Comprehensive test coverage includes:

1. **Encrypted.Binary tests:**
   - Encryption/decryption round-trips
   - IV uniqueness
   - Error handling

2. **OAuth flow tests:**
   - New user creation
   - Existing user sign-in
   - Account linking
   - Token updates

3. **Changeset tests:**
   - OAuth registration validation
   - Email format validation
   - Required field validation

## Compliance Considerations

### Data Protection

- Tokens are encrypted at rest (GDPR, CCPA compliance)
- Minimal token storage (only what's necessary)
- User can request data deletion including OAuth tokens

### Token Refresh

OAuth tokens have limited lifetimes. Consider implementing:

- Automatic token refresh when expired
- Secure token refresh flow
- Handling of revoked tokens

### Audit Trail

Consider logging:
- OAuth sign-in attempts
- Account linking events
- Token refresh operations
- Failed authentication attempts

## Troubleshooting

### "Encryption key not configured"

**Error:** `RuntimeError: Encryption key not configured for Dialectic.Encrypted.Binary`

**Solution:** Set the `ENCRYPTION_KEY` environment variable.

### OAuth tokens not decrypting

**Cause:** Encryption key changed after tokens were encrypted

**Solution:** 
- Restore the original encryption key, OR
- Clear OAuth tokens for affected users (they'll need to re-authenticate)

### Migration rollback fails

**Cause:** Trying to make hashed_password NOT NULL when OAuth users exist

**Solution:** The migration handles this automatically by setting a placeholder password. If manually rolling back, ensure OAuth users have passwords set first.

## References

- [Ueberauth Documentation](https://hexdocs.pm/ueberauth/readme.html)
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
- [Erlang Crypto Module](https://www.erlang.org/doc/man/crypto.html)
- [NIST AES-GCM Guidelines](https://csrc.nist.gov/publications/detail/sp/800-38d/final)