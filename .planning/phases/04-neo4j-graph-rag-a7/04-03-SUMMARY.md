---
phase: "04"
plan: "03"
subsystem: search
tags: [rag, neo4j, openai, vector-search, graph-enrichment]
dependency_graph:
  requires: ["04-01"]
  provides: ["GRAPH-07"]
  affects: ["routes/rag.py", "services/search_service.py"]
tech_stack:
  added: []
  patterns: ["RAG pipeline (embed → vector search → graph enrichment → LLM)", "German-language LLM answer with fallback", "Flask GET/POST route with flash messaging"]
key_files:
  created: []
  modified:
    - "services/search_service.py"
    - "routes/rag.py"
key_decisions:
  - "Call qdrant_repo.search() directly in rag_search (not vector_search()) to access hit.id for mysql_id lookup"
  - "_generate_llm_answer returns '[LLM nicht konfiguriert — OPENAI_API_KEY fehlt]' when client is None — no exception"
  - "Graph enrichment is non-fatal: Exception caught with log.warning, search continues without enrichment"
  - "/graph-rag redirects to /rag via url_for for backward compatibility"
metrics:
  duration: "3 min"
  completed_date: "2026-04-14"
  tasks_completed: 2
  files_modified: 2
---

# Phase 4 Plan 03: RAG Search with Neo4j Graph Enrichment Summary

**One-liner:** RAG pipeline (Qdrant vector search + Neo4j graph enrichment + OpenAI GPT-4.1-mini German answer) wired through `/rag` GET/POST route with graceful fallback when API key absent.

---

## What Was Built

Replaced two `NotImplementedError` stubs in `SearchService` and the stub `routes/rag.py` with a fully functional RAG pipeline:

### `SearchService.rag_search()` (services/search_service.py)

The complete RAG pipeline:
1. **Embed query** via `embed_texts([query])[0]`
2. **Vector retrieval** via `qdrant_repo.search()` directly (not `vector_search()`) to access `hit.id` as `mysql_id`
3. **Build hit dicts** capturing `mysql_id`, `title`, `brand`, `price`, `score`, `doc_preview`, `category=''`, `tags=[]`, `related_products=[]`, `graph_source=None`
4. **Graph enrichment** — calls `neo4j_repo.get_product_relationships(mysql_ids)`, sets `graph_source='Neo4j'`, fills `category`, `tags`, `related_products`; enrichment failures are non-fatal (log.warning, continue)
5. **LLM answer** via `_generate_llm_answer(query, hits)`
6. Returns `{'query': str, 'answer': str, 'hits': list[dict]}`

### `SearchService._generate_llm_answer()` (services/search_service.py)

- Returns `"[LLM nicht konfiguriert — OPENAI_API_KEY fehlt]"` if `_get_llm_client()` is `None`
- Builds German-language product context from top-5 hits (title, brand, category, tags, related_products, price)
- Calls `openai.chat.completions.create` with model from `LLM_MODEL` config (default `gpt-4.1-mini`)
- Catches all LLM exceptions → returns `f"[LLM-Fehler: {e}]"` (never raises)

### `routes/rag.py` (routes/rag.py)

- `GET /rag` → renders `rag.html` with empty form (`query=""`, `answer=None`, `results=[]`)
- `POST /rag` → validates query (empty → warning flash), calls `svc.rag_search(strategy="C", ...)`, maps hits to template shape with `name`/`title`/`brand`/`category`/`tags`/`price`/`score`/`graph_source`/`doc_preview`
- `GET/POST /graph-rag` → redirects to `/rag` (backward compat)

---

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement rag_search and _generate_llm_answer | ac401de | services/search_service.py |
| 2 | Implement routes/rag.py GET/POST handler | 6a1157e | routes/rag.py |

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Success Criteria

- [x] `GET /rag` returns 200, renders rag.html with empty form
- [x] `POST /rag` with valid query returns LLM answer OR fallback string (never 501)
- [x] RAG results show `graph_source='Neo4j'` badge for graph-enriched hits (after index build)
- [x] `_generate_llm_answer` returns German fallback if `OPENAI_API_KEY` absent — no exception
- [x] `/graph-rag` redirects to `/rag` (backward compat)

---

## Self-Check: PASSED

| Item | Status |
|------|--------|
| `services/search_service.py` | FOUND |
| `routes/rag.py` | FOUND |
| `04-03-SUMMARY.md` | FOUND |
| Commit `ac401de` (task 1 — rag_search + _generate_llm_answer) | FOUND |
| Commit `6a1157e` (task 2 — routes/rag.py handler) | FOUND |
