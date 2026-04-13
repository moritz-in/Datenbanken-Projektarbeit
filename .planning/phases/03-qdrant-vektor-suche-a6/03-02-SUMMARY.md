---
phase: "03"
plan: "02"
subsystem: index-service
tags: [index, etl, embedding, qdrant, flask-route]
dependency_graph:
  requires: [QdrantRepositoryImpl-core-methods]
  provides: [IndexService-complete, /index-route]
  affects: [templates/index.html]
tech_stack:
  added: []
  patterns: [PRG-pattern, batch-embed, log_etl_run-on-error]
key_files:
  created: []
  modified: [services/index_service.py, routes/index.py]
decisions:
  - "_get_embedding_model returns self._embedding_model — no lazy-load, singleton injected by ServiceFactory"
  - "build_index always uses Strategy C (delete+recreate) for Phase 3 — strategy param kept for API compat"
  - "build_index catches all exceptions, logs ETL run with status=error, then re-raises"
  - "get_index_status returns last_indexed_at=None (ETL log query deferred — not needed for Phase 3 demo)"
  - "GET /index has fallback status dict so page never 500s even if Qdrant unreachable"
metrics:
  duration: "6min"
  completed: "2026-04-13"
  tasks_completed: 2
  files_modified: 2
---

# Phase 03 Plan 02: IndexService ETL Pipeline + /index Route Summary

**One-liner:** IndexService ETL pipeline implemented — batch embed via SentenceTransformer, upsert to Qdrant with Strategy C (delete+recreate), ETL audit logging to MySQL on both success and error paths; /index route follows PRG pattern.

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Implement IndexService (product_to_document, embed_texts, build_index, get_index_status, truncate_index) | 4e8956a | ✅ |
| 2 | Implement routes/index.py (GET/POST /index + POST /truncate-index) | 4e8956a | ✅ |

## Key Implementation Details

### product_to_document
- Builds structured string: `"Name: X Beschreibung: Y Marke: Z Kategorie: W Tags: T"`
- Skips any label where value is None or empty string — never emits "None" as value
- Tags can be list or string — joins list with comma

### build_index (Strategy C)
1. Record `started_at = datetime.utcnow()`
2. `delete_collection` + `ensure_collection` (Strategy C)
3. `load_products_for_index()` from MySQL → optional limit
4. Build document strings via `product_to_document`
5. Batch embed in chunks of `batch_size` using `model.encode(...).tolist()`
6. Upsert to Qdrant with payload: `{title, brand, price, doc_preview, score}`
7. `log_etl_run` with status='success' on success, status='error' on exception

### GET /index
- Calls `get_index_status()` and renders `index.html` with status dict
- Fallback status dict with all-zero values if Qdrant unavailable

### POST /index (PRG)
- Flashes: `"{count} Produkte in {elapsed:.1f}s indexiert (Strategie C)"`
- On error: flashes `"Index-Build fehlgeschlagen: {e}"` with "danger"

### POST /truncate-index (PRG)
- Flashes: `"Index geleert"` on success
- On error: flashes with "danger"

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED
- `services/index_service.py` exists and has no NotImplementedError stubs ✅
- `routes/index.py` exists and has no NotImplementedError stubs ✅
- Commit `4e8956a` exists ✅
- product_to_document test cases passed ✅
- routes/index.py imports and syntax verified ✅
