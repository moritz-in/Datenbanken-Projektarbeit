# Roadmap: Datenbanken-Projektarbeit Teil 2

**Created:** 2026-04-02
**Granularity:** coarse (6 phases — driven by strict dependency chain)
**Coverage:** 50/50 v1 requirements mapped ✓

---

## Phases

- [x] **Phase 0 — Foundation & Blockers** — Schema fixes, factory singletons, NoOp repair, PostgreSQL dead-code removal (completed 2026-04-02)
- [x] **Phase 1 — MySQL CRUD & Transaktionen (A2)** — Repository write path with explicit transactions, rollback demos, CRUD routes (completed 2026-04-05)
- [x] **Phase 2 — MySQL DDL Features (A3, A4, A5)** — Trigger, Stored Procedure, B-Tree indexes, EXPLAIN analysis (completed 2026-04-13)
- [ ] **Phase 3 — Qdrant Vektor-Suche (A6)** — Vector ETL, semantic search route, index build route, ETL logging
- [ ] **Phase 4 — Neo4j Graph & RAG (A7)** — Graph population, RAG pipeline, LLM answer generation, RAG route
- [ ] **Phase 5 — Polish & Dokumentation** — COMPARISON.md comparative analysis

---

## Phase Details

### Phase 0: Foundation & Blockers

**Goal:** The app starts cleanly, all routes return a valid response (even if empty), `validate_mysql()` passes all table checks, and no factory or NoOp method crashes at runtime.

**Depends on:** Nothing — this is the mandatory first phase.

**Requirements:** FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-07, FOUND-08

**Key Tasks:**
1. Rename all 5 table names in `schema.sql` to plural (`product` → `products`, `brand` → `brands`, `category` → `categories`, `tag` → `tags`, `product_tag` → `product_tags`) — also update all `REFERENCES`, `DROP TABLE`, and FK `ON DELETE`/`ON UPDATE` clauses
2. Add `etl_run_log` DDL to `schema.sql` (columns: `id`, `strategy`, `started_at`, `finished_at`, `products_processed`, `products_written`, `status`, `error_msg`) before the `products` table
3. Add `product_change_log` DDL to `schema.sql` (columns: `id`, `product_id`, `changed_at`, `field_name`, `old_value`, `new_value`, `changed_by`) before the trigger DDL
4. Add `sku VARCHAR(100) UNIQUE NULL` column to `products` table in `schema.sql`
5. Implement `RepositoryFactory` — all `get_*()` methods with `threading.Lock` double-checked locking; `get_neo4j_repository()` returns `NoOpNeo4jRepository` when Neo4j URI absent
6. Implement `ServiceFactory` — all `get_*()` methods; `_get_embedding_model()` as true singleton in `_shared_resources` with `threading.Lock` double-checked locking; `_get_llm_client()` returns `None` gracefully if `OPENAI_API_KEY` absent
7. Fix `NoOpNeo4jRepository`: `get_product_relationships()` → `{}`, `execute_cypher()` → `[]`, `close()` → `pass`
8. Remove PostgreSQL dead code: `pg_session_factory` from `db.py`, `PG_URL` from `config.py`, `psycopg2-binary` from `requirements.txt`
9. Run `docker compose down -v && docker compose up` to verify schema applies cleanly

**Success Criteria** (what must be TRUE when this phase completes):
1. `docker compose up` completes without errors; app container reaches healthy state
2. `validate_mysql()` (via `/validate` route) returns PASSED for all 5 tables (`products`, `brands`, `categories`, `tags`, `product_tags`)
3. `SELECT COUNT(*) FROM etl_run_log` returns `0` (table exists, empty) — no SQL error
4. `SELECT COUNT(*) FROM product_change_log` returns `0` — no SQL error
5. Any route that goes through `RepositoryFactory` or `ServiceFactory` returns a non-501 response (may be empty data, not a crash)
6. Docker container RAM stays below 250 MB on first request (single embedding model load confirmed by single log line)

**Pitfall Warnings:**
- ⚠️ **Pitfall 1 (schema mismatch):** Must rename ALL references in `schema.sql` — `REFERENCES`, `DROP TABLE`, and FK clauses, not just `CREATE TABLE`. Verify with `validate_mysql()`.
- ⚠️ **Pitfall 2 (missing tables):** `etl_run_log` and `product_change_log` are referenced by code at runtime — they crash silently if absent. Add both before any other phase.
- ⚠️ **Pitfall 11 (threading race):** `ServiceFactory._get_embedding_model()` MUST use double-checked locking (`threading.Lock`) — two concurrent first requests can both attempt model load.
- ⚠️ **Pitfall 14 (RepositoryFactory race):** Same double-checked locking pattern required in `RepositoryFactory.get_*()` methods.
- ⚠️ **Pitfall 8 (NoOp crashes):** `NoOpNeo4jRepository` currently raises `NotImplementedError` — fix ALL three methods before implementing any factory.

**Plans:** TBD

---

### Phase 1: MySQL CRUD & Transaktionen (A2)

**Goal:** Users can create, update, and delete products through the web UI with full transaction safety — including visible rollback demonstrations for duplicate SKU and referential integrity violations.

**Depends on:** Phase 0 (schema plural names in place, factories implemented, session factory available)

**Requirements:** TXN-01, TXN-02, TXN-03, TXN-04, TXN-05, TXN-06, TXN-07, TXN-08, ROUTE-01

**Key Tasks:**
1. Implement `MySQLRepositoryImpl` read methods: `get_products_with_joins()`, `get_dashboard_stats()`, `get_last_runs()`, `has_column()`, `execute_raw_query()`, `load_products_for_index()`
2. Implement `MySQLRepositoryImpl.create_product()` with `with self._session_factory() as session: with session.begin():` — INSERT into `products` + `product_tags` in single transaction; UNIQUE constraint on `sku` triggers automatic rollback on duplicate
3. Implement `MySQLRepositoryImpl.update_product()` with explicit transaction block
4. Implement `MySQLRepositoryImpl.delete_product()` — DELETE `product_tags` first (FK), then `products`; FK constraint on `products.brand_id` or `products.category_id` from other tables triggers rollback if referenced
5. Implement `ProductService.create_product_with_relations()`, `update_product()`, `delete_product()`
6. Implement `routes/products.py` — product list (paginated), create form, edit form, delete confirmation; Flash messages on success and failure (green/red)
7. Implement `routes/dashboard.py` (ROUTE-01) — product count, last ETL run, system-status badges for MySQL/Qdrant/Neo4j

**Success Criteria** (what must be TRUE when this phase completes):
1. `/products` renders a paginated list of all 1000 seed products with brand, category, price
2. A new product can be submitted via the create form and appears in the product list
3. Submitting a create form with a duplicate SKU shows a red flash error — no partial row in the DB
4. Deleting a product that has dependent records shows a red flash error and leaves the product intact
5. `/dashboard` shows real product count and system-status indicators (not 501)

**Pitfall Warnings:**
- ⚠️ **Pitfall 3 (session pool):** EVERY `MySQLRepositoryImpl` method MUST use `with self._session_factory() as session:` — bare `session = factory()` without context manager exhausts the pool in ~5 requests.
- ⚠️ **Pitfall 5 (raw COMMIT):** Never use `session.execute(text("COMMIT"))`. Use `with session.begin():` — SQLAlchemy translates this to a real `START TRANSACTION / COMMIT` at the DBAPI level. Enable `echo=True` on the engine to verify in logs.
- ⚠️ **Pitfall 4 (nested commit):** Never call `session.commit()` inside a `with session.begin():` block — it commits the outermost transaction, not an inner savepoint.
- ⚠️ **Anti-Pattern 1:** Transaction management belongs in `MySQLRepositoryImpl`, NOT in `ProductService`. Each repository method is its own atomic unit — the service layer calls them sequentially without owning session state.

**Plans:** 3/3 plans complete

Plans:
- [ ] 01-01-PLAN.md — Read path: MySQLRepositoryImpl read methods + ProductService reads + dashboard route (Wave 1)
- [ ] 01-02-PLAN.md — Write path: MySQLRepositoryImpl write methods + ProductService writes + product_form.html (Wave 1)
- [ ] 01-03-PLAN.md — CRUD routes: routes/products.py full CRUD + products.html Actions column (Wave 2)

---

### Phase 2: MySQL DDL Features (A3, A4, A5)

**Goal:** MySQL demonstrably logs product changes automatically via trigger (no Python involvement), imports products through a validated stored procedure, and query performance is provably improved by B-Tree indexes documented with EXPLAIN output.

**Depends on:** Phase 1 (update form must work to test trigger; `products` table with plural name and `sku` column must exist for procedure)

**Requirements:** TRIG-01, TRIG-02, TRIG-03, PROC-01, PROC-02, PROC-03, PROC-04, IDX-01, IDX-02, IDX-03, IDX-04, IDX-05, IDX-06, ROUTE-02, ROUTE-03, DOC-02

**Key Tasks:**

*A3 — Trigger:*
1. Add `AFTER UPDATE ON products` trigger DDL to `schema.sql` (or `triggers.sql` mounted after schema): writes one row per changed field to `product_change_log` using `IF OLD.field <> NEW.field` conditional blocks
2. Verify trigger: update a product's price via the UI → query `product_change_log` → see auto-created row with no Python code involvement

*A4 — Stored Procedure:*
3. Add `import_product()` stored procedure DDL with IN params (`p_name`, `p_description`, `p_brand_name`, `p_category_name`, `p_price`, `p_sku`, `p_load_class`, `p_application`) and OUT params (`p_result_code INT`, `p_result_message VARCHAR(500)`)
4. Procedure enforces: name/price/category required; SKU uniqueness check; brand/category existence resolution; `DECLARE EXIT HANDLER FOR SQLEXCEPTION`; result codes 0=success, 1=duplicate, 2=validation_error, 3=db_error
5. Implement `ProductService` method to `CALL import_product(...)` and read `@rc`, `@rm` OUT params — including `cursor.nextset()` to flush result sets
6. Implement `routes/validate.py` (ROUTE-03) — call procedure with intentionally bad data, display OUT parameter messages

*A5 — Indexes:*
7. Add B-Tree index DDL to `schema.sql`: `CREATE INDEX idx_products_name ON products(name)`, `idx_products_category_id ON products(category_id)`, `idx_products_brand_id ON products(brand_id)`
8. Run `EXPLAIN` for 3 queries (exact-match on `name`, range on `price`, JOIN with `brands`) — capture output before and after index creation
9. Write Markdown analysis document (`docs/INDEX_ANALYSIS.md` or similar): why MySQL uses B-Trees, annotated EXPLAIN comparison, key columns (`type`, `key`, `rows`, `Extra`)

*Supporting Routes:*
10. Implement `routes/audit.py` (ROUTE-02) — display `etl_run_log` rows (run timestamp, strategy, products processed, status)

**Success Criteria** (what must be TRUE when this phase completes):
1. Updating a product's price in the UI → `SELECT * FROM product_change_log` shows a new row — with NO Python code having written it
2. Calling the import procedure with a duplicate SKU via the validate route returns `p_result_code = 1` and the error message appears in the UI
3. `EXPLAIN SELECT * FROM products WHERE name = 'X'` shows `type=ref` and `key=idx_products_name` (B-Tree hit, not full scan)
4. `/audit` renders the ETL run log table (may be empty if no index builds yet — must not 501)
5. `SHOW TRIGGERS FROM projectdb` returns at least one trigger row (`trg_products_after_update`)

**Pitfall Warnings:**
- ⚠️ **Pitfall 13 (trigger DDL order):** `product_change_log` table DDL MUST appear before `CREATE TRIGGER` in `schema.sql`. MySQL checks referenced tables at trigger creation time — wrong order = silent trigger failure.
- ⚠️ **Pitfall 12 (stored procedure nextset):** After every `CALL import_product(...)`, call `cursor.nextset()` until `False` before returning the connection to the pool. Missing this causes `ProgrammingError: Commands out of sync` on the very next request.
- ⚠️ **Trigger type:** Use `AFTER UPDATE` (not `BEFORE UPDATE`) — `BEFORE` triggers cannot see `NEW` values for logging purposes.
- ⚠️ **Index rename:** The original `schema.sql` may have index DDL on singular table `product` — ensure index DDL references plural `products` table after Phase 0 rename.

**Plans:** 3/3 plans complete

Plans:
- [ ] 02-01-PLAN.md — AFTER UPDATE trigger DDL + /audit route (Wave 1)
- [ ] 02-02-PLAN.md — import_product() stored procedure + /validate/procedure route (Wave 1)
- [ ] 02-03-PLAN.md — B-Tree index EXPLAIN documentation + index status on /validate (Wave 1)

---

### Phase 3: Qdrant Vektor-Suche (A6)

**Goal:** All 1000 products are indexed as 384-dimensional vectors in Qdrant, semantic search returns relevant results for queries that SQL LIKE cannot match, and the ETL run is logged to `etl_run_log`.

**Depends on:** Phase 1 (`load_products_for_index()` read path), Phase 0 (`etl_run_log` table, embedding model singleton)

**Requirements:** VECT-01, VECT-02, VECT-03, VECT-04, VECT-05, VECT-06, VECT-07, VECT-08, ROUTE-04

**Key Tasks:**
1. Implement `QdrantRepositoryImpl.create_collection()` — use `delete_collection()` + `create_collection()` (NOT deprecated `recreate_collection`); COSINE distance, 384 dimensions, HNSW m=16 ef_construct=128
2. Implement `QdrantRepositoryImpl.ensure_collection()` — idempotent: `collection_exists()` check → create only if absent
3. Implement `QdrantRepositoryImpl.upsert_points()` — call `ensure_collection()` first; convert numpy vectors with `.tolist()`; use `wait=True`
4. Implement `QdrantRepositoryImpl.search()` — embed query → Qdrant cosine search → return list of hits with scores and payload
5. Implement `QdrantRepositoryImpl.extract_pdf_chunks()` and `upload_pdf_chunks()` (VECT-04)
6. Implement `IndexService.build_index(strategy)` — load products from MySQL → `product_to_document()` → batch embed (batch_size=64) → `.tolist()` on numpy array → upsert to Qdrant → log ETL run to `etl_run_log`
7. Implement `SearchService.vector_search()` — embed query → Qdrant search → return formatted hits
8. Implement `routes/search.py` (VECT-07) — tabbed UI: semantic search results and SQL search results side-by-side in `search_unified.html`
9. Implement `routes/index.py` (VECT-08) — index build form with strategy selector; run `build_index()` synchronously; show result count and elapsed time
10. Implement `routes/pdf.py` (ROUTE-04) — PDF upload → text extraction → chunk embedding → Qdrant upload

**Success Criteria** (what must be TRUE when this phase completes):
1. Triggering an index build from `/index` completes without error and logs a row to `etl_run_log` with `status='success'` and `products_written > 0`
2. Qdrant collection `products` contains exactly 1000 points (verify via Qdrant Web UI at port 6333 or `count()`)
3. A semantic query like `"Lager für hohe Last"` on `/search` returns at least 3 relevant results — products that SQL `LIKE '%Lager für hohe Last%'` would miss
4. The `/search` page renders both the vector search tab and the SQL search tab without errors
5. ETL run log at `/audit` shows the index build entry with duration and product count

**Pitfall Warnings:**
- ⚠️ **Pitfall 6 (collection before upsert):** `ensure_collection()` MUST be called before every `upsert_points()` call — not just once at startup. A fresh container has no collections; calling `upsert()` first returns HTTP 404.
- ⚠️ **Pitfall 7 (numpy tolist):** `SentenceTransformer.encode()` returns `numpy.ndarray`. ALWAYS call `.tolist()` before constructing `PointStruct`. Some `qdrant_client` versions accept ndarray; others fail at JSON serialization with a cryptic error.
- ⚠️ **`wait=True`:** Always pass `wait=True` to `client.upsert()`. Without it, a subsequent `count()` or `search()` may see 0 results even after a successful upsert.
- ⚠️ **No `recreate_collection`:** `QdrantClient.recreate_collection()` was deprecated in v1.1.1 and removed. Use `delete_collection()` + `create_collection()` for full rebuilds (Strategy C).

**Plans:** TBD

---

### Phase 4: Neo4j Graph & RAG (A7)

**Goal:** A Neo4j graph is populated with product, brand, category, and tag nodes and relationships (synchronized from MySQL during index build), and a RAG search query returns an LLM-generated German-language answer enriched with graph context and a visible `graph_source` badge.

**Depends on:** Phase 3 (RAG pipeline starts with `QdrantRepository.search()`; no path to A7 without A6 working)

**Requirements:** GRAPH-01, GRAPH-02, GRAPH-03, GRAPH-04, GRAPH-05, GRAPH-06, GRAPH-07

**Key Tasks:**
1. Implement `Neo4jRepositoryImpl.__init__()` — `GraphDatabase.driver(uri, auth=(user, password))` + `driver.verify_connectivity()` for fast-fail
2. Implement `Neo4jRepositoryImpl.execute_cypher()` — `with self._driver.session(database="neo4j") as session:` + `session.run(query, params)` + fully consume result inside the `with` block via `[dict(r) for r in result]`
3. Implement `Neo4jRepositoryImpl.close()` — `self._driver.close(); self._driver = None`
4. Implement `Neo4jRepositoryImpl.get_product_relationships()` — Cypher `MATCH (p:Product) WHERE p.mysql_id IN $ids OPTIONAL MATCH ...` returning `{mysql_id: {title, brand, category, tags}}` dict; include `related_products` via `MATCH (p)-[:MADE_BY]->(b)<-[:MADE_BY]-(other)` traversal (GRAPH-05)
5. Implement `Neo4jRepositoryImpl.sync_products(products)` — MERGE-based Cypher upsert: `MERGE (p:Product {mysql_id: $id}) ON CREATE SET ... ON MATCH SET ...`; `MERGE (b:Brand {name: $brand_name})`; `MERGE (p)-[:MADE_BY]->(b)`; `MERGE (c:Category ...)`; `MERGE (p)-[:IN_CATEGORY]->(c)`; `UNWIND $tags MERGE (t:Tag) MERGE (p)-[:HAS_TAG]->(t)`
6. Integrate `sync_products()` into `IndexService.build_index()` after the Qdrant upsert step
7. Register Flask `teardown_appcontext` in `app.py` to call `repo.close()` on Neo4j driver shutdown
8. Implement `SearchService.rag_search()` — embed query → Qdrant search → extract `mysql_ids` → `get_product_relationships()` → merge enrichment → build LLM prompt → `openai.chat.completions.create(model="gpt-4.1-mini")` → return `{query, answer, hits}`
9. Implement `SearchService._generate_llm_answer()` — returns `"[LLM nicht konfiguriert]"` gracefully if `OPENAI_API_KEY` absent
10. Implement `routes/rag.py` (GRAPH-07) — RAG search form, answer display, hits table with `graph_source` badge column

**Success Criteria** (what must be TRUE when this phase completes):
1. After an index build, Neo4j Browser (port 7474) shows `Product`, `Brand`, `Category`, and `Tag` nodes with `MADE_BY`, `IN_CATEGORY`, and `HAS_TAG` relationships
2. A RAG query like `"Welches Kugellager eignet sich für Automotive?"` on `/rag` returns an LLM-generated German answer (not a 501 or empty response)
3. The results table on `/rag` shows a `graph_source` badge — at least some hits display `Neo4j` as the source
4. Running index build twice (repeated sync) does NOT create duplicate nodes in Neo4j — `MATCH (p:Product) RETURN count(p)` returns the same count both times
5. Stopping the app (`docker compose stop`) produces no Neo4j connection timeout errors in logs (teardown hook confirmed working)

**Pitfall Warnings:**
- ⚠️ **Pitfall 9 (session not closed):** EVERY Neo4j query method MUST use `with self._driver.session() as session:` — bare `session = driver.session()` leaks sessions; pool exhausts after ~20 requests.
- ⚠️ **Cursor leak:** The `Result` cursor from `session.run()` MUST be consumed (`.fetchall()` or `[dict(r) for r in result]`) INSIDE the `with session:` block. Returning the `Result` object directly causes a cursor leak on session close.
- ⚠️ **Anti-Pattern 4 (CREATE vs MERGE):** Never use `CREATE` in `sync_products()`. Every index build re-runs this — `CREATE` accumulates duplicate nodes that corrupt `get_product_relationships()` results. Use `MERGE` exclusively.
- ⚠️ **Anti-Pattern 3 (driver per request):** `Neo4jRepositoryImpl` is a `RepositoryFactory` singleton — the driver is created ONCE. Never instantiate `Neo4jRepositoryImpl` outside the factory.
- ⚠️ **`sync_products()` not in ABC:** This method is not in the current `Neo4jRepository` ABC. Add it as an `@abstractmethod` (with `NoOpNeo4jRepository` returning `0`) so the factory pattern remains consistent.

**Plans:** TBD

---

### Phase 5: Polish & Dokumentation

**Goal:** A reader (the professor) can compare the three search approaches side-by-side with concrete query examples, understanding when each method wins and why.

**Depends on:** Phases 0–4 (all three search modes must produce real results before the analysis can be written)

**Requirements:** DOC-01

**Key Tasks:**
1. Write `COMPARISON.md` with a 3×3 comparison matrix: 3 representative queries × 3 search methods (SQL LIKE, Qdrant vector, Neo4j+RAG)
2. For each cell: show the actual query / approach, the result (product names + scores/excerpts), and the teaching point — where this method wins or fails
3. Include explanation of HNSW parameters (m=16, ef_construct=128) and why MySQL uses B-Trees (sorted order → range queries, O(log N) height, 16 KB InnoDB pages)
4. Address: what SQL cannot find that vector search can (semantic gap), what vector search cannot guarantee that SQL can (exact match, ordering), what graph enrichment adds (relationship context, `related_products`)

**Success Criteria** (what must be TRUE when this phase completes):
1. `COMPARISON.md` exists and contains a table with ≥3 queries and all 3 search method columns filled with real results (not placeholder text)
2. Each query example cites an actual product name from the seeded catalog (evidence of real execution, not fabricated)
3. The document clearly answers: "for a query like X, which approach should you use and why?"

**Pitfall Warnings:**
- ⚠️ Write this LAST — the comparison is meaningless without real results from all three search modes. Any placeholder output will be obvious to the grader.

**Plans:** TBD

---

## Progress Table

| Phase | Requirements | Plans Complete | Status | Completed |
|-------|-------------|----------------|--------|-----------|
| 0. Foundation & Blockers | 8 (FOUND-01–08) | 0/TBD | Not started | - |
| 1. MySQL CRUD & Transaktionen | 3/3 | Complete   | 2026-04-05 | - |
| 2. MySQL DDL Features | 3/3 | Complete   | 2026-04-13 | - |
| 3. Qdrant Vektor-Suche | 9 (VECT-01–08, ROUTE-04) | 0/TBD | Not started | - |
| 4. Neo4j Graph & RAG | 7 (GRAPH-01–07) | 0/TBD | Not started | - |
| 5. Polish & Dokumentation | 1 (DOC-01) | 0/TBD | Not started | - |

**Total:** 50/50 requirements mapped ✓

---

## Dependency Chain

```
Phase 0 (Foundation)
    ↓ schema plural names, factories, NoOp fix
Phase 1 (MySQL CRUD)
    ↓ read path for load_products_for_index(), update form for trigger test
Phase 2 (MySQL DDL)       Phase 3 (Qdrant)
    ↓ (parallel with 3)        ↓ Qdrant search working
                          Phase 4 (Neo4j + RAG)
                               ↓ all 3 search modes producing real results
                          Phase 5 (Documentation)
```

Phase 2 and Phase 3 have a soft dependency (Phase 2 requires the update form from Phase 1 to test the trigger) but can overlap in practice once Phase 1 is complete.

---

## Key Architecture Constraints

These constraints are embedded in the phase plans and must be respected throughout implementation:

| Constraint | Rule | Why |
|-----------|------|-----|
| SQLAlchemy 2.0 transactions | `with session.begin():` only — never `text("COMMIT")` | Raw SQL COMMIT desynchronizes SQLAlchemy's state machine |
| Qdrant collection init | `ensure_collection()` before every `upsert_points()` | No auto-creation; 404 on fresh container |
| Qdrant vectors | Always `.tolist()` on numpy arrays | JSON serialization fails on ndarray in some client versions |
| Qdrant upsert confirmation | Always `wait=True` | Without it, subsequent `count()`/`search()` returns stale 0 |
| Qdrant recreate | `delete_collection()` + `create_collection()` | `recreate_collection()` removed in client v1.1.1+ |
| Neo4j sessions | Always `with driver.session() as session:` | Sessions not thread-safe; finite pool exhausts |
| Neo4j cursor | Consume `Result` inside `with session:` block | Cursor leak on session close |
| Neo4j sync | `MERGE` not `CREATE` | `CREATE` accumulates duplicates on repeated index builds |
| Embedding model | `threading.Lock` double-checked locking in `ServiceFactory` | Concurrent first requests can race to load the model twice |
| RepositoryFactory | Same `threading.Lock` pattern | dict check-then-set is not atomic without a lock |
| Stored procedure | `cursor.nextset()` after every `CALL` | MySQL returns implicit result set; dirty connection breaks next query |
| Session lifecycle | Always context manager (`with self._session_factory() as session:`) | Without it, connections leak from the pool (pool_size=5 → exhausted in 5 requests) |

---

*Roadmap created: 2026-04-02*
*Requirement coverage: 50/50 v1 requirements ✓*
