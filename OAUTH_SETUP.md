# OAuth Setup Guide

This application supports Google OAuth authentication as an alternative to email/password login.

## Features

- Sign in with Google on login and registration pages
- Automatic account creation for new OAuth users
- OAuth users are automatically confirmed (no email verification needed)
- Existing OAuth accounts are recognized and logged in
- Access tokens are stored for future use

## Google OAuth Configuration

### 1. Create Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google+ API
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client ID"
5. Configure the OAuth consent screen if prompted
6. Select "Web application" as the application type
7. Add authorized redirect URIs:
   - Development: `http://localhost:4000/auth/google/callback`
   - Production: `https://yourdomain.com/auth/google/callback`
8. Save and copy your Client ID and Client Secret

### 2. Set Environment Variables

Add these environment variables to your deployment:

```bash
GOOGLE_CLIENT_ID=your_client_id_here
GOOGLE_CLIENT_SECRET=your_client_secret_here
```

**Development (.env or shell):**
```bash
export GOOGLE_CLIENT_ID="your_client_id"
export GOOGLE_CLIENT_SECRET="your_client_secret"
```

**Production (Fly.io):**
```bash
fly secrets set GOOGLE_CLIENT_ID="your_client_id"
fly secrets set GOOGLE_CLIENT_SECRET="your_client_secret"
```

### 3. Database Migration

The OAuth fields are added to the users table via migration. Run migrations:

```bash
mix ecto.migrate
```

This adds:
- `provider` (string) - OAuth provider name (e.g., "google")
- `provider_id` (string) - Unique ID from the OAuth provider
- `access_token` (text) - OAuth access token
- Unique index on `(provider, provider_id)`
- Makes `hashed_password` nullable for OAuth users

## Testing

1. Start the server: `mix phx.server`
2. Navigate to `/users/log_in` or `/users/register`
3. Click "Sign in with Google"
4. You should be redirected to Google's OAuth consent screen
5. After authorizing, you'll be redirected back and logged in

## Security Notes

- Access tokens are stored in plain text in the database (encryption was intentionally omitted for simplicity)
- OAuth users do not have passwords and cannot use email/password login
- OAuth users are automatically confirmed and don't need email verification
- The implementation uses `ueberauth` and `ueberauth_google` libraries

## Troubleshooting

**"Failed to authenticate with Google"**
- Check that environment variables are set correctly
- Verify redirect URI matches exactly in Google Console
- Ensure Google+ API is enabled for your project

**"Unable to create account: email: has already been taken"**
- An account with this email already exists
- OAuth accounts are tied to provider+provider_id, not just email
- User should log in with their existing credentials

## Implementation Details

- **Routes:** `/auth/google` initiates OAuth, `/auth/google/callback` handles the response
- **Controller:** `DialecticWeb.AuthController` processes OAuth callbacks
- **Schema:** `Dialectic.Accounts.User` includes OAuth fields
- **Context:** `Dialectic.Accounts.find_or_create_oauth_user/1` handles user lookup/creation