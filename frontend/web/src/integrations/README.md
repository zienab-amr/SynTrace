# SynTrace Integrations

This feature folder owns the integrations directory UI and its metadata.

- `IntegrationHub.jsx` renders the dedicated Integrations workspace page.
- `integrations.css` styles the directory using existing SynTrace workspace theme tokens.
- `integrationCatalog.js` describes supported integration cards.
- `integrationService.js` exposes the existing authenticated GitHub/Jira API methods and explicitly documents Slack backend availability.

GitHub and Jira use the backend OAuth flows already exposed by SynTrace. Meeting Notes uses the Knowledge Sources API and the configured AI knowledge worker. Slack is displayed as an integration option, but its connect action explains the missing backend contract instead of pretending to authorize an account.
