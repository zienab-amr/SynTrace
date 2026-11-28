# SynTrace integrations (frontend)

The workspace dashboard now uses the GitHub App endpoints exposed by the current backend branch:

- `GET /api/integrations/github/connect`
- `GET /api/integrations/github/company`
- `GET /api/integrations/github/pending`
- `POST /api/integrations/github/complete`
- `GET /api/integrations/github/repositories`
- `GET /api/integrations/github/projects/{projectId}`
- `PUT|DELETE /api/integrations/github/projects/{projectId}/repository`
- `POST /api/integrations/github/projects/{projectId}/sync`

The GitHub company connection and repository mapping controls require a company Admin. The backend must be configured with a GitHub App before the Connect button can complete OAuth. The repository's Docker Compose configuration reads these values from the root `.env` file:

- `SYNTRACE_GITHUB_APP_ID`
- `SYNTRACE_GITHUB_APP_SLUG`
- `SYNTRACE_GITHUB_CLIENT_ID`
- `SYNTRACE_GITHUB_CLIENT_SECRET`
- `SYNTRACE_GITHUB_WEBHOOK_SECRET`
- `SYNTRACE_GITHUB_REDIRECT_URI`
- `SYNTRACE_GITHUB_FRONTEND_REDIRECT_URI` (normally `http://localhost:5173/app` for Vite's default local port)
- `SYNTRACE_GITHUB_PRIVATE_KEY_FILE` (absolute path to the GitHub App PEM file)
- `SYNTRACE_GITHUB_SYNC_ENABLED=true`

Keep the PEM file and secrets out of the frontend and out of source control. After changing root `.env`, recreate the backend and worker containers.

## Meeting Notes

Meeting Notes use the authenticated `POST /api/knowledge/sources` endpoint with `kind: "MeetingNotes"`, a project/client scope, meeting mode/date, and the original text. The backend knowledge worker extracts evidence asynchronously. The dashboard can inspect the source and evidence, retry failed extraction, and let eligible reviewers approve evidence before publishing it. The original transcript remains separate from extracted evidence. In the AI Docker profile, keep the `ai-knowledge-worker` service running; it polls pending sources, submits AI evidence for review, and indexes only approved/published evidence into the knowledge graph.

## Slack

The current backend branch does not expose Slack OAuth, callback, workspace status, token storage, event subscription, or sync endpoints. The dashboard therefore shows a setup-required action and does not pretend Slack is connected or store OAuth credentials in the browser. A real Slack integration requires backend implementation and Slack app credentials before the button can initiate a secure connection.
