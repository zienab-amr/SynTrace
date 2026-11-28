# SynTrace React ↔ ASP.NET API integration

This package contains the React frontend only. It does not modify ASP.NET, the AI service, Docker Compose at repository root, or any Flutter files.

## Local development

- The React app calls root-relative `/api/...` endpoints.
- `npm run dev` uses the Vite proxy to forward `/api` to `http://localhost:8081` by default.
- Set `VITE_API_PROXY_TARGET` to a different local backend origin when needed.
- Keep `VITE_API_URL` empty when using the proxy. To call a separately hosted API directly, set `VITE_API_URL` to its origin only, with no `/api`, `/web`, or `/scalar/v1` suffix.
- In production behind the shared gateway, leave `VITE_API_URL` empty and use `VITE_BASE_PATH=/web/`. Nginx should route `/api/` to ASP.NET and `/web/` to this React app.

## Meeting API routes consumed by React

All endpoints below are relative to the API root and use the user's bearer token through `apiClient.js`.

| Method | Route | React action |
|---|---|---|
| GET | `/api/meetings/permissions` | Load the signed-in user's meeting permissions |
| POST | `/api/meetings` | Submit an online/offline transcript, notes, or PDF |
| GET | `/api/meetings/{id}` | Poll or open analysis results |
| GET / PUT | `/api/meetings/{id}/document` | Load or save the review document |
| POST | `/api/meetings/{id}/document/rewrite` | Request an AI rewrite proposal |
| POST | `/api/meetings/{id}/review` | Approve/delete item or draft IDs and confirm Jira links |
| POST | `/api/meetings/{id}/retry` | Retry a failed source |
| DELETE | `/api/meetings/{id}` | Delete a meeting source |
| GET | `/api/meetings?projectKey=...&status=...` | List project meetings |
| GET | `/api/meetings/projects/{projectKey}/requirements?q=...` | Read project requirement history |
| PATCH | `/api/meetings/requirements/{requirementId}` | Edit a requirement |
| GET | `/api/meetings/projects/{projectKey}/open-questions` | Read open questions |
| POST | `/api/meetings/live` | Start a live session |
| GET | `/api/meetings/live/{sessionId}` | Read a live session |
| POST | `/api/meetings/live/{sessionId}/assist` | Analyze the transcript-so-far |
| POST | `/api/meetings/live/{sessionId}/wrap-up` | Check for gaps before ending |
| POST | `/api/meetings/live/{sessionId}/end` | End and optionally submit transcript for review |
| DELETE | `/api/meetings/live/{sessionId}` | Discard a live session |
| POST | `/api/meetings/{id}/drafts/{draftId}/publish` | Publish an approved Jira draft |
| GET | `/api/meetings/{id}/requirements.pdf` | Download the approved requirements PDF |

The project selector sends SynTrace `ProjectId` values returned by `/api/projects`; the browser does not invent Jira project keys. The backend must validate the selected project against the authenticated employee's scope.

## Chat meeting context

The existing `/api/assistant/ask` call can carry `transcript` and `meetingDate` only when the deployed backend and AI service implement the matching meeting-chat contract. React checks `/api/meetings/permissions` first and only enables transcript context when the response includes `Meetings.UseAgent`. Ordinary assistant chat remains available if the optional Meeting contract is absent.

The chat sends only the newly pasted transcript segment. The dedicated Live Meeting Assistant sends the complete transcript-so-far to `/api/meetings/live/{sessionId}/assist`.

## Required server configuration

The backend must expose the Meeting routes above, pass the selected project scope and current role permissions, and call the matching AI service with its internal API key. If the server uses a feature flag for this contract, enable it only when its Meeting routes and matching AI service implementation are deployed together. React intentionally does not contain internal service credentials and cannot enable a server-side feature flag.

## Known workflow constraints

- The API must let the user review Jira drafts after the meeting's extracted items have been approved. A server that only allows review while the source is `pending_review` can strand a newly generated draft after the final item is approved. The React UI prevents finalizing the last accepted proposal before its draft exists, but a separate backend draft-review route is the complete fix.
- Jira publication must reject a draft marked `stale` on the server, not only in React.
- The meeting-list endpoint must filter rows by the caller's `ReadApproved` and `ReadPending` permissions before returning data. React applies a second visibility filter, but it is not a substitute for server-side authorization.

## What was not possible to verify in this frontend-only workspace

The local workspace available for this task contains `frontend/web` and its earlier frontend archives; it does not contain the ASP.NET backend or AI-service source folders. Therefore the React API wiring can be checked locally, but server builds, database permissions, AI service calls, Jira issue creation, and live end-to-end workflows cannot honestly be marked as tested from this package alone.

## Current remote ngrok backend configuration

The frontend package is configured for the team's current gateway origin:

`https://jackeline-cibarious-supergallantly.ngrok-free.dev`

- During `npm run dev`, `.env.development.local` leaves `VITE_API_URL` empty and sets `VITE_API_PROXY_TARGET` to the ngrok origin. The browser calls local `/api/...`, and Vite forwards those requests to the remote gateway. This avoids browser CORS for local development.
- For production builds, `.env.production` sets `VITE_BASE_PATH=/web/` and `VITE_API_URL` to the ngrok origin. The shared gateway must route `/web/` to React and `/api/` to ASP.NET.
- The API base must be the origin only. `src/config/api.js` now trims whitespace (including non-breaking spaces) and strips accidentally pasted paths, query strings or Scalar fragments before appending `/api/...`.
- If the ngrok hostname changes, update both `.env.development.local` and `.env.production`. If the frontend and backend are hosted on different origins rather than the same shared gateway, the backend CORS policy must allow the frontend origin and the required `Authorization` and `Content-Type` headers.
