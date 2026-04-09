# HARDEN-008: Add Dependency Security Scanning to CI

## Priority: P1 — High
## Size: Small (1-2 hours)
## Theme: Supply Chain Security

---

## Problem Statement
CI (`.github/workflows/ci.yml`) runs only `brakeman` and `rubocop`. No dependency vulnerability scanning exists. The app depends on 30+ gems including security-sensitive ones (`devise`, `devise-jwt`, `faraday`, `nokogiri`). A CVE in any of these could go undetected.

### Current CI pipeline (`.github/workflows/ci.yml`):
- `scan_ruby` job: runs `bin/brakeman`
- `lint` job: runs `bin/rubocop`
- **Missing**: No `rspec` job, no `bundler-audit` job, no `strong_migrations`

## Files to Create/Modify

| File | Action |
|------|--------|
| `Gemfile` | Add `bundler-audit` and `strong_migrations` to `:development, :test` group |
| `.github/workflows/ci.yml` | Add `audit` job and `test` job |
| `config/initializers/strong_migrations.rb` | Create — configure for PostgreSQL |
| `.bundler-audit.yml` | Create (optional) — ignore file for false positives |

## Implementation Steps

### Step 1: Add gems to `Gemfile`
```ruby
group :development, :test do
  # ... existing gems ...
  gem 'bundler-audit', require: false
  gem 'strong_migrations', '~> 2.0'
end
```
```bash
bundle install
```

### Step 2: Configure strong_migrations
Create `config/initializers/strong_migrations.rb`:
```ruby
StrongMigrations.start_after = 20250408000000  # Only check migrations after today

# Target PostgreSQL version
StrongMigrations.target_postgresql_version = "16"
```

### Step 3: Add CI jobs to `.github/workflows/ci.yml`
Add these jobs after the existing `lint` job:

```yaml
  audit:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Audit gem dependencies for vulnerabilities
        run: bundle exec bundler-audit check --update

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: e_arca_api_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/e_arca_api_test
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Setup database
        run: bin/rails db:schema:load

      - name: Run tests
        run: bundle exec rspec
```

### Step 4: Verify current gems pass audit
```bash
bundle exec bundler-audit check --update
```
If any advisories are found, update the vulnerable gem or add to `.bundler-audit.yml` with documented justification:
```yaml
---
ignore:
  - CVE-XXXX-XXXX  # Reason: does not apply because...
```

### Step 5: Verify locally
```bash
bundle exec bundler-audit check --update  # Should pass
bin/rails db:migrate                       # strong_migrations should check new migrations
```

## Acceptance Criteria
1. `bundler-audit` gem added to Gemfile
2. `strong_migrations` gem added and configured
3. CI has an `audit` job running `bundle exec bundler-audit check --update`
4. CI has a `test` job running `bundle exec rspec` with PostgreSQL
5. CI fails if `bundler-audit` finds advisories (unless explicitly ignored)
6. `strong_migrations` only checks migrations created after the start date
7. Current gems pass `bundler-audit`

## Risks
- **False positives**: Some CVEs may not apply to our usage. Document in `.bundler-audit.yml`.
- **Gem updates**: Fixing a vulnerable gem may introduce breaking changes — test each update.
- **strong_migrations**: Only checks new migrations, so no retroactive noise.

## Dependencies
- None

## Out of Scope
- `npm audit` (no frontend in this repo)
- Dependabot
- Container image scanning
