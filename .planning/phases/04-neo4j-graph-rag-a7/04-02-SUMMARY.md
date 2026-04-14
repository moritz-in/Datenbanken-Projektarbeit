---
phase: 04-neo4j-graph-rag-a7
plan: "02"
subsystem: graph-etl
tags: [neo4j, graph, etl, index, sync, merge]
requirements: [GRAPH-04, GRAPH-06]

dependency_graph:
  requires: ["04-01"]
  provides: ["graph-sync-etl", "sync-products-impl"]
  affects: ["services/index_service.py", "repositories/neo4j_repository.py", "services/__init__.py"]

tech_stack:
  added: []
  patterns:
    - "MERGE-only Cypher for idempotent graph upserts (UNWIND batch + ON CREATE SET/ON MATCH SET)"
    - "Non-fatal Neo4j sync in ETL: log.warning and continue on exception"
    - "Optional dependency injection: neo4j_repo defaults to None, NoOp returns 0 silently"

key_files:
  created: []
  modified:
    - repositories/neo4j_repository.py
    - services/index_service.py
    - services/__init__.py

decisions:
  - "MERGE-only Cypher (not CREATE): idempotency across repeated index builds — no duplicate nodes"
  - "Neo4j sync failure is non-fatal in build_index: log.warning, ETL continues with Qdrant result"
  - "neo4j_repo injected as Optional with default None: IndexService usable without Neo4j configured"

metrics:
  duration: "5 minutes"
  completed: "2026-04-14"
  tasks: 2
  files_modified: 3
---

# Phase 4 Plan 02: Graph ETL — sync_products Implementation Summary

**One-liner:** MERGE-only Cypher sync_products populating Product/Brand/Category/Tag graph nodes integrated into IndexService.build_index ETL pipeline.

---

## What Was Built

Implemented `Neo4jRepositoryImpl.sync_products()` with MERGE-only Cypher and integrated it into `IndexService.build_index()` so every index build atomically populates both Qdrant and Neo4j.

### sync_products (repositories/neo4j_repository.py)

- Replaced the `raise NotImplementedError` stub with a full MERGE-only Cypher implementation
- Uses `UNWIND $products AS p` for batch processing
- `MERGE (prod:Product {mysql_id: p.mysql_id}) ON CREATE SET ... ON MATCH SET ...` — idempotent node upsert
- Creates `Brand`, `Category`, `Tag` nodes with `MADE_BY`, `IN_CATEGORY`, `HAS_TAG` relationships using MERGE
- Normalizes `tags` field: handles `list[str]`, comma-separated `str`, and `None` → always `list[str]`
- Returns `len(products)`; logs synced count at INFO level

### IndexService integration (services/index_service.py + services/__init__.py)

- Added `Neo4jRepository` import to `index_service.py`
- Added `neo4j_repo: Optional[Neo4jRepository] = None` to `IndexService.__init__`
- `build_index()` calls `self.neo4j_repo.sync_products(products)` after Qdrant upsert
- Neo4j failure is caught and logged as `log.warning` — ETL does NOT abort
- Return dict includes `neo4j_count` field alongside `count`, `elapsed`, `strategy`
- `ServiceFactory.get_index_service()` passes `RepositoryFactory.get_neo4j_repository()` as `neo4j_repo`

---

## Verification

```
✓ NoOp sync_products([...]) returns 0
✓ Neo4jRepositoryImpl.sync_products uses MERGE-only Cypher (source inspection)
✓ IndexService.__init__ params include neo4j_repo
✓ build_index source contains sync_products and neo4j_count
✓ ServiceFactory.get_index_service() passes get_neo4j_repository()
```

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Commits

| Hash | Message |
|------|---------|
| f2f0c64 | feat(04-02): implement Neo4jRepositoryImpl.sync_products with MERGE Cypher |
| e59e0d3 | feat(04-02): inject neo4j_repo into IndexService + call sync_products in build_index |

---

## Self-Check: PASSED

- `repositories/neo4j_repository.py` — FOUND (modified, sync_products implemented)
- `services/index_service.py` — FOUND (modified, neo4j_repo injected, sync_products called)
- `services/__init__.py` — FOUND (modified, get_neo4j_repository() passed)
- Commit f2f0c64 — FOUND
- Commit e59e0d3 — FOUND
