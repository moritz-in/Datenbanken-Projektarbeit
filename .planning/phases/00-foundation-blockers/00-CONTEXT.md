# Phase 0: Foundation & Blockers - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix all structural blockers so the app starts cleanly and every route returns a valid response (even if empty). Schema names, missing table DDL, factory singletons, NoOp repair, and PostgreSQL dead-code removal. All subsequent phases depend on this — nothing else can proceed until these pass.

</domain>

<decisions>
## Implementation Decisions

### etl_run_log DDL

Use the ROADMAP column set — it matches the existing `log_etl_run(strategy, products_processed, products_written)` code signature exactly.

DDL columns:
- `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY
- `strategy` VARCHAR(10) NOT NULL — ETL strategy identifier ('A', 'B', 'C')
- `started_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP — when ETL began
- `finished_at` DATETIME NULL — NULL until run completes
- `products_processed` INT NOT NULL DEFAULT 0
- `products_written` INT NOT NULL DEFAULT 0
- `status` ENUM('running', 'success', 'error') NOT NULL DEFAULT 'running'
- `error_msg` VARCHAR(500) NULL — stores exception message on failure

*REQUIREMENTS.md had a different simpler column set (run_at, products_indexed, duration_seconds) — that is superseded by this decision. The code is the ground truth.*

### Schema Loading Workflow

Keep the existing **manual install script** workflow (`install_database.sh`). Do NOT change to mysql-init/ auto-loading.

- `mysql-init/` directory stays empty — Docker Compose mounts it but nothing lives there
- The install workflow is: `docker compose up` → run `install_database.sh` → this loads `schema.sql` then `import.sql` in order
- Phase 0 success criteria must reflect this: validation is confirmed by running `install_database.sh` after containers are up, then hitting `/validate`

The ROADMAP success criterion "docker compose down -v && docker compose up to verify schema applies cleanly" is inaccurate — update to reflect the manual install step.

### Schema Table Names (Confirmed)

All 5 table names in `schema.sql` renamed to plural — this is already decided:
- `brand` → `brands`
- `category` → `categories`
- `tag` → `tags`
- `product` → `products`
- `product_tag` → `product_tags`

Must update ALL references: `CREATE TABLE`, `DROP TABLE IF EXISTS`, `REFERENCES`, `ON DELETE`, `ON UPDATE` clauses.

### RepositoryFactory Implementation

All `get_*()` methods with `threading.Lock` double-checked locking pattern. `_instances` dict keyed by class.

For the three "legacy" factory methods (`get_dashboard_repository`, `get_audit_repository`, `get_product_repository`) — not discussed, defer cleanup to later. Implement minimally (return `MySQLRepositoryImpl` singleton or leave as stub) — the caller pattern and cleanup is a Phase 1+ concern.

### ServiceFactory Implementation

All `get_*()` methods implemented. `_get_embedding_model()` is a true singleton in `_shared_resources` with `threading.Lock` double-checked locking — prevents the 3× memory load (~270 MB RAM) problem.

`_get_llm_client()` returns `None` gracefully when `OPENAI_API_KEY` is absent — never crashes.

### NoOpNeo4jRepository Fix

All three methods return safe empty values instead of raising `NotImplementedError`:
- `get_product_relationships()` → `{}`
- `execute_cypher()` → `[]`
- `close()` → `None` (pass)

### PostgreSQL Dead Code Removal

Remove:
- `pg_session_factory = None` from `db.py`
- `PG_URL` from `config.py`
- `psycopg2-binary==2.9.9` from `requirements.txt`

### OpenCode's Discretion

- Exact `threading.Lock` placement and double-checked locking boilerplate for both factories
- Whether to use `threading.Lock()` as a class-level attribute or a module-level lock
- How legacy repository factory methods (`get_dashboard_repository`, `get_audit_repository`, `get_product_repository`) are handled — can delegate to MySQLRepositoryImpl or be minimal stubs
- `etl_run_log` table placement in `schema.sql` (before `products` table to avoid FK issues)
- `product_change_log` column definitions — REQUIREMENTS.md has a clear spec: id, product_id, changed_at, field_name, old_value, new_value, changed_by

</decisions>

<specifics>
## Specific Ideas

- The ROADMAP success criterion needs updating: "docker compose up → install_database.sh → validate_mysql() passes" — not auto-load on compose up
- etl_run_log columns MUST match the `log_etl_run(strategy, products_processed, products_written)` signature exactly — no renaming the Python method

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets

- `validation.py` → `validate_mysql(engine)`: already built; returns `ValidationReport`. Used by `/validate` route to confirm schema. This IS the Phase 0 acceptance check — once it returns all PASSED, Phase 0 is done.
- `repositories/neo4j_repository.py` → `NoOpNeo4jRepository`: class already exists with the right interface, just needs 3 methods implemented
- `repositories/__init__.py` → `RepositoryFactory._instances = {}`: singleton dict pattern already scaffolded, just needs `get_*()` filled in
- `services/__init__.py` → `ServiceFactory._instances = {}` and `_shared_resources = {}`: both dicts already exist, pattern is set
- `install_database.sh`: existing schema install script — keep as the manual DB setup workflow

### Established Patterns

- Singleton dict: `_instances[ClassName] = instance` — both factories use this exact pattern
- Logger: `log = logging.getLogger(__name__)` at module top — used everywhere
- Config access: `current_app.config.get("KEY")` from within service/repo constructors — not `os.getenv()`
- SQLAlchemy sessions: `with self._session_factory() as session:` — never bare `session = factory()`

### Integration Points

- `db.py` exports `mysql_session_factory` (set in `app.py:create_app()`) — `RepositoryFactory.get_mysql_repository()` reads this via `current_app`
- `config.py` → `Config.NEO4J_URI`, `Config.QDRANT_URL` — read via `current_app.config` in factory methods
- `app.py:create_app()` — this is where `mysql_session_factory` is initialized; factories must be called after this (lazy init is correct approach)
- `schema.sql` loaded via `install_database.sh` (manual) → Docker container's MySQL — NOT auto-loaded on compose up

</code_context>

<deferred>
## Deferred Ideas

- Legacy repository cleanup (DashboardRepositoryImpl, AuditRepositoryImpl, ProductRepositoryImpl as duplicate tech debt) — CONCERNS.md flags this but Phase 0 won't remove them; defer to Phase 1+ review
- validation.py SKU commented-out checks — messy commented code; restore or clean up after Phase 1 adds the sku column and create_product() implementation
- Trigger/stored procedure SQL file strategy (separate triggers.sql vs all-in schema.sql) — Phase 2 concern
- mysql-init/ auto-loading approach — if delivery requirements change and the demo needs zero manual steps, reconsider in Phase 5 polish

</deferred>

---

*Phase: 00-foundation-blockers*
*Context gathered: 2026-04-02*
