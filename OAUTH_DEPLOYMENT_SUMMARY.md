# OAuth Implementation - Deployment Summary

## What Was Implemented

A simple, clean Google OAuth authentication system that allows users to sign in with their Google account instead of creating a password-based account.

## Changes Made

### 1. Dependencies (mix.exs)
- Added `ueberauth` v0.10
- Added `ueberauth_google` v0.12

### 2. Database Schema
**Migration:** `20260121170827_add_oauth_fields.exs`
- Added `provider` (string) - identifies OAuth provider (e.g., "google")
- Added `provider_id` (string) - unique user ID from OAuth provider
- Added `access_token` (text) - OAuth access token (stored plain text)
- Created unique index on `(provider, provider_id)`
- Made `hashed_password` nullable for OAuth users

### 3. Application Code

**User Schema** (`lib/dialectic/accounts/user.ex`)
- Added OAuth fields to schema
- Modified password validation to skip for OAuth users
- Added `oauth_changeset/2` for OAuth user creation

**Accounts Context** (`lib/dialectic/accounts.ex`)
- Added `get_user_by_provider/2` to lookup users by OAuth credentials
- Added `find_or_create_oauth_user/1` to handle OAuth login flow
- Uses `on_conflict` to handle concurrent OAuth requests gracefully

**AuthController** (`lib/dialectic_web/controllers/auth_controller.ex`)
- New controller to handle OAuth callbacks
- Creates or logs in users based on Google OAuth response
- Handles errors gracefully with user-friendly messages

**Router** (`lib/dialectic_web/router.ex`)
- Added `/auth/:provider` route to initiate OAuth
- Added `/auth/:provider/callback` route to handle OAuth response

**UI Updates**
- Added "Sign in with Google" button to login page
- Added "Sign in with Google" button to registration page
- Includes Google logo SVG for visual consistency

### 4. Configuration

**config/config.exs**
- Added Ueberauth configuration with Google provider

**config/runtime.exs**
- Added runtime configuration to read Google OAuth credentials from environment variables

## Deployment Instructions

### 1. Set Environment Variables

You must set these environment variables in your production environment:

```bash
fly secrets set GOOGLE_CLIENT_ID="your_google_client_id_here"
fly secrets set GOOGLE_CLIENT_SECRET="your_google_client_secret_here"
```

### 2. Get Google OAuth Credentials

1. Go to https://console.cloud.google.com/
2. Create or select a project
3. Enable Google+ API (under "APIs & Services" → "Library")
4. Go to "Credentials" → "CREATE CREDENTIALS" → "OAuth 2.0 Client ID"
5. Configure OAuth consent screen (if not done already)
6. Application type: "Web application"
7. Add authorized redirect URI: `https://your-production-domain.com/auth/google/callback`
8. Copy the Client ID and Client Secret

### 3. Run Database Migration

The migration will be run automatically on deploy, but you can run it manually:

```bash
fly ssh console -C "/app/bin/migrate"
```

Or locally:
```bash
mix ecto.migrate
```

### 4. Deploy

```bash
fly deploy
```

### 5. Test

1. Visit your production site
2. Navigate to `/users/log_in` or `/users/register`
3. Click "Sign in with Google"
4. Complete Google OAuth flow
5. Verify you're logged in

## What Was Intentionally Omitted

To keep the implementation simple and focused:

- **No token encryption at rest** - Access tokens are stored as plain text
- **No token refresh logic** - Tokens are stored but not automatically refreshed
- **No account linking** - If a user has both email/password and OAuth accounts, they're treated separately
- **No multiple OAuth providers** - Only Google is configured (but easy to add more)
- **No OAuth token usage** - Tokens are stored but not currently used for API calls

## Differences from Previous PR

The previous PR (`add-oauth` branch) included:

- Complex encryption module for tokens at rest
- Multiple documentation files (7+ markdown files)
- Complex account linking logic
- Two migrations instead of one
- Additional test files and fixtures
- 2,650+ lines of changes

This implementation:

- No encryption (tokens stored as text)
- Single comprehensive guide
- Simple user lookup: find by provider+id or create new
- One migration
- 300+ lines of changes
- Reuses existing test infrastructure
- Handles race conditions with `on_conflict` for concurrent OAuth requests
- Comprehensive test coverage (4 new OAuth tests)

## Security Considerations

- OAuth users are automatically confirmed (no email verification required)
- OAuth users cannot use password login (no hashed_password)
- Access tokens are stored but currently unused
- Consider adding token encryption if tokens will be used for API calls
- OAuth callback uses rate limiting via existing `:auth` pipeline

## Troubleshooting

**"Failed to authenticate with Google"**
- Check environment variables are set
- Verify redirect URI in Google Console matches exactly
- Ensure Google+ API is enabled

**"Unable to create account: email: has already been taken"**
- User already has an account with that email
- They should log in with existing credentials
- OAuth accounts are separate from email/password accounts

## Next Steps (Optional Enhancements)

1. Add token refresh logic for long-lived sessions
2. Add account linking to merge OAuth and password accounts
3. Add more OAuth providers (GitHub, Microsoft, etc.)
4. Encrypt tokens at rest if they'll be used for API calls
5. Add OAuth provider indicator on user settings page
6. Allow users to disconnect/reconnect OAuth accounts