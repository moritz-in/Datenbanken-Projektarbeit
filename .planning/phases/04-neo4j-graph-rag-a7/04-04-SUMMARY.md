---
phase: 04-neo4j-graph-rag-a7
plan: "04"
subsystem: database
tags: [neo4j, flask, atexit, driver, singleton, lazy-reconnect]

# Dependency graph
requires:
  - phase: 04-neo4j-graph-rag-a7/04-03
    provides: RAG pipeline with Neo4j graph enrichment wired
provides:
  - Neo4j driver null-after-teardown bug fixed — atexit shutdown + lazy reconnect
  - Index build no longer crashes with AttributeError after /rag request
affects: [phase 5, operations, docker shutdown]

# Tech tracking
tech-stack:
  added: [atexit (stdlib)]
  patterns:
    - atexit.register for singleton resource shutdown (not teardown_appcontext)
    - Lazy reconnect guard in execute_cypher for driver resilience

key-files:
  created: []
  modified:
    - repositories/neo4j_repository.py
    - app.py

key-decisions:
  - "atexit.register instead of teardown_appcontext — teardown_appcontext fires per-request, atexit fires once at process exit"
  - "Lazy reconnect in execute_cypher — self._driver is None check + reconnect before session.run(), prevents AttributeError without changing close() semantics"
  - "Credentials stored as self._uri/_user/_password in __init__ — required for reconnect path after close() sets _driver=None"

patterns-established:
  - "Singleton DB drivers: use atexit.register for shutdown, not Flask lifecycle hooks"
  - "Resilient execute method: guard driver is not None at entry, reconnect if needed"

requirements-completed: [GRAPH-06]

# Metrics
duration: 2min
completed: "2026-04-14"
---

# Phase 04 Plan 04: Neo4j Driver Null-After-Teardown Bug Fix Summary

**atexit-based Neo4j shutdown + lazy reconnect guard prevents AttributeError crash when /rag then /index are called in the same session**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-14T09:43:19Z
- **Completed:** 2026-04-14T09:45:19Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- `Neo4jRepositoryImpl.__init__()` now stores `self._uri`, `self._user`, `self._password` for reconnect
- `execute_cypher()` has a lazy-reconnect guard: if `self._driver is None`, transparently reconnects before `session.run()`
- `@app.teardown_appcontext` hook replaced with `atexit.register(_shutdown_neo4j)` — driver closed exactly once at process exit, not once per HTTP request
- UAT Test 7 ("Index build syncs products to Neo4j — neo4j_count > 0") should now pass: no more `AttributeError: 'NoneType' object has no attribute 'session'` after `/rag` call

## Task Commits

Each task was committed atomically:

1. **task 1: fix Neo4jRepositoryImpl — store credentials + lazy reconnect in execute_cypher** - `1c8328a` (fix)
2. **task 2: fix app.py — replace teardown_appcontext with atexit.register** - `786578e` (fix)

## Files Created/Modified
- `repositories/neo4j_repository.py` — stored `_uri/_user/_password` in `__init__`; added lazy-reconnect guard at top of `execute_cypher()`
- `app.py` — added `import atexit`; replaced `@app.teardown_appcontext _close_neo4j` with `atexit.register(_shutdown_neo4j)`

## Decisions Made
- `atexit.register` for Neo4j shutdown — Flask's `teardown_appcontext` fires at end of every HTTP request (app context is pushed/torn down per request), not at shutdown. `atexit` fires exactly once when the Python process exits, which is the correct semantics for a long-lived singleton driver.
- Lazy reconnect in `execute_cypher()` rather than in `close()` — keeps `close()` semantics clean (sets `_driver = None` to signal disconnected state). The reconnect happens at the first subsequent call that needs the driver, transparent to callers.
- Credentials stored as instance attributes — `self._uri`, `self._user`, `self._password` needed for reconnect; no other path to access them after construction.

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None — both fixes applied cleanly. Pre-existing LSP errors (unresolvable `sqlalchemy`, `neo4j` imports — Docker-only deps) are out of scope.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All Phase 4 bugs fixed; Neo4j driver lifecycle is now correct
- Phase 5 (Polish & Dokumentation) can proceed — COMPARISON.md and DOC-01

---
*Phase: 04-neo4j-graph-rag-a7*
*Completed: 2026-04-14*
