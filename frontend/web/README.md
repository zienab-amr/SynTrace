# SynTrace Web — React frontend

This folder is the standalone React/Vite web client for SynTrace. It consumes the existing ASP.NET Core API; it does not contain or replace backend business logic. The current UI design and brand palette are preserved.

## Requirements

- Node.js 22.12 or newer (the repository `.nvmrc` is 22.16.0).
- npm 10 or newer.
- The SynTrace backend running at `http://localhost:8081` (the local Docker Compose port).

## Run the web client

From this folder (`frontend/web`):

```powershell
npm ci
npm run dev
```

Open `http://localhost:5173`. The included `.env.development.local` keeps browser requests same-origin and proxies `/api` to the team's current remote ngrok backend (`https://jackeline-cibarious-supergallantly.ngrok-free.dev`). When that ngrok hostname changes, update `VITE_API_PROXY_TARGET` in `.env.development.local` and restart Vite. To use a local backend instead, set the proxy target to `http://localhost:8081`.

## Start the backend

From the repository root (the folder containing `docker-compose.yml`), configure the root `.env` using the repository's root `.env.example`, then start the backend profile:

```powershell
docker compose up -d --build
```

The compose file also requires SMTP and GitHub App private-key settings that are not all listed in the root example file. Supply `SYNTRACE_SMTP_EMAIL`, `SYNTRACE_SMTP_APP_PASSWORD`, and a valid local path in `SYNTRACE_GITHUB_PRIVATE_KEY_FILE`, along with the required SQL Server, RabbitMQ and JWT values, before starting Compose. Set `NEO4J_PASSWORD` before using the AI profile, and configure the model-provider keys (`GROQ_API_KEY` or the provider selected by your backend configuration). Keep `.env` and the private-key file out of source control. Do not put backend secrets in any `VITE_*` variable.

The API is exposed locally at `http://localhost:8081`. Check `http://localhost:8081/health/ready` for backend readiness. For local Jira OAuth testing, configure the backend's `JiraOAuth:FrontendRedirectUri` as `http://localhost:5173/jira/callback`; the web client forwards the returned `status` and `pendingId` into the authenticated workspace. The backend OAuth callback/webhook URLs must also be publicly reachable HTTPS URLs (for example through the team's configured tunnel) and must match the Atlassian app configuration.

### AI Assistant services

The ASP.NET API can run without the AI profile, but Assistant requests need the AI services, Neo4j, Ollama, RabbitMQ consumers, model configuration and provider keys. Start the full AI profile from the repository root when those settings are available:

```powershell
docker compose --profile ai up -d --build
```

If the API is running but AI services are not configured or available, the assistant may return `503`; if the signed-in employee has no accessible projects, it may return `403`. The UI reports those conditions instead of fabricating an answer.

## Real API integration

The frontend uses the backend contracts in the `feature/meeting-ai-phase-1` source branch. The API base URL and endpoint paths are centralized in `src/config/api.js`; request handling, bearer-token attachment, refresh and error parsing live in `src/services/apiClient.js`.

### Authentication

- `POST /api/Auth/login` with `{ request: { email, password } }`.
- The API returns `accessToken`, `refreshToken` and their expirations. The frontend then calls `GET /api/Employee/me` for the signed-in employee and roles.
- `POST /api/Auth/refresh-token` with `{ refreshToken }`, followed by one retry of an unauthorized API request.
- `POST /api/Auth/logout` with `{ refreshToken }`.
- Registration uses `send-otp`, `verify-otp`, then `register`.
- Password recovery uses `send-otp` with `purpose: "passwordReset"`, then `reset-password`.

**Token-storage limitation:** this backend currently returns the refresh token in JSON rather than setting an HttpOnly cookie. To work with the existing API, this frontend keeps the short-lived access token in memory and the rotating refresh token in tab-scoped `sessionStorage`. This is not as resistant to XSS as a Secure, HttpOnly, SameSite refresh cookie. A future backend improvement should move refresh-token handling to an HttpOnly cookie and update CORS/CSRF protections accordingly. The frontend sends requests with `credentials: "omit"` to match the current API CORS behavior.

### Workspace data

- Projects: `GET /api/projects?offset=0`.
- Clients: `GET /api/Client`.
- Employees: `GET /api/Employee/all-employee` and `/api/Employee/me`.
- Knowledge sources and Meeting Notes: `GET`/`POST /api/knowledge/sources`.
- Jira connection, OAuth site selection, sync status and manual sync use the existing `/api/integrations/Jira/*` and `/api/integrations/jira/sync/*` routes.
- Project, client and Meeting Note creation use their existing backend endpoints and backend authorization.

The dashboard's chart and counters are computed from these authenticated API responses. The project calendar intentionally shows an unavailable state because this backend branch does not expose Jira issue lists, sprint lists, task due dates or a team-calendar endpoint. Notifications likewise remain an explicit unavailable state because there is no notifications feed endpoint.

### AI Assistant

The Chat UI uses the persisted conversation endpoints:

- `GET /api/assistant/conversations`
- `GET /api/assistant/conversations/{id}/messages`
- `POST /api/assistant/ask`
- `DELETE /api/assistant/conversations/{id}` is available in the API; this current chat screen does not yet expose a delete action.

AI answers and source links come from the backend. No local fake answer is generated. Assistant access is limited by the backend to the employee's company and projects.

### Knowledge Graph limitation

The current public frontend API does not expose a direct, tenant-scoped Neo4j graph query. The displayed graph is therefore explicitly labelled **API-derived** and connects only IDs explicitly returned by the Projects, Clients and Knowledge Sources APIs. It does not invent Jira issue, sprint or employee edges, and it is not represented as a direct Neo4j query.

## Folder structure

```text
src/
  components/
    Chat/              Chat screen and its isolated components/styles/data
    ForgotPassword/    Password-reset flow
    Intro/             Intro experience
    Login/             Sign-in UI and logic
    OTP/               Registration email verification
    Register/          Registration flow
    Workspace/         Dashboard, graph, workspace dialogs and local styles
    common/             Theme toggle and shared status UI
  config/              API base URL and route definitions
  context/             Auth state provider
  services/            API client, tokens, auth and workspace APIs
  router/              Client-side routes
  theme/               Shared light/dark theme controller
  lib/                 Validation and safe redirects
public/assets/          SynTrace brand assets
```

## Mock mode

Real backend mode is the default. `VITE_USE_MOCK_AUTH=true` enables the local mock sign-in only for isolated UI work in a non-production Vite build. It does not connect to real workspace data, and password recovery intentionally requires the real backend. Leave mock mode disabled for end-to-end testing.

## Backend capabilities not exposed to this web client

This integration does not fabricate data for APIs that are absent from the inspected backend branch. In particular: Jira issue/sprint/task calendar data, a direct Neo4j graph endpoint, a notifications feed, and a production GitHub activity experience are not wired as live frontend endpoints here.

## Integrations

See [INTEGRATIONS-SETUP.md](./INTEGRATIONS-SETUP.md) for GitHub App configuration, project repository mapping, Meeting Notes AI extraction/review, and the current Slack backend limitation.

## Deployment under `/web/` (shared Nginx domain)

The React app supports both a root mount and a sub-path mount without changing its route definitions:

- Local development: `VITE_BASE_PATH=/` (the default), e.g. `http://localhost:5173/`.
- Shared-domain deployment: build with `VITE_BASE_PATH=/web/`, then serve the generated `dist/` directory at `/web/`.

The included `.env.production` builds React at `/web/` and points API requests to the team's current ngrok gateway origin. `VITE_API_URL` must be the origin only; the client appends `/api/...` itself. Do not paste a Scalar documentation URL such as `/scalar/v1#tag/...`. When the ngrok hostname changes, update `.env.production`.

When building with the repository-root Docker Compose file, the root `.env` variable `SYNTRACE_REACT_API_URL` (passed as the `VITE_API_URL` build argument) takes priority when non-empty. When it is empty, the Dockerfile unsets the empty argument so Vite reads the included `.env.production` fallback. `SYNTRACE_REACT_BASE_PATH=/web/` continues to control the React mount path.

Vite applies the configured base to generated JS/CSS and public files. The custom history router
adds `/web` to in-app links and navigation and removes it before matching React routes, so route
code continues to use `/`, `/login`, `/app`, etc. Brand images and the pre-paint theme script also
resolve through the configured base path.

**Gateway requirement:** Nginx must serve the React `dist/` output under `/web/` and provide SPA
fallback to `/web/index.html` for React routes such as `/web/login` and `/web/app`. It must continue
to proxy `/api/`, `/hubs/`, `/scalar/`, `/openapi/`, `/health/`, `/gateway-health`, `/jira/callback`,
and `/github/callback` according to the deployment architecture; this frontend change does not
rewrite or claim ownership of those gateway routes.

Example production build:

```bash
cp .env.production.example .env.production
npm ci
npm run build
```

For local work, `.env.development.local` defaults to the remote ngrok API through the Vite proxy. To use the local Docker backend, change `VITE_API_PROXY_TARGET` there to `http://localhost:8081`.

## Local development and API connection

See `FRONTEND-BACKEND-INTEGRATION.md` for the API wiring and environment settings.
