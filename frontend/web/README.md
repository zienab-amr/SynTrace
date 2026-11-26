# SynTrace Web (React + Vite)

```bash
npm install
cp .env.example .env.local     # set VITE_API_URL, or VITE_USE_MOCK_AUTH=true to work without the backend
npm run dev
```

Mock account (development only, never shipped): `demo@syntrace.dev` / `SynTrace#2026`.

## Structure

```
src/
  index.css                 design tokens (dark + light) = the single source of colour
  theme/                    themeController.js (one theme for the whole app) + useTheme.js
  router/router.jsx         tiny history router: <Link>, navigate(), useLocation()
  config/api.js             API base URL + endpoint paths (edit endpoints ONLY here)
  services/                 tokenStore (memory only), apiClient (fetch + refresh), authService
  context/AuthContext.jsx   auth state: loading | authenticated | anonymous
  hooks/useLoginThrottle.js client-side brake after failed attempts (UX only)
  lib/                      validation.js, safeRedirect.js
  components/
    common/                 ThemeToggle, StatusPage (placeholder / 404)
    Intro/                  the scroll story (engine.js is imperative, scoped to .intro-shell)
    Login/                  Login.jsx, useLoginForm.js, LoginStage.jsx, LoginIcons.jsx, login.css
    Workspace/              placeholder for the signed-in app
public/theme-init.js        sets data-theme before first paint (external file => CSP friendly)
```

## Theme (dark / light)

One choice for the whole app. `themeController` saves it in `localStorage["st-theme"]`, writes
`<html data-theme="dark|light">`, follows the system until the user chooses, and syncs open tabs.
Every page reads colours from the tokens in `index.css` (`--st-bg`, `--st-text`, `--st-accent` ...),
so a page never needs its own dark/light code. Use `<ThemeToggle />` anywhere.

## Auth and security

What the front end does:

- **Access token only in memory** (`tokenStore`), never in localStorage/sessionStorage. The refresh
  token must be an **HttpOnly + Secure + SameSite cookie set by the backend**; JS never sees it.
- Session restore on load and **one automatic refresh + retry** on 401 (`apiClient`).
- Generic error messages (no "email not found" vs "wrong password"), same minimum feedback time for every outcome.
- Password is cleared after a failed attempt, never logged or stored; `autocomplete` attributes keep password managers working.
- Validation + max lengths, double-submit protection, Caps Lock hint, accessible errors (`role="alert"`, `aria-invalid`).
- Client throttle (5 free tries, then 30s, 60s, 120s ... max 15 min) and server `Retry-After` support.
- `?redirect=` only accepts same-site paths (`safeRedirect`): no open redirect.
- Requests: `credentials: 'include'`, `cache: 'no-store'`, `redirect: 'error'`, 15 s timeout, `X-Requested-With`.
- Single sign-on buttons are visible but **disabled** until the backend supports them.

What the BACKEND must do (the browser cannot enforce these):

1. Real rate limiting / lockout on login (the client throttle is only a brake) and `429` + `Retry-After`.
2. Cookie flags `HttpOnly; Secure; SameSite=Lax|Strict`, short-lived access token, rotating refresh token.
3. CORS allow-list (exact origin, `Access-Control-Allow-Credentials: true`), and check `Origin` on state-changing requests (CSRF).
4. Same response for unknown email and wrong password; hash with Argon2id/bcrypt; log failed attempts server-side.
5. Production headers on the web server/CDN: `Content-Security-Policy`, `Strict-Transport-Security`,
   `frame-ancestors 'none'` (or `X-Frame-Options: DENY`), `X-Content-Type-Options: nosniff`.
   Starter CSP (tighten after self-hosting fonts): `default-src 'self'; img-src 'self' data:;
   style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com;
   connect-src 'self' <API origin>; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`.

### API contract this code assumes (confirm with the backend, then edit `config/api.js` / `authService.js`)

| Call | Request | Success response |
|---|---|---|
| `POST /api/auth/login` | `{ email, password }` | `200 { accessToken, expiresIn, user:{id,name,email,role,companyId} }` + refresh cookie |
| `POST /api/auth/refresh` | refresh cookie | `200 { accessToken, expiresIn, user }` |
| `POST /api/auth/logout` | auth header | `200`, cookie cleared |

Errors: `401/400` invalid credentials, `403` blocked, `429` + `Retry-After`, `5xx` server.
