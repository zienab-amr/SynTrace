# Authentication flow compatibility fix

The integrated frontend previously rejected a successful `GET /api/Employee/me` response unless the returned employee DTO contained both `id` and `companyId` as top-level camelCase/PascalCase properties. The frontend does not use `companyId` as an authentication prerequisite, so that check could discard valid sessions even when both login and the current-employee endpoint returned HTTP 200.

The authentication mapper now:

- accepts direct employee DTOs and common `data`, `employee`, `result`, `value`, or `payload` envelopes;
- recognizes common employee/user ID and profile field casing variants;
- normalizes role strings and role objects without assuming `roles` is always an array;
- treats `companyId` as optional for sign-in;
- falls back to the email entered at login when the current-employee DTO omits an email field;
- normalizes direct or wrapped camelCase/PascalCase access and refresh token responses, including refresh responses.

No backend, mobile/Flutter, GitHub, Docker Compose, or visual-design files were changed. This change is validated with Node syntax checks and focused mapper tests for direct and wrapped DTO/token shapes. A full Vite production build was not run because dependencies are not installed in this environment and no cached Vite package was available.
