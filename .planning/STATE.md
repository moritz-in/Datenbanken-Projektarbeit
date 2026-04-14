---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: milestone
status: completed
last_updated: "2026-04-14T10:18:09.885Z"
progress:
  total_phases: 6
  completed_phases: 6
  total_plans: 19
  completed_plans: 19
  percent: 100
---

# STATE: Datenbanken-Projektarbeit Teil 2

**Last updated:** 2026-04-14
**Session:** Phase 5 Plan 01 complete — COMPARISON.md final deliverable written

---

## Project Reference

**Core value:** Die Anwendung muss demonstrierbar laufen: Produkte anlegen/ändern/löschen mit Transaktionssicherheit, semantisch suchen (Qdrant) und per RAG mit Graph-Kontext antworten (Neo4j + OpenAI) — alles vergleichbar nebeneinander.

**Stack:** Python 3.12 + Flask 3.0.3 + SQLAlchemy 2.0.32 + MySQL 8.4 + Qdrant v1.16.2 + Neo4j 5 + OpenAI gpt-4.1-mini + sentence-transformers/all-MiniLM-L6-v2

**Deliverable:** `docker compose up` → fully working demo + `COMPARISON.md`

---

## Current Position

**Active Phase:** Phase 5 — Polish & Dokumentation — **Complete**
**Active Plan:** Plan 01 complete (COMPARISON.md — final deliverable)
**Status:** ALL PHASES COMPLETE — project deliverable ready

```
Progress: [██████████] 100%
           [COMPLETE | COMPLETE | COMPLETE | COMPLETE | COMPLETE |        ]
           [ 100%    | 100%    | 100%     | 4/4     | 1/1     |   —   ]
```

---

## Phase Status

| Phase | Name | Requirements | Status | Completed |
|-------|------|-------------|--------|-----------|
| 0 | Foundation & Blockers | FOUND-01–08 (8 reqs) | **Complete** | 2026-04-02 |
| 1 | MySQL CRUD & Transaktionen (A2) | TXN-01–08, ROUTE-01 (9 reqs) | **Complete** | 2026-04-05 |
| 2 | MySQL DDL Features (A3, A4, A5) | TRIG-01–03, PROC-01–04, IDX-01–06, ROUTE-02, ROUTE-03, DOC-02 (16 reqs) | **Complete** | 2026-04-13 |
| 3 | Qdrant Vektor-Suche (A6) | VECT-01–08, ROUTE-04 (9 reqs) | **Complete** | 2026-04-13 |
| 4 | Neo4j Graph & RAG (A7) | GRAPH-01–07 (7 reqs) | **Complete** | 2026-04-14 |
| 5 | Polish & Dokumentation | DOC-01 (1 req) | **Complete** | 2026-04-14 |

**Total requirements:** 50/50 mapped

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases total | 6 |
| Phases complete | 2 |
| Phases in progress | 0 |
| Requirements mapped | 50/50 |
| Requirements complete | 48/50 (FOUND-01–08, TXN-01–08, ROUTE-01, TRIG-01–03, ROUTE-02, PROC-01–04, ROUTE-03, IDX-01–06, DOC-02, VECT-01–08, ROUTE-04, GRAPH-01–07) |
| Plans created | 17 |
| Plans complete | 16 |

---
| Phase 00-foundation-blockers P04 | 1min | 2 tasks | 4 files |
| Phase 01-mysql-crud-transaktionen-a2 P02 | 3min | 2 tasks | 3 files |
| Phase 01-mysql-crud-transaktionen-a2 P01 | 17m | 2 tasks | 5 files |
| Phase 01-mysql-crud-transaktionen-a2 P03 | 9m | 2 tasks | 4 files |
| Phase 02-mysql-ddl-features P01 | 2min | 2 tasks | 2 files |
| Phase 02-mysql-ddl-features P02 | 3min | 2 tasks | 5 files |
| Phase 02-mysql-ddl-features P03 | 3m | 2 tasks | 3 files |
| Phase 03 P01 | 4min | 1 tasks | 1 files |
| Phase 03 P02 | 6min | 2 tasks | 2 files |
| Phase 03 P03 | 5min | 2 tasks | 2 files |
| Phase 03 P04 | 4min | 2 tasks | 2 files |
| Phase 04-neo4j-graph-rag-a7 P01 | 3min | 2 tasks | 2 files |
| Phase 04-neo4j-graph-rag-a7 P03 | 3min | 2 tasks | 2 files |
| Phase 04-neo4j-graph-rag-a7 P02 | 5min | 2 tasks | 3 files |
| Phase 04-neo4j-graph-rag-a7 P04 | 2min | 2 tasks | 2 files |
| Phase 05-polish-dokumentation P01 | 7min | 1 tasks | 1 files |

## Accumulated Context

### Key Decisions Made

| Decision | Rationale |
|----------|-----------|
| 6 phases (0–5), strictly sequential | Dependency chain is hard: Phase 0 unblocks everything; Phase 3 unblocks Phase 4; no shortcuts possible |
| Phase 0 contains ALL schema + factory fixes | Schema mismatch and factory race conditions cause cryptic failures everywhere — fix first, 100% |
| Phase 2 and Phase 3 have soft overlap | Both depend on Phase 1 being done; Phase 2 (DDL) and Phase 3 (Qdrant ETL) are relatively independent of each other |
| `with session.begin():` exclusively — no `text("COMMIT")` | SQLAlchemy 2.0 strict mode; raw COMMIT desynchronizes internal state machine |
| `MERGE` not `CREATE` for Neo4j sync | Idempotency — repeated index builds must not accumulate duplicate nodes |
| Embedding model singleton with `threading.Lock` | Flask dev server is threaded; concurrent first requests race to load 90 MB model |
| `ensure_collection()` before every upsert | Qdrant has no auto-create; 404 on fresh container; idempotent check is cheap |
| `.tolist()` on all numpy vectors | `PointStruct.vector` field requires `list[float]`; ndarray causes JSON serialization failure in some client versions |
| `cursor.nextset()` after every `CALL import_product()` | MySQL returns implicit result set; missing cleanup corrupts connection pool state |
| SKU immutable after creation | update_product() has no sku param; UPDATE SET excludes sku column — enforced at repo layer |
| Unknown tag names silently ignored in _resolve_tag_ids() | Phase 1 scope: no auto-create; tags must pre-exist; simpler UX |
| Use 'EUR' AS currency literal in SELECT | products table has no currency column; template needs it for display; literal matches create_product hardcoded 'EUR' |
| IntegrityError caught at route layer — repository propagates, route shows flash | TXN-04/TXN-05 rollback demo visible to user without exposing raw SQL errors |
| Single-click delete via POST form — no JS confirmation | CONTEXT.md locked decision; PRG redirect on all delete outcomes |
| templates/ bind-mounted in docker-compose.override.yml | Enables live template reload without Docker image rebuild (5+ min savings) |
| `DELIMITER $$` required for trigger DDL in MySQL init scripts | MySQL client uses `;` as delimiter by default — `BEGIN...END` body contains semicolons that would break parsing without `DELIMITER $$` |
| NULL-safe comparison in trigger for nullable fields | Simple `OLD.x <> NEW.x` fails silently when either value is NULL; three-part OR check correctly detects all transition types |
| `changed_by = 'web_ui'` hardcoded in trigger body | MySQL triggers have no access to Flask session context; hardcoded value is the correct approach |
| `ensure_collection()` idempotent via `collection_exists()` before create | Re-creating an existing collection would destroy data; check-then-create is safe and cheap |
| `build_index` Strategy C exclusively in Phase 3 | CONTEXT.md locked decision: delete+recreate before upsert; param kept for API compatibility |
| `execute_sql_search` uses local import ServiceFactory | Avoids circular import: services/__init__.py already imports SearchService |
| Phase 4 stubs preserved in SearchService | rag_search/pdf_rag_search/search_product_pdfs throw NotImplementedError; /search catches it → empty results (no 501) |
| `execute_cypher` consumes Result inside `with session:` block | `session.run()` returns lazy Result; consuming outside session scope raises SessionExpiredError at call site |
| `teardown_appcontext` fires per-request, not per-shutdown | teardown_appcontext fires on every HTTP request; replaced with atexit.register which fires once at process exit — correct semantics for singleton driver |
| Lazy reconnect in execute_cypher() | if self._driver is None, transparently reconnect before session.run(); prevents AttributeError after close() sets _driver=None without changing close() semantics |
| `qdrant_repo.search()` called directly in rag_search (not vector_search()) | hit.id provides mysql_id for Neo4j lookup; vector_search() discards the id field |
| `_generate_llm_answer` returns German fallback when OpenAI client is None | OPENAI_API_KEY absent → graceful degradation; RAG route stays functional without LLM |
| Graph enrichment wrapped in try/except (non-fatal) | Neo4j unavailable should not break vector search; log.warning and continue without enrichment |

### Known Risks

| Risk | Mitigation |
|------|-----------|
| Schema rename breaks FK references | Must update ALL `REFERENCES`, `DROP TABLE`, and `ON DELETE/ON UPDATE` clauses — not just `CREATE TABLE` |
| `etl_run_log` / `product_change_log` missing from `schema.sql` | Add DDL in Phase 0 before `docker compose up` — these tables are load-bearing for Phase 3 and Phase 2 respectively |
| `NoOpNeo4jRepository` crashes with `NotImplementedError` | Fix all 3 methods in Phase 0 — any factory code path returning NoOp will 501 instead of degrading gracefully |
| `sync_products()` not in `Neo4jRepository` ABC | Add as `@abstractmethod` during Phase 4; `NoOpNeo4jRepository` returns `0` |
| `etl_run_log` column names differ between IDE scratch file and FEATURES.md | Reconcile in Phase 0 — pick one schema, ensure `MySQLRepositoryImpl.log_etl_run()` signature matches |
| OpenAI API key absent | `_get_llm_client()` returns `None`; `_generate_llm_answer()` returns localized fallback string — RAG route still functional |

### Pitfall Index (for quick reference during implementation)

| Pitfall | Phase | Key Rule |
|---------|-------|---------|
| Schema table name mismatch | Phase 0 | Rename ALL references in `schema.sql` to plural |
| Missing `etl_run_log` | Phase 0 | Add DDL before `docker compose up` |
| Session not closed (pool exhaustion) | Phase 1 | `with self._session_factory() as session:` always |
| Raw `text("COMMIT")` | Phase 1 | Use `with session.begin():` exclusively |
| Nested `session.commit()` | Phase 1 | Never call `session.commit()` inside `with session.begin():` |
| Qdrant collection-before-upsert | Phase 3 | `ensure_collection()` before every `upsert_points()` |
| Qdrant numpy dimension | Phase 3 | `.tolist()` on all numpy arrays + `wait=True` |
| Neo4j driver singleton | Phase 4 | Only via `RepositoryFactory` — never per-request |
| Neo4j session not closed | Phase 4 | `with driver.session() as session:` always |
| Neo4j CREATE vs MERGE | Phase 4 | `MERGE` only — `CREATE` accumulates duplicates |
| Embedding model loaded 3× | Phase 0 | Double-checked locking singleton in `ServiceFactory._shared_resources` |
| Embedding model threading race | Phase 0 | `threading.Lock` around check-and-set |
| Stored procedure nextset | Phase 2 | `cursor.nextset()` until `False` after every `CALL` |
| RepositoryFactory race condition | Phase 0 | `threading.Lock` + double-checked locking |

---

## Session Continuity

### What Was Done This Session

- Executed Phase 4 Plan 04: Fixed Neo4j driver null-after-teardown bug
  - Root cause: @app.teardown_appcontext fires at end of every HTTP request (not only at process shutdown)
  - After /rag request, teardown_appcontext called repo.close() → self._driver = None
  - RepositoryFactory singleton kept broken instance; next /index call → AttributeError
  - Fix 1: repositories/neo4j_repository.py — store _uri/_user/_password in __init__; add lazy-reconnect guard in execute_cypher()
  - Fix 2: app.py — replace teardown_appcontext with atexit.register(_shutdown_neo4j) (fires once at process exit)
  - GRAPH-06 satisfied; Phase 4 completely done

### What to Do Next

1. Phase 5 — Polish & Dokumentation (COMPARISON.md, DOC-01)

### Files Written This Session

- `repositories/neo4j_repository.py` — stored credentials + lazy reconnect guard
- `app.py` — atexit.register instead of teardown_appcontext
- `.planning/phases/04-neo4j-graph-rag-a7/04-04-SUMMARY.md`

---

*State initialized: 2026-04-02*
*Next action: Start Phase 5 — Polish & Dokumentation (COMPARISON.md)*
