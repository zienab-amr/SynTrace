"""
ai_consumer.py
RabbitMQ consumer of the AI side. Reads syntrace.ai.jira and keeps Neo4j in step with Jira.

  python ai_consumer.py

The backend owns the topology. For local development set AI_DECLARE_TOPOLOGY=1 to declare it here.
Messages are handled one at a time and are acked only after their work is done or they were parked.
Embeddings run in their own thread, so a long run never delays Jira events. That thread finds its
work from the graph, so it resumes by itself after a restart or an Ollama failure.
"""
import json
import logging
import os
import signal
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime, timezone

import pika
from dotenv import load_dotenv

load_dotenv()

import event_reliability as rel
import field_catalog
import ingest
import webhook_handler

log = logging.getLogger("syntrace.consumer")

RETRY_HEADER = "x-retry-count"
RETRY_ROUTING_KEY = "retry"
DEAD_ROUTING_KEY = "dead"


@dataclass
class Settings:
    host: str = field(default_factory=lambda: os.getenv("RABBITMQ_HOST", "localhost"))
    port: int = field(default_factory=lambda: int(os.getenv("RABBITMQ_PORT", "5672")))
    vhost: str = field(default_factory=lambda: os.getenv("RABBITMQ_VHOST", "/"))
    user: str = field(default_factory=lambda: os.getenv("RABBITMQ_USER", "guest"))
    password: str = field(default_factory=lambda: os.getenv("RABBITMQ_PASSWORD", "guest"))
    exchange: str = field(default_factory=lambda: os.getenv("AI_EVENTS_EXCHANGE", "syntrace.events"))
    queue: str = field(default_factory=lambda: os.getenv("AI_QUEUE", "syntrace.ai.jira"))
    retry_exchange: str = field(default_factory=lambda: os.getenv("AI_RETRY_EXCHANGE", "syntrace.ai.retry"))
    retry_queue: str = field(default_factory=lambda: os.getenv("AI_RETRY_QUEUE", "syntrace.ai.jira.retry"))
    dead_exchange: str = field(default_factory=lambda: os.getenv("AI_DEAD_EXCHANGE", "syntrace.ai.dlx"))
    dead_queue: str = field(default_factory=lambda: os.getenv("AI_DEAD_QUEUE", "syntrace.ai.jira.dead-letter"))
    retry_ttl_ms: int = field(default_factory=lambda: int(os.getenv("AI_RETRY_TTL_MS", "30000")))
    max_retries: int = field(default_factory=lambda: int(os.getenv("AI_MAX_RETRIES", "5")))


@dataclass
class Decision:
    action: str          # ack | retry | dead
    reason: str = ""


class CatalogStore:
    """Custom-field definitions per company and Jira site, kept in Neo4j."""

    def __init__(self, session_factory):
        self.session_factory, self._cache = session_factory, {}

    @staticmethod
    def _uid(tenant, site):
        return f"{tenant}:site:{site}:field-catalog"

    def save(self, tenant, site, fields):
        meta = field_catalog.meta_from_api(fields)
        with self.session_factory() as session:
            session.execute_write(lambda tx: tx.run(
                "MERGE (c:FieldCatalog {uid: $uid}) SET c.tenant_id = $t, c.jira_site_id = $s, "
                "c.meta_json = $meta, c.updated_at = $now", uid=self._uid(tenant, site), t=tenant, s=site,
                meta=json.dumps(meta, ensure_ascii=False), now=datetime.now(timezone.utc).isoformat()))
        self._cache[(tenant, site)] = meta
        return len(meta)

    def get(self, tenant, site):
        key = (tenant, site)
        if key not in self._cache:
            with self.session_factory() as session:
                row = session.execute_read(lambda tx: tx.run(
                    "MATCH (c:FieldCatalog {uid: $uid}) RETURN c.meta_json AS meta",
                    uid=self._uid(tenant, site)).single())
            self._cache[key] = json.loads(row["meta"]) if row else {}
        return self._cache[key]

    def forget(self, tenant):
        self._cache = {k: v for k, v in self._cache.items() if k[0] != tenant}


def tenants_missing_embeddings():
    from query_engine import run_query
    rows = run_query("MATCH (w:WorkItem) WHERE w.summary IS NOT NULL AND w.embedding_hash IS NULL "
                     "RETURN DISTINCT w.tenant_id AS tenant")
    return [r["tenant"] for r in rows if r["tenant"]]


def embed_tenant(tenant):
    from build_embeddings import embed_work_items_detailed
    return embed_work_items_detailed(tenant)


class EmbeddingWorker:
    """Keeps embeddings complete in the background. A failed run is tried again on the next pass."""

    def __init__(self, embed=embed_tenant, find_pending=tenants_missing_embeddings, interval=None):
        self.embed, self.find_pending = embed, find_pending
        self.interval = interval or int(os.getenv("AI_EMBED_INTERVAL_SECONDS", "300"))
        self._wake, self._stop = threading.Event(), threading.Event()

    def request(self, _tenant=None):
        self._wake.set()

    def stop(self):
        self._stop.set()
        self._wake.set()

    def run_pass(self):
        try:
            tenants = self.find_pending()
        except Exception as exc:
            log.warning("embedding scan failed: %s", type(exc).__name__)
            return
        for tenant in tenants:
            if self._stop.is_set():
                return
            try:
                self.embed(tenant)
            except Exception as exc:
                log.warning("embedding run failed, will try again: %s: %s", type(exc).__name__, exc)

    def _loop(self):
        while not self._stop.is_set():
            self._wake.clear()
            self.run_pass()
            self._wake.wait(self.interval)

    def start(self):
        threading.Thread(target=self._loop, name="embeddings", daemon=True).start()


class EventProcessor:
    """Turns one message into graph writes and says what to do with it. No RabbitMQ code here."""

    def __init__(self, session_factory=None, catalog=None, handle=None, embed=None):
        self.session_factory = session_factory or (lambda: webhook_handler.get_driver().session())
        self.catalog = catalog or CatalogStore(self.session_factory)
        self.handle = handle or webhook_handler.handle_event
        self.embed = embed

    def process(self, body):
        try:
            event = json.loads(body)
            if not isinstance(event, dict):
                raise ValueError("not an object")
        except ValueError:
            return Decision("dead", "invalid json")
        tenant, site = event.get("companyId"), event.get("cloudId")
        kind = event.get("eventType")
        if not tenant or not kind:
            return Decision("dead", "companyId and eventType are required")
        if kind == "CompanyDisconnected":
            return self._guard(lambda: self._disconnect(tenant))
        if not site:
            return Decision("dead", "cloudId is required (schemaVersion 2)")
        if kind == "FieldCatalog":
            fields = (event.get("payload") or {}).get("fields")
            if not isinstance(fields, list):
                return Decision("dead", "FieldCatalog needs payload.fields")
            return self._guard(lambda: self.catalog.save(tenant, site, fields))
        if kind == "IssueSnapshot":
            return self._guard(lambda: self._snapshot(event, tenant, site))
        if kind == "ImportCompleted":
            if self.embed:
                self.embed(tenant)
            return Decision("ack")
        return self._webhook(event, tenant, site)

    def _guard(self, work):
        try:
            rel.run_with_retry(work, max_attempts=3, transient=_is_retryable)
            return Decision("ack")
        except Exception as exc:
            return Decision("retry" if _is_retryable(exc) else "dead", f"{type(exc).__name__}: {exc}")

    def _snapshot(self, event, tenant, site):
        issue = event.get("payload")
        if not isinstance(issue, dict) or not issue.get("key"):
            raise ValueError("IssueSnapshot needs a Jira issue in payload")
        meta = self.catalog.get(tenant, site)
        with self.session_factory() as session:
            return session.execute_write(lambda tx: ingest.upsert_issue_detailed(
                tx, issue, tenant, payload_mode="full", site_id=site, authoritative=True,
                field_meta=meta, browse_base=event.get("siteUrl")))

    def _webhook(self, event, tenant, site):
        raw = event.get("rawWebhook")
        if not isinstance(raw, dict):
            return Decision("dead", "rawWebhook is required (schemaVersion 2)")
        try:
            meta = self.catalog.get(tenant, site)
        except Exception as exc:
            return Decision("retry" if _is_retryable(exc) else "dead", f"{type(exc).__name__}: {exc}")
        result = self.handle(raw, tenant, site_id=site, delivery_id=event.get("eventId"), max_attempts=3,
                             session_factory=self.session_factory, field_meta=meta,
                             browse_base=event.get("siteUrl"))
        if result.outcome == "failed":
            return Decision("retry", result.error or "transient failure")
        if result.outcome == "rejected":
            return Decision("dead", result.error or result.status)
        return Decision("ack")

    def _disconnect(self, tenant):
        while True:
            with self.session_factory() as session:
                if not session.execute_write(lambda tx: ingest.delete_tenant(tx, tenant)):
                    break
        self.catalog.forget(tenant)


def _is_retryable(exc):
    return rel.is_transient(exc)


def retry_count(properties):
    headers = (properties.headers if properties else None) or {}
    try:
        return int(headers.get(RETRY_HEADER, 0))
    except (TypeError, ValueError):
        return 0


def route(decision, retries, max_retries):
    """-> (exchange attribute on Settings or None, routing key, header updates)."""
    if decision.action == "ack":
        return None, None, {}
    if decision.action == "retry" and retries < max_retries:
        return "retry_exchange", RETRY_ROUTING_KEY, {RETRY_HEADER: retries + 1}
    reason = decision.reason if decision.action == "dead" else f"retries exhausted: {decision.reason}"
    return "dead_exchange", DEAD_ROUTING_KEY, {"x-dead-letter-reason": reason[:500]}


def declare_topology(channel, s):
    channel.exchange_declare(s.exchange, "topic", durable=True)
    channel.queue_declare(s.queue, durable=True)
    channel.queue_bind(s.queue, s.exchange, "jira.#")
    channel.queue_bind(s.queue, s.exchange, "ai.#")
    channel.exchange_declare(s.retry_exchange, "direct", durable=True)
    channel.queue_declare(s.retry_queue, durable=True, arguments={
        "x-message-ttl": s.retry_ttl_ms, "x-dead-letter-exchange": "",
        "x-dead-letter-routing-key": s.queue})
    channel.queue_bind(s.retry_queue, s.retry_exchange, RETRY_ROUTING_KEY)
    channel.exchange_declare(s.dead_exchange, "direct", durable=True)
    channel.queue_declare(s.dead_queue, durable=True)
    channel.queue_bind(s.dead_queue, s.dead_exchange, DEAD_ROUTING_KEY)


def connect(s):
    return pika.BlockingConnection(pika.ConnectionParameters(
        host=s.host, port=s.port, virtual_host=s.vhost, heartbeat=60,
        credentials=pika.PlainCredentials(s.user, s.password)))


class Consumer:
    def __init__(self, processor=None, settings=None):
        self.processor = processor or EventProcessor()
        self.settings = settings or Settings()
        self.stopping = False
        self._executor = ThreadPoolExecutor(max_workers=1)

    def stop(self, *_):
        self.stopping = True

    def _finish(self, channel, method, properties, body, decision):
        exchange, routing_key, headers = route(decision, retry_count(properties), self.settings.max_retries)
        if exchange:
            log.warning("event %s -> %s: %s", properties.message_id, routing_key, decision.reason)
            channel.basic_publish(
                getattr(self.settings, exchange), routing_key, body,
                properties=pika.BasicProperties(
                    content_type=properties.content_type, delivery_mode=2,
                    message_id=properties.message_id, correlation_id=properties.correlation_id,
                    headers={**(properties.headers or {}), **headers}),
                mandatory=True)
        channel.basic_ack(method.delivery_tag)

    def run_once(self):
        """Consume until stopped or the connection drops."""
        connection = connect(self.settings)
        try:
            channel = connection.channel()
            channel.confirm_delivery()
            if os.getenv("AI_DECLARE_TOPOLOGY") == "1":
                declare_topology(channel, self.settings)
            channel.basic_qos(prefetch_count=1)
            log.info("consuming %s", self.settings.queue)
            for method, properties, body in channel.consume(self.settings.queue, inactivity_timeout=1):
                if self.stopping:
                    break
                if method is None:
                    continue
                job = self._executor.submit(self.processor.process, body)
                while not job.done():
                    connection.process_data_events(time_limit=1)
                try:
                    decision = job.result()
                except Exception as exc:   # a bug here must park the message, not lose it
                    decision = Decision("retry", f"{type(exc).__name__}: {exc}")
                self._finish(channel, method, properties, body, decision)
            channel.cancel()
        finally:
            if connection.is_open:
                connection.close()

    def run(self):
        while not self.stopping:
            try:
                self.run_once()
            except pika.exceptions.AMQPError as exc:
                log.error("RabbitMQ connection lost (%s); reconnecting in 10s", type(exc).__name__)
                time.sleep(10)


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    embeddings = EmbeddingWorker()
    embeddings.start()
    consumer = Consumer(EventProcessor(embed=embeddings.request))
    signal.signal(signal.SIGINT, consumer.stop)
    signal.signal(signal.SIGTERM, consumer.stop)
    consumer.run()


if __name__ == "__main__":
    main()
