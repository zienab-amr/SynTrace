"""
github_graph.py
The team's GitHub repositories in the graph, from the backend's GitHubAiEvent messages
(queue syntrace.ai.github), and the read-only queries the assistant uses.

Events, in sourceVersion order per repository binding (a retry can deliver an older one late):
  github.commit.upserted        default-branch commit: message, author, files, jiraKeys
  github.pull_request.upserted  pull request: title, body, state, merge, branches, files, commits, jiraKeys
  github.file.upserted          one code file of the default branch, with its content
  github.file.removed           the file left the default branch
  github.sync.completed         a full pass over the repository finished
  github.repository.revoked     the repository was unbound or access was lost: forget all of it

Graph (every node has tenant_id, syntrace_project_id, binding_id, source_version):
  (:GitHubRepository {uid, full_name, head_sha, last_sync_at})
  (:Commit {sha, message, author_login, committed_at, url, jira_keys, file_paths})-[:IN_REPO]->(repo)
  (:PullRequest {number, title, body, state, merged, merged_at, head_ref, base_ref, url, jira_keys,
                 commit_shas, file_paths})-[:IN_REPO]->(repo)
  (:CodeFile {path, blob_sha, url, line_count})-[:IN_REPO]->(repo), -[:HAS_CHUNK]->(:CodeChunk {text,
                 start_line, end_line, url, embedding})
Tickets are matched by key at query time (jira_keys), so a ticket created after its commit still
finds it. A node only changes for a newer source_version; a removed file stays as a small tombstone
so a late older event can't bring it back. Search is scoped by the SynTrace project ids the backend
allows for the asker; with none, GitHub data is not searched (deny by default).
"""
import logging
import math
import re
from datetime import datetime, timedelta, timezone

log = logging.getLogger("syntrace.github")

GITHUB_LABELS = ("GitHubRepository", "Commit", "PullRequest", "CodeFile", "CodeChunk", "GitHubRevoked")
CHUNK_LINES = 60
CHUNK_OVERLAP = 10
CHUNK_CHARS = 2400
MAX_BODY = 4000
MAX_LIST = 300
SEARCH_MIN_SCORE = 0.35
_SHA = re.compile(r"^[0-9a-f]{40}$")
_KEY = re.compile(r"^[A-Z][A-Z0-9_]{1,31}-[0-9]{1,12}$")


class BadEvent(ValueError):
    """A message that can never be applied: it goes to the dead-letter queue."""


# ---------- 1. Events ----------

def _str(value, limit=None):
    if value is None:
        return None
    value = str(value)
    return value[:limit] if limit else value


def _keys(values):
    out = []
    for v in values or []:
        v = str(v).upper()
        if _KEY.match(v) and v not in out:
            out.append(v)
    return out[:30]


def _files(files):
    paths, added, deleted = [], 0, 0
    for f in files or []:
        if not isinstance(f, dict):
            continue
        if f.get("path"):
            paths.append(str(f["path"])[:1024])
        added += int(f.get("additions") or 0)
        deleted += int(f.get("deletions") or 0)
    return paths[:MAX_LIST], added, deleted


def _full_name(url):
    match = re.match(r"https://github\.com/([^/]+)/([^/#?]+)", url or "")
    return f"{match.group(1)}/{match.group(2)}" if match else None


def parse_event(event):
    """-> a checked event dict, or BadEvent."""
    if not isinstance(event, dict):
        raise BadEvent("not an object")
    out = {k: event.get(k) for k in ("eventType", "companyId", "projectId", "bindingId", "entityId", "occurredAtUtc")}
    for field in ("eventType", "companyId", "projectId", "bindingId", "entityId"):
        if not isinstance(out[field], str) or not out[field].strip():
            raise BadEvent(f"{field} is required")
    try:
        out["sourceVersion"] = int(event.get("sourceVersion"))
        out["repositoryId"] = int(event.get("repositoryId") or 0)
    except (TypeError, ValueError):
        raise BadEvent("sourceVersion must be a number") from None
    payload = event.get("payload")
    out["payload"] = payload if isinstance(payload, dict) else {}
    return out


def _base(e):
    tenant, binding = e["companyId"], e["bindingId"]
    return {"tenant_id": tenant, "syntrace_project_id": e["projectId"], "binding_id": binding,
            "repository_id": e["repositoryId"], "source_version": e["sourceVersion"],
            "updated_at": e.get("occurredAtUtc") or datetime.now(timezone.utc).isoformat()}


def _hash(text):
    import hashlib
    return hashlib.sha1(text.encode("utf-8")).hexdigest()


def uid(tenant, binding, kind, entity=None):
    return f"{tenant}:github:{binding}:{kind}" + (f":{entity}" if entity is not None else "")


def chunks(code, path, url):
    """Overlapping line windows, each with its own line range and link."""
    lines = (code or "").splitlines()
    base = (url or "").split("#")[0]
    out, start = [], 0
    while start < len(lines):
        end = min(len(lines), start + CHUNK_LINES)
        text = "\n".join(lines[start:end])
        while len(text) > CHUNK_CHARS and end - start > 5:   # long lines: a smaller window
            end = start + max(5, (end - start) // 2)
            text = "\n".join(lines[start:end])
        if text.strip():
            out.append({"start_line": start + 1, "end_line": end, "text": text[:CHUNK_CHARS],
                        "url": f"{base}#L{start + 1}-L{end}" if base else None})
        if end >= len(lines):
            break
        start = max(end - CHUNK_OVERLAP, start + 1)
    return out


_NEWER = "WITH n WHERE n.source_version IS NULL OR n.source_version < $props.source_version "

UPSERT = ("MERGE (n:{label} {{uid: $uid}}) " + _NEWER +
          "SET n += $props REMOVE n.removed "
          "SET n.needs_embedding = coalesce(n.embedded_hash, '') <> coalesce(n.embed_hash, '') "
          "WITH n MATCH (r:GitHubRepository {{uid: $repo}}) MERGE (n)-[:IN_REPO]->(r) RETURN n.uid AS uid")


def _follow_project(tx, tenant, binding, repo, e, base):
    """The repository was bound to another SynTrace project: everything it brought moves with it, so
    nobody keeps seeing it through the old project. An older event keeps the newer project."""
    row = tx.run("MATCH (r:GitHubRepository {uid: $uid}) RETURN r.syntrace_project_id AS p, "
                 "coalesce(r.scope_version, -1) AS sv", uid=repo).single()
    v, wanted = e["sourceVersion"], e["projectId"]
    if not row or not row["p"]:
        tx.run("MERGE (r:GitHubRepository {uid: $uid}) SET r.scope_version = $v", uid=repo, v=v)
        return
    if row["p"] == wanted:
        return
    if v < row["sv"]:
        base["syntrace_project_id"] = row["p"]     # a late event from before the move
        return
    for label in GITHUB_LABELS:
        tx.run(f"MATCH (n:{label}) WHERE n.tenant_id = $t AND n.binding_id = $b SET n.syntrace_project_id = $p",
               t=tenant, b=binding, p=wanted)
    tx.run("MATCH (r:GitHubRepository {uid: $uid}) SET r.scope_version = $v", uid=repo, v=v)


def apply_event(tx, raw):
    """Apply one event in one transaction. -> what happened: upserted, removed, stale, completed,
    revoked or ignored."""
    e = parse_event(raw)
    kind, tenant, binding, v = e["eventType"], e["companyId"], e["bindingId"], e["sourceVersion"]
    base = _base(e)
    revoked = tx.run("MATCH (m:GitHubRevoked {uid: $uid}) RETURN m.source_version AS v",
                     uid=uid(tenant, binding, "revoked")).single()
    if revoked and revoked["v"] is not None and revoked["v"] >= v:
        return "stale"            # older than the revocation: its data is already gone

    if kind == "github.repository.revoked":
        tx.run("MATCH (n) WHERE n.tenant_id = $t AND n.binding_id = $b AND any(l IN labels(n) WHERE l IN $labels) "
               "DETACH DELETE n", t=tenant, b=binding, labels=list(GITHUB_LABELS))
        tx.run("MERGE (m:GitHubRevoked {uid: $uid}) SET m += $props", uid=uid(tenant, binding, "revoked"), props=base)
        return "revoked"

    repo = uid(tenant, binding, "repo")
    payload = e["payload"]
    _follow_project(tx, tenant, binding, repo, e, base)
    repo_props = {k: base[k] for k in ("tenant_id", "syntrace_project_id", "binding_id", "repository_id")}
    name = _full_name(payload.get("url"))
    if name:
        repo_props["full_name"] = name
    tx.run("MERGE (r:GitHubRepository {uid: $uid}) SET r += $props", uid=repo, props=repo_props)

    if kind == "github.commit.upserted":
        sha = str(payload.get("sha") or e["entityId"]).lower()
        if not _SHA.match(sha):
            raise BadEvent("commit sha is invalid")
        paths, added, deleted = _files(payload.get("files"))
        message = _str(payload.get("message"), MAX_BODY) or ""
        props = dict(base, sha=sha, short_sha=sha[:7], message=message, title=message.split("\n", 1)[0][:300],
                     author_login=_str(payload.get("authorLogin"), 256), author_id=payload.get("authorId"),
                     committed_at=_str(payload.get("commitDate")), authored_at=_str(payload.get("authoredAt")),
                     url=_str(payload.get("url"), 1024), jira_keys=_keys(payload.get("jiraKeys")),
                     parents=[str(p) for p in payload.get("parents") or []][:5], file_paths=paths,
                     additions=added, deletions=deleted, files_incomplete=bool(payload.get("filesMayBeIncomplete")))
        props["embed_hash"] = _hash(embedding_text(["Commit"], props))
        rows = tx.run(UPSERT.format(label="Commit"), uid=uid(tenant, binding, "commit", sha), repo=repo, props=props)
        return "upserted" if rows.single() else "stale"

    if kind == "github.pull_request.upserted":
        try:
            number = int(payload.get("number") or e["entityId"])
        except (TypeError, ValueError):
            raise BadEvent("pull request number is invalid") from None
        paths, added, deleted = _files(payload.get("files"))
        props = dict(base, number=number, title=_str(payload.get("title"), 500) or "",
                     body=_str(payload.get("body"), MAX_BODY) or "", state=_str(payload.get("state"), 20),
                     draft=bool(payload.get("draft")), merged=bool(payload.get("mergedAt")),
                     merged_at=_str(payload.get("mergedAt")), created_at=_str(payload.get("createdAt")),
                     pr_updated_at=_str(payload.get("updatedAt")), closed_at=_str(payload.get("closedAt")),
                     author_login=_str(payload.get("authorLogin"), 256), author_id=payload.get("authorId"),
                     head_ref=_str(payload.get("headRef"), 512), base_ref=_str(payload.get("baseRef"), 512),
                     head_sha=_str(payload.get("headSha"), 40), merge_commit_sha=_str(payload.get("mergeCommitSha"), 40),
                     url=_str(payload.get("url"), 1024), jira_keys=_keys(payload.get("jiraKeys")),
                     commit_shas=[str(s).lower() for s in payload.get("commitShas") or []][:250],
                     commits_incomplete=bool(payload.get("commitsMayBeIncomplete")), file_paths=paths,
                     additions=added, deletions=deleted, files_incomplete=bool(payload.get("filesMayBeIncomplete")))
        props["embed_hash"] = _hash(embedding_text(["PullRequest"], props))
        rows = tx.run(UPSERT.format(label="PullRequest"), uid=uid(tenant, binding, "pr", number), repo=repo, props=props)
        return "upserted" if rows.single() else "stale"

    if kind == "github.file.upserted":
        path = _str(payload.get("path"), 1024)
        if not path:
            raise BadEvent("file path is required")
        file_uid = uid(tenant, binding, "file", e["entityId"])
        old = tx.run("MATCH (n:CodeFile {uid: $uid}) RETURN n.source_version AS v, n.blob_sha AS blob",
                     uid=file_uid).single()
        if old and old["v"] is not None and old["v"] >= v:
            return "stale"
        code = payload.get("content") or ""
        props = dict(base, path=path, name=path.rsplit("/", 1)[-1], blob_sha=_str(payload.get("blobSha"), 40),
                     head_sha=_str(payload.get("headSha"), 40), url=_str(payload.get("url"), 1024),
                     line_count=int(payload.get("endLine") or len(code.splitlines())))
        tx.run(UPSERT.format(label="CodeFile"), uid=file_uid, repo=repo, props=props).consume()
        same_blob = old and old["blob"] and old["blob"] == props["blob_sha"]
        if same_blob:   # same content at a new head: only the links move
            tx.run("MATCH (:CodeFile {uid: $uid})-[:HAS_CHUNK]->(c:CodeChunk) "
                   "SET c.url = $base + '#L' + toString(c.start_line) + '-L' + toString(c.end_line), c.source_version = $v",
                   uid=file_uid, base=(props["url"] or "").split("#")[0], v=v)
            return "upserted"
        tx.run("MATCH (:CodeFile {uid: $uid})-[:HAS_CHUNK]->(c:CodeChunk) DETACH DELETE c", uid=file_uid)
        rows = [dict({k: base[k] for k in ("tenant_id", "syntrace_project_id", "binding_id", "source_version")},
                     uid=f"{file_uid}:chunk:{c['start_line']}", path=path, needs_embedding=True, **c)
                for c in chunks(code, path, props["url"])]
        if rows:
            tx.run("MATCH (f:CodeFile {uid: $uid}) UNWIND $rows AS r CREATE (c:CodeChunk) SET c = r "
                   "CREATE (f)-[:HAS_CHUNK]->(c)", uid=file_uid, rows=rows)
        return "upserted"

    if kind == "github.file.removed":
        file_uid = uid(tenant, binding, "file", e["entityId"])
        old = tx.run("MATCH (n:CodeFile {uid: $uid}) RETURN n.source_version AS v", uid=file_uid).single()
        if old and old["v"] is not None and old["v"] >= v:
            return "stale"
        tx.run("MATCH (:CodeFile {uid: $uid})-[:HAS_CHUNK]->(c:CodeChunk) DETACH DELETE c", uid=file_uid)
        tx.run("MERGE (n:CodeFile {uid: $uid}) SET n = $props", uid=file_uid,
               props=dict(base, uid=file_uid, removed=True))
        return "removed"

    if kind == "github.sync.completed":
        tx.run("MATCH (r:GitHubRepository {uid: $uid}) WHERE coalesce(r.sync_version, -1) < $v "
               "SET r.head_sha = $head, r.prepared_files = $prepared, r.skipped_files = $skipped, "
               "r.partial_reasons = $reasons, r.last_sync_at = $at, r.sync_version = $v",
               uid=repo, v=v, head=_str(payload.get("headSha"), 40), prepared=payload.get("preparedFiles"),
               skipped=payload.get("skippedFiles"), reasons=[str(x) for x in payload.get("partialReasons") or []],
               at=base["updated_at"])
        return "completed"

    return "ignored"   # a newer event type: acked so it does not block the queue


# ---------- 2. Embeddings ----------

def embedding_text(labels, n):
    if "CodeChunk" in labels:
        return f"{n.get('path')} lines {n.get('start_line')}-{n.get('end_line')}\n{n.get('text') or ''}"[:2000]
    if "PullRequest" in labels:
        return f"Pull request #{n.get('number')}: {n.get('title')}\n{n.get('head_ref') or ''}\n{n.get('body') or ''}"[:2000]
    return f"Commit: {n.get('message') or ''}\nFiles: {', '.join((n.get('file_paths') or [])[:20])}"[:2000]


def indexing_status(ctx, run_query):
    """Each repository the asker may see: last sync, what it covers, files the backend skipped and why,
    and how much is still waiting for embeddings. -> [{repo, status, ...}] where status is one of
    not_synced, embedding (still being indexed), partial (synced, some files skipped), ready."""
    projects = _projects(ctx)
    if not projects:
        return []
    repos = run_query(
        "MATCH (r:GitHubRepository) WHERE r.tenant_id = $t AND r.syntrace_project_id IN $projects "
        "RETURN r.binding_id AS binding, r.full_name AS repo, r.last_sync_at AS last_sync, r.head_sha AS head, "
        "r.prepared_files AS prepared, r.skipped_files AS skipped, r.partial_reasons AS reasons ORDER BY r.full_name",
        t=ctx.tenant_id, projects=projects)
    if not repos:
        return []
    bindings = [r["binding"] for r in repos]
    counts = {}
    for label, extra in (("Commit", ""), ("PullRequest", ""), ("CodeFile", "AND n.removed IS NULL "), ("CodeChunk", "")):
        for row in run_query(
                f"MATCH (n:{label}) WHERE n.tenant_id = $t AND n.binding_id IN $bindings {extra}"
                "RETURN n.binding_id AS b, count(*) AS total, "
                "sum(CASE WHEN n.needs_embedding = true THEN 1 ELSE 0 END) AS waiting",
                t=ctx.tenant_id, bindings=bindings):
            counts[(row["b"], label)] = (row["total"], row["waiting"])
    out = []
    for r in repos:
        get = lambda label: counts.get((r["binding"], label), (0, 0))
        waiting = sum(get(label)[1] for label in ("Commit", "PullRequest", "CodeChunk"))
        if not r["last_sync"]:
            status = "not_synced"
        elif waiting:
            status = "embedding"
        elif (r["skipped"] or 0) or (r["reasons"] or []):
            status = "partial"
        else:
            status = "ready"
        out.append({"repo": r["repo"], "status": status, "last_sync": r["last_sync"], "head": (r["head"] or "")[:7],
                    "commits": get("Commit")[0], "pull_requests": get("PullRequest")[0], "files": get("CodeFile")[0],
                    "skipped_files": r["skipped"] or 0, "reasons": list(r["reasons"] or []),
                    "waiting_for_embeddings": waiting})
    return out


REASONS = {"max_file_bytes": "files larger than 64 KB", "code_snapshot_limit": "over the 500 files / 8 MB snapshot limit",
           "unsupported_blob": "binary or non-UTF-8 files"}


def indexing_status_context(rows):
    lines = []
    for r in rows:
        state = {"not_synced": "first sync not finished yet", "embedding": "synced, still indexing for search",
                 "partial": "synced, some files not indexed", "ready": "fully synced and indexed"}[r["status"]]
        line = (f"- {r['repo']}: {state} | last sync {str(r['last_sync'] or 'never')[:16]} at {r['head'] or '-'} | "
                f"{r['commits']} commits, {r['pull_requests']} pull requests, {r['files']} code files")
        if r["skipped_files"]:
            why = ", ".join(REASONS.get(x, x) for x in r["reasons"]) or "not given"
            line += f" | {r['skipped_files']} files not indexed ({why})"
        if r["waiting_for_embeddings"]:
            line += f" | {r['waiting_for_embeddings']} items waiting to be searchable"
        lines.append(line)
    return "\n".join(lines) or "No GitHub repository is connected to these projects."


def tenants_missing_embeddings(run_query):
    rows = run_query("MATCH (n) WHERE n.needs_embedding = true AND (n:CodeChunk OR n:Commit OR n:PullRequest) "
                     "RETURN DISTINCT n.tenant_id AS t")
    return [r["t"] for r in rows if r["t"]]


def embed_pending(tenant, run_query, embed, batch=64, limit=5000):
    """Embed what is waiting, batch by batch. A node that changed meanwhile keeps waiting for its
    newer text. -> how many were stored."""
    stored = 0
    while stored < limit:
        rows = run_query("MATCH (n) WHERE n.tenant_id = $t AND n.needs_embedding = true AND "
                         "(n:CodeChunk OR n:Commit OR n:PullRequest) RETURN n.uid AS uid, labels(n) AS labels, "
                         "n.source_version AS v, properties(n) AS p LIMIT $batch", t=tenant, batch=batch)
        if not rows:
            break
        vectors = embed([embedding_text(r["labels"], r["p"]) for r in rows])
        for label in ("CodeChunk", "Commit", "PullRequest"):   # by label, so the uid index finds each node
            done = [{"uid": r["uid"], "v": r["v"], "vector": list(vec)} for r, vec in zip(rows, vectors)
                    if label in r["labels"]]
            if done:
                run_query(f"UNWIND $rows AS r MATCH (n:{label} {{uid: r.uid}}) WHERE n.tenant_id = $t "
                          "AND n.source_version = r.v SET n.embedding = r.vector, n.needs_embedding = false, "
                          "n.embedded_hash = n.embed_hash",
                          t=tenant, rows=done)
        stored += len(rows)
        if len(rows) < batch:
            break
    return stored


# ---------- 3. Queries for the assistant ----------

def _projects(ctx):
    return list(getattr(ctx, "syntrace_projects", ()) or ())


def _since(days):
    if not days:
        return None
    return (datetime.now(timezone.utc) - timedelta(days=int(days))).isoformat()


def _day(value, end=False):
    """'2015-01' or '2015-01-15' -> the start (or the end) of that month or day as an ISO time; else None."""
    text = str(value or "").strip()
    m = re.fullmatch(r"(\d{4})-(\d{2})(?:-(\d{2}))?", text)
    if not m:
        return None
    year, month, day = int(m.group(1)), int(m.group(2)), m.group(3)
    try:
        if day:
            start = datetime(year, month, int(day), tzinfo=timezone.utc)
            stop = start + timedelta(days=1)
        else:
            start = datetime(year, month, 1, tzinfo=timezone.utc)
            stop = datetime(year + (month == 12), month % 12 + 1, 1, tzinfo=timezone.utc)
    except ValueError:
        return None
    moment = stop - timedelta(seconds=1) if end else start
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def _number(value):
    text = str(value if value is not None else "").strip().lstrip("#")
    return int(text) if text.isdigit() else None


def activity(ctx, run_query, key=None, author=None, state=None, kind=None, text=None, since_days=None, limit=10,
             number=None, sha=None, repository=None, idle_days=None, from_date=None, to_date=None):
    """Pull requests and commits, newest first, in the asker's allowed SynTrace projects.
    -> {"pull_requests": [...], "commits": [...], "pr_total", "commit_total", "repos": [...]}"""
    projects = _projects(ctx)
    empty = {"pull_requests": [], "commits": [], "pr_total": 0, "commit_total": 0, "repos": []}
    if not projects:
        return empty
    key = (key or "").strip().upper() or None
    keys = None
    if key:
        if not _KEY.match(key):
            return empty
        keys = _all_keys(ctx, run_query, key)        # a moved ticket: commits may name its old key
        if not keys:
            return empty                               # a ticket the asker can't see
    params = {"t": ctx.tenant_id, "projects": projects, "key": key, "keys": keys, "author": (author or "").strip().lower() or None,
              "text": (text or "").strip().lower() or None, "since": _since(since_days), "limit": int(limit),
              "paths": 8 if (key or number or sha) else 0,   # one piece of work: name the files it changed
              "number": _number(number),
              "sha": (sha or "").strip().lower() or None, "repo": (repository or "").strip().lower() or None,
              "idle_before": _since(idle_days), "from": _day(from_date), "to": _day(to_date, end=True)}
    if (from_date and not params["from"]) or (to_date and not params["to"]):
        return empty                              # a date it can't read: nothing rather than everything
    params["bindings"] = None
    if params["repo"] and params["repo"].upper() in ctx.allowed_projects:
        # A Jira project named as the repository ("DATACASS pull requests"): its repositories are the
        # ones whose commits and pull requests name its tickets.
        params["bindings"] = project_repositories(ctx, run_query, params["repo"].upper())
        params["repo"] = None
        if not params["bindings"]:
            return empty
    if idle_days:                              # stuck: still open and untouched since then
        kind, state = "pull_request", "open"
    if number and params["number"] is None:
        return empty
    if params["number"] is not None:
        kind = "pull_request"
    if params["sha"]:
        if not re.fullmatch(r"[0-9a-f]{4,40}", params["sha"]):
            return empty
        kind = "commit"
    common = ("n.tenant_id = $t AND n.syntrace_project_id IN $projects "
              "AND ($key IS NULL OR any(k IN $keys WHERE k IN n.jira_keys)) "
              "AND ($repo IS NULL OR toLower(coalesce(r.full_name, '')) CONTAINS $repo) "
              "AND ($bindings IS NULL OR n.binding_id IN $bindings) ")
    # The author's Jira name when they linked their GitHub account in SynTrace; the filter matches either name.
    who = ("OPTIONAL MATCH (g:GitHubUser {tenant_id: $t, github_id: n.author_id}) "
           "OPTIONAL MATCH (p:Person {uid: $t + ':person:' + g.jira_account_id}) "
           "WITH n, r, p, g WHERE $author IS NULL OR toLower(coalesce(n.author_login, '')) CONTAINS $author "
           "OR toLower(coalesce(g.login, '')) CONTAINS $author "     # renamed since: today's login
           "OR toLower(coalesce(p.displayName, '')) CONTAINS $author ")
    out = dict(empty)
    state = (state or "").strip().lower() or None
    if kind in (None, "", "pull_request", "pr"):
        rows = run_query(
            "MATCH (n:PullRequest)-[:IN_REPO]->(r:GitHubRepository) WHERE " + common +
            "AND ($number IS NULL OR n.number = $number) "
            "AND ($idle_before IS NULL OR coalesce(n.pr_updated_at, n.created_at) <= $idle_before) "
            "AND ($text IS NULL OR toLower(n.title + ' ' + coalesce(n.body, '') + ' ' + coalesce(n.head_ref, '')) CONTAINS $text) "
            "AND ($since IS NULL OR coalesce(n.pr_updated_at, n.created_at) >= $since) "
            # a date range means when it was merged for merged ones, else when it was opened
            "AND ($from IS NULL OR CASE WHEN $state = 'merged' THEN n.merged_at ELSE n.created_at END >= $from) "
            "AND ($to IS NULL OR CASE WHEN $state = 'merged' THEN n.merged_at ELSE n.created_at END <= $to) "
            "AND ($state IS NULL OR ($state = 'merged' AND n.merged) OR ($state = 'open' AND n.state = 'open') "
            "     OR ($state = 'closed' AND n.state = 'closed' AND NOT n.merged)) " + who +
            "WITH n, r, p ORDER BY coalesce(n.pr_updated_at, n.created_at) DESC "
            "WITH collect({number: n.number, title: n.title, state: n.state, merged: n.merged, draft: n.draft, "
            "  merged_at: n.merged_at, created_at: n.created_at, author: n.author_login, author_name: p.displayName, "
            "  head: n.head_ref, "
            "  base: n.base_ref, keys: n.jira_keys, url: n.url, repo: r.full_name, commits: size(n.commit_shas), "
            "  files: size(n.file_paths), paths: n.file_paths[0..$paths], additions: n.additions, "
            "  deletions: n.deletions, partial: n.files_incomplete OR n.commits_incomplete}) AS found "
            "RETURN size(found) AS total, found[0..$limit] AS items", state=state, **params)
        out["pr_total"], out["pull_requests"] = rows[0]["total"], rows[0]["items"]
    if kind in (None, "", "commit") and state in (None, "merged"):
        rows = run_query(
            "MATCH (n:Commit)-[:IN_REPO]->(r:GitHubRepository) WHERE " + common +
            "AND ($sha IS NULL OR n.sha STARTS WITH $sha) "
            "AND ($text IS NULL OR toLower(n.message) CONTAINS $text) "
            "AND ($since IS NULL OR n.committed_at >= $since) "
            "AND ($from IS NULL OR n.committed_at >= $from) AND ($to IS NULL OR n.committed_at <= $to) " + who +
            "WITH n, r, p ORDER BY n.committed_at DESC "
            "WITH collect({sha: n.short_sha, title: n.title, date: n.committed_at, author: n.author_login, "
            "  author_name: p.displayName, "
            "  keys: n.jira_keys, url: n.url, repo: r.full_name, files: size(n.file_paths), "
            "  paths: n.file_paths[0..$paths], additions: n.additions, deletions: n.deletions, "
            "  partial: n.files_incomplete}) AS found "
            "RETURN size(found) AS total, found[0..$limit] AS items", **params)
        out["commit_total"], out["commits"] = rows[0]["total"], rows[0]["items"]
    for item in out["pull_requests"] + out["commits"]:
        item["keys"] = visible_keys(item.get("keys"), ctx)
    out["repos"] = sorted({i["repo"] for i in out["pull_requests"] + out["commits"] if i.get("repo")})
    return out


def project_repositories(ctx, run_query, project):
    """Binding ids of the repositories whose pull requests or commits name tickets of this Jira project."""
    prefix = project + "-"
    found = set()
    for label in ("PullRequest", "Commit"):
        found |= {r["b"] for r in run_query(
            f"MATCH (n:{label}) WHERE n.tenant_id = $t AND n.syntrace_project_id IN $projects "
            "AND any(k IN n.jira_keys WHERE k STARTS WITH $prefix) RETURN DISTINCT n.binding_id AS b",
            t=ctx.tenant_id, projects=_projects(ctx), prefix=prefix)}
    return sorted(found)


def visible_keys(keys, ctx):
    """Ticket keys of the asker's projects only: a commit may name tickets of projects they can't see,
    and naming those would tell them the tickets exist (the same rule as hidden blockers in Jira)."""
    allowed = set(ctx.allowed_projects)
    return [k for k in keys or [] if k.rsplit("-", 1)[0] in allowed]


def _all_keys(ctx, run_query, key):
    """[current key and its old keys] of a ticket the asker may see, or [] when they may not.
    A ticket not in the graph keeps its own key, when its project is allowed."""
    rows = run_query("MATCH (w:WorkItem {tenant_id: $t}) WHERE w.key = $key OR $key IN coalesce(w.key_aliases, []) "
                     "RETURN w.key AS key, w.project_key AS project, w.key_aliases AS aliases LIMIT 1",
                     t=ctx.tenant_id, key=key)
    if not rows:
        return [key] if key.rsplit("-", 1)[0] in ctx.allowed_projects else []
    r = rows[0]
    if (r["project"] or r["key"].rsplit("-", 1)[0]) not in ctx.allowed_projects:
        return []
    return list(dict.fromkeys([r["key"], key] + list(r["aliases"] or [])))


def ticket_family(ctx, run_query, keys, limit=15):
    """For tickets a commit or pull request names: each one's place in the hierarchy (its story and epic
    above it) and the tickets right under it (a story's subtasks), with Jira type and status. Only tickets
    of the asker's projects are named. -> [{key, type, status, summary, above: [...], under: [...]}]"""
    keys = [k for k in dict.fromkeys(keys or []) if _KEY.match(k)]
    if not keys:
        return []
    allowed = list(ctx.allowed_projects)
    rows = run_query(
        "MATCH (w:WorkItem {tenant_id: $t}) WHERE (w.key IN $keys OR any(k IN coalesce(w.key_aliases, []) WHERE k IN $keys)) "
        "AND w.project_key IN $allowed "
        "OPTIONAL MATCH path = (w)-[:CHILD_OF*1..3]->(a:WorkItem) WHERE a.project_key IN $allowed "
        "WITH w, [x IN collect({key: a.key, type: a.issuetype, status: a.status, summary: a.summary, depth: length(path)}) "
        "         WHERE x.key IS NOT NULL] AS above "
        "OPTIONAL MATCH (c:WorkItem)-[:CHILD_OF]->(w) WHERE c.tenant_id = $t AND c.project_key IN $allowed "
        "WITH w, above, [x IN collect({key: c.key, type: c.issuetype, status: c.status, summary: c.summary}) "
        "                WHERE x.key IS NOT NULL] AS under "
        "RETURN w.key AS key, w.issuetype AS type, w.status AS status, w.summary AS summary, above, under "
        "ORDER BY w.key LIMIT $limit", t=ctx.tenant_id, keys=keys, allowed=allowed, limit=limit)
    out = []
    for r in rows:
        out.append({"key": r["key"], "type": r["type"], "status": r["status"], "summary": r["summary"],
                    "above": sorted(r["above"], key=lambda a: a["depth"]),
                    "under": sorted(r["under"], key=lambda c: c["key"])[:limit]})
    return out


def ticket_family_context(family):
    lines = []
    for t in family:
        chain = " under ".join([f"{t['key']} ({t['type']}, {t['status']})"] +
                               [f"{a['key']} ({a['type']}, {a['status']}: {a['summary']})" for a in t["above"]])
        lines.append(f"Ticket: {chain}")
        if t["under"]:
            lines.append(f"  {t['key']} has {len(t['under'])} tickets under it: " +
                         "; ".join(f"{c['key']} ({c['type']}, {c['status']})" for c in t["under"]))
    return "\n".join(lines)


def code_progress(ctx, run_query, key, limit=25):
    """An epic's or story's work in code: the ticket and every ticket under it (subtasks, stories of an
    epic, up to three levels), each with its Jira status and its pull requests and commits, plus totals.
    A pull request usually names the subtask, while people ask about the epic. -> dict, or None when the
    ticket is not one the asker may see."""
    projects = _projects(ctx)
    key = (key or "").strip().upper()
    if not projects or not _KEY.match(key):
        return None
    rows = run_query(
        "MATCH (w:WorkItem {tenant_id: $t}) WHERE w.key = $key OR $key IN coalesce(w.key_aliases, []) "
        "WITH w LIMIT 1 WHERE w.project_key IN $allowed "
        "OPTIONAL MATCH (c:WorkItem)-[:CHILD_OF*1..3]->(w) WHERE c.tenant_id = $t AND c.project_key IN $allowed "
        "WITH w, collect(DISTINCT c) AS children "
        "RETURN w.key AS key, w.summary AS summary, w.issuetype AS type, w.status AS status, "
        "coalesce(w.statusCategory, '') AS category, w.key_aliases AS aliases, "
        "[c IN children | {key: c.key, summary: c.summary, type: c.issuetype, status: c.status, "
        " category: coalesce(c.statusCategory, ''), aliases: c.key_aliases}] AS children",
        t=ctx.tenant_id, key=key, allowed=list(ctx.allowed_projects))
    if not rows:
        return None
    top = rows[0]
    tickets = [{k: top[k] for k in ("key", "summary", "type", "status", "category", "aliases")}] + \
        sorted(top["children"], key=lambda c: c["key"])
    owner = {}                                   # every key a commit may name -> the ticket's current key
    for t in tickets:
        for k in [t["key"]] + list(t.get("aliases") or []):
            owner[k] = t["key"]
    prs = run_query(
        "MATCH (p:PullRequest)-[:IN_REPO]->(r:GitHubRepository) WHERE p.tenant_id = $t "
        "AND p.syntrace_project_id IN $projects AND any(k IN p.jira_keys WHERE k IN $keys) "
        "RETURN p.number AS number, p.title AS title, p.state AS state, p.merged AS merged, p.merged_at AS merged_at, "
        "p.url AS url, p.jira_keys AS keys, r.full_name AS repo ORDER BY p.number",
        t=ctx.tenant_id, projects=projects, keys=list(owner))
    commits = run_query(
        "MATCH (c:Commit) WHERE c.tenant_id = $t AND c.syntrace_project_id IN $projects "
        "UNWIND c.jira_keys AS k WITH c, k WHERE k IN $keys RETURN k, count(DISTINCT c) AS n",
        t=ctx.tenant_id, projects=projects, keys=list(owner))
    by_ticket = {t["key"]: dict(t, prs=[], commits=0) for t in tickets}
    for p in prs:
        for k in {owner[k] for k in p["keys"] or [] if k in owner}:
            by_ticket[k]["prs"].append({f: p[f] for f in ("number", "title", "state", "merged", "merged_at", "url", "repo")})
    for r in commits:
        by_ticket[owner[r["k"]]]["commits"] += r["n"]
    totals = {"tickets": len(by_ticket), "done_in_jira": 0, "merged": 0, "open_pr": 0, "commits_only": 0, "no_code": 0}
    for t in by_ticket.values():
        totals["done_in_jira"] += t["category"] == "done"
        if any(p["merged"] for p in t["prs"]):
            totals["merged"] += 1
        elif any(p["state"] == "open" for p in t["prs"]):
            totals["open_pr"] += 1
        elif t["commits"]:
            totals["commits_only"] += 1
        else:
            totals["no_code"] += 1
    items = list(by_ticket.values())
    return {"root": items[0], "children": items[1:limit + 1], "more": max(0, len(items) - 1 - limit), "totals": totals}


def code_progress_context(result):
    root, t = result["root"], result["totals"]
    lines = [f"{root['key']} ({root['type']}, {root['status']}): {root['summary']}",
             f"Tickets: {t['tickets']} (this one and {t['tickets'] - 1} under it); done in Jira: {t['done_in_jira']}; "
             f"code merged: {t['merged']}; pull request still open: {t['open_pr']}; commits without a pull request: "
             f"{t['commits_only']}; no code yet: {t['no_code']}"]
    for item in [root] + result["children"]:
        code = ", ".join(f"PR #{p['number']} " + ("merged " + str(p["merged_at"])[:10] if p["merged"] else p["state"])
                         for p in item["prs"][:3])
        if item["commits"]:
            code = (code + "; " if code else "") + f"{item['commits']} commits"
        lines.append(f"- {item['key']} | {item['type']} | {item['status']} | {item['summary']} | {code or 'no code yet'}")
    if result["more"]:
        lines.append(f"... and {result['more']} more tickets")
    return "\n".join(lines)


def jira_vs_github(ctx, run_query, project=None, limit=15):
    """Tickets whose Jira state and GitHub state disagree, in the asker's projects:
      done_unmerged  done in Jira, but no pull request of theirs was merged and no default-branch commit
                     mentions them (a pull request applied by hand still has its commit, so it is not listed)
      merged_open    a pull request of theirs was merged, but the ticket is not done in Jira
      open_pr_done   done in Jira while a pull request of theirs is still open
    -> {"counts": {kind: n}, "items": {kind: [...]}}"""
    projects = _projects(ctx)
    empty = {"counts": {"done_unmerged": 0, "merged_open": 0, "open_pr_done": 0},
             "items": {"done_unmerged": [], "merged_open": [], "open_pr_done": []}}
    if not projects:
        return empty
    project = (project or "").strip().upper() or None
    if project and project not in ctx.allowed_projects:
        return empty
    aliases = {a: r["key"] for r in run_query(
        "MATCH (w:WorkItem {tenant_id: $t}) WHERE w.key_aliases IS NOT NULL RETURN w.key AS key, w.key_aliases AS aliases",
        t=ctx.tenant_id) for a in (r["aliases"] or []) if a != r["key"]}
    rows = run_query(
        "MATCH (p:PullRequest) WHERE p.tenant_id = $t AND p.syntrace_project_id IN $projects "
        "UNWIND [k IN p.jira_keys | coalesce($aliases[k], k)] AS k WITH k, collect(DISTINCT p) AS prs "
        "MATCH (w:WorkItem {tenant_id: $t, key: k}) WHERE w.project_key IN $allowed "
        "AND ($project IS NULL OR w.project_key = $project) "
        "WITH w, prs, coalesce(w.statusCategory, '') = 'done' AS done, "
        "     any(p IN prs WHERE p.merged) AS merged, any(p IN prs WHERE p.state = 'open') AS open_pr "
        "WHERE done <> merged OR (done AND open_pr) "
        "RETURN w.key AS key, w.summary AS summary, w.status AS status, w.url AS url, done, merged, open_pr, "
        "[p IN prs | {number: p.number, state: p.state, merged: p.merged, merged_at: p.merged_at, url: p.url}] AS prs "
        "ORDER BY w.key",
        t=ctx.tenant_id, projects=projects, allowed=list(ctx.allowed_projects), project=project, aliases=aliases)
    keys = [r["key"] for r in rows]
    commits = {r["k"]: r["c"] for r in run_query(
        "MATCH (c:Commit) WHERE c.tenant_id = $t AND c.syntrace_project_id IN $projects "
        "UNWIND c.jira_keys AS k WITH k WHERE k IN $keys RETURN k, count(*) AS c",
        t=ctx.tenant_id, projects=projects, keys=keys)} if keys else {}
    out = {"counts": dict(empty["counts"]), "items": {k: [] for k in empty["items"]}}
    for r in rows:
        item = {k: r[k] for k in ("key", "summary", "status", "url")}
        item["commits"] = commits.get(r["key"], 0)
        item["prs"] = sorted(r["prs"], key=lambda p: p["number"] or 0)[:3]
        kinds = []
        if r["done"] and not r["merged"] and not item["commits"]:
            kinds.append("done_unmerged")
        if r["merged"] and not r["done"]:
            kinds.append("merged_open")
        if r["done"] and r["open_pr"]:
            kinds.append("open_pr_done")
        for kind in kinds:
            out["counts"][kind] += 1
            if len(out["items"][kind]) < limit:
                out["items"][kind].append(item)
    return out


def jira_vs_github_context(result):
    titles = {"done_unmerged": "Done in Jira, but no pull request was merged and no commit mentions them",
              "merged_open": "Pull request merged, but the ticket is not done in Jira",
              "open_pr_done": "Done in Jira while a pull request is still open"}
    lines = []
    for kind, title in titles.items():
        lines.append(f"{title}: {result['counts'][kind]}")
        for i in result["items"][kind]:
            prs = ", ".join(f"PR #{p['number']} " + ("merged " + str(p["merged_at"])[:10] if p["merged"] else p["state"])
                            for p in i["prs"])
            lines.append(f"- {i['key']} | {i['status']} | {i['summary']} | {prs}")
    return "\n".join(lines)


_IDENT = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*(?:[a-z][A-Z]|_)[A-Za-z0-9_]*|[A-Za-z0-9_-]+\.[a-z]{1,5})\b")


def name_hits(question, ctx, run_query, limit=3):
    """Files named like an identifier in the question (StatementBuilder, user_service, app.js): the
    first lines of each, ahead of anything found by meaning."""
    names = sorted({m.lower().rsplit(".", 1)[0] for m in _IDENT.findall(question)})[:5]
    if not names:
        return []
    rows = run_query(
        "MATCH (f:CodeFile)-[:HAS_CHUNK]->(c:CodeChunk) WHERE f.tenant_id = $t AND f.syntrace_project_id IN $projects "
        "AND f.removed IS NULL AND any(n IN $names WHERE toLower(f.name) STARTS WITH n + '.') "
        "WITH f, c ORDER BY c.start_line WITH f, collect(c)[0] AS c "
        "RETURN f.path AS path, c.start_line AS start_line, c.end_line AS end_line, c.text AS text, c.url AS url "
        "LIMIT $limit", t=ctx.tenant_id, projects=_projects(ctx), names=names, limit=limit)
    return [dict({k: r[k] for k in r.keys()}, kind="code", number=None, title=None, sha=None, keys=None,
                 author=None, date=None, score=1.0) for r in rows]


def search_code(question, ctx, run_query, embed, k=5, min_score=SEARCH_MIN_SCORE):
    """Code chunks, pull requests and commits closest to the question, in the allowed projects.
    Files named in the question come first."""
    projects = _projects(ctx)
    if not projects:
        return []
    named = name_hits(question, ctx, run_query)
    try:
        rest = _by_meaning(question, ctx, run_query, embed, k, min_score)
    except Exception as error:   # embeddings down: files named in the question are still found
        if not named:
            raise
        log.warning("code search by meaning unavailable: %s", type(error).__name__)
        rest = []
    for hit in named + rest:
        hit["keys"] = visible_keys(hit.get("keys"), ctx)
    seen = {(h["path"], h["start_line"]) for h in named}
    return (named + [h for h in rest if (h.get("path"), h.get("start_line")) not in seen])[:k]


VECTOR_CACHE_SECONDS = 60
_VECTORS = {}   # (tenant, projects) -> (time loaded, [(kind, row, vector, norm)])
_FIELDS = ("uid", "path", "start_line", "end_line", "text", "number", "title", "sha", "url", "keys", "author", "date")
_KIND_OF = {"CodeChunk": "code", "PullRequest": "pull_request", "Commit": "commit"}


def _vectors(ctx, run_query):
    """Every embedded code chunk, pull request and commit the asker may see, with its norm worked out once.
    One query per label, so each uses its (tenant_id, syntrace_project_id) index. Cached for a minute,
    like ticket vectors; a node deleted meanwhile is dropped by _live before it is shown."""
    import time
    key = (ctx.tenant_id, tuple(sorted(_projects(ctx))))
    hit = _VECTORS.get(key)
    if hit and time.time() - hit[0] < VECTOR_CACHE_SECONDS:
        return hit[1]
    items = []
    for label, kind in _KIND_OF.items():
        rows = run_query(
            f"MATCH (n:{label}) WHERE n.tenant_id = $t AND n.syntrace_project_id IN $projects "
            "AND n.embedding IS NOT NULL AND n.removed IS NULL "
            "RETURN n.uid AS uid, n.path AS path, n.start_line AS start_line, n.end_line AS end_line, n.text AS text, "
            "n.number AS number, n.title AS title, n.short_sha AS sha, n.url AS url, n.jira_keys AS keys, "
            "n.author_login AS author, coalesce(n.merged_at, n.committed_at, n.created_at) AS date, n.embedding AS emb",
            t=ctx.tenant_id, projects=list(key[1]))
        for r in rows:
            v = r["emb"]
            items.append((kind, {f: r[f] for f in _FIELDS}, v, math.sqrt(sum(x * x for x in v)) or 1.0))
    _VECTORS[key] = (time.time(), items)
    return items


def _live(hits, ctx, run_query):
    """uids of hits still in the graph, checked per label so the uid index is used."""
    alive = set()
    for label, kind in _KIND_OF.items():
        uids = [row["uid"] for k, row in hits if k == kind]
        if uids:
            alive |= {r["uid"] for r in run_query(
                f"UNWIND $uids AS u MATCH (n:{label} {{uid: u}}) WHERE n.tenant_id = $t AND n.removed IS NULL "
                "RETURN n.uid AS uid", uids=uids, t=ctx.tenant_id)}
    return alive


def _by_meaning(question, ctx, run_query, embed, k, min_score):
    items = _vectors(ctx, run_query)
    if not items:
        return []
    query = embed([question])[0]
    qn = math.sqrt(sum(x * x for x in query)) or 1.0
    scored = sorted(((sum(a * b for a, b in zip(query, v)) / (qn * norm), kind, row) for kind, row, v, norm in items),
                    key=lambda t: t[0], reverse=True)
    top = [(s, kind, row) for s, kind, row in scored[:k * 2] if s >= min_score]
    alive = _live([(kind, row) for _, kind, row in top], ctx, run_query) if top else set()
    return [dict(row, kind=kind, score=round(s, 3)) for s, kind, row in top if row["uid"] in alive][:k]


def _paths(item):
    paths = item.get("paths") or []
    if not paths:
        return " | file list incomplete" if item.get("partial") else ""
    more = item.get("files", 0) - len(paths)
    tail = " (the list GitHub gave is incomplete)" if item.get("partial") else ""
    return " | files " + ", ".join(paths) + (f" and {more} more" if more > 0 else "") + tail


_CLAIM_URL = re.compile(r"https?://github\.com/([\w.-]+/[\w.-]+)/(pull|commit)/([0-9a-f]{4,40}|\d+)", re.I)
_CLAIM_PR = re.compile(r"(?:\bPR|pull request)\s*(?:#|number\s*|رقم\s*)?(\d+)", re.I)
_CLAIM_SHA = re.compile(r"\bcommit\s+`?([0-9a-f]{7,40})\b", re.I)


def unverified_claims(answer, ctx, run_query):
    """GitHub facts an answer states (pull request links or numbers, commits) that are not in the graph
    for this asker. A model can recall real pull requests of public projects from its training; only
    what this company's connected repositories hold may be said. -> list of the claims not found."""
    urls = {(m.group(1).lower(), m.group(2).lower(), m.group(3).lower()) for m in _CLAIM_URL.finditer(answer or "")}
    numbers = {int(n) for n in _CLAIM_PR.findall(answer or "")} | {int(i) for _, kind, i in urls if kind == "pull"}
    shas = {s.lower() for s in _CLAIM_SHA.findall(answer or "")} | {i for _, kind, i in urls if kind == "commit"}
    if not numbers and not shas:
        return []
    projects = _projects(ctx)
    if not projects:
        return [f"#{n}" for n in sorted(numbers)] + sorted(shas)
    known_prs = {}   # repository -> pull request numbers it holds
    rows = run_query("MATCH (n:PullRequest)-[:IN_REPO]->(r:GitHubRepository) WHERE n.tenant_id = $t "
                     "AND n.syntrace_project_id IN $projects AND n.number IN $numbers "
                     "RETURN n.number AS number, toLower(coalesce(r.full_name, '')) AS repo",
                     t=ctx.tenant_id, projects=projects, numbers=sorted(numbers)) if numbers else []
    for r in rows:
        known_prs.setdefault(r["repo"], set()).add(r["number"])
    found_numbers = {n for nums in known_prs.values() for n in nums}
    missing = [f"#{n}" for n in sorted(numbers - found_numbers)]
    # a link must also point at the repository that holds that number
    missing += [f"{repo}/pull/{i}" for repo, kind, i in sorted(urls)
                if kind == "pull" and int(i) in found_numbers and int(i) not in known_prs.get(repo, set())]
    for sha in sorted(shas):
        hit = run_query("MATCH (n:Commit) WHERE n.tenant_id = $t AND n.syntrace_project_id IN $projects "
                        "AND n.sha STARTS WITH $sha RETURN count(n) AS c", t=ctx.tenant_id, projects=projects, sha=sha)
        if not hit or not hit[0]["c"]:
            missing.append(sha)
    return missing


def _who(item):
    name = item.get("author_name")
    return f"{item['author']} (Jira: {name})" if name else str(item["author"])


def activity_context(result):
    lines = []
    if result["repos"]:
        lines.append("Repositories: " + ", ".join(result["repos"]))
    if result["pull_requests"] or result["pr_total"]:
        lines.append(f"Pull requests: {result['pr_total']} (newest first)")
    for p in result["pull_requests"]:
        status = ("merged " + str(p["merged_at"])[:10]) if p["merged"] else ("draft" if p["draft"] else p["state"])
        lines.append(f"- PR #{p['number']} | {status} | {p['title']} | by {_who(p)} | {p['head']} -> {p['base']}"
                     f" | opened {str(p['created_at'])[:10]} | {p['commits']} commits, {p['files']} files"
                     + (f" | tickets {', '.join(p['keys'])}" if p["keys"] else "") + _paths(p) + f" | {p['url']}")
    if result["commits"] or result["commit_total"]:
        lines.append(f"Commits on the default branch: {result['commit_total']} (newest first)")
    for c in result["commits"]:
        lines.append(f"- commit {c['sha']} | {str(c['date'])[:10]} | {c['title']} | by {_who(c)}"
                     f" | {c['files']} files +{c['additions']} -{c['deletions']}"
                     + (f" | tickets {', '.join(c['keys'])}" if c["keys"] else "") + _paths(c) + f" | {c['url']}")
    return "\n".join(lines)


def code_context(hits):
    lines = ["GitHub results closest to the question (code is from the default branch):"]
    for h in hits:
        if h["kind"] == "code":
            lines.append(f"- file {h['path']} lines {h['start_line']}-{h['end_line']} | {h['url']}\n"
                         + "\n".join("    " + l for l in (h["text"] or "").splitlines()[:25]))
        elif h["kind"] == "pull_request":
            lines.append(f"- PR #{h['number']} | {h['title']} | by {h['author']} | {str(h['date'] or '')[:10]}"
                         + (f" | tickets {', '.join(h['keys'])}" if h["keys"] else "") + f" | {h['url']}")
        else:
            lines.append(f"- commit {h['sha']} | {h['title']} | by {h['author']} | {str(h['date'] or '')[:10]}"
                         + (f" | tickets {', '.join(h['keys'] or [])}" if h["keys"] else "") + f" | {h['url']}")
    return "\n".join(lines)


# ---------- 4. Who is who: SynTrace employee, Jira account, GitHub account ----------

def link_identities(tx, tenant, rows):
    """Replace the company's GitHub-to-Jira links with the backend's list (each employee linked both
    accounts themselves, through OAuth). rows: [{employeeId, jiraAccountId, gitHubUserId, gitHubLogin}].
    The Jira person is matched at query time, so a person who appears later is still found."""
    clean = []
    for r in rows or []:
        try:
            gid = int(r.get("gitHubUserId"))
        except (TypeError, ValueError):
            continue
        clean.append({"uid": f"{tenant}:github-user:{gid}", "github_id": gid,
                      "login": _str(r.get("gitHubLogin"), 256), "employee_id": _str(r.get("employeeId"), 200),
                      "jira_account_id": _str(r.get("jiraAccountId"), 200) or None})
    tx.run("MATCH (g:GitHubUser {tenant_id: $t}) WHERE NOT g.github_id IN $ids DETACH DELETE g",
           t=tenant, ids=[c["github_id"] for c in clean])
    tx.run("MATCH (:Person)-[s:SAME_AS]->(g:GitHubUser {tenant_id: $t}) DELETE s", t=tenant)
    if clean:
        tx.run("UNWIND $rows AS r MERGE (g:GitHubUser {uid: r.uid}) SET g = r, g.tenant_id = $t "
               "WITH g, r WHERE r.jira_account_id IS NOT NULL "
               "MATCH (p:Person {uid: $t + ':person:' + r.jira_account_id}) MERGE (p)-[:SAME_AS]->(g)",
               t=tenant, rows=clean)
    return len(clean)
