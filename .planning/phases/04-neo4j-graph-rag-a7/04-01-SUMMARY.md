---
phase: 04-neo4j-graph-rag-a7
plan: "01"
subsystem: database

tags: [neo4j, graph-database, driver, cypher, flask, teardown]

# Dependency graph
requires:
  - phase: 03-qdrant-vektor-suche-a6
    provides: RepositoryFactory pattern with singleton locking; NoOp fallback pattern established
provides:
  - Neo4jRepositoryImpl with __init__ (GraphDatabase.driver + verify_connectivity), execute_cypher (session.run consuming inside with block), close (sets _driver=None), get_product_relationships ({mysql_id: {title, brand, category, tags, related_products}})
  - sync_products @abstractmethod on Neo4jRepository ABC; NoOpNeo4jRepository.sync_products returns 0
  - Flask teardown_appcontext hook closing Neo4j driver on app context teardown
affects: [04-neo4j-graph-rag-a7 plans 02-04, any phase using RepositoryFactory.get_neo4j_repository()]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Neo4j driver singleton via RepositoryFactory — never per-request"
    - "Session-scoped Cypher execution: consume Result inside `with driver.session() as session:` block"
    - "teardown_appcontext for driver cleanup — fires on app context teardown, not per-request"
    - "NoOp graceful fallback when NEO4J_URI absent — returns 0/empty structures"

key-files:
  created: []
  modified:
    - repositories/neo4j_repository.py
    - app.py

key-decisions:
  - "sync_products added as @abstractmethod to ABC now (not in Phase 4 Plan 02) — NoOpNeo4jRepository.sync_products returns 0 to satisfy ABC contract"
  - "execute_cypher consumes Result inside with session block — prevents SessionExpiredError on lazy evaluation"
  - "teardown_appcontext (not teardown_request) used for Neo4j close — fires at shutdown, not on every HTTP request"
  - "exception=None default on _close_neo4j — Flask passes exception arg when app context tears down on error"

patterns-established:
  - "Result consumed inside session block: `return [dict(r) for r in result]` — never return lazy result outside with block"
  - "Context manager __enter__/__exit__ delegates to close() — safe for `with Neo4jRepositoryImpl(...) as repo:` usage"

requirements-completed: [GRAPH-01, GRAPH-02, GRAPH-03, GRAPH-05]

# Metrics
duration: 3min
completed: 2026-04-14
---

# Phase 04 Plan 01: Neo4j Driver Layer Summary

**Neo4j driver wired via GraphDatabase.driver + verify_connectivity, execute_cypher consuming Result inside session block, get_product_relationships returning `{mysql_id: {title, brand, category, tags, related_products}}`, and Flask teardown_appcontext hook preventing connection timeout errors on docker stop**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-14T07:09:57Z
- **Completed:** 2026-04-14T07:12:22Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `Neo4jRepositoryImpl.__init__` connects via `GraphDatabase.driver()` + `verify_connectivity()` — no longer raises NotImplementedError
- `execute_cypher` consumes Cypher `Result` inside `with session:` block returning `list[dict]` — prevents lazy evaluation errors outside session scope
- `close()` sets `self._driver = None` — safe for double-close
- `get_product_relationships()` returns `{mysql_id: {title, brand, category, tags, related_products}}` via MATCH/OPTIONAL MATCH Cypher
- `sync_products` added as `@abstractmethod` to `Neo4jRepository` ABC; `NoOpNeo4jRepository.sync_products([])` returns `0`
- `__enter__`/`__exit__` stubs replaced with real context manager delegation to `close()`
- `teardown_appcontext` hook `_close_neo4j(exception=None)` registered in `create_app()` after blueprint registration

## Task Commits

Each task was committed atomically:

1. **task 1: implement Neo4jRepositoryImpl core driver methods + extend ABC** - `1c87d3b` (feat)
2. **task 2: register teardown_appcontext in app.py to close Neo4j driver** - `ed31b7d` (feat)

**Plan metadata:** (docs commit — see final commit)

## Files Created/Modified

- `repositories/neo4j_repository.py` — ABC extended with sync_products abstractmethod; NoOpNeo4jRepository.sync_products returns 0; Neo4jRepositoryImpl fully implemented (__init__, execute_cypher, close, get_product_relationships, __enter__/__exit__)
- `app.py` — teardown_appcontext hook `_close_neo4j(exception=None)` registered after blueprint block in create_app()

## Decisions Made

- `sync_products` added as `@abstractmethod` now rather than later — ABC contract must be satisfied for all concrete classes; NoOpNeo4jRepository returns 0 (no Neo4j configured fallback)
- `execute_cypher` consumes Result inside `with session:` block — returning a lazy Result object outside the session scope raises `SessionExpiredError` at call site
- `teardown_appcontext` (not `teardown_request`) — teardown_request fires on every HTTP request; teardown_appcontext fires on app context teardown (shutdown)
- `exception=None` default parameter on `_close_neo4j` — Flask passes the exception argument when the context tears down due to an unhandled error

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None — local environment lacks `neo4j`, `sqlalchemy`, `dotenv`, and other packages (all run inside Docker), so verification used unittest.mock to patch external modules. Both verification checks passed.

## Next Phase Readiness

- Neo4j driver layer complete — `RepositoryFactory.get_neo4j_repository()` will return `Neo4jRepositoryImpl` when `NEO4J_URI` is set (no longer raises NotImplementedError from `__init__`)
- `sync_products` abstractmethod ready for Plan 02 (graph sync ETL implementation)
- Teardown hook prevents connection timeout errors in `docker compose logs app` on `docker stop`
- Ready for Plan 02: implement `Neo4jRepositoryImpl.sync_products` + graph ETL route

---
*Phase: 04-neo4j-graph-rag-a7*
*Completed: 2026-04-14*

## Self-Check: PASSED

- ✅ `repositories/neo4j_repository.py` — exists
- ✅ `app.py` — exists
- ✅ `.planning/phases/04-neo4j-graph-rag-a7/04-01-SUMMARY.md` — exists
- ✅ Commit `1c87d3b` — found
- ✅ Commit `ed31b7d` — found
