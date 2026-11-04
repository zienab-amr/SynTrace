"""
test_offline.py
اختبارات من غير Neo4j ولا Groq ولا Ollama: بتختبر المنطق (normalization، الـ webhook dispatch،
الـ stale check، الفلترة، الـ templates). مش بتختبر صحة الـ Cypher نفسه، ده شغل verify_graph.py
و evaluate_graphrag.py على الـ database الحقيقية.

  python test_offline.py                  # يشغّل الاختبارات
  python test_offline.py --write-mocks    # يكتب mock_events/*.json لاختبار webhook_handler.py على Neo4j
"""
import copy
import json
import os
import sys

os.environ.setdefault("JIRA_SITE_ID", "syntrace.atlassian.net")

import ingest
import webhook_handler as wh
import query_engine as qe
import answer_generator as ag

T = "t1"


def para(text):
    return {"type": "doc", "version": 1,
            "content": [{"type": "paragraph", "content": [{"type": "text", "text": text}]}]}


def person(acc, name):
    return {"accountId": acc, "displayName": name, "emailAddress": f"{acc}@x.com"}


def make_issue(key="SYNTECH-300", updated="2026-10-27T11:04:58.398+0300", **fields_over):
    issue = {
        "id": "10300", "key": key,
        "self": "https://syntrace.atlassian.net/rest/api/3/issue/10300",
        "names": {"customfield_10020": "Sprint", "customfield_10016": "Story point estimate",
                  "customfield_10099": "Severity"},
        "fields": {
            "summary": "Login endpoint",
            "description": {"type": "doc", "version": 1, "content": [
                {"type": "paragraph", "content": [{"type": "text", "text": "Intro text"}]},
                {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Acceptance criteria"}]},
                {"type": "bulletList", "content": [
                    {"type": "listItem", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "returns 200"}]}]}]},
            ]},
            "issuetype": {"name": "Story", "hierarchyLevel": 0, "subtask": False},
            "status": {"name": "In Progress", "statusCategory": {"key": "indeterminate"}},
            "priority": {"name": "High"},
            "created": "2026-10-20T10:00:00.000+0300", "updated": updated,
            "resolutiondate": None, "duedate": None,
            "labels": ["auth"], "components": [{"name": "backend"}],
            "project": {"key": "SYNTECH", "name": "SynTech", "projectTypeKey": "software"},
            "assignee": person("acc-f", "Fatma saeedd"),
            "reporter": person("acc-i", "Ihab Ramadan"),
            "parent": {"key": "SYNTECH-18", "fields": {"summary": "Epic summary (stale copy)"}},
            "subtasks": [{"key": "SYNTECH-301", "fields": {"summary": "sub"}}],
            "issuelinks": [
                {"type": {"name": "Blocks", "inward": "is blocked by", "outward": "blocks"},
                 "inwardIssue": {"key": "SYNDATA-3"}},
                {"type": {"name": "Blocks", "inward": "is blocked by", "outward": "blocks"},
                 "outwardIssue": {"key": "SYNTECH-30"}},
                {"type": {"name": "Relates", "inward": "relates to", "outward": "relates to"},
                 "outwardIssue": {"key": "SYNTECH-3"}},
            ],
            "customfield_10020": [{"id": 5, "name": "Sprint 5", "state": "active", "boardId": 1,
                                   "startDate": "2026-10-19T09:00:00.000Z"}],
            "customfield_10016": 5.0,
            "customfield_10099": {"value": "Medium"},
            "customfield_10050": None,
            "comment": {"total": 1, "comments": [
                {"id": "1", "author": person("acc-z", "Zienab amr"), "body": para("looks good, see SYNDATA-3"),
                 "created": "2026-10-26T10:00:00.000+0300", "updated": "2026-10-26T10:00:00.000+0300"}]},
            "worklog": {"worklogs": [
                {"id": "w1", "author": person("acc-f", "Fatma saeedd"), "timeSpent": "2h",
                 "timeSpentSeconds": 7200, "started": "2026-10-26T09:00:00.000+0300", "comment": para("api work")}]},
            "attachment": [{"id": "a1", "filename": "login.png", "mimeType": "image/png", "size": 1234,
                            "created": "2026-10-26T10:00:00.000+0300", "author": person("acc-f", "Fatma saeedd"),
                            "content": "https://syntrace.atlassian.net/secure/attachment/a1/login.png"},
                           {"id": "a2", "filename": "demo.mp4", "mimeType": "video/mp4", "size": 99}],
            "watches": {"watchCount": 3},
        },
        "changelog": {"histories": [{
            "id": "h1", "created": "2026-10-25T10:00:00.000+0300", "author": person("acc-i", "Ihab Ramadan"),
            "items": [
                {"field": "assignee", "fieldtype": "jira", "from": "acc-z", "fromString": "Zienab amr",
                 "to": "acc-f", "toString": "Fatma saeedd"},
                {"field": "status", "fieldtype": "jira", "from": "1", "fromString": "To Do",
                 "to": "3", "toString": "In Progress"}]}]},
    }
    issue["fields"].update(fields_over)
    return issue


class FakeResult:
    def __init__(self, row=None, rows=()):
        self._row, self._rows = row, list(rows)

    def single(self):
        return self._row

    def __iter__(self):
        return iter(self._rows)


class FakeTx:
    """بيسجّل الـ queries. existing = الصف اللي يرجع لو الـ query فيها 'RETURN w.updated'."""
    def __init__(self, existing=None, subtasks=()):
        self.calls, self.existing, self.subtasks = [], existing, list(subtasks)

    def run(self, query, **params):
        q = " ".join(query.split())
        self.calls.append((q, params))
        if "RETURN w.updated AS updated" in q:
            return FakeResult(self.existing)
        if "RETURN s.key AS k" in q:
            return FakeResult(rows=[{"k": k} for k in self.subtasks])
        return FakeResult(None)

    def queries(self, needle):
        return [(q, p) for q, p in self.calls if needle in q]


PASSED = FAILED = 0


def check(name, cond, detail=""):
    global PASSED, FAILED
    if cond:
        PASSED += 1
        print(f"PASS  {name}")
    else:
        FAILED += 1
        print(f"FAIL  {name}  {detail}")


# ==================================================
def test_normalize():
    m = ingest.normalize_issue(make_issue(), T, field_meta={})
    p = m["props"]
    check("uid + tenant/site/Jira ID على الـ WorkItem",
          m["uid"] == f"{T}:site:syntrace.atlassian.net:issue:10300" and p["tenant_id"] == T)
    check("project_key + url من self", p["project_key"] == "SYNTECH"
          and p["url"] == "https://syntrace.atlassian.net/browse/SYNTECH-300", p.get("url"))
    check("statusCategory + is_subtask", p["statusCategory"] == "indeterminate" and p["is_subtask"] is False)
    check("description_text فيه الـ bullets", "- returns 200" in p["description_text"], p["description_text"])
    check("sections من الـ ADF heading", "Acceptance criteria" in json.loads(p["description_sections"]))
    check("Sprint اتكشف من شكل القيمة (من غير meta ولا رقم ثابت)",
          m["sprints"] and m["sprints"][0]["uid"] == f"{T}:site:syntrace.atlassian.net:sprint:5", m.get("sprints"))
    cf = json.loads(p["custom_fields"])
    check("custom fields بأسمائها الحقيقية", cf.get("Story point estimate") == 5.0 and cf.get("Severity") == "Medium", cf)
    check("الـ field الفاضي والـ noise مش بيتخزنوا", "watches" not in cf and "customfield_10050" not in cf, cf)
    check("parent = key بس", m["parent"] == "SYNTECH-18")
    check("subtasks = keys", m["subtasks"] == ["SYNTECH-301"])
    check("اتجاه الـ links صح (inward/outward)",
          set(m["links"]) == {("BLOCKS", "SYNDATA-3", "SYNTECH-300"),
                              ("BLOCKS", "SYNTECH-300", "SYNTECH-30"),
                              ("RELATES_TO", "SYNTECH-300", "SYNTECH-3")}, m["links"])
    check("مفيش email على أي Person",
          all("email" not in str(x) for x in [m["assignee"], m["reporter"], m["comments"][0]["author"]]))
    check("comment نصه من ADF", m["comments"][0]["props"]["text"] == "looks good, see SYNDATA-3")
    check("attachment kinds + content_status مش بيتكتب هنا",
          [a["props"]["kind"] for a in m["attachments"]] == ["image", "video"])
    check("worklog", m["worklogs"][0]["props"]["timeSpentSeconds"] == 7200)
    ch = m["changes"]
    check("changelog -> ChangeEvents (assignee + status)", [c["props"]["field"] for c in ch] == ["assignee", "status"])
    check("AssignmentChange بيعرف from/to person", ch[0]["from_person"]["uid"] == f"{T}:person:acc-z"
          and ch[0]["to_person"]["uid"] == f"{T}:person:acc-f")
    check("changed_at بالـ UTC", ch[0]["props"]["changed_at"] == "2026-10-25T07:00:00+00:00", ch[0]["props"]["changed_at"])


def test_partial_and_unassigned():
    partial = {"key": "SYNTECH-300", "id": "10300", "fields": {"assignee": None}}
    m = ingest.normalize_issue(partial, T, field_meta={})
    check("payload جزئي: summary مش بيتمسح", "summary" not in m["props"])
    check("assignee=null: موجود في الموديل كـ None (يعني unassigned)", "assignee" in m["assignee"] if False else
          ("assignee" in m and m["assignee"] is None))
    check("payload جزئي: مفيش links/parent/sprints يتلمسوا", not any(k in m for k in ("links", "parent", "sprints")))
    tx = FakeTx()
    ingest.write_issue_state(tx, m)
    dels = [q for q, _ in tx.queries("DELETE r") if "ASSIGNED_TO" in q]
    check("unassigned: بيمسح الـ edge القديم ومبيعملش جديد",
          len(dels) == 1 and not tx.queries("MERGE (a)-[:ASSIGNED_TO]"))
    check("payload جزئي: مفيش مسح للـ links", not any("NOT type(r) IN" in q for q, _ in tx.calls))


def test_meta_sprint_and_collision():
    issue = make_issue()
    issue["fields"]["customfield_10020"] = None    # sprint اتشال
    meta = {"customfield_10020": {"name": "Sprint", "schema_custom": "com.pyxis.greenhopper.jira:gh-sprint"}}
    m = ingest.normalize_issue(issue, T, field_meta=meta)
    check("بالـ meta: sprint=null بيتعرف ويتمسح الـ IN_SPRINT", m.get("sprints") == [])
    m2 = ingest.normalize_issue(issue, T, field_meta={})
    check("من غير meta: مش بنمسح حاجة مش متأكدين منها", "sprints" not in m2)


def test_time():
    check("stale: نفس الوقت", ingest.is_stale("2026-10-27T11:00:00.000+0300", "2026-10-27T11:00:00.000+0300"))
    check("stale: أقدم بـ offset مختلف", ingest.is_stale("2026-10-27T11:00:00.000+0300", "2026-10-27T07:30:00.000+0000"))
    check("مش stale: أحدث", not ingest.is_stale("2026-10-27T11:00:00.000+0300", "2026-10-27T11:00:01.000+0300"))
    check("ms epoch", ingest.to_utc_iso(1788000000000).startswith("2026-"), ingest.to_utc_iso(1788000000000))


def test_upsert_flow():
    tx = FakeTx(existing=None)
    check("أول مرة: upserted", ingest.upsert_issue(tx, make_issue(), T, field_meta={}) == "upserted")
    check("MERGE بـ uid", any("MERGE (w:WorkItem {uid: $uid})" in q for q, _ in tx.calls))
    check("الـ stubs بتتعمل ON CREATE بس", tx.queries("ON CREATE SET x.key"))
    check("assignment history اتكتب", len(tx.queries("MERGE (c:ChangeEvent")) == 2)
    check("AssignmentChange label", tx.queries("SET c:AssignmentChange"))

    tx2 = FakeTx(existing={"updated": "2026-10-27T11:04:58.398+0300", "summary": "x"})
    res = ingest.upsert_issue(tx2, make_issue(), T, field_meta={})
    check("update قديم/مكرر: الـ state بيتتجاهل", res == "state_skipped_stale"
          and not tx2.queries("MERGE (w:WorkItem {uid: $uid}) SET w += $props"))
    check("...لكن الـ events (changelog/comments) بتتكتب برضه (idempotent)",
          tx2.queries("MERGE (c:ChangeEvent") and tx2.queries("MERGE (c:Comment"))

    tx3 = FakeTx(existing={"updated": "2026-10-27T11:04:58.398+0300", "summary": "x"})
    res = ingest.upsert_issue(tx3, make_issue(updated="2026-10-28T09:00:00.000+0300"), T, field_meta={})
    check("update أحدث: upserted", res == "upserted")
    tx4 = FakeTx(existing={"updated": "2026-10-27T11:04:58.398+0300", "summary": None})
    res = ingest.upsert_issue(tx4, make_issue(), T, field_meta={})
    check("stub (من غير summary) بيتملى حتى لو الوقت نفسه", res == "upserted")


def test_webhook():
    check("split_event", wh.split_event("jira:issue_created") == ("issue", "created")
          and wh.split_event("board_configuration_changed") == ("board", "configuration_changed")
          and wh.split_event("sprint_started") == ("sprint", "started"))
    payload = {"webhookEvent": "jira:issue_updated", "timestamp": 1788000000000,
               "user": person("acc-i", "Ihab Ramadan"), "issue": make_issue(),
               "changelog": {"id": "55", "items": [{"field": "assignee", "from": "acc-f", "fromString": "Fatma saeedd",
                                                    "to": "acc-z", "toString": "Zienab amr"}]}}
    payload["issue"].pop("changelog")
    tx = FakeTx()
    wh.on_issue(tx, payload, "updated", T)
    ev = [p for q, p in tx.queries("MERGE (c:ChangeEvent")]
    check("webhook changelog -> ChangeEvent بوقت الـ event", len(ev) == 1
          and ev[0]["props"]["changed_at"].startswith("2026-") and ev[0]["props"]["from_name"] == "Fatma saeedd", ev)

    tx = FakeTx(subtasks=["SYNTECH-301"])
    wh.on_issue(tx, {"webhookEvent": "jira:issue_deleted", "issue": {"key": "SYNTECH-300"}}, "deleted", T)
    dels = [q for q, p in tx.calls if "DETACH DELETE w" in q]
    check("issue_deleted = DETACH DELETE (مفيش soft delete) + subtasks",
          len(dels) == 2 and not any("lifecycle_status" in q for q, _ in tx.calls))
    check("بيمسح ملحقات التذكرة (comments/attachments/worklogs/changes)",
          tx.queries("HAS_COMMENT|HAS_ATTACHMENT|HAS_WORKLOG|HAD_CHANGE"))

    tx = FakeTx()
    r = wh.make_generic_handler("issuetype", "IssueType")(
        tx, {"issueType": {"id": 7, "name": "Test Case", "subtask": False, "self": "x"}}, "created", T)
    check("issuetype event عام (label من whitelist)", r == "upserted"
          and tx.calls[0][1]["props"].get("name") == "Test Case" and "self" not in tx.calls[0][1]["props"])
    tx = FakeTx()
    r = wh.on_worklog(tx, {"worklog": {"id": 9, "issueId": "10300", "timeSpentSeconds": 60,
                                       "author": person("acc-f", "Fatma saeedd")}}, "created", T)
    check("worklog بيتربط بالـ issueId مش الـ key", r == "upserted"
          and tx.queries("jira_id: $issue_id") and tx.queries("jira_id: $issue_id")[0][1]["issue_id"] == "10300")
    check("event غريب مش بيكسر", wh.ENTITY_HANDLERS.get(wh.split_event("jira:version_released")[0]) is None)
    tx = FakeTx()
    check("comment_deleted", wh.on_comment(tx, {"comment": {"id": "1"}}, "deleted", T) == "deleted")
    try:
        ingest.delete_by_uid(FakeTx(), "WorkItem) DETACH DELETE (x", "u")
        check("label injection مرفوض", False)
    except ValueError:
        check("label injection مرفوض", True)
    check("rel_type injection بيتعقّم", ingest.rel_type_of("blocks}) DETACH DELETE (n") ==
          "BLOCKS___DETACH_DELETE__N")


def test_retrieval_logic():
    ctx = qe.AccessContext(T, ("SYNTECH",))
    check("extract_keys بيتجاهل مشروع مش مسموح", qe.extract_keys("compare SYNTECH-5 and SYNDATA-3", ctx) == ["SYNTECH-5"])
    check("extract_keys: lowercase", qe.extract_keys("who is on syntech-5?", ctx) == ["SYNTECH-5"])
    check("extract_keys من غير ctx: generic", qe.extract_keys("see ABC-1 and FOO_2-22") == ["ABC-1", "FOO_2-22"])
    r = qe.build_item("SYNDATA-3", "Hybrid retrieval", "In Progress", "u", "Fatma", "SYNDATA", {"SYNTECH"})
    check("مشروع مش مسموح: key + summary بس", r["restricted"] and r["url"] is None
          and r["status"] == "Restricted" and r["assignee"] == "Restricted")
    r = qe.build_item("SYNTECH-5", "x", "ToDo", "u", None, "SYNTECH", {"SYNTECH"})
    check("مسموح: status زي Jira + unassigned", r["status"] == "ToDo" and r["assignee"] == "Unassigned")
    check("incomplete", qe.build_item("A-1", None, None, None, None)["incomplete"])


def test_answers():
    details = {"key": "SYNTECH-3", "summary": "Ask Jira in chat", "status": "In Progress",
               "status_category": "indeterminate", "priority": "High", "assignee": "Fatma saeedd",
               "project": "SYNTECH", "issuetype": "Story", "sprints": ["Sprint 5"], "parent": "SYNTECH-18",
               "children": {"total": 12, "by_status_category": {"new": 2, "indeterminate": 1, "done": 9},
                            "by_type": {"Subtask": 12}, "more": 9,
                            "items": [{"key": "SYNTECH-9", "summary": "key lookup", "status": "To Do", "assignee": "Fatma saeedd"},
                                      {"key": "SYNDATA-3", "summary": "Hybrid", "restricted": True}]},
               "assignment_history": [{"at": "2026-10-25T07:00:00+00:00", "from": "Zienab amr", "to": "Fatma saeedd", "by": "Ihab Ramadan"}],
               "comments": {"total": 4, "latest": [{"created": "2026-10-26", "author": "Zienab amr", "text": "blocked by SYNDATA-3 now"}]}}
    details["description"] = "Users ask about tickets in chat. Depends on SYNDATA-3 for retrieval."
    ctxt = ag.build_ticket_context(details)
    check("context فيه الـ description", "Description:\nUsers ask about tickets in chat." in ctxt, ctxt)
    check("context فيه الـ subtasks كتجميع + 'and 9 more'",
          "Subtasks/children: 12 total (to do 2, in progress 1, done 9)" in ctxt and "and 9 more" in ctxt, ctxt)
    check("context فيه history والـ restricted", "Zienab amr -> Fatma saeedd" in ctxt and "details restricted" in ctxt)
    facts = ag.ticket_facts(details)
    check("grounded: ذكر subtask ومرجع من الكومنت", ag.is_grounded("SYNTECH-3 has 12 subtasks, e.g. SYNTECH-9; blocked by SYNDATA-3.", facts))
    check("key مذكور في الـ description مسموح", ag.is_grounded("SYNTECH-3 depends on SYNDATA-3.", facts))
    check("not grounded: key مخترع", not ag.is_grounded("SYNTECH-3 has subtask SYNTECH-777.", facts))
    tmpl = ag.ticket_template(details)
    check("template فيه parent + subtasks + آخر reassignment",
          "Parent: SYNTECH-18" in tmpl and "Subtasks: 12" in tmpl and "Last reassignment" in tmpl, tmpl)
    rel = {"key": "SYNTECH-11", "items": [{"key": "SYNDATA-3", "summary": "Hybrid", "restricted": True}]}
    check("relation template للـ restricted", "details restricted" in ag.relation_template("SYNTECH-11", rel, "blockers"))
    check("رسالة no-results فيها 'jira ticket key'", "jira ticket key" in ag.NO_RESULTS_MESSAGE.lower())

    # open question: semantic hits -> template (LLM مقفول)
    import types
    fake_mod = types.ModuleType("semantic_search")
    fake_mod.semantic_search = lambda text, ctx: [
        {"key": "SYNTECH-12", "summary": "Login screen", "status": "Done", "assignee": "Rodaina Mohamed",
         "url": "https://x/browse/SYNTECH-12", "score": 0.71}]
    sys.modules["semantic_search"] = fake_mod
    ag.call_llm = lambda *a, **k: None
    out = ag.answer_open_question("tickets about login?", qe.AccessContext(T, ("SYNTECH",)))
    check("open question: template + لينك من الكود", "SYNTECH-12: Login screen" in out and "https://x/browse/SYNTECH-12" in out, out)
    two = [{"key": "SYNTECH-12", "summary": "Login screen", "status": "Done", "assignee": "R",
            "url": "https://x/browse/SYNTECH-12", "score": 0.7},
           {"key": "SYNTECH-17", "summary": "Audit log", "status": "To Do", "assignee": "F",
            "url": "https://x/browse/SYNTECH-17", "score": 0.5}]
    fake_mod.semantic_search = lambda text, ctx: two
    ag.call_llm = lambda *a, **k: "SYNTECH-12 (Login screen) is the relevant one."
    out = ag.answer_open_question("login?", None)
    check("لينكات للتذاكر المذكورة في الإجابة بس",
          "SYNTECH-12: https://x/browse/SYNTECH-12" in out and "SYNTECH-17: https" not in out, out)
    ag.call_llm = lambda *a, **k: None
    fake_mod.semantic_search = lambda text, ctx: []
    check("open question من غير نتايج -> رسالة", ag.answer_open_question("weather?", None) == ag.NO_RESULTS_MESSAGE)
    def boom(text, ctx): raise RuntimeError("ollama down")
    fake_mod.semantic_search = boom
    check("Ollama واقع -> رسالة مش crash", ag.answer_open_question("x", None) == ag.NO_RESULTS_MESSAGE)


# ==================================================
# Mock events (للاختبار على Neo4j الحقيقي بـ webhook_handler.py)
# ==================================================

def write_mocks(folder="mock_events"):
    os.makedirs(folder, exist_ok=True)
    base = make_issue("SYNTECH-300", updated="2026-10-27T11:00:00.000+0300")
    base.pop("changelog")
    sub = make_issue("SYNTECH-301", updated="2026-10-27T11:01:00.000+0300",
                     issuetype={"name": "Subtask", "hierarchyLevel": -1, "subtask": True},
                     parent={"key": "SYNTECH-300"}, subtasks=[], issuelinks=[])
    sub["id"] = "10301"
    sub.pop("changelog")
    updated = copy.deepcopy(base)
    updated["fields"]["updated"] = "2026-10-27T12:00:00.000+0300"
    updated["fields"]["assignee"] = person("acc-z", "Zienab amr")
    events = [
        ("01_issue_created.json", {"timestamp": 1788000000000, "webhookEvent": "jira:issue_created",
                                   "user": person("acc-i", "Ihab Ramadan"), "issue": base}),
        ("02_subtask_created.json", {"timestamp": 1788000060000, "webhookEvent": "jira:issue_created",
                                     "user": person("acc-i", "Ihab Ramadan"), "issue": sub}),
        ("03_issue_updated_assignee_changed.json",
         {"timestamp": 1788003600000, "webhookEvent": "jira:issue_updated", "user": person("acc-i", "Ihab Ramadan"),
          "issue": updated,
          "changelog": {"id": "10501", "items": [{"field": "assignee", "fieldtype": "jira", "from": "acc-f",
                                                  "fromString": "Fatma saeedd", "to": "acc-z", "toString": "Zienab amr"}]}}),
        ("04_comment_created.json", {"timestamp": 1788003700000, "webhookEvent": "comment_created",
                                     "issue": updated,
                                     "comment": {"id": "77", "author": person("acc-z", "Zienab amr"),
                                                 "body": para("taking over this one"),
                                                 "created": "2026-10-27T12:05:00.000+0300", "updated": "2026-10-27T12:05:00.000+0300"}}),
        ("05_worklog_created.json", {"timestamp": 1788003800000, "webhookEvent": "worklog_created",
                                     "worklog": {"id": "88", "issueId": "10300", "author": person("acc-z", "Zienab amr"),
                                                 "timeSpent": "1h", "timeSpentSeconds": 3600,
                                                 "started": "2026-10-27T12:00:00.000+0300", "comment": para("review")}}),
        ("06_sprint_started.json", {"timestamp": 1788003900000, "webhookEvent": "sprint_started",
                                    "sprint": {"id": 6, "name": "Sprint 6", "state": "active", "originBoardId": 1,
                                               "startDate": "2026-10-27T09:00:00.000Z"}}),
        ("07_issuetype_created.json", {"timestamp": 1788004000000, "webhookEvent": "issuetype_created",
                                       "issueType": {"id": 10040, "name": "Test Case", "subtask": False,
                                                     "hierarchyLevel": 0, "self": "https://x"}}),
        ("08_unknown_event.json", {"timestamp": 1788004100000, "webhookEvent": "jira:version_released",
                                   "version": {"id": 1, "name": "v1"}}),
        ("09_issue_deleted.json", {"timestamp": 1788004200000, "webhookEvent": "jira:issue_deleted",
                                   "issue": {"id": "10300", "key": "SYNTECH-300"}}),
    ]
    for name, payload in events:
        with open(os.path.join(folder, name), "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
    print(f"Wrote {len(events)} mock events to {folder}/ (امسحي الملفات القديمة في الفولدر الأول)")


if __name__ == "__main__":
    if "--write-mocks" in sys.argv:
        write_mocks()
        sys.exit(0)
    for t in (test_normalize, test_partial_and_unassigned, test_meta_sprint_and_collision, test_time,
              test_upsert_flow, test_webhook, test_retrieval_logic, test_answers):
        print(f"\n--- {t.__name__} ---")
        t()
    print(f"\n==== {PASSED} passed, {FAILED} failed ====")
    sys.exit(1 if FAILED else 0)
