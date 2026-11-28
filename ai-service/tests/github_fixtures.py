"""GitHubAiEvent messages shaped exactly like the backend's (System.Text.Json web defaults: camelCase)."""
import hashlib
import json

REPO_URL = "https://github.com/syntrace-team/SynTrace"
SHA1 = "a" * 40
SHA2 = "b" * 40
HEAD = "c" * 40


def event(kind, entity, version, payload, tenant="c1", project="p1", binding="b1"):
    return {"eventId": f"{binding}:{version}", "eventType": kind, "companyId": tenant, "projectId": project,
            "bindingId": binding, "installationId": 77, "repositoryId": 501, "entityId": entity,
            "sourceVersion": version, "occurredAtUtc": "2026-11-20T10:00:00Z", "payload": payload,
            "schemaVersion": 1}


def commit(version, sha=SHA1, message="SYNT-12 add Google login endpoint\n\nwith token check", **kw):
    return event("github.commit.upserted", sha, version, {
        "sha": sha, "message": message, "authorId": 9, "authorLogin": "zienab-amr",
        "commitDate": "2026-11-19T12:00:00Z", "authoredAt": "2026-11-19T11:00:00Z", "parents": [HEAD],
        "url": f"{REPO_URL}/commit/{sha}",
        "files": [{"path": "backend/AuthController.cs", "previousPath": None, "status": "modified",
                   "additions": 40, "deletions": 3}],
        "filesMayBeIncomplete": False, "jiraKeys": ["SYNT-12"]}, **kw)


def pull_request(version, number=7, merged=True, title="SYNT-12 Google login", **kw):
    return event("github.pull_request.upserted", str(number), version, {
        "number": number, "title": title, "body": "Adds Google sign in. Closes SYNT-12.",
        "state": "closed" if merged else "open", "draft": False, "authorId": 9, "authorLogin": "zienab-amr",
        "headRef": "feature/SYNT-12-google-login", "baseRef": "main", "headSha": SHA1,
        "updatedAt": "2026-11-20T09:00:00Z", "createdAt": "2026-11-18T09:00:00Z",
        "closedAt": "2026-11-20T09:00:00Z" if merged else None, "mergedAt": "2026-11-20T09:00:00Z" if merged else None,
        "mergedById": 9 if merged else None, "mergeCommitSha": SHA2 if merged else None,
        "url": f"{REPO_URL}/pull/{number}", "jiraKeys": ["SYNT-12"],
        "files": [{"path": "backend/AuthController.cs", "previousPath": None, "status": "modified",
                   "additions": 40, "deletions": 3}],
        "filesMayBeIncomplete": False, "commitShas": [SHA1], "commitsMayBeIncomplete": False}, **kw)


def file_id(path):
    return hashlib.sha256(path.encode()).hexdigest()


def code_file(version, path="backend/AuthController.cs", content=None, blob="d" * 40, **kw):
    content = content if content is not None else "\n".join(
        ["public class AuthController {"] + [f"    // line {i}" for i in range(2, 80)]
        + ["    public IActionResult GoogleLogin(string idToken) { return ValidateGoogleToken(idToken); }", "}"])
    lines = content.count("\n") + 1
    return event("github.file.upserted", file_id(path), version, {
        "path": path, "blobSha": blob, "headSha": HEAD, "startLine": 1, "endLine": lines, "content": content,
        "url": f"{REPO_URL}/blob/{HEAD}/{path}#L1-L{lines}"}, **kw)


def file_removed(version, path="backend/AuthController.cs", **kw):
    return event("github.file.removed", file_id(path), version, {"headSha": HEAD}, **kw)


def sync_completed(version, **kw):
    return event("github.sync.completed", "b1", version, {
        "headSha": HEAD, "preparedFiles": 1, "skippedFiles": 2, "partialReasons": ["max_file_bytes"],
        "covers": ["default_branch_commits", "all_pull_requests", "current_default_branch_code"]}, **kw)


def revoked(version, **kw):
    return event("github.repository.revoked", "b1", version, {}, **kw)


def body(e):
    return json.dumps(e).encode()
