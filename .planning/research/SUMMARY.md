# Project Research Summary

**Project:** Datenbanken-Projektarbeit — Flask RAG Application (Teil 2)
**Domain:** University database course project — multi-database product catalog (MySQL + Qdrant + Neo4j)
**Researched:** 2026-04-02
**Confidence:** HIGH — all research derived from official docs and direct codebase analysis

## Executive Summary

This is a university course submission (not a commercial product) demonstrating six database techniques across assignments A2–A7: explicit MySQL transactions, triggers, stored procedures, B-Tree indexes, vector search (Qdrant), and graph-augmented RAG (Neo4j + OpenAI). The grading criteria are concrete and assignment-specific — "table stakes" means satisfying rubric requirements, and "differentiators" means showing deeper understanding beyond the minimum. The scaffold is mostly complete (templates, ABCs, route stubs), and the core work is implementing stubs correctly using the right library APIs and patterns.

The recommended approach is strictly sequential, bottom-up: fix the known blockers first (schema table name mismatch, missing tables, broken NoOp repository, thread-unsafe factory singletons), then build upward through the dependency chain — repository layer → service layer → routes → MySQL DDL features → Qdrant ETL → Neo4j graph → full RAG pipeline. Every layer above depends on the layers below; attempting A6 or A7 before A2 is working will cause cascading failures. The architecture is a clean 3-tier pattern (routes → services → repositories) with explicit dependency injection via factory singletons.

The top risks are all known and preventable: the schema has singular table names but all application code expects plural (one-time fix), two tables (`etl_run_log`, `product_change_log`) are missing from `schema.sql` (add DDL before first run), and the embedding model singleton must use double-checked locking to prevent race conditions on first request. SQLAlchemy 2.0 semantics differ significantly from 1.x — raw `text("COMMIT")` and bare `session.query()` patterns must be avoided entirely. All critical pitfalls have clear, concrete prevention strategies documented in PITFALLS.md.

---

## Key Findings

### Recommended Stack

The stack is already pinned in `requirements.txt` — this is not a decision to make. Flask 3.0.3 with SQLAlchemy 2.0.32 (`future=True`) handles the MySQL relational layer; Qdrant v1.16.2 via `qdrant-client` handles vector search; Neo4j 5.x via the official Python driver handles graph enrichment. The embedding model is `sentence-transformers/all-MiniLM-L6-v2` (384-dim, COSINE distance). OpenAI `gpt-4.1-mini` handles LLM completion in the RAG pipeline.

**Core technologies:**
- **Flask 3.0.3**: Web framework — pinned, use synchronous routes only (no async/await)
- **SQLAlchemy 2.0 + PyMySQL**: MySQL ORM/query layer — `text()` + `session.begin()` context manager exclusively; never use 1.x `session.query()` or bare string queries
- **Qdrant v1.16.2**: Vector search — `collection_exists()` before every upsert; always `wait=True`; always `.tolist()` on numpy vectors
- **Neo4j 5.x Python driver**: Graph DB — singleton driver via `RepositoryFactory`; always `with driver.session()` context manager; use `MERGE` not `CREATE` for sync
- **sentence-transformers/all-MiniLM-L6-v2**: Embedding model — shared singleton in `ServiceFactory._shared_resources` with `threading.Lock`; 384-dim output
- **OpenAI gpt-4.1-mini**: LLM — blocking call via `openai.OpenAI`; returns `None` gracefully if `OPENAI_API_KEY` absent

See [STACK.md](.planning/research/STACK.md) for precise API patterns and anti-patterns for each library.

### Expected Features

This is a graded university submission. Features are dictated by the assignment rubric (A2–A7), not market research.

**Must have (table stakes — required to pass):**
- **A2: CRUD with explicit transactions** — `create_product`, `update_product`, `delete_product` with `START TRANSACTION / COMMIT / ROLLBACK`; at least one rollback demo scenario (duplicate SKU or FK violation)
- **A3: MySQL trigger** — `AFTER UPDATE ON products` trigger writing to `product_change_log`; demonstrable without Python code involvement
- **A4: Stored procedure** — `import_product()` with OUT parameters for result code and message; validation for name, price, SKU uniqueness, brand/category existence
- **A5: B-Tree indexes + EXPLAIN** — indexes in DDL + before/after EXPLAIN output in Markdown
- **A6: Qdrant vector search** — all 1000 products indexed; semantic search tab working; `etl_run_log` populated
- **A7: Neo4j graph + LLM RAG** — graph populated via `MERGE`; RAG pipeline returning LLM answer with `graph_source` badge in UI

**Blockers (must fix before anything else):**
- Schema table rename: singular → plural (`product` → `products`, etc.)
- Add `etl_run_log` and `product_change_log` to `schema.sql`
- Implement `RepositoryFactory` and `ServiceFactory` with thread-safe singletons
- Fix `NoOpNeo4jRepository` (replace `raise NotImplementedError` with safe empty returns)

**Should have (earn full marks):**
- Conditional trigger (`IF OLD.field <> NEW.field`) — avoids log spam, shows deeper understanding
- `DECLARE EXIT HANDLER FOR SQLEXCEPTION` in stored procedure
- Three EXPLAIN queries (exact match, range, JOIN)
- `related_products` via Neo4j graph traversal
- `COMPARISON.md` with concrete vector vs SQL query examples
- ETL run duration tracking in `etl_run_log`

**Defer to after core works (P3):**
- Strategy B/C incremental index builds (Strategy A + C sufficient for demo)
- PDF upload RAG feature
- `product_to_document()` optimization beyond basic fields

See [FEATURES.md](.planning/research/FEATURES.md) for full feature dependency graph and prioritization matrix.

### Architecture Approach

The project follows a strict 3-tier architecture: HTTP routes (Blueprints) → service layer (business logic, RAG orchestration) → repository layer (database-specific implementations). Transaction boundaries belong in `MySQLRepositoryImpl`, not in `ProductService` — each repository method is self-contained with its own session lifecycle. The embedding model and LLM client are shared singletons injected via `ServiceFactory._shared_resources`, preventing the 270 MB / 3× model load problem. Neo4j sync happens during `IndexService.build_index()` alongside Qdrant upsert — no event-driven infrastructure needed for a demo.

**Major components:**
1. **`RepositoryFactory`** — thread-safe singleton cache for all DB repository instances; must be implemented first
2. **`ServiceFactory`** — thread-safe singleton cache for all services + shared embedding model + LLM client; must be implemented second
3. **`MySQLRepositoryImpl`** — all raw SQL via `text()` + explicit session/transaction management; owns A2/A3/A4/A5
4. **`QdrantRepositoryImpl`** — collection management, vector upsert/search; owns A6
5. **`Neo4jRepositoryImpl`** — Cypher queries via driver sessions; `sync_products()` called from `IndexService`; owns A7 graph part
6. **`SearchService`** — RAG pipeline: embed → vector search → graph enrich → LLM answer; owns A7 RAG part
7. **`IndexService`** — ETL: MySQL → embed → Qdrant upsert → Neo4j sync → log; owns A6 ETL + A7 graph population

See [ARCHITECTURE.md](.planning/research/ARCHITECTURE.md) for complete data flow diagrams and build order (13 steps).

### Critical Pitfalls

1. **Schema table name mismatch crashes everything** — `schema.sql` uses singular names; all Python code expects plural. Fix all 5 tables in DDL before writing any repository code. Verification: `validate_mysql()` returns PASSED.

2. **`etl_run_log` and `product_change_log` missing from schema** — both tables exist only in scratch files, never in `schema.sql`. Add both DDL blocks before `docker compose up`. Verification: `SELECT COUNT(*) FROM etl_run_log` returns 0 (not an error).

3. **`NoOpNeo4jRepository` raises `NotImplementedError`** — scaffold left stubs that crash instead of returning empty values. Fix immediately: `get_product_relationships()` → `{}`, `execute_cypher()` → `[]`, `close()` → `pass`. Verification: app starts cleanly without Neo4j configured.

4. **SQLAlchemy 2.0 session/transaction anti-patterns** — raw `text("COMMIT")` corrupts SQLAlchemy's internal state; `session.commit()` inside `with session.begin()` commits the outer transaction; sessions not closed as context managers exhaust the connection pool. Always use `with self._session_factory() as session: with session.begin():` pattern exclusively.

5. **Embedding model loaded 3×** — `SearchService`, `IndexService`, `PDFService` each calling `SentenceTransformer()` independently costs 270 MB RAM and 3–9 sec startup. Implement `ServiceFactory._get_embedding_model()` with double-checked locking before any service is instantiated.

6. **Qdrant collection not ensured before upsert** — `upsert_points()` on a non-existent collection raises 404. Always call `ensure_collection()` (idempotent) before any upsert.

7. **MySQL stored procedure `CALL` leaves dirty result sets** — must call `cursor.nextset()` after every `CALL import_product(...)` or the connection is returned to the pool in a broken state causing `ProgrammingError: Commands out of sync` on the next request.

See [PITFALLS.md](.planning/research/PITFALLS.md) for the full 14-pitfall catalog with warning signs, recovery strategies, and phase-to-pitfall mapping.

---

## Implications for Roadmap

Based on research, the build order is strictly dictated by dependency chains — not by feature priority. The 13-step build order from ARCHITECTURE.md maps naturally to 5 phases:

### Phase 0: Blockers & Foundation
**Rationale:** Nothing else can be tested until the schema matches what the code expects, the factories are thread-safe singletons, and the NoOp repository doesn't crash. This is a surgical prerequisite phase — low effort, maximum unblocking value.
**Delivers:** App starts cleanly, all routes return a valid response (even if empty), `validate_mysql()` passes all checks.
**Addresses:** Schema rename, `etl_run_log` + `product_change_log` DDL addition, `RepositoryFactory` + `ServiceFactory` implementation with `threading.Lock`, `NoOpNeo4jRepository` safe returns, embedding model singleton with double-checked locking.
**Avoids:** Pitfalls 1 (schema mismatch), 2 (missing tables), 8 (NoOp crashes), 10+11 (embedding model race condition), 14 (RepositoryFactory race condition).
**Research flag:** NONE — all patterns are fully documented and verified.

### Phase 1: MySQL Repository + CRUD (A2)
**Rationale:** `MySQLRepositoryImpl` is the foundation for every subsequent feature. The read path (product listing, dashboard stats) must work before the write path (create/update/delete). The SQLAlchemy 2.0 session pattern must be established correctly here — errors here propagate to all phases.
**Delivers:** Working product list page, dashboard with real stats, full CRUD with transaction-wrapped write operations, at least one visible rollback demo scenario.
**Addresses:** A2 assignment — explicit `START TRANSACTION / COMMIT / ROLLBACK` (via `session.begin()` context manager), rollback on duplicate SKU or FK violation, flash messages.
**Avoids:** Pitfalls 3 (session not closed), 4 (nested commit semantics), 5 (raw `text("COMMIT")`).
**Research flag:** NONE — SQLAlchemy 2.0 patterns are thoroughly documented.

### Phase 2: MySQL DDL Features (A3, A4, A5)
**Rationale:** These are pure SQL/DDL work that can proceed in parallel with or immediately after Phase 1. A3 (trigger) requires A2's update form to be testable. A4 (stored procedure) and A5 (indexes) are largely standalone DDL additions. Grouping them saves context-switching and keeps all MySQL-layer work together.
**Delivers:** `AFTER UPDATE` trigger on `products` writing to `product_change_log`, `import_product()` stored procedure with full validation and OUT parameters, B-Tree indexes in `schema.sql`, EXPLAIN Markdown document.
**Addresses:** A3 (trigger), A4 (stored procedure), A5 (indexes + EXPLAIN).
**Avoids:** Pitfall 13 (trigger DDL order — `product_change_log` must precede trigger), Pitfall 12 (stored procedure `nextset()` for clean cursor state).
**Research flag:** NONE — MySQL DDL patterns are well-documented and fully specified in FEATURES.md.

### Phase 3: Qdrant Vector Search (A6)
**Rationale:** Requires `MySQLRepositoryImpl.load_products_for_index()` to work (Phase 1 dependency) and the `etl_run_log` table to exist (Phase 0 dependency). The `QdrantRepositoryImpl` and `IndexService` can now be built with the singleton embedding model from Phase 0.
**Delivers:** All 1000 products indexed as 384-dim vectors in Qdrant, semantic search tab working in `search_unified.html`, ETL run logged to `etl_run_log`, vector vs SQL comparison demonstrable.
**Addresses:** A6 (Vektor-DB) — `QdrantRepositoryImpl`, `IndexService.build_index()` with strategy A, `SearchService.vector_search()`, `/index` and `/search` routes.
**Avoids:** Pitfall 6 (ensure collection before upsert), Pitfall 7 (numpy `.tolist()` conversion, `wait=True`).
**Research flag:** NONE — Qdrant API patterns fully documented in STACK.md.

### Phase 4: Neo4j Graph + Full RAG (A7)
**Rationale:** Explicitly depends on Phase 3 — the RAG pipeline starts with Qdrant vector search and enriches results with Neo4j. `Neo4jRepositoryImpl` and `sync_products()` integrate into the existing `IndexService.build_index()` call. The LLM answer generation is the final step in the RAG pipeline.
**Delivers:** Neo4j graph populated with Product/Brand/Category/Tag nodes and relationships, `get_product_relationships()` returning enriched context, `SearchService.rag_search()` returning LLM-generated answer with `graph_source` badge, `/rag` route functional.
**Addresses:** A7 (Graph-DB + RAG) — `Neo4jRepositoryImpl` with MERGE-based sync, `SearchService.rag_search()`, `_generate_llm_answer()` with OpenAI gpt-4.1-mini.
**Avoids:** Pitfall 8 (driver close teardown), Pitfall 9 (session context managers in Neo4j), Architecture anti-pattern 4 (MERGE not CREATE for idempotency).
**Research flag:** NONE — Neo4j driver patterns fully documented in STACK.md; RAG data flow fully specified in ARCHITECTURE.md.

### Phase 5: Polish & Documentation (P2 Features)
**Rationale:** Write last — `COMPARISON.md` requires all three search modes working, conditional trigger improvements require the basic trigger to work, and remaining routes (audit, validate, pdf) are cosmetic for the demo.
**Delivers:** `COMPARISON.md` with concrete query examples showing vector vs SQL vs RAG differences, conditional trigger logic (`IF OLD.field <> NEW.field`), audit route, validate route with `execute_raw_query()`, dashboard polish.
**Addresses:** P2 differentiators from FEATURES.md prioritization matrix.
**Research flag:** NONE — standard patterns, no novel integrations.

### Phase Ordering Rationale

- **Phase 0 is non-negotiable first** — the schema mismatch and factory race conditions will produce cryptic, misleading failures at every other phase; fixing these first saves hours of debugging.
- **Phase 1 before Phase 2** — the trigger test requires a working update form; the stored procedure requires a working product schema with plural table names.
- **Phase 2 before Phase 3** — `etl_run_log` is in Phase 0 (schema fix), but the `IndexService` also calls `load_products_for_index()` which requires the MySQL read path from Phase 1.
- **Phase 3 strictly before Phase 4** — the RAG pipeline opens with `QdrantRepository.search()`. There is no path to A7 without A6 working first; this dependency is architectural, not just a convenience.
- **Phase 5 is always last** — comparative documentation (`COMPARISON.md`) is meaningless until all three search modes produce real results.

### Research Flags

Phases with standard, well-documented patterns (skip `/gsd-research-phase`):
- **Phase 0:** All fixes are from direct codebase analysis — no external research needed
- **Phase 1:** SQLAlchemy 2.0 patterns fully specified in STACK.md + PITFALLS.md
- **Phase 2:** MySQL DDL fully specified in FEATURES.md (complete DDL blocks provided)
- **Phase 3:** Qdrant patterns fully specified in STACK.md with concrete code examples
- **Phase 4:** Neo4j driver patterns + RAG data flow fully specified in STACK.md + ARCHITECTURE.md
- **Phase 5:** Polish phase — no novel integrations

**No phase requires additional research.** All patterns are verified against official documentation with HIGH confidence. The research files contain copy-paste-ready code examples for every major implementation step.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All APIs verified against official docs; version-specific anti-patterns documented (e.g., `recreate_collection` deprecated since 1.1.1, `session.query()` deprecated in 2.0) |
| Features | HIGH | Derived directly from scaffold code, schema, templates, and ABCs — no guessing; requirements are concrete rubric items |
| Architecture | HIGH | Based on direct codebase analysis of actual source files; build order is logically verified through dependency tracing |
| Pitfalls | HIGH | SQLAlchemy, Qdrant, Neo4j pitfalls verified against official docs; threading race conditions identified from source inspection |

**Overall confidence: HIGH**

### Gaps to Address

- **`sync_products()` not in `Neo4jRepository` ABC** — this method needs to be added as either an `@abstractmethod` or a concrete method on `Neo4jRepositoryImpl` only. Decision needed during Phase 4 implementation: modify the ABC or bypass it. Recommendation: add to ABC so `NoOpNeo4jRepository` can return `0` safely.
- **`sku` column not in current `schema.sql`** — FEATURES.md recommends adding `sku VARCHAR(100) UNIQUE` to `products` table. This is needed for the stored procedure duplicate-SKU demo and for `import_product()` validation. Must be added during Phase 0 schema fix.
- **`etl_run_log` column names may differ** — the IDE scratch file version has `strategy`, `started_at`, `finished_at`, `status`. The FEATURES.md version has slightly different columns (`run_timestamp`, `duration_seconds`). The `MySQLRepositoryImpl.log_etl_run()` signature (`strategy`, `products_processed`, `products_written`) must be reconciled with whichever DDL is chosen. Pick one schema during Phase 0 and ensure the Python method matches.
- **Docker Compose init order** — `schema.sql` is mounted as an init file; trigger DDL in a separate file (if separated) must be mounted in order. If triggers are in a separate `.sql` file, verify Docker init runs them after schema creation.

---

## Sources

### Primary (HIGH confidence — official documentation)
- SQLAlchemy 2.0 Session Transactions: https://docs.sqlalchemy.org/en/20/orm/session_transaction.html
- SQLAlchemy 2.0 Core Text Construct: https://docs.sqlalchemy.org/en/20/core/sqlelement.html
- Qdrant Python Quickstart: https://qdrant.tech/documentation/quickstart/
- Qdrant Collections API: https://qdrant.tech/documentation/manage-data/collections/
- Qdrant Python Client API: https://python-client.qdrant.tech/
- Neo4j Python Driver — Simple Queries: https://neo4j.com/docs/python-manual/current/query-simple/
- Neo4j Python Driver — Transactions: https://neo4j.com/docs/python-manual/current/transactions/
- Neo4j Python Driver — Advanced Connection: https://neo4j.com/docs/python-manual/current/connect-advanced/

### Primary (HIGH confidence — direct codebase analysis)
- `schema.sql` — table definitions, constraints, column types
- `repositories/mysql_repository.py`, `qdrant_repository.py`, `neo4j_repository.py` — ABC definitions, method signatures
- `services/__init__.py`, `services/search_service.py`, `services/index_service.py` — service architecture
- `db.py`, `app.py`, `config.py`, `validation.py` — infrastructure patterns
- `templates/` — Jinja2 templates confirming expected data shapes
- `.planning/PROJECT.md` — assignment requirements A2–A7
- `.planning/codebase/ARCHITECTURE.md` — existing architecture documentation
- `.planning/codebase/CONCERNS.md` — known issues documented by scaffold author

---
*Research completed: 2026-04-02*
*Ready for roadmap: yes*
