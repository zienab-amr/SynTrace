"""
cache_version.py
One token per company that changes whenever that company's Jira data changes.

The consumer calls bump() after every Jira event it applied (an edit, a delete, a comment, a whole
import or a disconnect) and after new embeddings. The service puts token() in the key of its answer
cache, so an answer saved before a change is never served after it, however long the cache keeps it.

The token is random, not a counter: a disconnect deletes the company's nodes, this one included, and
a counter starting again from zero could match keys saved before.
"""
import logging

log = logging.getLogger(__name__)

BUMP = "MERGE (v:CacheVersion {tenant_id: $tenant}) SET v.token = randomUUID()"
READ = "MATCH (v:CacheVersion {tenant_id: $tenant}) RETURN v.token AS token"


def bump(tenant, session_factory):
    """Never raises: a failed bump must not fail the Jira event, and the cache TTL still applies."""
    try:
        with session_factory() as session:
            session.execute_write(lambda tx: tx.run(BUMP, tenant=tenant).consume())
    except Exception as exc:
        log.warning("cache version bump failed: %s", type(exc).__name__)


def token(tenant, run_query):
    """The company's current token, "" when it has none yet, or None when Neo4j can't be read
    (then the caller does not use the cache)."""
    try:
        rows = run_query(READ, tenant=tenant)
    except Exception as exc:
        log.warning("cache version read failed: %s", type(exc).__name__)
        return None
    return (rows[0]["token"] if rows else "") or ""
