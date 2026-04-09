# HARDEN-003: Fix Production SSL Cipher Weakness

## Priority: P0 — Critical
## Size: Small (1-2 hours)
## Theme: Encryption & Data in Transit

---

## Problem Statement
Four Faraday connections to AFIP use weak SSL configurations:

**Production** (`ciphers: 'DEFAULT:@SECLEVEL=0'` — allows broken ciphers):
- `app/services/invoices/production/send_to_arca_service.rb:32`
- `app/services/invoices/production/auth_with_arca_service.rb:85`

**Development** (`verify: false` — disables certificate verification entirely):
- `app/services/invoices/development/send_to_arca_service.rb:31`
- `app/services/invoices/development/auth_with_arca_service.rb:58`

## Files to Modify

| File | Line | Current | Target |
|------|------|---------|--------|
| `app/services/invoices/production/send_to_arca_service.rb` | 32 | `ssl: { verify: true, ciphers: 'DEFAULT:@SECLEVEL=0' }` | `ssl: { verify: true }` |
| `app/services/invoices/production/auth_with_arca_service.rb` | 85 | `ssl: { verify: true, ciphers: 'DEFAULT:@SECLEVEL=0' }` | `ssl: { verify: true }` |
| `app/services/invoices/development/send_to_arca_service.rb` | 31 | `ssl: { verify: false }` | `ssl: { verify: true }` |
| `app/services/invoices/development/auth_with_arca_service.rb` | 58 | `ssl: { verify: false }` | `ssl: { verify: true }` |

## Implementation Steps

### Step 1: Fix production services
In both production files, replace:
```ruby
# Before
Faraday.new(url: URL, ssl: { verify: true, ciphers: 'DEFAULT:@SECLEVEL=0' })

# After
Faraday.new(url: URL, ssl: { verify: true })
```
This uses Ruby/OpenSSL defaults, which enforce TLS 1.2+ with modern cipher suites.

### Step 2: Fix development services
In both development files, replace:
```ruby
# Before
Faraday.new(url: URL, ssl: { verify: false })

# After
Faraday.new(url: URL, ssl: { verify: true })
```

### Step 3: Test against AFIP sandbox (homologacion)
- Run the dev environment and trigger an AFIP auth flow (`AuthWithArcaService` -> `SendToArcaService`)
- If the handshake fails, AFIP's sandbox may require older ciphers. In that case:
  1. Use `@SECLEVEL=1` (not 0) and document why in a comment
  2. Add an ADR in `docs/adrs/` explaining the AFIP compatibility constraint

### Step 4: Test against AFIP production
- Same flow but against production endpoints
- If it fails, same fallback to `@SECLEVEL=1` with documentation

### Step 5: Keep rollback ready
Add a comment above the SSL config in each file:
```ruby
# AFIP SSL: Using OpenSSL defaults (TLS 1.2+, modern ciphers).
# If AFIP handshake fails, try: ciphers: 'DEFAULT:@SECLEVEL=1'
# Do NOT use @SECLEVEL=0 — it allows broken ciphers (POODLE, BEAST).
```

## Acceptance Criteria
1. Zero occurrences of `@SECLEVEL=0` in the codebase
2. Zero occurrences of `verify: false` in AFIP service files
3. Both production and development AFIP auth flows succeed (manual verification)
4. If `@SECLEVEL=1` is required, it is documented with a comment and an ADR
5. `bundle exec rspec` passes (no code behavior change for unit tests)

## Risks
- **AFIP compatibility**: Argentina's government servers may use older TLS. If connection fails, use `@SECLEVEL=1` (minimum acceptable) — never drop back to 0.
- **Rollback**: Keep the old config in a comment for quick restore if AFIP connectivity breaks.
- **Testing**: Must test against both sandbox (`wsaahomo.afip.gov.ar`, `wswhomo.afip.gov.ar`) and production (`wsaa.afip.gov.ar`, `servicios1.afip.gov.ar`).

## Dependencies
- Requires access to AFIP sandbox and production environments

## Out of Scope
- Upgrading AFIP integration from SOAP to REST
- TLS version pinning
