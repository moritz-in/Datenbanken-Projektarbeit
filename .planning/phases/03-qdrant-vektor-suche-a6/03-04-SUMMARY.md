---
phase: "03"
plan: "04"
subsystem: search-service
tags: [search, vector-search, sql-search, flask-route, phase4-stubs]
dependency_graph:
  requires: [QdrantRepositoryImpl-core-methods]
  provides: [SearchService-phase3, /search-route]
  affects: [templates/search_unified.html]
tech_stack:
  added: []
  patterns: [local-import-to-avoid-circular, NotImplementedError-caught-not-propagated]
key_files:
  created: []
  modified: [services/search_service.py, routes/search.py]
decisions:
  - "execute_sql_search uses local 'from services import ServiceFactory' to avoid circular import"
  - "Phase 4 stubs (rag_search, pdf_rag_search, search_product_pdfs, _generate_llm_answer) preserved as NotImplementedError"
  - "search route catches NotImplementedError for Phase 4 types — returns empty results, NOT 501"
  - "_get_llm_client returns self._llm_client (may be None if no API key) — no exception"
metrics:
  duration: "4min"
  completed: "2026-04-13"
  tasks_completed: 2
  files_modified: 2
---

# Phase 03 Plan 04: SearchService Vector Search + /search Route Summary

**One-liner:** SearchService implements Phase 3 methods (vector_search with ScoredPoint→dict mapping, execute_sql_search delegation, _coerce helpers) while preserving Phase 4 stubs; unified /search route dispatches all 6 types and catches NotImplementedError for Phase 4 tabs.

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Implement SearchService (vector_search, execute_sql_search, embed_texts, _coerce helpers) | e80144b | ✅ |
| 2 | Implement routes/search.py unified handler | e80144b | ✅ |

## Key Implementation Details

### vector_search
1. Gets collection name from `current_app.config.get("QDRANT_COLLECTION", "products")`
2. `query_vector = self.embed_texts([query])[0]` — embeds single query string
3. `hits = self.qdrant_repo.search(coll, query_vector, limit=topk, with_payload=True)`
4. Maps each `ScoredPoint` to: `{title, brand, price, score, doc_preview, graph_source}`
5. `graph_source=None` — enriched in Phase 4

### execute_sql_search
- Uses local `from services import ServiceFactory` import to avoid circular import
- Delegates to `product_svc.execute_sql_query(query)`

### _coerce_int / _coerce_ints
- `_coerce_int`: `try: return int(value) except (ValueError, TypeError): return None`
- `_coerce_ints`: generator comprehension filtering None values

### Unified /search route
- Default `search_type = "vector"` when no param
- POST with query: dispatches to 6 types (vector, sql, rag, graph, pdf, pdf_mgmt)
- Types rag/graph/pdf/pdf_mgmt: wrapped in `except NotImplementedError: results=[]; answer=None`
- Empty vector results: `flash("Qdrant-Index leer — bitte zuerst Index aufbauen unter /index", "warning")`
- SQL ValueError: `flash(str(e), "danger")`
- Always renders `search_unified.html` with `{search_type, query, results, answer}`

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED
- `services/search_service.py` exists ✅
- `routes/search.py` exists with no unhandled NotImplementedError stubs ✅
- Commit `e80144b` exists ✅
- Phase 4 stubs preserved (rag_search, _generate_llm_answer) ✅
- `_coerce_int('abc') == None` ✅
- `_coerce_ints(['1','x','3']) == [1, 3]` ✅
