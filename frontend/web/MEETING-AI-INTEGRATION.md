# SynTrace Meeting AI — frontend integration and backend contract

This folder contains the React Meeting AI workspace and its authenticated API client. It is aligned with the Meeting contract currently on these GitHub feature branches:

- Backend: `feature/meeting-backend-phase-1` — reviewed at `aa311276e89c17273125b29cf28e8068ceaa3905`.
- AI service: `feature/meeting-ai-phase-1` — reviewed at `a0f39aec7ad659bca88ba303d1cdfabb70df25cf`.
- Current integration target: `sprint-4` — reviewed at `4c7468e6ff8cfc6ef34863a385f432b61a352815` (28 November 2026).

**Important deployment state:** the Meeting controller, Gateway and AI meeting contract are not yet present on the reviewed `sprint-4` head. The React page is ready for the feature-branch API contract, but the feature cannot work end-to-end against that `sprint-4` backend until the backend and AI changes are deliberately integrated and deployed.

## What the React page covers

- Submit online/offline transcripts, written notes and text-based PDF files, with date, title, SynTrace project, and optional glossary.
- Show analysis state, summary, generated notes, evidence quotes and line references, rejected evidence count, unresolved references, requirements, decisions, action items, blockers and open questions.
- Show user stories, speaker/owner/due date, priority and priority evidence, category/clarity, clarification questions, client-spoken acceptance criteria and separately-labelled AI suggestions.
- Review individual meeting items; confirm only AI-suggested Jira links; edit or request an AI rewrite of the meeting document; approve an empty analysis explicitly.
- Browse a project's meetings, retry failed analysis using the same source ID, delete a meeting, and create a correction linked to an approved meeting through `linkedSourceId`.
- Browse approved requirement lifecycle history and open questions; edit a requirement while retaining its change history.
- Run a dedicated live session with incremental transcript context, questions, dismissible suggestions, wrap-up and send-to-review.
- Use the same authenticated chat conversation for live meeting context: send **new transcript segments only**; the AI chat retains the project and transcript for that conversation, and “Finish meeting” triggers its wrap-up/end flow.
- Export requirements PDF only after approval; separately approve a Jira draft and explicitly publish it to Jira. The UI reports failed subtasks instead of claiming they were all created.

The component is permission-aware, but the backend remains the security boundary and re-checks the current grants, tenant and project scope on every request.

## Project identifiers

The create, list, live-session and memory routes accept the project identifier resolved by the backend scope. In this React workspace the project selector submits the SynTrace `ProjectId` (`projectId`/`id` from `/api/projects`), not a Jira project key chosen by the browser. The Gateway maps and verifies it against the signed-in employee's allowed Jira/SynTrace project scope. Do not replace this with free-text Jira-key entry.

## API routes used

All routes are relative to `/api/meetings` and use the existing authenticated API client:

| Method | Route | Purpose |
|---|---|---|
| GET | `/permissions` | Current employee's meeting permissions |
| POST | `/` | Create online/offline/note/PDF source; correction uses `linkedSourceId` |
| GET | `/{id}` | Meeting source, analysis and extracted items |
| GET / PUT | `/{id}/document` | Read/update review document |
| POST | `/{id}/document/rewrite` | Request a constrained AI rewrite |
| POST | `/{id}/review` | Approve/delete item and draft IDs; confirm suggested Jira links |
| GET | `/{id}/requirements.pdf` | Export an approved meeting's requirements |
| POST | `/{id}/retry` | Retry only a failed source, preserving its source ID |
| DELETE | `/{id}` | Delete source and replay project memory |
| GET | `/?projectKey=...&status=...` | Project meeting list |
| GET | `/projects/{projectKey}/requirements?q=...` | Requirement lifecycle history |
| PATCH | `/requirements/{requirementId}` | Edit a requirement with history |
| GET | `/projects/{projectKey}/open-questions` | Questions still open after approved meetings |
| POST / GET | `/live` and `/live/{sessionId}` | Start/read live session |
| POST | `/live/{sessionId}/assist` | Analyze transcript-so-far, question and dismissed suggestions |
| POST | `/live/{sessionId}/wrap-up` | Check remaining gaps before ending |
| POST / DELETE | `/live/{sessionId}/end` and `/live/{sessionId}` | End (optionally submit transcript) or discard session |
| POST | `/{id}/drafts/{draftId}/publish` | Create a Jira issue from an approved draft |

The assistant chat uses the existing `/api/assistant/ask` endpoint with `transcript` and `meetingDate`. Transcript segments sent through chat are incremental; the dedicated live-session endpoint expects the complete transcript-so-far on each assist call.

## Permission names used by the UI

- `Meetings.Create` + `Meetings.ReadPending`: submit/correct/retry and send live transcript for review.
- `Meetings.ReadPending`: view pending work.
- `Meetings.ReadApproved`: browse approved items, project memory and open questions.
- `Meetings.Approve`: submit item/draft review.
- `Meetings.Edit`: edit requirements and pending meeting documents.
- `Meetings.UseAgent`: request document rewrite.
- `Meetings.Delete`: delete meetings.
- `Meetings.ExportPdf`: export approved PDF (also requires `Meetings.ReadApproved`).
- `Meetings.ManageLiveSessions`: start/assist/end/discard dedicated live sessions.
- `Meetings.PublishJiraTasks`: publish approved drafts (also requires `Meetings.ReadApproved`).

Role grants are managed by the backend's admin-only `/api/roles/{roleId}/meeting-permissions` endpoint. The React page does not silently grant permissions.

## Backend integration needed before end-to-end testing

1. Integrate the matching Meeting API/Gateway/permission/draft-publisher changes from `feature/meeting-backend-phase-1` into the backend that will be deployed. Do not merge this branch blindly; review conflicts with the current `sprint-4` backend first.
2. Integrate the corresponding AI service Meeting modules and `/meetings`, `/live-sessions`, requirement-history and chat-meeting routes from `feature/meeting-ai-phase-1` into the deployed AI service.
3. Set `AiService:BaseUrl` and `AiService:ApiKey` in the backend environment. The AI service must accept the same internal key.
4. Add/pass `AiService:EnableMeetingContract=true` only after both matching deployments are available. The option defaults to `false`; with it disabled the Gateway intentionally returns HTTP 503 for Meeting routes.
5. Build and deploy React with the existing same-origin API path. For the shared gateway deployment, keep `VITE_BASE_PATH=/web/` and leave `VITE_API_URL` empty so `/api/...` is sent to the root gateway, not `/web/api`.
6. Assign the necessary Meeting permissions to the intended roles and confirm the company Jira integration is connected before testing Jira publishing.

The current `sprint-4` `docker-compose.yml` and `.env.example` do not yet expose/pass the Meeting contract feature flag. The latest `sprint-4` head does include SMTP/GitHub deployment variables and the Flutter build flag; this frontend-only package deliberately does not change any Flutter files. This is a backend/deployment integration task, not a React setting. Do not enable the flag against an older AI service.

## Verified contract caveats / backend follow-ups

These are important issues found by comparing the feature branches. The React page contains safeguards where possible, but these are not fixed by frontend code alone:

1. **Accepted proposal → generated Jira draft approval lifecycle.** The AI review flow creates drafts for an accepted `Proposed:` item after `_write_review` has completed. If that same review makes the meeting fully approved, the new draft is left `pending`; the Gateway's review route only accepts a meeting in `pending_review`, while the Jira publisher requires the draft itself to be `approved`. There is no separate draft-review route for an already-approved meeting. The React UI prevents final approval of the last proposal when it has no draft yet and asks the reviewer to leave another item pending, but the backend needs a proper draft-review route or an atomic/staged draft-generation design to remove this workaround.
2. **Stale draft enforcement.** AI returns `draft.stale`, and React blocks publication of stale drafts. The reviewed backend `MeetingDraftPublisher.FindDraft` checks approval, item review and already-published state, but does not reject `stale=true`. Add the same stale check server-side (409) before creating a Jira issue; UI-only protection is not sufficient.
3. **ReadPending-only meeting list scope.** The reviewed Gateway narrows the meeting list to approved records when the employee lacks `Meetings.ReadPending`, but it does not narrow the response when an employee has `Meetings.ReadPending` and lacks `Meetings.ReadApproved`. That can disclose approved-meeting metadata in the list even though opening those records is rejected by `GetAsync`. React filters out rows it cannot open, but the Gateway/AI list response must enforce readable statuses server-side.
4. **Source references vs item references.** `answeredBy[].id` and `relatedEarlier[].id` returned by AI are MeetingItem IDs, not meeting source IDs. React displays these as evidence references and does not call `GET /meetings/{id}` with them.
5. **Flutter Docker feature gate.** The latest Flutter repository contains the Meeting AI screens, but `MeetingContractRepository.enabled` depends on `ENABLE_MEETING_CONTRACT`. The reviewed `mobile/Dockerfile` does not pass `--dart-define=ENABLE_MEETING_CONTRACT=true`, and the root Compose Flutter build args do not expose that flag. As a result, the Flutter Meeting AI button stays hidden in that Docker build unless the Flutter build is updated. This React-only delivery does not modify Flutter.

## Latest verification update — 28 November 2026

- Latest `sprint-4` head: `4c7468e6ff8cfc6ef34863a385f432b61a352815`.
- Meeting backend head: `aa311276e89c17273125b29cf28e8068ceaa3905`. A compare against the current sprint head shows 4 commits unique to the feature branch and 89 commits on the sprint branch that are not in the feature branch. It shares an older base; this is not a safe whole-branch merge without conflict resolution and integration tests.
- Meeting AI head: `a0f39aec7ad659bca88ba303d1cdfabb70df25cf`. It shares a much newer base with sprint-4 (one current sprint commit ahead of its common base), but contains a substantial AI service package move and many new tests. Integrate this service refactor as a coherent change rather than copying isolated files into the old flat `ai-service` layout.
- Current `sprint-4` backend tree still has no `MeetingsController`, `MeetingPermissionsController` or Meeting Gateway services. The `AiServiceOptions` class also does not expose `EnableMeetingContract` there. This is why Meeting API buttons cannot work end-to-end against the current sprint deployment, even when the React page is correct.

### Frontend interaction fixes included in this package

- Slack controls are disabled and explicitly labelled as requiring backend setup. The old click path only showed a toast; it did not authorize Slack or create a connection.
- The chat `Finish meeting` action stays disabled until a transcript segment exists, avoiding a request that cannot submit useful meeting content.
- Chat answer copying now uses the Clipboard API when available and falls back to a temporary textarea for browsers that block `navigator.clipboard`; it reports a failure instead of silently pretending to copy.
- Existing SSO controls remain visibly disabled as coming soon; they are not presented as live authentication integrations.

### Required backend fixes before rollout

1. **Review Jira drafts after source approval.** The AI review path creates draft records after the item-approval transaction. When that same review approves the final pending item, the source changes to `approved`, and the next review call rejects the source because it is no longer pending. Add a separate authenticated draft-review operation for approved sources (or redesign the flow so draft creation and approval are atomic). Do not run project-memory application a second time when reviewing only a draft.
2. **Reject stale Jira drafts server-side.** `MeetingDraftPublisher.FindDraft` must return HTTP 409 when a draft has `stale=true`, before creating any Jira issue. The UI check is only a usability safeguard.
3. **Enforce list visibility in the Gateway.** A user with `Meetings.ReadPending` but without `Meetings.ReadApproved` must not receive approved meeting records in an unfiltered list. Reject explicit `status=approved` and return only processing/pending_review/failed records (or apply an equivalent server-side filter).
4. **Register and configure the feature flag.** Add `AiService:EnableMeetingContract` to the current sprint's options and expose `AiService__EnableMeetingContract` in deployment configuration. Keep it `false` until the matching AI service contract is deployed and validated.
5. **Integrate both server-side branches safely.** The backend branch is 4 commits ahead but 89 behind the current sprint head. Rebase/cherry-pick its Meeting-specific commits onto a fresh branch from current `sprint-4`, resolve conflicts, run backend integration checks and review all assistant/identity changes. The AI branch is a separate larger refactor and must be integrated/tested as a coherent AI-service update. Do not merge either branch blindly.

## Validation status

- JavaScript/JSX syntax check: 50 source JS/JSX files parsed with TypeScript transpilation; no syntax diagnostics were reported.
- Relative import check: 120 relative imports checked; no unresolved source paths.
- `npm run build` could not run because `vite` is not installed in the isolated workspace. An offline `npm ci` cannot download it because the package tarball is not cached and the environment has no registry network access.
- The current source tree contains the interaction fixes documented in `FRONTEND-REPAIR-NOTES.md`; this does not prove a browser-level test of the hosted application.
- A production `vite build` still requires installing the exact dependencies from `package-lock.json`; do not interpret a syntax-only check as a full production build.
- The backend feature branch includes a `MeetingContractChecks.cs` integration-check harness, but it was not run in this review.
- A live end-to-end test requires the integrated backend, the matching AI service, a user with the required permission grants, an accessible project and a company Jira connection for publishing. This frontend package alone cannot prove those server-side conditions.
