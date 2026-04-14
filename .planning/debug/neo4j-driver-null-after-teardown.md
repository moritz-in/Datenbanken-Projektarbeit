---
status: diagnosed
trigger: "Index build syncs products to Neo4j — neo4j_count > 0 in result — 'NoneType' object has no attribute 'session'"
created: 2026-04-14T00:00:00Z
updated: 2026-04-14T00:00:00Z
---

## Current Focus

hypothesis: teardown_appcontext fires per-request (not just on shutdown), nullifying _driver on every request — contradicting the comment in STATE.md
test: traced teardown_appcontext Flask lifecycle semantics; cross-referenced with log timestamps showing close fired after the RAG request, not on shutdown
expecting: confirmed — close() called after /rag request, leaving singleton's _driver = None for subsequent /index request
next_action: DONE — root cause confirmed, diagnosis returned

## Symptoms

expected: After triggering /index, build_index() calls neo4j_repo.sync_products(), neo4j_count > 0 is returned
actual: build_index logs "Neo4j sync failed (non-fatal): 'NoneType' object has no attribute 'session'"
errors: AttributeError: 'NoneType' object has no attribute 'session' — self._driver is None inside execute_cypher()
reproduction: Run /rag (RAG search) first, then run /index (index build) in the same app session
started: Discovered during UAT Phase 04, Test 7

## Eliminated

- hypothesis: teardown_appcontext only fires on app shutdown (as stated in STATE.md comment)
  evidence: Log timestamps show "Neo4j driver closed" at 09:13:03 — right after a /rag request at the same second, not at docker stop. The close fires within the same request cycle, not at process exit.
  timestamp: 2026-04-14T00:00:00Z

## Evidence

- timestamp: 2026-04-14T00:00:00Z
  checked: app.py line 194-203 — _close_neo4j registered with @app.teardown_appcontext
  found: Flask's teardown_appcontext fires at the END OF EVERY REQUEST (when the application context is popped), not only at process shutdown. Flask pushes a new app context for each request and tears it down when the request ends.
  implication: Every single HTTP request that causes Neo4jRepositoryImpl to be used will call repo.close() at the end of that request, setting self._driver = None.

- timestamp: 2026-04-14T00:00:00Z
  checked: neo4j_repository.py line 92-97 — close() method
  found: close() sets self._driver = None after closing the driver. No reconnect logic exists.
  implication: Once close() is called, the singleton is permanently broken — _driver is None with no way to recover.

- timestamp: 2026-04-14T00:00:00Z
  checked: repositories/__init__.py line 97-109 — get_neo4j_repository() double-checked locking
  found: The factory caches the Neo4jRepositoryImpl instance in cls._instances[Neo4jRepositoryImpl]. It only creates a NEW instance if Neo4jRepositoryImpl not in cls._instances. After close() sets _driver = None, the factory still returns the SAME broken instance — it never re-creates it.
  implication: The cached singleton with _driver = None is returned on every subsequent request. There is no re-initialization path.

- timestamp: 2026-04-14T00:00:00Z
  checked: Log sequence: 09:13:03 connected, 09:13:03 closed, 09:17:12 sync failed
  found: The "driver closed" log fires within the same second as the "driver connected" log during a /rag request. This definitively proves teardown_appcontext fires per-request, not per-process.
  implication: Any request after the first one that uses Neo4j will see _driver = None.

- timestamp: 2026-04-14T00:00:00Z
  checked: STATE.md line 118 — key decision comment
  found: Comment says "teardown_request fires on every HTTP request; teardown_appcontext fires on app context teardown (shutdown only)". This is INCORRECT. In a standard Flask app (not using app.app_context() manually pushed for background tasks), the application context is pushed per-request and torn down at request end — teardown_appcontext fires every request.
  implication: The architectural decision was made on a false premise.

- timestamp: 2026-04-14T00:00:00Z
  checked: services/__init__.py line 113-118 — IndexService construction
  found: IndexService receives the neo4j_repo object at construction time (dependency injection). If the repo singleton has _driver = None by the time /index is called, the IndexService.neo4j_repo reference also points to the broken singleton.
  implication: Confirms the broken singleton propagates into IndexService.

## Resolution

root_cause: |
  `@app.teardown_appcontext` fires at the end of EVERY HTTP request (not just on process shutdown).
  The _close_neo4j hook calls Neo4jRepositoryImpl.close() which sets self._driver = None.
  RepositoryFactory caches the now-broken instance — it never creates a new one because
  Neo4jRepositoryImpl is still in cls._instances.
  The next request (e.g., /index) calls get_neo4j_repository() → gets the cached instance with
  _driver = None → sync_products() → execute_cypher() → self._driver.session() → AttributeError.

fix: not applied (goal: find_root_cause_only)
verification: not applied
files_changed: []
