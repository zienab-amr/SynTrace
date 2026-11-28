# SynTrace frontend/backend connection status

## What is connected in this frontend package

- All frontend API calls use the root `/api/...` namespace; the React mount path `/web/` is never added to API routes.
- The API base accepts the backend origin only. It trims trailing whitespace (including non-breaking spaces) and strips mistakenly pasted paths such as `/api`, `/scalar/v1`, query strings and Scalar URL fragments.
- Local React development (`npm run dev`) proxies `/api` to the current remote ngrok gateway using `.env.development.local`. The browser calls the Vite dev server, avoiding a browser cross-origin request.
- Production builds use `.env.production`, set `VITE_BASE_PATH=/web/`, and call the provided ngrok gateway origin. The root Docker Compose build argument `SYNTRACE_REACT_API_URL`, when non-empty, overrides the checked-in production fallback.
- Existing auth, refresh-token handling, workspace, Jira/GitHub integration, assistant chat, Meeting AI, project memory, Live Meeting, PDF and Jira-publish client requests all share the same API client and bearer-token flow.
- Chat transcript context is not sent unless `/api/meetings/permissions` confirms `Meetings.UseAgent`.

## Current API origin

`https://jackeline-cibarious-supergallantly.ngrok-free.dev`

This is a public API origin, not a secret. If the ngrok hostname changes, update `.env.development.local` (`VITE_API_PROXY_TARGET`) and `.env.production` (`VITE_API_URL`). Do not append `/api`, `/web`, `/scalar/v1` or a Scalar hash fragment.

## What this package cannot change

This delivery contains `frontend/web` only. The ASP.NET backend and AI service source folders were not present in the local files available for this work, so no server code, database permission, Docker Compose at repository root, or AI-service code was modified. A frontend cannot create a missing backend route. If the remote server returns `404` for `/api/meetings/permissions` or `503` for Meeting endpoints, the matching Meeting API/Gateway and AI Meeting service must already be deployed and enabled on that backend. Regular chat and other existing API routes remain independent of that optional Meeting contract.

If React and the API are ultimately hosted on different origins, the backend CORS policy must allow the React origin and the `Authorization` and `Content-Type` headers. When both are served through the same ngrok Nginx gateway, `/web/` and `/api/` are same-origin and do not require browser CORS.

## Validation performed in this workspace

- TypeScript parser checked 50 `.js`/`.jsx` source files: 0 syntax diagnostics.
- Checked 104 relative imports: 0 unresolved paths (Vite's `intro-markup.html?raw` import was accounted for).
- Tested API-origin normalization with the current ngrok URL plus trailing non-breaking whitespace, a pasted Scalar URL, an `/api/` suffix and an empty value: 4/4 passed.
- `npm run build` could not run because Vite was not installed in the available `node_modules` directory. `npm ci` could not restore packages because the npm registry DNS lookup failed (`EAI_AGAIN`). Run `npm ci` and `npm run build` on the Windows development machine when npm registry access is available.
- No request was made to the live ngrok endpoint from this workspace, so remote availability, sign-in, permissions, Meeting AI extraction, Jira ticket creation and PDF export are not represented as live-tested.
