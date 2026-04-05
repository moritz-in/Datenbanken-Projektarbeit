---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: milestone
status: planning
last_updated: "2026-04-05T19:27:39.923Z"
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 7
  completed_plans: 7
  percent: 100
---

# STATE: Datenbanken-Projektarbeit Teil 2

**Last updated:** 2026-04-05
**Session:** Phase 1 Plan 03 execution — CRUD routes (routes/products.py) + Actions column (products.html)

---

## Project Reference

**Core value:** Die Anwendung muss demonstrierbar laufen: Produkte anlegen/ändern/löschen mit Transaktionssicherheit, semantisch suchen (Qdrant) und per RAG mit Graph-Kontext antworten (Neo4j + OpenAI) — alles vergleichbar nebeneinander.

**Stack:** Python 3.12 + Flask 3.0.3 + SQLAlchemy 2.0.32 + MySQL 8.4 + Qdrant v1.16.2 + Neo4j 5 + OpenAI gpt-4.1-mini + sentence-transformers/all-MiniLM-L6-v2

**Deliverable:** `docker compose up` → fully working demo + `COMPARISON.md`

---

## Current Position

**Active Phase:** Phase 1 — MySQL CRUD & Transaktionen (A2) — **Complete**
**Active Plan:** Plan 03 complete — Phase 1 DONE
**Status:** Ready to plan

```
Progress: [██████████] 100%
           [COMPLETE | COMPLETE |         |         |         |        ]
           [ 100%    | 100%    |   0%    |   0%    |   0%    |   0%  ]
```

---

## Phase Status

| Phase | Name | Requirements | Status | Completed |
|-------|------|-------------|--------|-----------|
| 0 | Foundation & Blockers | FOUND-01–08 (8 reqs) | **Complete** | 2026-04-02 |
| 1 | MySQL CRUD & Transaktionen (A2) | TXN-01–08, ROUTE-01 (9 reqs) | **Complete** | 2026-04-05 |
| 2 | MySQL DDL Features (A3, A4, A5) | TRIG-01–03, PROC-01–04, IDX-01–06, ROUTE-02, ROUTE-03, DOC-02 (16 reqs) | Pending | - |
| 3 | Qdrant Vektor-Suche (A6) | VECT-01–08, ROUTE-04 (9 reqs) | Pending | - |
| 4 | Neo4j Graph & RAG (A7) | GRAPH-01–07 (7 reqs) | Pending | - |
| 5 | Polish & Dokumentation | DOC-01 (1 req) | Pending | - |

**Total requirements:** 50/50 mapped

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases total | 6 |
| Phases complete | 2 |
| Phases in progress | 0 |
| Requirements mapped | 50/50 |
| Requirements complete | 17/50 (FOUND-01–08, TXN-01–08, ROUTE-01) |
| Plans created | 7 |
| Plans complete | 7 |

---
| Phase 00-foundation-blockers P04 | 1min | 2 tasks | 4 files |
| Phase 01-mysql-crud-transaktionen-a2 P02 | 3min | 2 tasks | 3 files |
| Phase 01-mysql-crud-transaktionen-a2 P01 | 17m | 2 tasks | 5 files |
| Phase 01-mysql-crud-transaktionen-a2 P03 | 9m | 2 tasks | 4 files |

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

- Executed Phase 1 Plan 01: MySQLRepositoryImpl read methods + ProductService read methods + dashboard/products routes
- Added abstract methods to MySQLRepository ABC (get_brands, get_categories, get_tags, create_product, update_product, delete_product, get_product_by_id)
- Implemented all read-path methods in MySQLRepositoryImpl (get_products_with_joins, get_dashboard_stats, get_last_runs, get_audit_entries, execute_raw_query, has_column, load_products_for_index, log_etl_run, get_brands, get_categories, get_tags)
- Implemented ProductService delegation methods (list_products_joined, get_dashboard_data, get_audit_log, get_last_runs, execute_sql_query)
- Implemented GET / dashboard route and GET /products product list route
- Fixed bug: products table has no currency column → use 'EUR' AS currency literal
- Created docker-compose.override.yml to bind-mount source dirs for live code reload

- Executed Phase 1 Plan 02: MySQLRepositoryImpl write methods (create/update/delete/get_by_id + get_brands/categories/tags)
- Implemented ProductService write methods (create_product_with_relations, update_product, delete_product, _resolve_tag_ids)
- Added ProductService delegation methods (get_product_by_id, get_brands, get_categories)
- Created templates/product_form.html shared Bootstrap 5 create/edit form

- Executed Phase 1 Plan 03: CRUD routes in routes/products.py + Actions column in products.html
- Implemented new_product, create_product, edit_product, update_product, delete_product route handlers
- Added Aktionen column with Edit/Delete buttons to products.html
- Auto-fixed: Plan 02 stubs not implemented → implemented create/update/delete/get_product_by_id in mysql_repository.py
- Auto-fixed: Wrong column name (p.product_id → p.id) and currency column not in products table
- Auto-fixed: templates/ bind-mount added to docker-compose.override.yml
- Phase 1 MySQL CRUD & Transaktionen COMPLETE

### What to Do Next

1. Start Phase 2 — MySQL DDL Features (A3, A4, A5): triggers, stored procedures, indexes
2. Phase 2 plans: triggers (TRG-01–03), stored procedures (PROC-01–04), indexes (IDX-01–06)
3. Phase 2 requires Phase 1 complete — now done

### Files Written This Session

- `routes/products.py` — full CRUD routes implemented
- `templates/products.html` — Actions column added
- `repositories/mysql_repository.py` — write methods implemented (fix for Plan 02 stubs)
- `docker-compose.override.yml` — templates/ bind-mount added
- `.planning/phases/01-mysql-crud-transaktionen-a2/01-03-SUMMARY.md`

---

*State initialized: 2026-04-02*
*Next action: Start Phase 2 — MySQL DDL Features (triggers, stored procedures, indexes)*
