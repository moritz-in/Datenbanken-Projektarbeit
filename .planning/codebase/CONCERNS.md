# Codebase Concerns

**Analysis Date:** 2026-04-02

## Tech Debt

**Intentional Skeleton: Entire Business Logic Unimplemented:**
- Issue: This is a teaching scaffold. Every service, repository, and route body raises `NotImplementedError("TODO: ...")`. The app cannot serve any page or API call in its current state.
- Files: `routes/dashboard.py`, `routes/products.py`, `routes/search.py`, `routes/rag.py`, `routes/audit.py`, `routes/validate.py`, `routes/index.py`, `routes/pdf.py` (all route handlers), `services/product_service.py`, `services/search_service.py`, `services/index_service.py`, `services/pdf_service.py`, `services/__init__.py`, `repositories/mysql_repository.py`, `repositories/qdrant_repository.py`, `repositories/neo4j_repository.py`, `repositories/dashboard_repository.py`, `repositories/audit_repository.py`, `repositories/product_repository.py`, `repositories/__init__.py`
- Impact: 100% of application functionality is blocked. The only working code is the Flask application factory, logging setup, and validation schema. The app starts but returns 501 for every route.
- Fix approach: Implement each stub following the documented interface signatures. Start with `RepositoryFactory` singletons in `repositories/__init__.py`, then service factories in `services/__init__.py`, then route handlers.

**Duplicate Legacy Repository Layer:**
- Issue: Two parallel repository abstractions exist side-by-side. `DashboardRepositoryImpl` (`repositories/dashboard_repository.py`) and `AuditRepositoryImpl` (`repositories/audit_repository.py`) and `ProductRepositoryImpl` (`repositories/product_repository.py`) duplicate responsibility already covered by `MySQLRepositoryImpl`. The `RepositoryFactory` comments these as "legacy".
- Files: `repositories/dashboard_repository.py`, `repositories/audit_repository.py`, `repositories/product_repository.py`, `repositories/__init__.py` (lines 80–108)
- Impact: Confusion about which repository to implement and call. Double the implementation surface.
- Fix approach: Remove the legacy thin repositories and rely solely on `MySQLRepositoryImpl`. Update `RepositoryFactory.get_dashboard_repository()` and `get_audit_repository()` to delegate to the MySQL repo.

**`NoOpNeo4jRepository` Is Broken By Design:**
- Issue: `NoOpNeo4jRepository` is documented as a no-op fallback for when Neo4j is unconfigured, but all three methods raise `NotImplementedError` instead of returning empty results.
- Files: `repositories/neo4j_repository.py` (lines 36–43)
- Impact: Any code path that selects `NoOpNeo4jRepository` (intended for graceful degradation) will crash with a 501 instead of silently continuing.
- Fix approach: Implement the three methods to return empty/safe values: `get_product_relationships` → `{}`, `execute_cypher` → `[]`, `close` → `None`.

**Dead PostgreSQL Integration:**
- Issue: `db.py` declares `pg_session_factory = None` and `config.py` reads `PG_URL`, but nothing in the codebase ever initializes or uses the PostgreSQL session factory. `psycopg2-binary` is a dependency in `requirements.txt` with no usage.
- Files: `db.py` (line 10), `config.py` (line 33), `requirements.txt` (line 4)
- Impact: Unnecessary dependency bloat; `psycopg2-binary` requires C compilation and adds ~10 MB to the image. Developers may be confused about whether PostgreSQL is intended.
- Fix approach: Remove `pg_session_factory` from `db.py`, `PG_URL` from `config.py`, and `psycopg2-binary` from `requirements.txt` unless PostgreSQL is a planned requirement.

**Commented-Out Validation Checks:**
- Issue: Two validation checks in `validation.py` are commented out with inconsistent indentation: SKU empty string check (lines 82–92) and SKU duplicate check (lines 94–110). The commenting style uses mixed `##`, `###`, and `#` prefixes suggesting incremental manual commenting.
- Files: `validation.py` (lines 82–110)
- Impact: SKU uniqueness and empty-string SKU are not validated despite a comment saying "shouldn't happen". Schema integrity gap.
- Fix approach: Either restore and fix the commented-out checks or delete them. If intentional, replace with a clear `# Not applicable: SKU not present in current schema` comment.

**`etl_run_log` Table Defined Only in IDE Query File:**
- Issue: `MySQLRepositoryImpl.log_etl_run()` and `get_audit_entries()` both reference a table `etl_run_log`, but its DDL only exists in `.idea/queries/etl_run_log.sql` — a JetBrains IDE scratch file, not part of `schema.sql` or `import.sql`.
- Files: `.idea/queries/etl_run_log.sql`, `repositories/mysql_repository.py` (lines 94, 175), `schema.sql`
- Impact: Running the app against a fresh database created from `schema.sql` will produce `Table 'etl_run_log' doesn't exist` errors at runtime.
- Fix approach: Add `etl_run_log` DDL to `schema.sql` before the products table, or to a separate migration file.

**Schema Table Name Mismatch Between DDL and Application Code:**
- Issue: `schema.sql` creates singular table names (`brand`, `category`, `tag`, `product`, `product_tag`) while `validation.py` and application code expect plural names (`brands`, `categories`, `tags`, `products`, `product_tags`).
- Files: `schema.sql` (lines 45, 63, 80, 104, 155), `validation.py` (line 37), `repositories/mysql_repository.py` (docstrings)
- Impact: Validation will always report `MYSQL_TABLES_MISSING` error for all 5 expected tables when run against a database built from `schema.sql`. Raw SQL queries in stubs will fail with table-not-found errors.
- Fix approach: Align names — either rename tables in `schema.sql` to plural, or update `validation.py` and all repository queries to use singular names consistently.

**`src/sql/foo.sql` Is a Placeholder:**
- Issue: The only SQL file in `src/sql/` is `foo.sql` — a trivial `SELECT id, name, price FROM products WHERE category = 'tools'` stub. The test harness in `tests/run_tests.sh` runs all `src/sql/*.sql` files against a seeded DB and compares to `tests/expected/`.
- Files: `src/sql/foo.sql`, `tests/expected/foo.csv`, `tests/run_tests.sh`
- Impact: The test suite has only 1 stub test. Real student SQL tasks are not present. Test infrastructure exists but is not exercised.
- Fix approach: Add real SQL task files to `src/sql/` and their corresponding expected output CSVs to `tests/expected/`.

---

## Security Considerations

**Hardcoded Default Secrets in `docker-compose.yml`:**
- Risk: `docker-compose.yml` uses fallback defaults: `FLASK_SECRET_KEY: ${FLASK_SECRET_KEY:-dev-secret}`, `NEO4J_AUTH: ${NEO4J_AUTH:-neo4j/admin123}`, `NEO4J_PASSWORD: ${NEO4J_PASSWORD:-admin123}`. If `.env` is missing or vars are unset, Docker Compose silently applies these weak defaults.
- Files: `docker-compose.yml` (lines 65, 85, 96), `config.py` (line 26)
- Current mitigation: `config.py` has `SECRET_KEY = os.getenv("FLASK_SECRET_KEY", "dev-secret")` which means the dev secret is the fallback at both config and compose level.
- Recommendations: Remove `:-dev-secret` and `:-admin123` fallbacks from `docker-compose.yml`. Require explicit env var injection. Add `Config.validate()` call at startup to fail fast if secrets are absent.

**SQL Injection Risk via f-string in `validation.py`:**
- Risk: Table names from an internal hardcoded list are interpolated directly into SQL queries using f-strings: `text(f"SELECT COUNT(*) FROM {t}")` and `text(f"SELECT COUNT(*) FROM {table} WHERE ...")`. While the list is currently hardcoded (not user-supplied), this pattern is fragile.
- Files: `validation.py` (lines 54, 60–64)
- Current mitigation: The table names come from an internal Python list `["brands", "categories", "tags"]` — not user input. Risk is low in current form.
- Recommendations: Replace with hardcoded queries or use a safe identifier quoting approach. Do not extend this pattern to user-supplied input.

**`execute_raw_query` / `execute_sql_query` — Security by TODO:**
- Risk: Both `MySQLRepositoryImpl.execute_raw_query()` and `ProductService.execute_sql_query()` are designed to execute user-supplied SQL. Their security documentation says "Only SELECT queries are allowed. Forbidden keywords are blocked." But the actual validation logic (`_strip_string_literals`, `_extract_table_names`) is unimplemented — all three static methods raise `NotImplementedError`.
- Files: `repositories/mysql_repository.py` (lines 133, 137, 141), `services/product_service.py` (line 96)
- Current mitigation: None — the methods raise `NotImplementedError` so no SQL reaches the DB currently.
- Recommendations: When implementing, use a strict allowlist approach: parse with `sqlglot` or similar, reject anything that is not a `SELECT` at the AST level, not just string matching. The `_strip_string_literals` stub hints at this complexity.

**No CSRF Protection:**
- Risk: Flask forms (RAG search, PDF upload, index build) have no CSRF token protection. No `flask-wtf` or `flask-seasurf` integration is present.
- Files: `routes/rag.py`, `routes/pdf.py`, `routes/index.py`
- Current mitigation: All mutating routes are currently `NotImplementedError` stubs.
- Recommendations: Add `flask-wtf` with CSRF enabled before implementing POST routes.

**No Rate Limiting:**
- Risk: The RAG and search routes trigger expensive LLM API calls (OpenAI) and embedding model inference. No rate limiting or request throttling exists.
- Files: `routes/rag.py`, `routes/search.py`
- Current mitigation: Routes raise `NotImplementedError`.
- Recommendations: Add `flask-limiter` before deploying search/RAG endpoints.

---

## Performance Bottlenecks

**Embedding Model Loaded Lazily Per Service (Not Shared at Startup):**
- Problem: `SearchService`, `IndexService`, and `PDFService` each have their own `_get_embedding_model()` stub designed to lazy-load a `SentenceTransformer`. Even with the `ServiceFactory._get_embedding_model()` shared-resource approach, if implemented naively each service could load its own model copy.
- Files: `services/search_service.py` (line 42), `services/index_service.py` (line 40), `services/pdf_service.py` (line 39), `services/__init__.py` (lines 41–48)
- Cause: `sentence-transformers/all-MiniLM-L6-v2` requires ~90 MB of RAM and 1–3 seconds to load. Loading it three times would triple memory usage.
- Improvement path: Implement `ServiceFactory._get_embedding_model()` as a true shared singleton stored in `_shared_resources`. Pass the single instance to all three services.

**No Database Connection Pool Tuning:**
- Problem: `db.make_session()` uses SQLAlchemy defaults (`pool_size=5`, `max_overflow=10`). For a multi-threaded Flask app with ML inference, this may cause connection exhaustion under load.
- Files: `db.py` (line 5)
- Cause: No explicit `pool_size`, `max_overflow`, or `pool_timeout` parameters.
- Improvement path: Tune pool parameters based on expected concurrency once the app is functional.

**No Result Caching for Embedding or LLM Responses:**
- Problem: Identical search queries will hit the embedding model and LLM every time. No caching layer (Redis, in-memory LRU) exists.
- Files: `services/search_service.py`
- Cause: Not implemented.
- Improvement path: Add `functools.lru_cache` for embedding results or `flask-caching` with Redis for LLM responses.

---

## Fragile Areas

**`RepositoryFactory._instances` Is a Class-Level Mutable Dict:**
- Files: `repositories/__init__.py` (line 30)
- Why fragile: Singleton state stored on the class is shared across all tests and requests. `RepositoryFactory.reset()` (also unimplemented) is the only way to clear it. In a threaded Flask app, concurrent initialization could cause race conditions.
- Safe modification: Implement `reset()` first. Add thread locks (`threading.Lock`) around instance creation in `get_*` methods before implementing production logic.
- Test coverage: Zero — no pytest test files exist.

**`DailyFileHandler` Is Not Thread-Safe:**
- Files: `app.py` (lines 32–74)
- Why fragile: The `_rotate_if_needed` method closes and reopens the underlying file handle. In a multi-threaded Flask/Gunicorn deployment with multiple worker threads hitting the rotation boundary simultaneously, this could result in lost log records or file handle corruption.
- Safe modification: Add a `threading.Lock` around the rotation and emit logic.

**Validation References Non-Existent Tables:**
- Files: `validation.py` (line 37), `schema.sql`
- Why fragile: `validate_mysql()` will always fail with `MYSQL_TABLES_MISSING` on a clean DB from `schema.sql` because the table names are mismatched (see Tech Debt section above). This means the validation feature is broken out of the box.
- Safe modification: Fix the table name mismatch before relying on `validate_mysql()` for any correctness signal.

**`Dockerfile` Runs pytest in Build Stage with No Tests:**
- Files: `Dockerfile` (lines 14–17)
- Why fragile: The `test` build stage runs `pytest -q` but there are no Python pytest test files (only `tests/run_tests.sh` for SQL testing). The build will pass trivially since pytest finds no tests, providing no build-time quality gate.
- Safe modification: Either add Python unit tests or remove the `test` stage from the Dockerfile to avoid false confidence.

---

## Test Coverage Gaps

**No Python Unit or Integration Tests:**
- What's not tested: All service logic, all repository logic, all route handlers, all utility functions, config loading, and the `DailyFileHandler`.
- Files: `services/`, `repositories/`, `routes/`, `utils.py`, `validation.py`
- Risk: Any implementation of the `NotImplementedError` stubs could ship with silent regressions.
- Priority: High — implement at minimum service-layer unit tests using pytest-mock before implementing routes.

**SQL Test Suite Has Only One Placeholder Query:**
- What's not tested: Actual student SQL tasks (JOINs, aggregations, subqueries against the product schema).
- Files: `src/sql/foo.sql`, `tests/expected/foo.csv`
- Risk: The test harness (`tests/run_tests.sh`) works correctly but is exercised against a trivial stub, providing no meaningful coverage of the database schema.
- Priority: Medium — add real task SQL files and expected output CSVs as student exercises are assigned.

**`validate_mysql()` Cannot Self-Test:**
- What's not tested: The validation function itself has no tests. The commented-out SKU checks mean two validation paths are permanently disabled with no test to document the expected behavior.
- Files: `validation.py`
- Risk: Validation could produce false positives or miss real schema errors silently.
- Priority: Medium.

---

## Missing Critical Features

**`ServiceFactory` and `RepositoryFactory` Both Unimplemented:**
- Problem: The dependency injection factories that wire the entire application together are all stubs. Without these, no route can reach any service or database.
- Blocks: Everything. The app cannot function until `RepositoryFactory.get_mysql_repository()`, `get_qdrant_repository()`, and `get_neo4j_repository()` are implemented, followed by `ServiceFactory.get_search_service()`, `get_index_service()`, `get_pdf_service()`, and `get_product_service()`.

**`etl_run_log` Missing from Official Schema:**
- Problem: The ETL audit trail table is required by `MySQLRepositoryImpl.log_etl_run()` and `get_audit_entries()` but absent from `schema.sql`.
- Blocks: `routes/audit.py` (audit view), `services/product_service.py` (`get_audit_log`), any indexing operation that logs a run.

---

*Concerns audit: 2026-04-02*
