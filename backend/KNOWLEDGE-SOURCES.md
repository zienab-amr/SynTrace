# Documentation, requirements and meeting notes

A source belongs to one SynTrace client. A project can be selected during creation or linked later. When a project is selected, it must belong to that client and company. Create the client first if this is the first meeting. For in-person meetings, record the notes under `MeetingNotes` with mode `InPerson`. For online meetings, paste notes or an exported transcript, or upload a supported file, with mode `Online`.

## User API

Send the SynTrace JWT in the Authorization header. All paths below use `/api/knowledge/sources` as the prefix.

| Method and path | Purpose |
| --- | --- |
| `POST /` | Create a source from text. |
| `POST /upload` | Create a source using multipart form fields and one `file`. |
| `GET /?clientId=…&projectId=…&skip=0&take=20` | List sources available to the caller. Filters are optional. |
| `GET /{id}?version=1` | Read a specific version, or omit `version` for the default version available to the caller. |
| `POST /{id}/versions` and `POST /{id}/versions/upload` | Add a version using `expectedVersion` from the last read, a title and the new content. Supply meeting metadata again for meeting notes. |
| `POST /{id}/versions/{version}/extraction` | Submit extracted evidence manually. |
| `POST /{id}/versions/{version}/retry` | Return a failed extraction to the extraction queue. |
| `POST /{id}/versions/{version}/review` | Review evidence and publish approved items or reject the version. |
| `PUT /{id}/project` | Attach a client-only source to a project using `{"projectId":"…"}`. Project publication requires review under the new scope. |
| `DELETE /{id}` | Withdraw the source and invalidate its publication. |

Example JSON for the first meeting with a client before a project exists.

```json
{
  "clientId": "replace-with-client-id",
  "kind": "MeetingNotes",
  "title": "Initial requirements meeting",
  "text": "Users must be able to export a PDF report.",
  "meetingMode": "InPerson",
  "meetingAt": "2026-11-20T10:00:00+02:00"
}
```

Use `Documentation`, `Requirements` or `MeetingNotes` for `kind`. `meetingMode` and `meetingAt` apply to and are required for `MeetingNotes`. Text input accepts up to 256,000 characters. For multipart uploads, pass the same metadata fields and use `file` for a UTF-8 `.txt` or `.md` file, or a PDF up to 5 MiB. The backend stores the PDF and needs a transcript from the extractor or manual processing before matching quotes. Online notes use a supplied transcript or file. Automatic recording and meeting-provider integrations are outside this backend feature.

The source author and project reviewers can work on draft versions and view source transcripts. To give an existing project member review access, a company admin can set the member's project role to `ProductOwner` or `ProjectManager` in the project membership API. Company admins can review all company sources. With no project selected, client-only sources are available to company admins and company-level `Product Owner` and `Project Manager` roles. Other project members can read the approved evidence from the current publication.

Extraction accepts kinds `Requirement`, `Decision`, `ActionItem`, `OpenQuestion` and `Blocker`. Each entry needs a short `text` summary and a verbatim `quote` from the source. For PDF inputs, submit `extractedText` with the transcript. A failed extraction can use `failureCode` set to `Unreadable`, `ExtractionUnavailable` or `TimedOut`. Omit `items` and `extractedText` when reporting failure.

```json
{
  "items": [
    {
      "kind": "Requirement",
      "text": "Support PDF report export",
      "quote": "Users must be able to export a PDF report."
    }
  ]
}
```

Review a version by reading it to get its evidence IDs. Send exactly one decision per item. `publish: true` requires at least one approved item. A review with `publish: false` rejects the version. The previous approved version stays available until a new version is published or the source is withdrawn.

```json
{
  "decisions": [{ "id": "replace-with-evidence-guid", "approve": true }],
  "publish": true
}
```

## Extraction and graph handoff

The AI service sends `X-Internal-Api-Key` using the shared `AiService__ApiKey` configuration. Use the internal API on the private network with server-side credentials. This backend provides the handoff endpoints. Extraction, PDF parsing and writing to the external knowledge graph belong to the AI service.

1. Poll `GET /api/internal/knowledge/pending?companyId=…&take=5` for each authorized company. For PDF jobs, download the original with `GET /api/internal/knowledge/sources/{id}/versions/{version}/pdf?companyId=…`.
2. Submit extracted items or a failure to `POST /api/internal/knowledge/sources/{id}/versions/{version}/extraction?companyId=…`. The response moves a successful extraction to `AwaitingReview`. A `409` indicates that another submission or source change has already superseded the job.
3. Maintain a cursor per company for `GET /api/internal/knowledge/changes?companyId=…&after=0&take=20`. Each change carries source ID, version and project ID. For a publication, fetch `GET /api/internal/knowledge/sources/{id}/versions/{version}/published?companyId=…&projectId=…` and replace graph evidence under the company, project and source key. If this exact version returns `404`, a later update has superseded it. A withdrawn change has `removed: true` and requires deleting evidence for that company, project and source. Advance the cursor after applying a change so an interrupted poll can replay the change safely.
4. Store source ID, version, evidence ID, quote and `quoteOffset` with each graph record for traceability. `quoteOffset` counts UTF-16 code units from the start of the text. Index approved evidence only.
