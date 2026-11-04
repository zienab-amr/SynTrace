"""Phase 3 tests: Jira client, normalization/dynamic fields, webhook contract, event reliability,
deletion/moves, reconciliation. Offline: HTTP and the graph are in-memory doubles
(phase3_fakes.py). They prove the decision logic and the Cypher routing, not Neo4j semantics."""
import glob
import json
import os
import shutil
import tempfile
import types
import unittest
from datetime import datetime, timedelta, timezone

os.environ["JIRA_SITE_ID"] = "syntrace.atlassian.net"
os.environ["EMBED_ON_WEBHOOK"] = "0"

import event_adapter
import event_reliability as rel
import field_catalog
import ingest
import webhook_handler as wh
from phase3_fakes import GraphTx, session_factory

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = "syntrace.atlassian.net"
T = "t1"


class TransientError(Exception):          # name-matched by rel.is_transient like neo4j's
    pass


Fetched = lambda status, issue=None: types.SimpleNamespace(status=status, issue=issue)


class NormalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = sorted(glob.glob(os.path.join(HERE, "all_tickets", "*.json")))
        cls.meta = ingest.load_field_meta(os.path.join(HERE, "field_meta.json"))

    def load(self, key):
        path = os.path.join(HERE, "all_tickets", f"{key}.json")
        if not os.path.exists(path):
            self.skipTest("local all_tickets export is not present")
        with open(path, encoding="utf-8") as f:
            return json.load(f)

    def test_all_274_exported_issues_normalize_with_unique_stable_identity(self):
        if not self.files:
            self.skipTest("local all_tickets export is not present")
        self.assertEqual(len(self.files), 274)
        uids, fps = set(), []
        for path in self.files:
            with open(path, encoding="utf-8") as f:
                issue = json.load(f)
            m = ingest.normalize_issue(issue, T, self.meta, payload_mode="full")
            uids.add(m["uid"])
            self.assertEqual(m["uid"], f"{T}:site:{SITE}:issue:{issue['id']}")
            again = ingest.normalize_issue(issue, T, self.meta, payload_mode="full")
            self.assertEqual(m["fingerprint"], again["fingerprint"])   # deterministic -> idempotent
        self.assertEqual(len(uids), 274)

    def test_core_fields_resolution_estimates_ids_and_changelog_from_real_export(self):
        done = ingest.normalize_issue(self.load("SYNDATA-4"), T, self.meta, payload_mode="full")
        self.assertEqual(done["props"]["resolution"], "Done")
        self.assertEqual(done["props"]["resolution_id"], "10000")
        self.assertRegex(done["props"]["status_id"], r"^\d+$")
        est = ingest.normalize_issue(self.load("SYNDATA-100"), T, self.meta, payload_mode="full")
        self.assertEqual(est["props"]["original_estimate_seconds"], 14400)
        self.assertEqual(est["props"]["remaining_estimate_seconds"], 14400)
        self.assertEqual(est["props"]["project_key"], "SYNDATA")
        self.assertEqual(est["project"]["props"]["jira_id"], "10035")
        hist = ingest.normalize_issue(self.load("SYNDATA-1"), T, self.meta, payload_mode="full")
        self.assertTrue(hist["changes"])
        self.assertEqual(hist["changelog_max_id"], max(int(h["id"]) for h in self.load("SYNDATA-1")["changelog"]["histories"]))
        # resolution/estimates are first-class now, not leaked into custom_fields as strings
        cf = json.loads(done["props"]["custom_fields"])
        self.assertNotIn("Resolution", cf)
        self.assertNotIn("Time Spent", cf)

    def test_custom_fields_keep_types_and_raw_values(self):
        m = ingest.normalize_issue(self.load("SYNDATA-113"), T, self.meta, payload_mode="full")
        cf = json.loads(m["props"]["custom_fields"])
        raw = json.loads(m["props"]["custom_fields_raw"])
        defs = json.loads(m["props"]["custom_field_defs"])
        self.assertEqual(cf["Story point estimate"], 8.0)
        self.assertIsInstance(cf["Story point estimate"], float)            # not "8.0"
        self.assertEqual(raw["customfield_10016"], 8.0)
        self.assertEqual(defs["customfield_10016"]["kind"], "number")
        self.assertIsInstance(cf["Rank"], str)
        self.assertNotIn("customfield_10020", raw)                          # sprint is a relationship

    def test_fields_are_discovered_from_schema_not_hardcoded_ids(self):
        """A different Jira site: the same concepts under other ids and other custom types."""
        meta = field_catalog.meta_from_api([
            {"id": "customfield_20001", "name": "Sprint", "custom": True,
             "schema": {"type": "array", "items": "json", "custom": "com.pyxis.greenhopper.jira:gh-sprint"}},
            {"id": "customfield_20002", "name": "Effort", "custom": True,
             "schema": {"type": "number", "custom": "com.atlassian.jira.plugin.system.customfieldtypes:float"}},
            {"id": "customfield_20003", "name": "Go live", "custom": True,
             "schema": {"type": "date", "custom": "com.atlassian.jira.plugin.system.customfieldtypes:datepicker"}},
            {"id": "customfield_20004", "name": "Reviewed at", "custom": True,
             "schema": {"type": "datetime", "custom": "com.atlassian.jira.plugin.system.customfieldtypes:datetime"}},
            {"id": "customfield_20005", "name": "Tier", "custom": True,
             "schema": {"type": "option", "custom": "com.atlassian.jira.plugin.system.customfieldtypes:select"}},
            {"id": "customfield_20006", "name": "Squads", "custom": True,
             "schema": {"type": "array", "items": "option", "custom": "com.atlassian.jira.plugin.system.customfieldtypes:multiselect"}},
            {"id": "customfield_20007", "name": "Approvers", "custom": True,
             "schema": {"type": "array", "items": "user", "custom": "com.atlassian.jira.plugin.system.customfieldtypes:multiuserpicker"}},
            {"id": "customfield_20008", "name": "Notes", "custom": True,
             "schema": {"type": "string", "custom": "com.atlassian.jira.plugin.system.customfieldtypes:textarea"}},
            {"id": "customfield_20009", "name": "Budget", "custom": True,
             "schema": {"type": "number", "custom": "com.atlassian.jira.plugin.system.customfieldtypes:float"}},
        ])
        issue = {"id": "7", "key": "X-7", "self": f"https://{SITE}/rest/api/3/issue/7",
                 "fields": {"project": {"key": "X"},
                            "customfield_20001": [{"id": 9, "name": "Sprint 9", "state": "active"}],
                            "customfield_20002": 0,                        # zero is a value, not "empty"
                            "customfield_20003": "2026-12-01",
                            "customfield_20004": "2026-11-02T10:00:00.000+0200",
                            "customfield_20005": {"id": "1", "value": "Gold"},
                            "customfield_20006": [{"id": "a", "value": "Red"}, {"id": "b", "value": "Blue"}],
                            "customfield_20007": [{"accountId": "u1", "displayName": "Ann"}],
                            "customfield_20008": {"type": "doc", "version": 1, "content": [
                                {"type": "paragraph", "content": [{"type": "text", "text": "hello"}]}]},
                            "customfield_20009": "12.5",                   # string in a number field
                            "customfield_29999": {"unknown": [1, 2]}}}      # id absent from the catalog
        m = ingest.normalize_issue(issue, T, meta, payload_mode="full")
        cf = json.loads(m["props"]["custom_fields"])
        self.assertEqual(m["sprints"][0]["uid"], f"{T}:site:{SITE}:sprint:9")
        self.assertEqual(cf["Effort"], 0)
        self.assertIsInstance(cf["Effort"], int)
        self.assertEqual(cf["Go live"], "2026-12-01")
        self.assertEqual(cf["Reviewed at"], "2026-11-02T08:00:00+00:00")
        self.assertEqual(cf["Tier"], "Gold")
        self.assertEqual(cf["Squads"], ["Red", "Blue"])
        self.assertEqual(cf["Approvers"], ["Ann"])
        self.assertEqual(cf["Notes"], "hello")
        self.assertEqual(cf["Budget"], 12.5)                               # clean numeric string -> number
        self.assertEqual(cf["customfield_29999"], {"unknown": [1, 2]})     # unknown object kept intact
        raw = json.loads(m["props"]["custom_fields_raw"])
        self.assertEqual(raw["customfield_20005"], {"id": "1", "value": "Gold"})   # ids preserved
        self.assertEqual(field_catalog.unknown_field_ids(issue["fields"], meta), ["customfield_29999"])

    def test_type_mismatch_is_kept_and_reported_not_coerced(self):
        meta = field_catalog.meta_from_api([{"id": "customfield_1", "name": "Effort", "custom": True,
                                             "schema": {"type": "number", "custom": "x:float"}}])
        m = ingest.normalize_issue({"id": "1", "key": "X-1", "self": f"https://{SITE}/x",
                                    "fields": {"customfield_1": "about a week"}}, T, meta)
        self.assertEqual(json.loads(m["props"]["custom_fields"])["Effort"], "about a week")
        self.assertIn("type_mismatch:customfield_1:number", m["props"]["ingest_warnings"])

    def test_missing_fields_partial_vs_full_and_null_semantics(self):
        sparse = {"id": "5", "key": "X-5", "self": f"https://{SITE}/x", "fields": {"project": {"key": "X"}}}
        partial = ingest.normalize_issue(sparse, T, {}, payload_mode="partial")
        full = ingest.normalize_issue(sparse, T, {}, payload_mode="full")
        for p in ("resolution", "priority", "environment", "remaining_estimate_seconds"):
            self.assertNotIn(p, partial["clear_props"])
            self.assertIn(p, full["clear_props"])
        cleared = ingest.normalize_issue({**sparse, "fields": {"project": {"key": "X"}, "resolution": None}}, T, {})
        self.assertIn("resolution", cleared["clear_props"])
        self.assertTrue(set(full["clear_props"]) <= ingest.CLEARABLE_PROPS)

    def test_repeated_bulk_ingestion_creates_no_duplicates(self):
        tx = GraphTx()
        for _ in range(3):
            for key in ("SYNDATA-1", "SYNDATA-4", "SYNDATA-113"):
                ingest.upsert_issue(tx, self.load(key), T, field_meta=self.meta, payload_mode="full")
        self.assertEqual(len([n for n in tx.items.values() if n.get("summary")]), 3)
        hist_count = sum(len(ingest.normalize_issue(self.load(k), T, self.meta)["changes"])
                         for k in ("SYNDATA-1", "SYNDATA-4", "SYNDATA-113"))
        self.assertGreater(hist_count, 1)
        self.assertEqual(tx.count("ChangeEvent"), hist_count)
        self.assertEqual(len(tx.projects), 1)

    def test_comment_worklog_attachment_metadata_normalized(self):
        issue = {"id": "8", "key": "X-8", "self": f"https://{SITE}/x", "fields": {
            "project": {"key": "X"},
            "comment": {"comments": [{"id": "c1", "author": {"accountId": "a", "displayName": "A", "emailAddress": "a@x"},
                                      "body": {"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "hi"}]}]},
                                      "created": "2026-10-01T10:00:00.000+0000", "updated": "2026-10-01T10:00:00.000+0000"}]},
            "worklog": {"worklogs": [{"id": "w1", "issueId": "8", "timeSpentSeconds": 600, "author": {"accountId": "a"},
                                      "updated": "2026-10-01T10:00:00.000+0000"}]},
            "attachment": [{"id": "at1", "filename": "a.png", "mimeType": "image/png", "size": 5}]}}
        m = ingest.normalize_issue(issue, T, {})
        self.assertEqual(m["comments"][0]["props"]["text"], "hi")
        self.assertEqual(m["worklogs"][0]["props"]["issue_id"], "8")
        self.assertEqual(m["attachments"][0]["props"]["kind"], "image")
        self.assertNotIn("email", json.dumps(m["comments"][0]["author"]))


# ============================================================ helpers for event tests
def issue_obj(key="SYNTECH-300", jid="10300", updated="2026-10-27T11:00:00.000+0000", summary="s",
              project=("SYNTECH", "10035"), host=SITE, **fields):
    return {"id": jid, "key": key, "self": f"https://{host}/rest/api/3/issue/{jid}",
            "fields": {"summary": summary, "updated": updated,
                       "project": {"key": project[0], "id": project[1], "name": project[0]},
                       "status": {"name": "To Do", "id": "1", "statusCategory": {"key": "new"}}, **fields}}


def event(name, issue=None, ts=1788000000000, changelog=None, **extra):
    p = {"webhookEvent": name, "timestamp": ts, **extra}
    if issue is not None:
        p["issue"] = issue
    if changelog is not None:
        p["changelog"] = changelog
    return p


class EventBase(unittest.TestCase):
    def setUp(self):
        self.tx = GraphTx()
        self.sleeps = []
        self.raw = tempfile.mkdtemp()
        self._old_raw = wh.RAW_EVENTS_DIR
        wh.RAW_EVENTS_DIR = self.raw
        self.recent = rel.RecentEvents()
        os.environ["JOURNAL_FAILED_EVENTS"] = "1"   # journaling is opt-in; these tests cover it

    def tearDown(self):
        os.environ.pop("JOURNAL_FAILED_EVENTS", None)
        wh.RAW_EVENTS_DIR = self._old_raw
        shutil.rmtree(self.raw, ignore_errors=True)

    def handle(self, payload, fail_plan=None, **kw):
        kw.setdefault("session_factory", session_factory(self.tx, fail_plan))
        kw.setdefault("recent", self.recent)
        kw.setdefault("sleep", self.sleeps.append)
        kw.setdefault("rng", lambda: 1.0)
        return wh.handle_event(payload, T, **kw)

    def node(self, jid="10300"):
        return self.tx.items[ingest.workitem_uid(T, SITE, jid)]


# ============================================================ 3. Webhook contract & scope
class ContractTests(EventBase):
    def test_native_jira_payload_is_still_accepted_and_legacy_string_returned(self):
        r = self.handle(event("jira:issue_created", issue_obj()))
        self.assertEqual((r.status, r.outcome), ("upserted", "applied"))
        mock = {"webhookEvent": "jira:issue_created", "issue": {"key": "SYNTECH-300", "fields": {}}}
        # no Jira id: refused (identity must be stable), surfaced as an error to the caller
        self.assertEqual(self.handle(mock).outcome, "rejected")
        with self.assertRaises(wh.EventProcessingError):
            wh.process_webhook_event(mock, T, session_factory=session_factory(self.tx), recent=self.recent)
        self.tx = GraphTx()
        with open(os.path.join(HERE, "mock_events", "1_issue_created.json")) as f:
            self.assertEqual(self.handle(json.load(f)).outcome, "applied")

    def test_internal_deletion_notice_is_recognized_only_in_exact_shape(self):
        ok = {"type": "issue", "id": "10300"}
        self.assertTrue(event_adapter.is_internal_deletion(ok))
        self.assertTrue(event_adapter.is_internal_deletion({"type": "project", "id": 7, "site_id": "s"}))
        self.assertFalse(event_adapter.is_internal_deletion({**ok, "issue": {}}))          # extra keys
        self.assertFalse(event_adapter.is_internal_deletion({"webhookEvent": "jira:issue_deleted", **ok}))
        r = self.handle({"type": "issue", "id": "1", "surprise": True})
        self.assertEqual(r.outcome, "ignored")                                               # never deletes

    def test_unsupported_internal_type_is_rejected_and_journaled(self):
        r = self.handle({"type": "webhook", "id": "1"})
        self.assertEqual((r.status, r.outcome, r.retryable), ("rejected_scope", "rejected", False))
        self.assertTrue(os.listdir(os.path.join(self.raw, T, "failed")))

    def test_tenant_mismatch_is_rejected(self):
        r = self.handle({"type": "issue", "id": "1", "tenant_id": "other"})
        self.assertEqual(r.outcome, "rejected")
        self.assertIn("tenant mismatch", r.error)

    def test_missing_site_is_rejected_never_guessed(self):
        old = os.environ.pop("JIRA_SITE_ID")
        old_base = os.environ.pop("JIRA_BASE_URL", None)   # a local .env may set it
        try:
            r = self.handle({"type": "issue", "id": "1"})
            self.assertEqual(r.outcome, "rejected")
            self.assertIn("site unknown", r.error)
            r = self.handle(event("jira:issue_deleted", {"id": "1", "key": "A-1"}))   # no `self`
            self.assertEqual(r.outcome, "rejected")
        finally:
            os.environ["JIRA_SITE_ID"] = old
            if old_base is not None:
                os.environ["JIRA_BASE_URL"] = old_base

    def test_cross_site_payload_is_rejected_when_configured_site_differs(self):
        r = self.handle(event("jira:issue_created", issue_obj(host="other.atlassian.net")))
        self.assertEqual(r.outcome, "rejected")
        self.assertIn("site mismatch", r.error)
        self.assertFalse(self.tx.items)

    def test_same_issue_id_on_two_sites_never_collides(self):
        self.handle(event("jira:issue_created", issue_obj()))
        self.handle(event("jira:issue_created", issue_obj(host="other.atlassian.net")), site_id="other.atlassian.net")
        self.assertEqual(len([n for n in self.tx.items.values() if n.get("summary")]), 2)
        self.handle({"type": "issue", "id": "10300"})                    # configured site only
        remaining = [n for n in self.tx.items.values() if n.get("summary")]
        self.assertEqual([n["jira_site_id"] for n in remaining], ["other.atlassian.net"])

    def test_tenant_scoping_of_identical_events(self):
        self.handle(event("jira:issue_created", issue_obj()))
        wh.handle_event(event("jira:issue_created", issue_obj()), "t2",
                        session_factory=session_factory(self.tx), recent=self.recent, sleep=self.sleeps.append)
        self.assertEqual(len([n for n in self.tx.items.values() if n.get("summary")]), 2)

    def test_event_id_is_stable_and_discriminates(self):
        a = event_adapter.adapt(event("jira:issue_updated", issue_obj(), changelog={"id": "5", "items": []}), T)
        b = event_adapter.adapt(event("jira:issue_updated", issue_obj(), changelog={"id": "5", "items": []}), T)
        c = event_adapter.adapt(event("jira:issue_updated", issue_obj(), changelog={"id": "6", "items": []}), T)
        d = event_adapter.adapt(event("jira:issue_updated", issue_obj()), T, delivery_id="abc")
        e = event_adapter.adapt(event("jira:issue_updated", issue_obj(), ts=1), T, delivery_id="abc")
        self.assertEqual(a.event_id, b.event_id)
        self.assertNotEqual(a.event_id, c.event_id)
        self.assertEqual(d.event_id, e.event_id)               # retry-stable delivery header wins


# ============================================================ 4. Reliability: duplicates, ordering, retries
class ReliabilityTests(EventBase):
    def test_duplicate_delivery_is_suppressed_and_idempotent_even_after_restart(self):
        p = event("jira:issue_updated", issue_obj(), changelog={"id": "10", "items": [
            {"field": "status", "fromString": "To Do", "toString": "Done"}]})
        self.assertEqual(self.handle(p).outcome, "applied")
        self.assertEqual(self.handle(p).outcome, "duplicate")             # LRU short-circuit
        before = (self.tx.count("ChangeEvent"), dict(self.node()))
        self.recent.clear()                                               # simulate process restart
        r = self.handle(p)
        self.assertEqual((r.outcome, r.status), ("stale", "state_skipped_stale"))
        self.assertEqual((self.tx.count("ChangeEvent"), dict(self.node())), before)
        self.assertEqual(self.tx.count("ChangeEvent"), 1)

    def test_out_of_order_older_event_cannot_overwrite_newer_state(self):
        new = event("jira:issue_updated", issue_obj(summary="NEW", updated="2026-10-27T12:00:00.000+0000"), ts=2000)
        old = event("jira:issue_updated", issue_obj(summary="OLD", updated="2026-10-27T11:00:00.000+0000"), ts=1000,
                    changelog={"id": "3", "items": [{"field": "summary", "fromString": "a", "toString": "OLD"}]})
        self.assertEqual(self.handle(new).outcome, "applied")
        r = self.handle(old)
        self.assertEqual(r.outcome, "stale")
        self.assertEqual(self.node()["summary"], "NEW")
        self.assertEqual(self.tx.count("ChangeEvent"), 1)                 # history of the old event is kept

    def test_created_arriving_after_updated_does_not_regress(self):
        self.handle(event("jira:issue_updated", issue_obj(summary="v2", updated="2026-10-27T12:00:00.000+0000")))
        r = self.handle(event("jira:issue_created", issue_obj(summary="v1", updated="2026-10-27T10:00:00.000+0000"), ts=5))
        self.assertEqual(r.outcome, "stale")
        self.assertEqual(self.node()["summary"], "v2")

    def test_changelog_id_orders_events_when_updated_ties_or_is_missing(self):
        ts = "2026-10-27T12:00:00.000+0000"
        self.handle(event("jira:issue_updated", issue_obj(summary="c10", updated=ts), changelog={"id": "10", "items": []}))
        r = self.handle(event("jira:issue_updated", issue_obj(summary="c9", updated=ts), ts=7,
                              changelog={"id": "9", "items": []}))
        self.assertEqual(r.outcome, "stale")                               # same updated, lower changelog id
        self.assertEqual(self.node()["summary"], "c10")
        r = self.handle(event("jira:issue_updated", issue_obj(summary="c11", updated=ts), ts=8,
                              changelog={"id": "11", "items": []}))
        self.assertEqual(r.outcome, "applied")                             # same updated, higher id wins
        self.assertEqual(self.node()["summary"], "c11")
        nodate = issue_obj(summary="nodate")
        nodate["fields"].pop("updated")
        r = self.handle(event("jira:issue_updated", nodate, ts=9, changelog={"id": "12", "items": []}))
        self.assertEqual((r.outcome, self.node()["summary"]), ("applied", "nodate"))   # changelog id alone proves newer
        self.assertEqual(self.node()["last_changelog_id"], 12)

    def test_compare_versions_matrix(self):
        cv = ingest.compare_versions
        a, b = "2026-10-27T11:00:00.000+0000", "2026-10-27T11:00:00.001+0000"
        self.assertEqual(cv(a, None, b, None), "newer")
        self.assertEqual(cv(b, None, a, None), "older")
        self.assertEqual(cv(a, None, a, None), "duplicate")
        self.assertEqual(cv(a, 5, a, 6), "newer")
        self.assertEqual(cv(a, 5, a, 5), "duplicate")
        self.assertEqual(cv(a, 5, a, 4), "older")
        self.assertEqual(cv(a, None, a, None, existing_fp="x", incoming_fp="y",
                            existing_fp_mode="partial", incoming_fp_mode="partial"), "ambiguous")
        self.assertEqual(cv(a, None, a, None, existing_fp="x", incoming_fp="y",
                            existing_fp_mode="full", incoming_fp_mode="partial"), "duplicate")
        self.assertEqual(cv(a, None, None, None), "ambiguous")
        # delivery timestamp proves OLDER only
        before = datetime(2026, 10, 27, 10, 0, tzinfo=timezone.utc).isoformat()
        after = datetime(2026, 10, 27, 13, 0, tzinfo=timezone.utc).isoformat()
        self.assertEqual(cv(a, None, None, None, event_time=before), "older")
        self.assertEqual(cv(a, None, None, None, event_time=after), "ambiguous")
        self.assertEqual(cv(None, None, a, None), "newer")
        self.assertEqual(cv(a, None, "not-a-date", None), "ambiguous")

    def _tie_events(self):
        ts = "2026-10-27T12:00:00.000+0000"
        first = event("jira:issue_updated", issue_obj(summary="first", updated=ts), ts=100)
        second = event("jira:issue_updated", issue_obj(summary="second", updated=ts), ts=101)
        return first, second

    def test_same_timestamp_different_content_is_ambiguous_flagged_not_overwritten(self):
        first, second = self._tie_events()
        self.handle(first)
        r = self.handle(second)
        self.assertEqual((r.outcome, r.status), ("ambiguous", "state_skipped_ambiguous"))
        self.assertEqual(self.node()["summary"], "first")
        self.assertTrue(self.node()["reconcile_needed"])

    def test_ambiguity_resolved_by_authoritative_jira_read(self):
        first, second = self._tie_events()
        self.handle(first)

        class Reader:
            def __init__(s):
                s.asked = []

            def get_issue(s, target):
                s.asked.append(target)
                live = issue_obj(summary="LIVE", updated="2026-10-27T12:00:00.000+0000")
                return Fetched("found", live)

            def get_fields(s):
                return []
        reader = Reader()
        r = self.handle(second, jira_reader=reader)
        self.assertEqual((r.outcome, r.status), ("applied", "upserted"))
        self.assertEqual(reader.asked, ["10300"])
        self.assertEqual(self.node()["summary"], "LIVE")
        self.assertNotIn("reconcile_needed", self.node())                  # flag cleared by the write
        self.assertEqual(r.detail["resolution"]["authoritative_read"], "found")

    def test_authoritative_404_or_error_never_deletes_and_stays_flagged(self):
        first, second = self._tie_events()
        self.handle(first)
        for fetched in (Fetched("not_found_or_inaccessible"), RuntimeError("jira down")):
            class Reader:
                def get_issue(s, target):
                    if isinstance(fetched, Exception):
                        raise fetched
                    return fetched

                def get_fields(s):
                    return []
            self.recent.clear()
            r = self.handle(second, jira_reader=Reader())
            self.assertEqual(r.outcome, "ambiguous")
            self.assertEqual(self.node()["summary"], "first")
            self.assertTrue(self.node()["reconcile_needed"])

    def test_transient_failure_retries_with_exponential_backoff_and_rolls_back(self):
        p = event("jira:issue_created", issue_obj(),
                  changelog={"id": "1", "items": [{"field": "status", "fromString": "a", "toString": "b"}]})
        r = self.handle(p, fail_plan=[TransientError("deadlock"), TransientError("leader switch"), None])
        self.assertEqual((r.outcome, r.attempts), ("applied", 3))
        self.assertEqual(self.sleeps, [0.5, 1.0])                          # base*2**(n-1), jitter fixed at 1.0
        self.assertNotIn("partial-garbage", self.tx.items)                 # failed attempts rolled back
        self.assertEqual(self.tx.count("ChangeEvent"), 1)                  # no duplicates after retry

    def test_retries_exhausted_returns_retryable_failure_and_journals_payload(self):
        p = event("jira:issue_created", issue_obj())
        r = self.handle(p, fail_plan=[TransientError("x")] * 5, max_attempts=3)
        self.assertEqual((r.outcome, r.retryable, r.attempts), ("failed", True, 3))
        self.assertFalse(self.tx.items)
        self.assertEqual(len(os.listdir(os.path.join(self.raw, T, "failed"))), 1)
        with self.assertRaises(wh.EventProcessingError) as cm:
            wh.process_webhook_event(p, T, session_factory=session_factory(self.tx, [TransientError("x")] * 5),
                                     recent=rel.RecentEvents(), sleep=lambda s: None, max_attempts=2)
        self.assertTrue(cm.exception.retryable)                            # caller knows redelivery can help

    def test_permanent_error_is_not_retried(self):
        r = self.handle(event("jira:issue_created", issue_obj()), fail_plan=[ingest.IdentityConflictError("dup ids")])
        self.assertEqual((r.outcome, r.retryable, r.attempts), ("rejected", False, 1))
        self.assertEqual(self.sleeps, [])

    def test_replay_of_journaled_failures_is_idempotent_and_removes_the_file(self):
        p = event("jira:issue_created", issue_obj())
        self.handle(p, fail_plan=[TransientError("x")] * 5, max_attempts=2)
        stats = rel.replay_failed(self.raw, T, lambda payload, tenant, **kw: wh.process_webhook_event(
            payload, tenant, session_factory=session_factory(self.tx), recent=self.recent,
            sleep=self.sleeps.append, **kw))
        self.assertEqual(stats["replayed"], 1)
        self.assertEqual(os.listdir(os.path.join(self.raw, T, "failed")), [])
        self.assertEqual(self.node()["summary"], "s")
        stats = rel.replay_failed(self.raw, T, lambda *a, **k: self.fail("nothing left to replay"))
        self.assertEqual(stats, {"replayed": 0, "failed": 0, "skipped": 0})

    def test_unknown_event_is_stored_raw_only(self):
        r = self.handle(event("jira:version_released"))
        self.assertEqual((r.status, r.outcome), ("stored_raw_only", "ignored"))

    def test_unknown_customfield_triggers_catalog_refresh_failures_do_not_fail_event(self):
        class Reader:
            def get_fields(s):
                raise RuntimeError("boom")
        wh._last_field_refresh[0] = 0
        p = event("jira:issue_created", issue_obj(customfield_77777="x"))
        self.assertEqual(self.handle(p, jira_reader=Reader()).outcome, "applied")


# ============================================================ 5. Deletion and moves
class DeletionAndMoveTests(EventBase):
    def seed(self, key="SYNTECH-300", jid="10300", **kw):
        return self.handle(event("jira:issue_created", issue_obj(key=key, jid=jid, **kw)))

    def test_native_issue_deleted_removes_data(self):
        self.seed()
        self.handle(event("jira:issue_updated", issue_obj(updated="2026-10-27T11:30:00.000+0000"),
                          changelog={"id": "1", "items": [{"field": "status", "toString": "x"}]}))
        r = self.handle(event("jira:issue_deleted", {"id": "10300", "key": "SYNTECH-300", "self": f"https://{SITE}/rest/api/3/issue/10300"}, ts=9))
        self.assertEqual(r.status, "deleted")
        self.assertFalse(self.tx.by_key("SYNTECH-300"))
        self.assertEqual(self.tx.count("ChangeEvent"), 0)

    def test_internal_deletion_by_jira_id_and_by_key(self):
        self.seed()
        self.seed("SYNTECH-301", "10301")
        self.assertEqual(self.handle({"type": "issue", "id": "10300"}).status, "deleted")
        self.assertFalse(self.tx.by_key("SYNTECH-300"))
        self.assertEqual(self.handle({"type": "issue", "id": 10301}).status, "deleted")   # numeric JSON id
        self.seed("SYNTECH-302", "10302")
        self.assertEqual(self.handle({"type": "issue", "id": "SYNTECH-302"}).status, "deleted")
        self.assertFalse([n for n in self.tx.items.values() if n.get("summary")])
        self.assertEqual(self.handle({"type": "issue", "id": "not an id!"}).outcome, "rejected")

    def test_deleted_issue_is_stored_again_when_it_comes_back(self):
        self.seed()
        self.handle({"type": "issue", "id": "10300"})
        self.assertFalse(self.tx.by_key("SYNTECH-300"))
        self.assertEqual(ingest.upsert_issue(self.tx, issue_obj(), T, payload_mode="full"), "upserted")
        self.assertTrue(self.tx.by_key("SYNTECH-300"))

    def test_recreated_issue_with_new_id_and_same_key_is_stored(self):
        self.seed()
        self.handle({"type": "issue", "id": "10300"})
        self.assertEqual(ingest.upsert_issue(self.tx, issue_obj(jid="20300"), T, payload_mode="full"), "upserted")
        self.assertEqual(len(self.tx.by_key("SYNTECH-300")), 1)

    def test_deletion_notice_for_never_ingested_issue_does_not_block_a_later_snapshot(self):
        self.assertEqual(self.handle({"type": "issue", "id": "999"}).status, "deleted")
        self.assertEqual(ingest.upsert_issue(self.tx, issue_obj(key="P-9", jid="999"), T, payload_mode="full"),
                         "upserted")

    def test_replayed_deletion_is_idempotent(self):
        self.seed()
        self.assertEqual(self.handle({"type": "issue", "id": "10300"}).status, "deleted")
        self.recent.clear()
        self.assertEqual(self.handle({"type": "issue", "id": "10300"}).status, "deleted")
        self.assertFalse(self.tx.by_key("SYNTECH-300"))

    def test_comment_deletion_removes_it_and_a_later_event_stores_it_again(self):
        cid = "55"
        com = {"id": cid, "body": "hi", "updated": "2026-10-27T10:00:00.000+0000", "author": {"accountId": "a"}}
        iss = issue_obj()
        self.handle(event("comment_created", iss, comment=com))
        self.assertEqual(self.tx.count("Comment"), 1)
        self.handle({"type": "comment", "id": cid})
        self.assertEqual(self.tx.count("Comment"), 0)
        r = self.handle(event("comment_updated", iss, ts=3, comment={**com, "updated": "2026-10-27T10:05:00.000+0000"}))
        self.assertEqual(r.status, "upserted")
        self.assertEqual(self.tx.count("Comment"), 1)

    def test_worklog_deletion_via_native_event(self):
        w = {"id": "w1", "issueId": "10300", "timeSpentSeconds": 60, "updated": "2026-10-27T10:00:00.000+0000"}
        self.handle(event("worklog_created", issue_obj(), worklog=w))
        self.assertEqual(self.tx.count("Worklog"), 1)
        self.handle(event("worklog_deleted", issue_obj(), ts=4, worklog=w))
        self.assertEqual(self.tx.count("Worklog"), 0)
        self.assertEqual(self.handle(event("worklog_updated", issue_obj(), ts=5, worklog=w)).status, "upserted")

    # ---- moves
    def test_issue_move_keeps_one_node_records_alias_and_project(self):
        self.seed()
        moved = issue_obj(key="NEWP-7", updated="2026-10-27T12:00:00.000+0000", project=("NEWP", "10099"))
        r = self.handle(event("jira:issue_updated", moved, changelog={"id": "20", "items": [
            {"field": "Key", "fromString": "SYNTECH-300", "toString": "NEWP-7"},
            {"field": "project", "fromString": "SYNTECH", "toString": "NEWP"}]}))
        self.assertEqual(r.outcome, "applied")
        self.assertEqual(r.detail["moved_from"], "SYNTECH-300")
        self.assertEqual(r.detail["project_from"], "SYNTECH")
        nodes = [n for n in self.tx.items.values() if n.get("summary")]
        self.assertEqual(len(nodes), 1)                                    # no duplicate WorkItem
        self.assertEqual((nodes[0]["key"], nodes[0]["project_key"]), ("NEWP-7", "NEWP"))
        self.assertEqual(nodes[0]["key_aliases"], ["SYNTECH-300"])
        self.assertEqual(nodes[0]["jira_id"], "10300")

    def test_stale_event_under_old_key_after_move_does_not_recreate_or_revert(self):
        self.seed()
        self.handle(event("jira:issue_updated", issue_obj(key="NEWP-7", updated="2026-10-27T12:00:00.000+0000",
                                                          project=("NEWP", "10099"))))
        r = self.handle(event("jira:issue_updated", issue_obj(key="SYNTECH-300", summary="old", updated="2026-10-27T11:30:00.000+0000"), ts=3))
        self.assertEqual(r.outcome, "stale")
        self.assertEqual(len([n for n in self.tx.items.values() if n.get("summary")]), 1)
        self.assertEqual(self.node()["key"], "NEWP-7")

    def test_deleting_by_old_key_after_move_deletes_the_moved_issue(self):
        self.seed()
        self.handle(event("jira:issue_updated", issue_obj(key="NEWP-7", updated="2026-10-27T12:00:00.000+0000",
                                                          project=("NEWP", "10099"))))
        self.assertEqual(self.handle({"type": "issue", "id": "SYNTECH-300"}).status, "deleted")
        self.assertFalse([n for n in self.tx.items.values() if n.get("summary")])

    def test_project_key_rename_renames_in_place_and_keeps_alias(self):
        self.seed()
        self.handle(event("project_updated", None, project={"id": "10035", "key": "SYNTECH", "name": "SynTech"}))
        self.handle(event("project_updated", None, ts=2, project={"id": "10035", "key": "SYNT2", "name": "SynTech"}))
        self.assertEqual([p["key"] for p in self.tx.projects.values()], ["SYNT2"])
        self.assertEqual(list(self.tx.projects.values())[0]["key_aliases"], ["SYNTECH"])
        self.assertEqual(self.node()["project_key"], "SYNT2")

    # ---- project deletion
    def test_project_deletion_does_not_need_per_issue_events(self):
        for i in range(5):
            self.seed(f"SYNTECH-{i}", str(100 + i))
        self.seed("OTHER-1", "200", project=("OTHER", "10050"))
        self.handle(event("project_updated", None, project={"id": "10035", "key": "SYNTECH"}))
        r = self.handle(event("project_deleted", None, ts=5, project={"id": "10035", "key": "SYNTECH"}))
        self.assertEqual(r.status, "deleted")
        self.assertEqual([n["key"] for n in self.tx.items.values() if n.get("summary")], ["OTHER-1"])
        self.assertEqual(ingest.upsert_issue(self.tx, issue_obj(key="SYNTECH-77", jid="777"), T), "upserted")

    def test_internal_project_deletion_by_id_resolves_key_through_stored_project_id(self):
        self.seed("SYNTECH-1", "100")
        self.seed("SYNTECH-2", "101")
        self.assertEqual(self.handle({"type": "project", "id": "10035"}).status, "deleted")
        self.assertFalse([n for n in self.tx.items.values() if n.get("summary")])
        self.assertEqual(ingest.upsert_issue(self.tx, issue_obj(key="SYNTECH-9", jid="900"), T), "upserted")

    def test_internal_project_deletion_by_key(self):
        self.seed("SYNTECH-1", "100")
        self.assertEqual(self.handle({"type": "project", "id": "SYNTECH"}).status, "deleted")
        self.assertFalse(self.tx.items and [n for n in self.tx.items.values() if n.get("summary")])

    def test_project_deletion_for_unknown_id_is_a_no_op(self):
        r = self.handle({"type": "project", "id": "424242"})
        self.assertEqual(r.status, "deleted")
        self.assertEqual(ingest.upsert_issue(self.tx, issue_obj(project=("X", "424242")), T), "upserted")

    def test_project_soft_delete_and_restore_requires_resync(self):
        self.seed("SYNTECH-1", "100")
        self.handle(event("project_soft_deleted", None, ts=3, project={"id": "10035", "key": "SYNTECH"}))
        self.assertFalse([n for n in self.tx.items.values() if n.get("summary")])
        r = self.handle(event("project_restored_deleted", None, ts=4, project={"id": "10035", "key": "SYNTECH"}))
        self.assertEqual(r.status, "restored_resync_required")
        self.assertEqual(ingest.upsert_issue(self.tx, issue_obj(key="SYNTECH-1", jid="100"), T), "upserted")


if __name__ == "__main__":
    unittest.main(verbosity=2)