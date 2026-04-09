# HARDEN-018: Migrate Authentication from Bearer Tokens to HTTP-only Cookies

## Priority: P1 — High
## Size: Medium (4-6 hours backend + 2-3 hours frontend)
## Theme: Authentication Security

---

## Problem
The API currently dispatches JWT tokens via the `Authorization` response header. The frontend (not yet connected) would need to store this token in JavaScript-accessible memory (localStorage, sessionStorage, or a variable). Any XSS vulnerability in the React SPA would allow an attacker to steal the token and impersonate the user — including issuing AFIP invoices under their tax ID.

The frontend (`e-arca-frontend`) has **no auth implementation yet** — `LoginPage.tsx` has a placeholder `// Will connect to API later`, `src/services/` is empty, and there's no token management code. This is the ideal time to change the auth transport before any frontend auth code is written.

## Solution
Switch from Bearer token (Authorization header) to HTTP-only secure cookies for JWT transport. The browser handles cookie storage and attachment automatically — the frontend never touches the token, eliminating the XSS token-theft vector entirely.

## User Stories
- As a user, I want my authentication to be secure against XSS attacks, so that an attacker can't steal my session and issue invoices under my tax ID
- As a frontend developer, I want auth to work automatically via cookies, so that I don't need to manage token storage, refresh logic, or header injection

## Current Behavior (Backend)

| File | Line | Current |
|------|------|---------|
| `config/initializers/devise.rb` | 317-322 | JWT dispatched via `Authorization` header on `POST /api/v1/auth/sign_in` |
| `config/initializers/cors.rb` | 8 | `expose: ['Authorization']` — exposes header to JS |
| `config/initializers/cors.rb` | 5-7 | No `credentials: true` — cookies not sent cross-origin |
| `app/controllers/api/v1/auth/sessions_controller.rb` | 17 | Checks `request.headers['Authorization']` for sign-out |
| `config/application.rb` | 19-20 | Cookie/session middleware already loaded |

## Current Behavior (Frontend — `e-arca-frontend`)

| File | Status |
|------|--------|
| `src/pages/auth/LoginPage.tsx:17` | Placeholder: `// Will connect to API later` |
| `src/services/` | Empty — no API client, no auth service |
| `src/App.tsx` | No route guards, no auth checks |
| `src/components/layout/AppLayout.tsx` | No auth check before rendering |

## Desired Behavior

### Backend
- JWT is set as an HTTP-only secure cookie on successful login
- Cookie flags: `HttpOnly`, `Secure` (production), `SameSite=Lax`, `Path=/`
- CORS includes `credentials: true` for the frontend origin
- Sign-out clears the cookie
- The API reads the JWT from the cookie (not the Authorization header)
- Existing `devise-jwt` revocation (JwtDenylist) continues to work

### Frontend
- Login calls `POST /api/v1/auth/sign_in` with `credentials: 'include'`
- Browser automatically stores and sends the cookie — no token management code
- All API calls use `credentials: 'include'`
- No token in localStorage, sessionStorage, or JS variables

## Acceptance Criteria

### Backend
1. `devise-jwt` configured to dispatch JWT via `Set-Cookie` header (not `Authorization`)
2. Cookie flags set: `HttpOnly: true`, `Secure: true` (production), `SameSite: Lax`, `Path: /`
3. CORS updated: `credentials: true`, `expose: ['Authorization']` removed
4. `SessionsController` sign-out clears the cookie
5. JWT is read from cookie on incoming requests (Warden strategy or Rack middleware)
6. All existing request specs pass (update auth helper to use cookies)
7. JWT revocation via `JwtDenylist` still works

### Frontend
8. API client (Axios/fetch) configured with `withCredentials: true` / `credentials: 'include'`
9. Login form submits to API endpoint, cookie is set automatically by browser
10. No JWT token stored in JavaScript-accessible storage
11. Protected routes redirect to `/login` when cookie is missing/expired (401 response)

## Implementation Notes

### Backend approach — Rack middleware
The simplest approach is a Rack middleware that moves the JWT from the `Authorization` header to a cookie on response, and from cookie to `Authorization` header on request. This avoids modifying devise-jwt internals:

```ruby
# app/middleware/jwt_cookie_middleware.rb
class JwtCookieMiddleware
  COOKIE_NAME = '_e_arca_jwt'

  def initialize(app)
    @app = app
  end

  def call(env)
    # On request: copy JWT from cookie to Authorization header
    if (token = Rack::Request.new(env).cookies[COOKIE_NAME])
      env['HTTP_AUTHORIZATION'] = "Bearer #{token}"
    end

    status, headers, body = @app.call(env)

    # On response: move JWT from Authorization header to cookie
    if (auth = headers.delete('Authorization'))
      token = auth.sub('Bearer ', '')
      Rack::Utils.set_cookie_header!(headers, COOKIE_NAME, {
        value: token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        path: '/',
        max_age: 24.hours.to_i
      })
    end

    [status, headers, body]
  end
end
```

### CORS update
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('CORS_ORIGINS', 'http://localhost:3001').split(',')
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true  # Required for cookies
  end
end
```

### Frontend API client
```typescript
// src/services/api.ts
const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  withCredentials: true, // Send cookies with every request
})
```

## Out of Scope
- Token refresh mechanism (JWT expires in 24h, user re-authenticates)
- CSRF token implementation (SameSite=Lax handles this for same-site requests)
- Multi-device session management
- Remember me / persistent sessions

## RICE Score
- Reach: 100% of users (all authenticated requests)
- Impact: 2 (high — eliminates XSS token theft vector)
- Confidence: 100% (well-established pattern, no frontend auth code to migrate)
- Effort: 1 person-week
- **Score: (100 × 2 × 1.0) / 1 = 200**

## Success Metrics
- Zero JWT tokens stored in JavaScript-accessible browser storage
- All API requests authenticated via HTTP-only cookie
- Existing test suite passes with updated auth helper

## Risks
- **Same-domain requirement**: HTTP-only cookies require API and frontend on the same domain (or subdomains). If they're on completely different domains, this won't work. Confirm deployment plan.
- **Mobile app**: If a mobile app is planned, it will need Bearer token auth (cookies are browser-only). Consider supporting both transports via a header check.

## Dependencies
- Should be done AFTER the Harden & Protect sprint (HARDEN-001 through HARDEN-017)
- Frontend must be connected to the API (currently using mocks)
- CORS origins must be configured for the deployment domain
