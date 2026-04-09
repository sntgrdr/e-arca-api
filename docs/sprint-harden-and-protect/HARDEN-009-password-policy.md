# HARDEN-009: Strengthen Password Policy

## Priority: P1 — High
## Size: Small (1-2 hours)
## Theme: Authentication Security

---

## Problem Statement
`config/initializers/devise.rb:181` sets `config.password_length = 6..128`. A 6-character password can be cracked in minutes. The `User` model (`app/models/user.rb:3`) does not include `:lockable` — there is no account lockout after failed attempts.

## Files to Modify

| File | Line | Action |
|------|------|--------|
| `config/initializers/devise.rb` | 181 | Change `6..128` to `12..128` |
| `config/initializers/devise.rb` | 196-214 | Uncomment and configure lockable settings |
| `app/models/user.rb` | 3 | Add `:lockable` to devise modules |
| New migration | — | Add `failed_attempts`, `locked_at`, `unlock_token` columns to users |

## Implementation Steps

### Step 1: Update password length in `config/initializers/devise.rb`
```ruby
# Line 181 — change from:
config.password_length = 6..128

# To:
config.password_length = 12..128
```

### Step 2: Configure lockable in `config/initializers/devise.rb`
Uncomment and set these values (lines 196-214):
```ruby
config.lock_strategy = :failed_attempts
config.unlock_keys = [:email]
config.unlock_strategy = :time
config.maximum_attempts = 5
config.unlock_in = 15.minutes
config.last_attempt_warning = true
```

### Step 3: Add `:lockable` to User model
```ruby
# app/models/user.rb:3
devise :database_authenticatable, :registerable,
       :recoverable, :validatable, :lockable,
       :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
```

### Step 4: Generate migration
```bash
bin/rails generate migration AddLockableToUsers
```

Migration content:
```ruby
class AddLockableToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime
    add_column :users, :unlock_token, :string
    add_index :users, :unlock_token, unique: true
  end
end
```

```bash
bin/rails db:migrate
```

### Step 5: Update factories if needed
If `spec/factories/users.rb` uses a password shorter than 12 chars, update it:
```ruby
password { "securepassword12" }  # Must be >= 12 characters
```

### Step 6: Verify
```bash
bundle exec rspec
```

## Acceptance Criteria
1. `config.password_length = 12..128` in Devise config
2. `:lockable` added to User model devise modules
3. Lockable configured: 5 attempts, time-based unlock, 15 minutes
4. Migration adds `failed_attempts`, `locked_at`, `unlock_token` to users
5. Registration with password < 12 chars returns validation error
6. After 5 failed logins, account is locked (returns appropriate error)
7. Account auto-unlocks after 15 minutes
8. Existing users with short passwords can still log in (enforced only on password change)
9. `bundle exec rspec` passes

## Risks
- **Existing users**: Can still log in with short passwords. New minimum enforced only on password change or registration.
- **Account lockout abuse**: Attacker can lock accounts by brute-forcing. 15-min auto-unlock + rate limiting (HARDEN-002) mitigates this.
- **Test factories**: If any factory uses a short password, tests will fail. Update factories first.

## Dependencies
- Pairs with HARDEN-002 (rate limiting) for defense-in-depth

## Out of Scope
- Have I Been Pwned integration
- MFA
- Password expiration
