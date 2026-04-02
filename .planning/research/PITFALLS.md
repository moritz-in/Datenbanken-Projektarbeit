# Pitfalls Research

**Domain:** Flask + SQLAlchemy 2.0 + MySQL 8.4 + Qdrant + Neo4j RAG application
**Researched:** 2026-04-02
**Confidence:** HIGH (SQLAlchemy, Neo4j — official docs verified; Qdrant — official docs verified; sentence-transformers threading — HIGH from known Python GIL + model-loading behavior)

---

## Critical Pitfalls

### Pitfall 1: Schema Table Name Mismatch Crashes Validation and All Queries at Startup

**What goes wrong:**
`schema.sql` creates singular table names (`brand`, `category`, `tag`, `product`, `product_tag`). Every raw SQL query in `MySQLRepositoryImpl` will reference plural names (`brands`, `categories`, `tags`, `products`, `product_tags`) because `validation.py` line 37 and all repository query strings use plural. Running `docker compose up` with a fresh database produces `Table 'projectdb.products' doesn't exist` on literally every repository call, and `validate_mysql()` always reports `MYSQL_TABLES_MISSING` for all 5 tables.

**Why it happens:**
The scaffold was authored using plural names in Python but the DDL used singular. The mismatch is invisible until the first actual SQL executes. The app starts cleanly (Flask boot does not query the DB), giving a false sense of readiness.

**How to avoid:**
Rename all 5 tables in `schema.sql` before implementing any repository method. This is a one-time surgical fix, not an option to defer:

```sql
-- In schema.sql: rename every CREATE TABLE to plural
CREATE TABLE brands   (...)   -- was: brand
CREATE TABLE categories (...)  -- was: category
CREATE TABLE tags     (...)   -- was: tag
CREATE TABLE products (...)   -- was: product
CREATE TABLE product_tags (...) -- was: product_tag
```

Also update all `DROP TABLE IF EXISTS` lines, all `FOREIGN KEY REFERENCES`, and all `ON DELETE`/`ON UPDATE` references. The `schema.sql` already drops plural names in its clean-up block (lines 20–31), so those DROP statements are ahead of the fix.

**Warning signs:**
- `validate_mysql()` returns `MYSQL_TABLES_MISSING` on a fresh database
- Any repository method raises `sqlalchemy.exc.OperationalError: Table '...' doesn't exist`
- Dashboard loads but shows zeros or crashes immediately

**Phase to address:** Phase 0 (Blockers) — must be fixed before A2 implementation begins. Nothing else can be tested without this.

---

### Pitfall 2: `etl_run_log` Table Missing from `schema.sql` Crashes Index Build and Audit Route

**What goes wrong:**
`MySQLRepositoryImpl.log_etl_run()` and `get_audit_entries()` both `INSERT INTO etl_run_log` and `SELECT FROM etl_run_log`. The table DDL exists only in `.idea/queries/etl_run_log.sql` — a JetBrains scratch file that Docker Compose never runs. On a fresh database built from `schema.sql`, any indexing operation fails with `Table 'projectdb.etl_run_log' doesn't exist`, silently breaking the entire A6 ETL flow and the audit route.

**Why it happens:**
The IDE query file was used during development as a throwaway scratchpad. It was never promoted to `schema.sql`. The omission is invisible at startup.

**How to avoid:**
Add the DDL to `schema.sql` before the `products` table (foreign key order). Based on the IDE file, the minimal schema is:

```sql
CREATE TABLE etl_run_log (
    id           INT NOT NULL AUTO_INCREMENT,
    strategy     VARCHAR(10)  NOT NULL,
    started_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at  DATETIME     NULL,
    products_processed INT    NOT NULL DEFAULT 0,
    products_written   INT    NOT NULL DEFAULT 0,
    status       VARCHAR(20)  NOT NULL DEFAULT 'running',
    error_msg    TEXT         NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Warning signs:**
- `routes/audit.py` renders empty page or 500 error
- Any call to `index.py` (index-build form) fails mid-way with a DB error
- Dashboard "last runs" widget is empty even after a successful upsert

**Phase to address:** Phase 0 (Blockers) — must be in `schema.sql` before A6 (IndexService) implementation.

---

### Pitfall 3: SQLAlchemy 2.0 Session Not Closed After Raw `text()` Queries — Connection Pool Exhaustion

**What goes wrong:**
`db.make_session()` returns a `sessionmaker`. Every call to `_get_session()()` (calling the factory) produces a new `Session` object. If a session is opened inside a repository method without a `with` block or explicit `session.close()`, the DBAPI connection is never returned to the pool. With a `pool_size=5` (SQLAlchemy default) and a multi-threaded Flask dev server, 5 concurrent requests that each open but don't close a session will exhaust the pool — all subsequent requests hang indefinitely waiting for a connection.

**Why it happens:**
SQLAlchemy 2.0 uses "autobegin": a transaction starts implicitly on the first `session.execute()`. The session holds a DBAPI connection from that point until `session.close()`, `session.commit()`, or `session.rollback()` is called. Developers forget that `session.execute()` alone is not enough — the connection is only released on close/commit/rollback.

**How to avoid:**
Always use the session as a context manager. The canonical pattern for every repository method:

```python
def get_products_with_joins(self, page: int, page_size: int) -> dict:
    with self._session_factory() as session:          # auto-closes on exit
        with session.begin():                          # auto-commits on exit, rolls back on exception
            result = session.execute(text("""
                SELECT p.*, b.name as brand_name, c.name as category_name
                FROM products p
                JOIN brands b ON p.brand_id = b.id
                JOIN categories c ON p.category_id = c.id
                LIMIT :limit OFFSET :offset
            """), {"limit": page_size, "offset": (page - 1) * page_size})
            return [dict(r._mapping) for r in result.fetchall()]
    # connection automatically returned to pool here
```

For write operations that need explicit rollback on error:
```python
def create_product(self, data: dict) -> int:
    with self._session_factory() as session:
        try:
            with session.begin():
                session.execute(text("INSERT INTO products ..."), data)
                # session.begin() context auto-commits here
        except Exception as e:
            # session.begin() already rolled back
            log.error("create_product failed: %s", e)
            raise
```

**Warning signs:**
- App becomes unresponsive after ~5 requests
- SQLAlchemy logs show `TimeoutError: QueuePool limit of size 5 overflow 10 reached`
- `docker stats` shows memory growing unbounded for the `app` container

**Phase to address:** A2 (Transactions) — establish the session context manager pattern in `MySQLRepositoryImpl.__init__` and `_get_session()` before implementing any other method.

---

### Pitfall 4: SQLAlchemy 2.0 `session.commit()` Inside a Nested `session.begin()` Block Commits the Outer Transaction

**What goes wrong:**
In SQLAlchemy 2.0, calling `session.commit()` **always commits the outermost transaction**, not the nearest `begin()` block. Code like this silently commits everything even if the intent was to commit a savepoint:

```python
# WRONG — commits outermost transaction, not the savepoint
with session.begin():
    session.execute(text("INSERT INTO products ..."), data)
    savepoint = session.begin_nested()
    session.execute(text("INSERT INTO product_tags ..."), tag_data)
    session.commit()  # BUG: commits the outer transaction, not the savepoint!
```

This is a **breaking behavior change from SQLAlchemy 1.x** where `commit()` committed the nearest transaction. Under 1.x, the inner `commit()` would only commit the savepoint.

**Why it happens:**
The scaffold is already on SQLAlchemy 2.0 (`future=True` in `db.make_session()`). Any code copied from SQLAlchemy 1.x tutorials or Stack Overflow answers from before 2022 will use the old pattern. The project requirement for "explicit `START TRANSACTION / COMMIT / ROLLBACK`" may lead students to write raw `text("COMMIT")` which also bypasses the ORM's transaction tracking entirely (see Pitfall 5).

**How to avoid:**
Use `with session.begin()` as the outer context manager (it auto-commits on exit, auto-rolls-back on exception). Use `with session.begin_nested()` for savepoints. **Never call `session.commit()` explicitly inside a `with session.begin()` block.**

```python
# CORRECT — rollback sku_insert if product_tags insert fails
with session.begin():                        # outer tx
    session.execute(text("INSERT INTO products ..."), data)
    try:
        with session.begin_nested():         # SAVEPOINT
            session.execute(text("INSERT INTO product_tags ..."), tag_data)
        # RELEASE SAVEPOINT here
    except Exception:
        pass  # ROLLBACK TO SAVEPOINT here; outer tx still live
# COMMIT outer tx here
```

**Warning signs:**
- Partial inserts committed when a later step fails
- Tests show data persisting in DB even when an exception was raised mid-way
- `OperationalError: Can't do a commit in the middle of a transaction`

**Phase to address:** A2 (Transactions) — review every `session.commit()` call for correctness before implementation.

---

### Pitfall 5: Using Raw `text("COMMIT")` / `text("ROLLBACK")` Bypasses SQLAlchemy's Connection State Tracking

**What goes wrong:**
The A2 task description says "explicit `START TRANSACTION / COMMIT / ROLLBACK`". If implemented literally as:

```python
session.execute(text("START TRANSACTION"))
session.execute(text("INSERT INTO products ..."), data)
session.execute(text("COMMIT"))
```

...SQLAlchemy's internal transaction state machine gets out of sync. The session still believes it is in a transaction and will attempt to emit a `ROLLBACK` when the session closes (on pool return). Under MySQL 8, issuing `ROLLBACK` on a connection that already committed is a no-op — but the connection pool's "reset on return" rollback means the pool emits a second `ROLLBACK` on a fresh (already clean) connection, which is harmless but confusing in logs. More dangerously, if the session is reused (singleton pattern), subsequent operations may execute outside any transaction context.

**Why it happens:**
The course requirement says "demonstrate explicit transactions". Students interpret this as raw SQL strings. The SQLAlchemy-correct way to satisfy the requirement is to use `session.begin()` which translates to a real `START TRANSACTION` at the DBAPI level.

**How to avoid:**
Demonstrate transactions via SQLAlchemy's API — the `BEGIN`/`COMMIT`/`ROLLBACK` still happen at the DB level, they just go through the driver:

```python
# SQLAlchemy 2.0 — explicit transaction that satisfies A2 requirement
with self._session_factory() as session:
    with session.begin():                    # → START TRANSACTION in MySQL
        session.execute(text("INSERT INTO products ..."), data)
        session.execute(text("INSERT INTO product_tags ..."), tag_data)
    # → COMMIT (or ROLLBACK if exception)
```

To **demonstrate** the transaction for grading purposes, enable SQL logging via `echo=True` on the engine or log at `DEBUG` level — the actual `BEGIN`/`COMMIT`/`ROLLBACK` statements will appear in logs.

**Warning signs:**
- MySQL general log shows `ROLLBACK` immediately after a `COMMIT`
- `session.in_transaction()` returns `True` after a `text("COMMIT")` executed
- Subsequent queries on the same session fail or use stale connection state

**Phase to address:** A2 (Transactions) — establish the correct abstraction before implementing CRUD methods.

---

### Pitfall 6: Qdrant `upsert_points()` Raises `UnexpectedResponse` (404) When Collection Doesn't Exist

**What goes wrong:**
Calling `client.upsert()` on a Qdrant collection name that has not been created first raises `qdrant_client.http.exceptions.UnexpectedResponse: Unexpected Response: 404` (or similar). There is no auto-creation. The `IndexService` will call `upsert_points()` before `ensure_collection()` if the startup order is wrong, crashing the entire index build.

**Why it happens:**
Qdrant is not like a relational DB where `INSERT INTO missing_table` gives a clear error upfront during query planning. The Qdrant Python client's `upsert()` sends an HTTP PUT to `/collections/{name}/points` — the server returns 404 if the collection doesn't exist, which surfaces as an exception only at runtime when `upsert()` is called.

**How to avoid:**
`ensure_collection()` must **always** be called before `upsert_points()`. The safest pattern is to call it idempotently at the start of every `upsert_points()` call (or in the `IndexService` before the upsert loop):

```python
def ensure_collection(self, collection_name: str, vector_size: int, distance: str = "COSINE", ...) -> None:
    """Create if not exists — idempotent."""
    if not self._client.collection_exists(collection_name=collection_name):
        self._client.create_collection(
            collection_name=collection_name,
            vectors_config=VectorParams(
                size=vector_size,
                distance=Distance[distance],
                hnsw_config=HnswConfigDiff(m=hnsw_m, ef_construct=hnsw_ef_construct),
            ),
        )
        log.info("Created Qdrant collection: %s (dim=%d)", collection_name, vector_size)
    else:
        log.debug("Qdrant collection already exists: %s", collection_name)
```

`collection_exists()` is available from `qdrant_client` v1.8.0 onwards (confirmed in official Qdrant docs). The project uses Qdrant v1.16.2, so this API is available.

**Warning signs:**
- `IndexService.build_index()` raises `UnexpectedResponse: 404`
- Qdrant Web UI (port 6333) shows no collections after running index build
- `count()` on the collection raises a 404 before any upsert

**Phase to address:** A6 (Vektor-DB) — `ensure_collection()` must be implemented and called first in `QdrantRepositoryImpl.__init__` or at the start of `IndexService.build_index()`.

---

### Pitfall 7: Qdrant `upsert_points()` With Wrong Vector Dimension Fails Silently or Raises Cryptic Error

**What goes wrong:**
The collection is created with `vector_size=384` (all-MiniLM-L6-v2 output). If the embedding model is loaded incorrectly (e.g. wrong model name, wrong normalization) and produces vectors of a different dimension (e.g. 768 for `all-mpnet-base-v2`), the upsert raises `BadRequestError: wrong input: Vector inserting error: expected dim: 384, got 768`. More subtly, if `numpy` arrays aren't converted to plain Python `list[float]` before being passed to `PointStruct`, some versions of `qdrant_client` accept `ndarray` but others raise a serialization error.

**Why it happens:**
`SentenceTransformer.encode()` returns a `numpy.ndarray`. The `PointStruct` vector field expects `list[float]`. The mismatch is not type-checked by Python — it fails at JSON serialization time in the HTTP client.

**How to avoid:**
Always convert embeddings explicitly:

```python
def upsert_points(self, collection_name: str, points: list[dict]) -> None:
    qdrant_points = [
        PointStruct(
            id=p["id"],
            vector=p["vector"].tolist() if hasattr(p["vector"], "tolist") else list(p["vector"]),
            payload=p.get("payload", {}),
        )
        for p in points
    ]
    self._client.upsert(collection_name=collection_name, points=qdrant_points, wait=True)
```

Use `wait=True` so that the upsert is confirmed before returning — without it, a subsequent `count()` or `search()` may return stale results.

**Warning signs:**
- `upsert_points()` raises `BadRequestError: wrong input: Vector inserting error: expected dim: 384, got N`
- `count()` returns 0 immediately after a seemingly successful `upsert_points()`
- Search returns no results even though the index appears to have points

**Phase to address:** A6 (Vektor-DB) — enforce `.tolist()` conversion in `upsert_points()` implementation.

---

### Pitfall 8: Neo4j Driver Created Once as Singleton But `driver.close()` Never Called — Resource Leak

**What goes wrong:**
`GraphDatabase.driver(uri, auth=...)` opens a connection pool. If the driver is stored as a singleton in `RepositoryFactory._instances` but `close()` is never called (because `NoOpNeo4jRepository.close()` raises `NotImplementedError`), the bolt connection pool leaks. Under Docker, this is benign for a single-run demo, but repeated container restarts or hot-reload in development can exhaust Neo4j's default connection limit (100 connections per database).

**Why it happens:**
The current `NoOpNeo4jRepository.close()` raises `NotImplementedError` instead of `pass`. The factory creates an instance but has no teardown hook. Flask's application factory pattern has no built-in DB teardown for non-SQL backends.

**How to avoid:**
Fix `NoOpNeo4jRepository` immediately (this is a documented blocker):

```python
class NoOpNeo4jRepository(Neo4jRepository):
    def get_product_relationships(self, mysql_ids: list[int]) -> dict[int, dict]:
        return {}

    def execute_cypher(self, query: str, parameters=None) -> list:
        return []

    def close(self) -> None:
        pass  # no connection to close
```

For `Neo4jRepositoryImpl`, register a teardown with Flask:

```python
# In app.py create_app():
@app.teardown_appcontext
def close_neo4j(exception=None):
    repo = RepositoryFactory._instances.get("neo4j")
    if repo is not None:
        repo.close()
```

And in `Neo4jRepositoryImpl`:
```python
def __init__(self, uri: str, user: str, password: str):
    self._driver = GraphDatabase.driver(uri, auth=(user, password))
    self._driver.verify_connectivity()  # fail fast on bad credentials

def close(self) -> None:
    if self._driver:
        self._driver.close()
        self._driver = None
```

**Warning signs:**
- Neo4j logs show `WARNING: Connection pool is full` or connection timeout errors
- `docker logs neo4j` shows `Thread X: [...]` warnings about unclosed connections
- Any call to `NoOpNeo4jRepository.close()` raises 501 instead of doing nothing

**Phase to address:** Phase 0 (Blockers) for `NoOpNeo4jRepository`; A7 (Graph-DB) for `Neo4jRepositoryImpl`.

---

### Pitfall 9: Neo4j Session Not Closed Inside `execute_cypher()` — Result Cursor Leak

**What goes wrong:**
The Neo4j Python driver manual is explicit: **sessions are not thread safe** and have a **finite pool**. If `execute_cypher()` opens a session with `driver.session()` but doesn't use a `with` block, and an exception is raised mid-query, the session is never closed. Over time, the session pool is exhausted and new requests hang waiting for a session.

**Why it happens:**
The `Result` object returned by `tx.run()` is a lazy cursor. If the result is not fully consumed or the session isn't closed, the server-side cursor also stays open, holding memory on the Neo4j server side.

**How to avoid:**
Always use context managers for both session and transaction:

```python
def execute_cypher(self, query: str, parameters: dict = None) -> list:
    with self._driver.session(database="neo4j") as session:
        result = session.run(query, parameters or {})
        return [dict(record) for record in result]  # consume fully before session closes
    # session.close() called automatically here
```

For `get_product_relationships()` which runs a read query:
```python
def get_product_relationships(self, mysql_ids: list[int]) -> dict[int, dict]:
    with self._driver.session(database="neo4j") as session:
        result = session.run(
            "MATCH (p:Product) WHERE p.mysql_id IN $ids "
            "OPTIONAL MATCH (p)-[:BELONGS_TO]->(c:Category) "
            "OPTIONAL MATCH (p)-[:MADE_BY]->(b:Brand) "
            "OPTIONAL MATCH (p)-[:TAGGED_WITH]->(t:Tag) "
            "RETURN p.mysql_id AS id, p.name AS title, "
            "       b.name AS brand, c.name AS category, "
            "       collect(t.name) AS tags",
            {"ids": mysql_ids},
        )
        return {r["id"]: dict(r) for r in result}
```

**Warning signs:**
- RAG queries work for first few requests then hang indefinitely
- Neo4j Browser shows many open transactions in "Current Transactions" view
- `driver.verify_connectivity()` times out after heavy usage

**Phase to address:** A7 (Graph-DB) — establish context manager pattern in `Neo4jRepositoryImpl` before implementing any query methods.

---

### Pitfall 10: `SentenceTransformer` Loaded Multiple Times — 270 MB RAM Overhead and 3–9 Second Startup Penalty

**What goes wrong:**
`SearchService`, `IndexService`, and `PDFService` each call `_get_embedding_model()`. If the `ServiceFactory._shared_resources` singleton is not implemented correctly and each service instantiates its own `SentenceTransformer("all-MiniLM-L6-v2")`, the model is loaded 3× — consuming ~270 MB RAM instead of ~90 MB, and adding 3–9 seconds to the first request across all three services. Under Docker's default memory limits, this can cause the app container to be OOM-killed.

**Why it happens:**
`SentenceTransformer.__init__()` unconditionally loads model weights from disk/cache. There is no internal caching by model name. If three service instances each call `SentenceTransformer(model_name)`, three full model loads happen.

**How to avoid:**
Implement `ServiceFactory._get_embedding_model()` as a true singleton stored in `_shared_resources`:

```python
@classmethod
def _get_embedding_model(cls) -> SentenceTransformer:
    if "embedding_model" not in cls._shared_resources:
        model_name = current_app.config.get("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
        log.info("Loading embedding model: %s", model_name)
        cls._shared_resources["embedding_model"] = SentenceTransformer(model_name)
        log.info("Embedding model loaded.")
    return cls._shared_resources["embedding_model"]
```

Then pass the **same instance** to all three services at construction time:

```python
@classmethod
def get_search_service(cls) -> SearchService:
    if "search" not in cls._instances:
        model = cls._get_embedding_model()   # shared instance
        cls._instances["search"] = SearchService(
            mysql_repo=RepositoryFactory.get_mysql_repository(),
            qdrant_repo=RepositoryFactory.get_qdrant_repository(),
            embedding_model=model,
        )
    return cls._instances["search"]
```

**Warning signs:**
- Docker container memory usage exceeds 500 MB during first search request
- First request to `/search` or `/index` takes 5–15 seconds
- `docker stats` shows container memory spiking 3× then staying elevated

**Phase to address:** Phase 0 (Blockers) — implement in `ServiceFactory._get_embedding_model()` before any service that uses embeddings is implemented.

---

### Pitfall 11: `SentenceTransformer.encode()` Is Not Thread-Safe Under Flask's Default Threaded Server

**What goes wrong:**
Flask's dev server uses threads (`threaded=True` by default). `SentenceTransformer.encode()` with PyTorch backend acquires the GIL for the forward pass — this prevents actual CPU parallelism but does not prevent concurrent calls from corrupting internal model state. However, if `encode()` is called concurrently with model initialization still in progress (race condition during lazy loading), a `RuntimeError: CUDA device-side assertion triggered` (GPU) or silent wrong-dimension output (CPU) can occur.

More practically: if the singleton is initialized lazily on first request and two requests arrive simultaneously before initialization completes, both will attempt to call `SentenceTransformer(model_name)` concurrently, loading the model twice and racing to store it in `_shared_resources`.

**Why it happens:**
`ServiceFactory._shared_resources` is a plain `dict`. Without a lock around the "check and set" operation, two threads can both see `"embedding_model" not in cls._shared_resources` as `True` simultaneously.

**How to avoid:**
Add a `threading.Lock` around model initialization:

```python
import threading

class ServiceFactory:
    _instances = {}
    _shared_resources = {}
    _lock = threading.Lock()

    @classmethod
    def _get_embedding_model(cls) -> SentenceTransformer:
        if "embedding_model" not in cls._shared_resources:
            with cls._lock:
                if "embedding_model" not in cls._shared_resources:  # double-checked locking
                    model_name = current_app.config.get("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
                    cls._shared_resources["embedding_model"] = SentenceTransformer(model_name)
        return cls._shared_resources["embedding_model"]
```

**Warning signs:**
- Intermittent `RuntimeError` or `AssertionError` inside sentence-transformers on first few requests
- Second request returns embeddings of wrong dimension
- `docker logs app` shows duplicate "Loading embedding model" log lines

**Phase to address:** Phase 0 (Blockers) — add the lock when implementing `ServiceFactory._get_embedding_model()`.

---

### Pitfall 12: MySQL Stored Procedure `CALL import_product()` Requires `nextset()` to Retrieve Results via SQLAlchemy

**What goes wrong:**
MySQL stored procedures return results via multiple result sets. When called via SQLAlchemy's `session.execute(text("CALL import_product(...)"))`, the DBAPI cursor may hold additional result sets (e.g., an OK packet or output params). If these are not consumed via `cursor.nextset()`, the connection is returned to the pool in a "dirty" state — the next query on that connection will receive stale result data or raise `ProgrammingError: Commands out of sync; you can't run this command now`.

**Why it happens:**
MySQL stored procedures always produce at least one result set. Even `CALL proc()` with no `SELECT` inside generates an implicit result. The `mysqlclient` / `PyMySQL` DBAPI requires explicit consumption of all result sets before the connection can be reused.

**How to avoid:**
Use `Connection.exec_driver_sql()` with the raw DBAPI cursor, or use `session.execute()` followed by consuming all result sets:

```python
def call_import_product(self, data: dict) -> dict:
    with self._session_factory() as session:
        with session.begin():
            conn = session.connection()
            cursor = conn.connection.cursor()  # raw DBAPI cursor
            cursor.callproc("import_product", [
                data["sku"], data["name"], data["price"],
                data["category_id"], data.get("brand_id"),
            ])
            results = list(cursor.fetchall())
            # Consume any remaining result sets to prevent "Commands out of sync"
            while cursor.nextset():
                pass
            cursor.close()
        return results
```

Alternatively, use `session.execute(text("CALL import_product(:sku, :name, :price, :cat, :brand)"), data)` and call `.fetchall()` and then check `result.cursor.nextset()` if your DBAPI supports it through SQLAlchemy's cursor proxy.

**Warning signs:**
- `ProgrammingError: Commands out of sync; you can't run this command now` on the query after a `CALL`
- The second request on the same connection fails even though the stored procedure "worked"
- MySQL general log shows repeated `ROLLBACK` after procedure calls

**Phase to address:** A4 (Stored Procedure) — implement the `nextset()` pattern from the start.

---

### Pitfall 13: MySQL Triggers Fire But Duplicate `product_change_log` DDL Missing

**What goes wrong:**
A3 requires an `AFTER UPDATE ON products` trigger that writes to `product_change_log`. If the `product_change_log` table is not defined in `schema.sql` before the trigger DDL, `CREATE TRIGGER` fails with `Table 'product_change_log' doesn't exist`. The trigger will not be created, and `UPDATE` statements will silently succeed without logging — no error at the application layer.

**Why it happens:**
MySQL checks the existence of referenced tables at `CREATE TRIGGER` time. If the tables are created in the wrong order (trigger before log table), the trigger creation silently fails or raises a DDL error during Docker initialization.

**How to avoid:**
Add `product_change_log` to `schema.sql` **before** the trigger DDL:

```sql
CREATE TABLE product_change_log (
    id           INT NOT NULL AUTO_INCREMENT,
    product_id   INT NOT NULL,
    changed_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by   VARCHAR(100) DEFAULT 'system',
    old_name     VARCHAR(255),
    new_name     VARCHAR(255),
    old_price    DECIMAL(10,2),
    new_price    DECIMAL(10,2),
    PRIMARY KEY (id),
    INDEX idx_product_change_log_product_id (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Trigger DDL (in same file or `triggers.sql`):
```sql
DELIMITER $$
CREATE TRIGGER trg_products_after_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF OLD.name != NEW.name OR OLD.price != NEW.price THEN
        INSERT INTO product_change_log (product_id, old_name, new_name, old_price, new_price)
        VALUES (OLD.id, OLD.name, NEW.name, OLD.price, NEW.price);
    END IF;
END$$
DELIMITER ;
```

**Warning signs:**
- `UPDATE` on a product succeeds but `product_change_log` stays empty
- `SHOW TRIGGERS FROM projectdb` shows no triggers
- Docker logs during init show `ERROR 1146 (42S02): Table 'projectdb.product_change_log' doesn't exist`

**Phase to address:** A3 (Trigger) — `product_change_log` DDL must precede trigger DDL in schema ordering.

---

### Pitfall 14: `RepositoryFactory._instances` Race Condition Under Flask Threaded Server

**What goes wrong:**
`RepositoryFactory._instances` is a plain class-level `dict`. Two concurrent first requests (e.g., one to `/products`, one to `/dashboard`) will each call `get_mysql_repository()`. Both see `"mysql" not in cls._instances` as `True`, and both instantiate `MySQLRepositoryImpl` — creating two separate session factories backed by two separate connection pools. This means the app runs with 2× the expected connection pool size and two separate instances serving different requests — violating the singleton guarantee.

**Why it happens:**
Python's `dict` operations are individually thread-safe (GIL), but the "check-then-set" pattern (`if key not in dict: dict[key] = value`) is not atomic. Two threads can both pass the `if` check before either stores the value.

**How to avoid:**
Add a `threading.Lock` to `RepositoryFactory` (same pattern as ServiceFactory):

```python
import threading

class RepositoryFactory:
    _instances = {}
    _lock = threading.Lock()

    @classmethod
    def get_mysql_repository(cls, session_factory=None) -> MySQLRepository:
        if "mysql" not in cls._instances:
            with cls._lock:
                if "mysql" not in cls._instances:  # double-checked locking
                    sf = session_factory or db.mysql_session_factory
                    cls._instances["mysql"] = MySQLRepositoryImpl(session_factory=sf)
        return cls._instances["mysql"]
```

**Warning signs:**
- Two "Initializing MySQL repository" log lines appearing on startup
- Inconsistent behavior between requests (one gets data, another doesn't)
- Pool exhaustion at 2× expected connection count

**Phase to address:** Phase 0 (Blockers — RepositoryFactory implementation) — add lock before implementing any factory method.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip `ensure_collection()` in Qdrant, call `upsert_points()` directly | Fewer lines of code | 404 crash on fresh container | Never — collections must always be ensured first |
| Leave `NoOpNeo4jRepository` raising `NotImplementedError` | No change needed | Every no-op code path raises 501 instead of degrading gracefully | Never — this is explicitly documented as a blocker |
| Open session without `with` block | Simpler code | Connection pool exhaustion under load | Never — always use context managers |
| Call `text("COMMIT")` directly | Looks like "explicit transactions" | SQLAlchemy internal state corruption | Never — use `session.begin()` context manager |
| Load embedding model per service (not shared) | Simpler service init | 270 MB RAM overhead, 3–9 sec startup per service | Never for production; acceptable only in unit tests with mocking |
| Singular table names in schema | Legacy DDL reuse | All application code broken, validation always fails | Never — the code side expects plural, DDL must match |
| Leave `product_change_log` / `etl_run_log` out of `schema.sql` | Less DDL to write | Runtime crashes on A3/A4/A6 routes | Never — these tables are load-bearing |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| SQLAlchemy + MySQL | Using `text("START TRANSACTION")` raw SQL | Use `session.begin()` — translates to `START TRANSACTION` at DBAPI level |
| SQLAlchemy + MySQL | Not calling `result.fetchall()` before session closes | Consume results inside the `with session.begin()` block |
| Qdrant Python client | Passing `numpy.ndarray` directly to `PointStruct.vector` | Always call `.tolist()` on numpy arrays before constructing `PointStruct` |
| Qdrant Python client | Assuming collection auto-creates on first upsert | Always call `ensure_collection()` / `collection_exists()` first |
| Qdrant Python client | Using `upsert()` without `wait=True` | Use `wait=True` so counts/searches are consistent after upsert returns |
| Neo4j Python driver | Using `driver.session()` without `with` | Always `with driver.session() as session:` — sessions have finite pool |
| Neo4j Python driver | Returning `Result` object from transaction function | Always call `list(result)` or `[dict(r) for r in result]` inside the `with` block |
| Neo4j Python driver | `driver.close()` never called | Register Flask `teardown_appcontext` to call `repo.close()` |
| MySQL + stored procedures | Not consuming extra result sets after `CALL` | Call `cursor.nextset()` until `False` after each `CALL` statement |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading SentenceTransformer per service | 270 MB RAM, 3–9 sec first request | Singleton in `ServiceFactory._shared_resources` with `_lock` | Immediately on any request that uses embeddings |
| Pool exhaustion from unclosed sessions | Requests hang after ~5 concurrent users | Always use `with session.begin()` context manager | With `pool_size=5` default, after 5 unclosed sessions |
| Qdrant `upsert()` without `wait=True` | `count()` returns 0 after successful upsert | Use `wait=True` parameter | Inconsistent even at small scale |
| N+1 JOIN queries for product tags | Dashboard shows correct counts but product list is slow | Use single JOIN query with `GROUP_CONCAT` or `collect()` | At ~50+ products |
| SentenceTransformer encode() on every search without caching | Search latency 200–500ms per query | Add `functools.lru_cache` on embedding call or in-memory cache | From first request |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| f-string table names in `validation.py` `text(f"SELECT COUNT(*) FROM {t}")` | SQL injection if table name list ever accepts user input | Only acceptable because list is hardcoded — never extend this pattern to user input |
| Leaving `execute_raw_query()` unimplemented | No user SQL reaches DB yet — but when implemented, missing validation | Use `sqlglot` for AST-level SELECT validation, not string matching |
| Hardcoded default secrets in `docker-compose.yml` (`:-dev-secret`, `:-admin123`) | Accidental production deployment with weak credentials | Remove fallback defaults; fail fast if env vars missing |
| `execute_cypher()` accepting raw user Cypher strings | Graph injection — arbitrary node/relationship modification | Validate that queries are `MATCH`/`RETURN` only before execution |

---

## "Looks Done But Isn't" Checklist

- [ ] **Schema fix:** `schema.sql` table names are plural AND all `REFERENCES` and `DROP TABLE` statements are also updated to plural
- [ ] **`etl_run_log` in schema:** Table is in `schema.sql` and docker init mounts run it (check `docker-compose.yml` volume mount order)
- [ ] **`product_change_log` in schema:** Table exists AND the trigger fires (verify with a test UPDATE and check the log table)
- [ ] **Session always closed:** Every `MySQLRepositoryImpl` method uses `with self._session_factory() as session: with session.begin():` — no bare `session = self._session_factory()()`
- [ ] **Qdrant collection ensured:** `ensure_collection()` is called before every `upsert_points()` call (not just once at startup)
- [ ] **Qdrant vectors as list:** All `PointStruct` vectors are `embedding.tolist()` — not raw numpy arrays
- [ ] **Neo4j sessions closed:** Every `execute_cypher()` and `get_product_relationships()` uses `with driver.session() as session:`
- [ ] **`NoOpNeo4jRepository` fixed:** All 3 methods return empty values (`{}`, `[]`, `None`) instead of raising `NotImplementedError`
- [ ] **Singleton embedding model:** `ServiceFactory._get_embedding_model()` is implemented with double-checked locking and stores result in `_shared_resources`
- [ ] **Stored procedure nextset:** After every `CALL import_product(...)`, all result sets are consumed before returning the connection

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Schema table name mismatch | LOW | Rename tables in `schema.sql`, run `docker compose down -v && docker compose up` to rebuild from scratch |
| Missing `etl_run_log` | LOW | Add DDL to `schema.sql`, `docker compose down -v && docker compose up` |
| Connection pool exhaustion | MEDIUM | Restart container to reset pool; then fix unclosed sessions in code |
| Qdrant 404 on upsert | LOW | Add `ensure_collection()` call before upsert, re-run index build |
| Wrong vector dimension in Qdrant | MEDIUM | Delete and recreate collection (`truncate_index()`), re-embed, re-upsert |
| Neo4j connection leak | MEDIUM | `docker compose restart neo4j` to kill connections; add teardown hook |
| Embedding model loaded 3× | LOW | Implement singleton, restart app container |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Schema table name mismatch | Phase 0 (Blockers) | Run `validate_mysql()` — should return PASSED for all tables |
| Missing `etl_run_log` | Phase 0 (Blockers) | `SELECT COUNT(*) FROM etl_run_log` returns 0 (table exists, empty) |
| Missing `product_change_log` | A3 (Trigger) | `SHOW TABLES LIKE 'product_change_log'` returns 1 row |
| Session not closed (pool exhaustion) | A2 (Transactions) | Run 10 concurrent requests to `/products`; none hang |
| `session.commit()` in nested `begin()` | A2 (Transactions) | Test: insert product + tags; delete product mid-way; verify rollback |
| Raw `text("COMMIT")` | A2 (Transactions) | Enable `echo=True`; verify `BEGIN`/`COMMIT` appear in SQLAlchemy logs |
| Qdrant collection-before-upsert | A6 (Vektor-DB) | Fresh container: run index build; verify no 404 errors |
| Qdrant numpy dimension mismatch | A6 (Vektor-DB) | `count()` returns expected N after `upsert_points()` |
| Neo4j driver never closed | A7 (Graph-DB) / Phase 0 NoOp fix | Graceful shutdown: `docker compose stop` shows no connection timeout errors |
| Neo4j session not closed | A7 (Graph-DB) | Run 20 RAG requests; Neo4j Browser shows 0 open transactions |
| Embedding model loaded 3× | Phase 0 (Blockers) | `docker stats` shows app RAM < 250 MB after all services initialized |
| Embedding model threading race | Phase 0 (Blockers) | Concurrent first requests: check logs for single "Loading embedding model" line |
| Stored procedure `nextset()` | A4 (Stored Procedure) | Call `import_product()` twice in a row; second call must not fail |
| RepositoryFactory race condition | Phase 0 (Blockers) | Concurrent first requests: check logs for single "Initializing MySQL repository" line |

---

## Sources

- **SQLAlchemy 2.0 Transactions docs** — https://docs.sqlalchemy.org/en/20/orm/session_transaction.html (verified 2026-04-02, release 2.0.48)
- **SQLAlchemy 2.0 Engine/Connection** — https://docs.sqlalchemy.org/en/20/core/connections.html (verified 2026-04-02)
- **Qdrant Collections API** — https://qdrant.tech/documentation/manage-data/collections/ (verified 2026-04-02, Qdrant v1.16.x)
- **Neo4j Python Driver — Transactions** — https://neo4j.com/docs/python-manual/current/transactions/ (verified 2026-04-02, driver v6 current)
- **Neo4j Python Driver — Advanced Connection** — https://neo4j.com/docs/python-manual/current/connect-advanced/ (verified 2026-04-02)
- **Codebase analysis** — `.planning/codebase/CONCERNS.md` (2026-04-02): known issues documented by scaffold author
- **Project requirements** — `.planning/PROJECT.md` (2026-04-02): A2–A7 implementation constraints
- **db.py** — `sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)` — SQLAlchemy 2.0 mode confirmed via `future=True`
- **repositories/__init__.py** — `_instances = {}` without lock — race condition identified from source inspection

---
*Pitfalls research for: Flask + SQLAlchemy 2.0 + MySQL 8.4 + Qdrant + Neo4j RAG application*
*Researched: 2026-04-02*
