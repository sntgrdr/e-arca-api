# HARDEN-001: Secure JWT Secret Management

## Priority: P0 — Critical
## Size: Small (1-2 hours)
## Theme: Authentication Security

---

## Problem Statement
The JWT signing secret in `config/initializers/devise.rb:316` is configured as:
```ruby
jwt.secret = ENV.fetch('DEVISE_JWT_SECRET_KEY') { Rails.application.credentials.secret_key_base }
```
This falls back to `secret_key_base` if the env var is missing — meaning the JWT secret and Rails session secret are the same key. If either is compromised, both systems are compromised. There is no validation that a dedicated JWT secret exists, and the `.env` file may contain a weak placeholder.

## Files to Modify

| File | Action |
|------|--------|
| `config/initializers/devise.rb` (line 316) | Read JWT secret from `Rails.application.credentials.devise_jwt_secret_key!` |
| `config/credentials.yml.enc` | Add `devise_jwt_secret_key` with a 256-bit random value |
| `.env` / `.env.example` | Remove `DEVISE_JWT_SECRET_KEY` if present |

## Implementation Steps

### Step 1: Generate a dedicated JWT secret
```bash
bin/rails secret
# Copy the output — this is your new JWT signing key
```

### Step 2: Add to Rails credentials
```bash
EDITOR="code --wait" bin/rails credentials:edit
# Add:
#   devise_jwt_secret_key: <paste-the-generated-secret>
```

### Step 3: Update `config/initializers/devise.rb`
Replace line 316:
```ruby
# Before
jwt.secret = ENV.fetch('DEVISE_JWT_SECRET_KEY') { Rails.application.credentials.secret_key_base }

# After
jwt.secret = Rails.application.credentials.devise_jwt_secret_key!
```
The bang method (`!`) raises `KeyError` if the credential is missing — fail-safe, not fail-open.

### Step 4: Clean up environment files
- Remove `DEVISE_JWT_SECRET_KEY` from `.env`, `.env.example`, `.env.development` if present
- Verify `.env` is in `.gitignore`

### Step 5: Verify production deployment
- Ensure `config/master.key` (or `config/credentials/production.key`) is available in the Kamal deployment pipeline
- The app will refuse to boot if the credential is missing — this is intentional

## Acceptance Criteria
1. `config/initializers/devise.rb` reads JWT secret via `Rails.application.credentials.devise_jwt_secret_key!`
2. App raises `KeyError` on boot if the credential is missing
3. No `DEVISE_JWT_SECRET_KEY` in any `.env` file
4. `bundle exec rspec` passes
5. All active sessions are invalidated after deployment (expected one-time cost)

## Risks
- **Session invalidation**: All users will be logged out. Coordinate with any active beta users.
- **Deployment**: Production server must have the key file for credential decryption. Verify Kamal config before deploying.

## Dependencies
- None

## Out of Scope
- Token refresh mechanism
- Multi-device session management
