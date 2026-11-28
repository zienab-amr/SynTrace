# Frontend repair notes — 28 November 2026

Scope: `frontend/web` only. No Flutter/mobile source or GitHub branch was changed.

## Interaction changes

1. **Slack integration:** replaced the misleading enabled “Connect Slack” CTA with a disabled “Unavailable” state. The previously wired action only produced a toast; it did not perform OAuth or connect an account. The dashboard's Slack action is disabled for the same reason.
2. **Chat meeting completion:** “Finish meeting” is disabled until a transcript segment is present, so the UI does not submit a finish request without any meeting content.
3. **Copy assistant answer:** the copy action tries `navigator.clipboard.writeText`, falls back to a temporary textarea when the Clipboard API is unavailable or rejects the request, and displays “Copy unavailable” if both methods fail.
4. **Honest setup states:** the existing SSO buttons remain disabled as “Coming soon”; Slack is not shown as a working integration without a server-side OAuth flow.

No redesign was made. The changes correct control behavior and communicate unavailable backend capabilities.

## Checks performed

- TypeScript parser syntax pass: 50 `.js`/`.jsx` source files, zero syntax diagnostics.
- Relative import check: 120 relative imports, zero unresolved paths (Vite `?raw` HTML import accounted for).
- `npm run build`: could not run because `vite` is not installed in this isolated copy. `npm ci --offline` also cannot install it because the package tarball is not cached and this environment has no package-registry network access.
- ZIP integrity: checked with `unzip -t` after packaging.

This is not an end-to-end certification. Meeting AI, project-memory, live-session, PDF and Jira-publishing actions still require the matching Meeting backend and AI service branches to be integrated and deployed. See `BACKEND-INTEGRATION-REQUIRED.md` and `MEETING-AI-INTEGRATION.md`.


## Remote backend connection pass — 28 November 2026

- Added `.env.development.local`: local Vite `/api` requests proxy to the team's remote ngrok gateway, avoiding browser CORS during local frontend development.
- Added `.env.production`: React is built at `/web/` and uses `https://jackeline-cibarious-supergallantly.ngrok-free.dev` as the backend origin.
- Updated the Dockerfile so an empty Compose `VITE_API_URL` build argument does not override the `.env.production` fallback; a non-empty root `SYNTRACE_REACT_API_URL` still wins.
- Allowed `.env.production` through `.dockerignore` so Docker can read it at build time.
- Hardened API origin parsing: whitespace including non-breaking spaces is trimmed, and a wrongly pasted `/api` or Scalar path/query/hash is normalized to the origin.
- Current syntax/import validation: 50 JS/JSX source files parsed with 0 syntax diagnostics; 104 relative imports checked with 0 unresolved paths.
- Production build remains unverified because the npm registry could not resolve (`EAI_AGAIN`) and Vite is not installed in this isolated workspace. No live call to the ngrok endpoint was made.
- This is a frontend-only delivery: no ASP.NET/AI source was present locally to modify. See `INTEGRATION-STATUS.md` for the server-side boundary.
