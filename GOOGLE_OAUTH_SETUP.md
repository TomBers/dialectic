# Google OAuth Setup Guide

## Overview
This application now supports Google OAuth authentication alongside the traditional email/password login.

## Prerequisites
You should have already created OAuth credentials in the Google Cloud Console. If not, follow these steps:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to "APIs & Services" > "Credentials"
4. Click "Create Credentials" > "OAuth 2.0 Client ID"
5. Configure the OAuth consent screen if you haven't already
6. Select "Web application" as the application type
7. Add authorized redirect URIs:
   - Development: `http://localhost:4000/auth/google/callback`
   - Production: `https://yourdomain.com/auth/google/callback`
8. Save and copy your Client ID and Client Secret

## Environment Variables

You need to set the following environment variables:

### Development (.env or shell)
```bash
export GOOGLE_CLIENT_ID="your-client-id-here.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="your-client-secret-here"
```

### Production (Fly.io)
```bash
fly secrets set GOOGLE_CLIENT_ID="your-client-id-here.apps.googleusercontent.com"
fly secrets set GOOGLE_CLIENT_SECRET="your-client-secret-here"
```

## Database Schema Changes

The following fields have been added to the `users` table:
- `provider` (string, nullable) - e.g., "google", "email"
- `provider_id` (string, nullable) - The OAuth provider's user ID
- `provider_token` (text, nullable) - OAuth access token
- `provider_refresh_token` (text, nullable) - OAuth refresh token

The `hashed_password` field is now nullable to support OAuth users.

## How It Works

### User Flow
1. User clicks "Sign in with Google" button on login or registration page
2. User is redirected to Google's OAuth consent screen
3. User grants permission
4. Google redirects back to `/auth/google/callback` with auth data
5. Application either:
   - Creates a new user account (if email is new)
   - Links OAuth to existing account (if email exists)
   - Logs in existing OAuth user
6. User is logged in and redirected to the home page

### Account Linking
If a user registered with email/password and later tries to sign in with Google using the same email:
- The OAuth credentials are automatically linked to their existing account
- They can then use either method to log in
- Their existing data is preserved

### Email Confirmation
Users who sign up via Google OAuth are automatically confirmed since Google has already verified their email address.

## Testing

### Manual Testing
1. Start your development server: `mix phx.server`
2. Navigate to `http://localhost:4000/users/log_in` or `/users/register`
3. Click "Sign in with Google" or "Sign up with Google"
4. Complete the OAuth flow
5. Verify you're logged in

### Edge Cases to Test
- New user signup via Google
- Existing email/password user logging in via Google (account linking)
- Existing Google user logging in again
- Error handling (denied permissions, invalid tokens)

## Security Notes

- OAuth tokens are stored encrypted in the database (marked with `redact: true`)
- The `hashed_password` is also marked as redacted
- CSRF protection is handled automatically by Ueberauth
- Users authenticate via session cookies (same as email/password flow)

## Troubleshooting

### "Failed to authenticate with Google"
- Check that environment variables are set correctly
- Verify redirect URI matches exactly in Google Console
- Check application logs for detailed error messages

### "Invalid redirect_uri"
- Ensure the redirect URI in Google Console matches your environment
- Development: `http://localhost:4000/auth/google/callback`
- Production: `https://yourdomain.com/auth/google/callback`

### "Unable to create account: email: has already been taken"
This shouldn't happen as the code handles account linking, but if it does:
- Check the `find_or_create_oauth_user` function in `lib/dialectic/accounts.ex`
- Verify the unique constraint on the users table

## Additional OAuth Providers

The current implementation uses Ueberauth, which makes it easy to add more providers:
- Facebook: Add `ueberauth_facebook` dependency
- GitHub: Add `ueberauth_github` dependency
- Twitter: Add `ueberauth_twitter` dependency

Each provider follows the same pattern as Google.

## Files Modified/Created

### New Files
- `lib/dialectic_web/controllers/auth_controller.ex` - Handles OAuth callbacks
- `priv/repo/migrations/20260121134817_add_oauth_fields_to_users.exs` - Database migration

### Modified Files
- `lib/dialectic/accounts/user.ex` - Added OAuth fields and changeset
- `lib/dialectic/accounts.ex` - Added OAuth user functions
- `lib/dialectic_web/router.ex` - Added OAuth routes
- `lib/dialectic_web/live/user_login_live.ex` - Added Google sign-in button
- `lib/dialectic_web/live/user_registration_live.ex` - Added Google sign-up button
- `config/config.exs` - Added Ueberauth configuration
- `mix.exs` - Added dependencies

## Support

For issues or questions, refer to:
- [Ueberauth Documentation](https://hexdocs.pm/ueberauth/readme.html)
- [Ueberauth Google Strategy](https://hexdocs.pm/ueberauth_google/readme.html)
- [Google OAuth Documentation](https://developers.google.com/identity/protocols/oauth2)