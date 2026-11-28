"""
github_consumer.py
Reads syntrace.ai.github (the backend's GitHubAiEvent, routing key github.ai.v1 on syntrace.github.events)
and keeps the GitHub part of the graph in step. It runs inside ai_consumer.py on its own connection,
with its own retry and dead-letter queues, so a GitHub problem never holds up Jira events.

The backend declares the exchange and syntrace.ai.github; this declares the same (idempotent) and
adds syntrace.ai.github.retry and syntrace.ai.github.dead-letter.
"""
import json
import logging
import os
from dataclasses import dataclass, field

from syntrace_ai.assistant import cache_version
from syntrace_ai.workers import event_reliability as rel
from syntrace_ai.github import github_graph
from syntrace_ai.workers import webhook_handler
from syntrace_ai.workers.ai_consumer import RETRY_ROUTING_KEY, DEAD_ROUTING_KEY, Consumer, Decision, Settings

log = logging.getLogger("syntrace.github")

GITHUB_ROUTE = "github.ai.v1"
EMBEDDED_KINDS = {"github.commit.upserted", "github.pull_request.upserted", "github.file.upserted"}


@dataclass
class GitHubSettings(Settings):
    exchange: str = field(default_factory=lambda: os.getenv("GITHUB_EVENTS_EXCHANGE", "syntrace.github.events"))
    queue: str = field(default_factory=lambda: os.getenv("GITHUB_AI_QUEUE", "syntrace.ai.github"))
    retry_exchange: str = field(default_factory=lambda: os.getenv("GITHUB_RETRY_EXCHANGE", "syntrace.ai.github.retry"))
    retry_queue: str = field(default_factory=lambda: os.getenv("GITHUB_RETRY_QUEUE", "syntrace.ai.github.retry"))
    dead_exchange: str = field(default_factory=lambda: os.getenv("GITHUB_DEAD_EXCHANGE", "syntrace.ai.github.dlx"))
    dead_queue: str = field(default_factory=lambda: os.getenv("GITHUB_DEAD_QUEUE", "syntrace.ai.github.dead-letter"))


def declare_topology(channel, s):
    # Same arguments as the backend's declaration, or RabbitMQ refuses it.
    channel.exchange_declare(s.exchange, "topic", durable=True)
    channel.queue_declare(s.queue, durable=True)
    channel.queue_bind(s.queue, s.exchange, GITHUB_ROUTE)
    channel.exchange_declare(s.retry_exchange, "direct", durable=True)
    channel.queue_declare(s.retry_queue, durable=True, arguments={
        "x-message-ttl": s.retry_ttl_ms, "x-dead-letter-exchange": "", "x-dead-letter-routing-key": s.queue})
    channel.queue_bind(s.retry_queue, s.retry_exchange, RETRY_ROUTING_KEY)
    channel.exchange_declare(s.dead_exchange, "direct", durable=True)
    channel.queue_declare(s.dead_queue, durable=True)
    channel.queue_bind(s.dead_queue, s.dead_exchange, DEAD_ROUTING_KEY)


class GitHubProcessor:
    """One message -> one transaction -> a Decision. No RabbitMQ code here."""

    def __init__(self, session_factory=None, embed=None, bump=None):
        self.session_factory = session_factory or (lambda: webhook_handler.get_driver().session())
        self.embed = embed
        self.bump = bump or (lambda tenant: cache_version.bump(tenant, self.session_factory))

    def process(self, body):
        try:
            event = json.loads(body)
            github_graph.parse_event(event)
        except (ValueError, github_graph.BadEvent) as exc:
            return Decision("dead", f"invalid GitHub event: {exc}")
        try:
            outcome, _attempts = rel.run_with_retry(self._apply(event), max_attempts=3, transient=rel.is_transient)
        except github_graph.BadEvent as exc:
            return Decision("dead", str(exc))
        except Exception as exc:
            return Decision("retry" if rel.is_transient(exc) else "dead", f"{type(exc).__name__}: {exc}")
        log.info("github event %s v%s -> %s", event["eventType"], event.get("sourceVersion"), outcome)
        if outcome not in ("stale", "ignored"):
            self.bump(event["companyId"])
            if self.embed and event["eventType"] in EMBEDDED_KINDS:
                self.embed(event["companyId"])
        return Decision("ack")

    def _apply(self, event):
        def work():
            with self.session_factory() as session:
                return session.execute_write(lambda tx: github_graph.apply_event(tx, event))
        return work


def consumer(embed=None):
    return Consumer(GitHubProcessor(embed=embed), GitHubSettings(), declare=declare_topology)
