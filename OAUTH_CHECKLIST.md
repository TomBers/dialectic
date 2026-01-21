# Google OAuth Deployment Checklist

## ✅ Implementation Complete

The following items have been completed:

- [x] Added `ueberauth` and `ueberauth_google` dependencies to `mix.exs`
- [x] Created database migration for OAuth fields (`provider`, `provider_id`, `provider_token`, `provider_refresh_token`)
- [x] Made `hashed_password` nullable in users table
- [x] Updated `User` schema with OAuth fields
- [x] Added `oauth_registration_changeset/2` to User module
- [x] Added OAuth functions to Accounts context:
  - `get_user_by_provider/2`
  - `find_or_create_oauth_user/1`
- [x] Created `AuthController` to handle OAuth callbacks
- [x] Added OAuth routes to router (`/auth/:provider` and `/auth/:provider/callback`)
- [x] Added Ueberauth configuration to `config/config.exs`
- [x] Added "Sign in with Google" button to login page
- [x] Added "Sign up with Google" button to registration page
- [x] Ran database migrations

## 📋 Before Testing Locally

### 1. Set Environment Variables
You need to set your Google OAuth credentials. Choose one method:

**Option A: Using .env file (recommended for development)**
```bash
# Create/edit .env file in project root
echo 'export GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"' >> .env
echo 'export GOOGLE_CLIENT_SECRET="your-secret"' >> .env
source .env
```

**Option B: Export directly in terminal**
```bash
export GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="your-secret"
```

### 2. Verify Google Cloud Console Setup
- [ ] Created OAuth 2.0 Client ID in Google Cloud Console
- [ ] Added redirect URI: `http://localhost:4000/auth/google/callback`
- [ ] OAuth consent screen configured
- [ ] Copied Client ID and Client Secret

### 3. Start Development Server
```bash
mix phx.server
```

### 4. Test the Flow
- [ ] Navigate to `http://localhost:4000/users/log_in`
- [ ] Click "Sign in with Google"
- [ ] Complete OAuth flow with Google
- [ ] Verify you're logged in and redirected to home page
- [ ] Check database to see your user record with OAuth fields populated

### 5. Test Edge Cases
- [ ] Register new user via Google OAuth
- [ ] Log out and log in again via Google OAuth (existing user)
- [ ] Create user via email/password, then log in via Google OAuth (account linking)
- [ ] Test error handling (deny permissions on Google consent screen)

## 🚀 Before Deploying to Production

### 1. Update Google Cloud Console
- [ ] Add production redirect URI: `https://yourdomain.com/auth/google/callback`
- [ ] Verify OAuth consent screen is set to "Production" (not "Testing")
- [ ] Add your production domain to authorized domains

### 2. Set Production Environment Variables (Fly.io)
```bash
fly secrets set GOOGLE_CLIENT_ID="your-production-client-id"
fly secrets set GOOGLE_CLIENT_SECRET="your-production-secret"
```

### 3. Deploy Application
```bash
fly deploy
```

### 4. Run Production Migrations
```bash
fly ssh console -C "/app/bin/migrate"
```

### 5. Test Production
- [ ] Navigate to your production login page
- [ ] Click "Sign in with Google"
- [ ] Complete OAuth flow
- [ ] Verify successful login

## 🔍 Troubleshooting

### Issue: "redirect_uri_mismatch" error
**Solution:** Ensure the redirect URI in Google Console exactly matches:
- Dev: `http://localhost:4000/auth/google/callback`
- Prod: `https://yourdomain.com/auth/google/callback`

### Issue: "Failed to authenticate with Google"
**Solution:** Check that environment variables are set:
```bash
# In your terminal where you run mix phx.server
echo $GOOGLE_CLIENT_ID
echo $GOOGLE_CLIENT_SECRET
```

### Issue: Environment variables not found
**Solution:** Make sure you export them in the same terminal where you start the server:
```bash
source .env
mix phx.server
```

### Issue: User creation fails with "email has already been taken"
**Solution:** This shouldn't happen due to account linking logic. Check:
1. The `find_or_create_oauth_user` function is being called correctly
2. The database has the unique index on `(provider, provider_id)`
3. Check logs for the actual error

### Issue: OAuth callback gets CSRF error
**Solution:** Ueberauth handles CSRF automatically. If you see this:
1. Clear your browser cookies
2. Restart your server
3. Try the flow again

## 📊 Database Verification

After a successful OAuth login, verify the data:

```sql
-- Connect to your database
mix ecto.psql

-- Check the user record
SELECT id, email, provider, provider_id, confirmed_at, hashed_password 
FROM users 
WHERE email = 'your-google-email@gmail.com';
```

Expected results:
- `provider` should be `"google"`
- `provider_id` should be Google's user ID (a string of numbers)
- `confirmed_at` should be automatically set
- `hashed_password` should be `NULL` for OAuth-only users

## 🔐 Security Checklist

- [x] OAuth tokens stored with `redact: true` in schema
- [x] CSRF protection enabled (via Ueberauth)
- [x] Email auto-confirmed for OAuth users (Google already verified)
- [x] Session-based authentication (same security as email/password)
- [x] Unique constraint on `(provider, provider_id)` to prevent duplicates

## 📝 Notes

- **Account Linking**: If a user registers with email/password first, then logs in with Google using the same email, their accounts will be automatically linked
- **Password Not Required**: OAuth users don't have passwords, so password reset doesn't apply to them
- **Multiple Providers**: The architecture supports adding more OAuth providers (GitHub, Facebook, etc.) in the future

## 🎉 Success Criteria

You'll know it's working when:
1. ✅ You can click "Sign in with Google" and be redirected to Google
2. ✅ After granting permissions, you're redirected back and logged in
3. ✅ Your user record shows `provider: "google"` in the database
4. ✅ You can log out and log back in using Google OAuth
5. ✅ The same email used for password auth can be linked to Google OAuth

## 📚 Additional Resources

- [Google OAuth Setup Guide](./GOOGLE_OAUTH_SETUP.md)
- [Ueberauth Documentation](https://hexdocs.pm/ueberauth/readme.html)
- [Ueberauth Google Strategy](https://hexdocs.pm/ueberauth_google/readme.html)