# Architecture

**Analysis Date:** 2026-04-02

## Pattern Overview

**Overall:** Controller-Service-Repository (3-tier) with Flask Application Factory

**Key Characteristics:**
- Flask blueprints serve as the Controller layer — each blueprint handles one domain's HTTP routes
- Services encapsulate business logic and coordinate multiple repositories
- Repositories provide database-specific data access, each backed by an abstract base class (ABC) and a concrete `Impl` class
- Both `ServiceFactory` and `RepositoryFactory` manage singleton instances and provide dependency injection hooks for testing
- Most `Impl` methods are stubbed with `raise NotImplementedError(...)` — this is a student exercise project; implementations are intentionally left blank

## Layers

**Controller (Routes/Blueprints):**
- Purpose: Handle HTTP requests, parse query params, delegate to services, render Jinja2 templates
- Location: `routes/`
- Contains: One blueprint module per domain (`dashboard.py`, `products.py`, `search.py`, `rag.py`, `audit.py`, `index.py`, `pdf.py`, `validate.py`)
- Depends on: `services.ServiceFactory`, `utils`
- Used by: Flask app via `app.register_blueprint(...)`

**Service Layer:**
- Purpose: Business logic, orchestration across repositories, embedding model and LLM coordination
- Location: `services/`
- Contains: `ProductService`, `SearchService`, `IndexService`, `PDFService`, `ServiceFactory`
- Depends on: `repositories.*`, `sentence_transformers`, `openai`
- Used by: Route handlers in `routes/`

**Repository Layer:**
- Purpose: Data access abstraction — each repository wraps one database backend
- Location: `repositories/`
- Contains:
  - `MySQLRepositoryImpl` — SQL queries via SQLAlchemy + raw `text()`
  - `QdrantRepositoryImpl` — vector operations via `qdrant_client`
  - `Neo4jRepositoryImpl` — Cypher queries via `neo4j` driver
  - `ProductRepositoryImpl`, `DashboardRepositoryImpl`, `AuditRepositoryImpl` — legacy thin wrappers (being superseded by `MySQLRepositoryImpl`)
  - `NoOpNeo4jRepository` — fallback when Neo4j is not configured
- Depends on: `db` module (SQLAlchemy session factory), vendor SDKs
- Used by: Services

**Cross-Cutting Utilities:**
- `db.py` — SQLAlchemy session factory init; `mysql_session_factory` / `pg_session_factory` globals set in `app.py`
- `config.py` — `Config` class loads env vars via `python-dotenv`; accessed via `flask.current_app.config`
- `validation.py` — Standalone `validate_mysql(engine)` function; returns `ValidationReport` dataclass
- `utils.py` — Stateless helper functions (`_get_int`, `_get_optional_int`) for safe type coercion

**Presentation (Templates):**
- Purpose: Server-side HTML rendering with Jinja2
- Location: `templates/`
- Contains: `base.html` layout with Bootstrap 5.3 navbar; one template per route (`dashboard.html`, `products.html`, `search.html`, etc.)
- Depends on: Flask `render_template()` calls in routes

## Data Flow

**Standard Read Request (e.g., product listing):**

1. HTTP GET arrives at `routes/products.py` → `products()` blueprint handler
2. Handler calls `ServiceFactory.get_product_service()` to obtain `ProductService`
3. `ProductService.list_products_joined(page, page_size)` calls `MySQLRepository.get_products_with_joins()`
4. `MySQLRepositoryImpl` opens SQLAlchemy session, executes SQL, returns `dict` with `items` + `total`
5. Service returns result dict to route handler
6. Route renders `templates/products.html` with Jinja2 and returns HTML response

**Vector Search / RAG Flow:**

1. HTTP POST to `routes/search.py` → `search()` or `routes/rag.py` → `rag()`
2. Handler calls `ServiceFactory.get_search_service()` → `SearchService`
3. `SearchService.rag_search()` or `vector_search()`:
   a. Loads `SentenceTransformer` embedding model (lazy-loaded singleton via `ServiceFactory._get_embedding_model()`)
   b. Embeds query text into a float vector
   c. Calls `QdrantRepository.search()` to retrieve top-k similar product vectors
   d. Optionally calls `Neo4jRepository.get_product_relationships()` to enrich hits with graph data
   e. Calls `OpenAI` client to generate an LLM answer over the hits
4. Returns `dict` with `query`, `answer`, `hits` to route handler
5. Route renders `templates/rag.html` or `templates/search_unified.html`

**PDF Upload Flow:**

1. HTTP POST to `routes/pdf.py` → `upload_teaching_pdf()` or `upload_product_pdf()`
2. Handler calls `ServiceFactory.get_pdf_service()` → `PDFService`
3. `PDFService.upload_pdf_to_qdrant()`:
   a. Calls `QdrantRepository.extract_pdf_chunks()` — extracts text via `pdfplumber`, splits into 300-char chunks
   b. Embeds all chunks with `SentenceTransformer`
   c. Calls `QdrantRepository.upload_pdf_chunks()` — upserts chunk vectors into `pdf_skripte` or `pdf_produkte` Qdrant collection

**Index Build Flow:**

1. HTTP POST to `routes/index.py` → `index()` (form submission)
2. Handler calls `ServiceFactory.get_index_service()` → `IndexService`
3. `IndexService.build_index(strategy)`:
   a. Calls `MySQLRepository.load_products_for_index()` to fetch all products
   b. Converts each to a document string via `product_to_document()`
   c. Embeds in batches with `SentenceTransformer`
   d. Upserts vectors into Qdrant via `QdrantRepository.upsert_points()`
   e. Logs ETL run to MySQL via `MySQLRepository.log_etl_run()`

**State Management:**
- No client-side state. No session store beyond Flask's cookie-based flash messages (`SECRET_KEY` required).
- Database state lives in MySQL (relational), Qdrant (vectors), and Neo4j (graph).
- Embedding model and LLM client are in-process singletons managed by `ServiceFactory._shared_resources`.

## Key Abstractions

**Abstract Repository Bases (ABCs):**
- Purpose: Interface contracts that decouple services from database implementations
- Examples: `repositories/mysql_repository.py` (`MySQLRepository`), `repositories/qdrant_repository.py` (`QdrantRepository`), `repositories/neo4j_repository.py` (`Neo4jRepository`)
- Pattern: Each ABC defines `@abstractmethod` signatures; `Impl` class provides the concrete implementation; `NoOpNeo4jRepository` provides a safe fallback

**ServiceFactory / RepositoryFactory:**
- Purpose: Singleton management + dependency injection point
- Examples: `services/__init__.py` (`ServiceFactory`), `repositories/__init__.py` (`RepositoryFactory`)
- Pattern: `_instances = {}` dict keyed by class; `get_*()` classmethods return cached or newly created instances; `reset()` method clears cache for test isolation

**ValidationReport:**
- Purpose: Structured result from schema validation checks
- Examples: `validation.py` (`ValidationReport`, `ValidationItem`)
- Pattern: Dataclass with `ok: bool`, `summary: dict`, `items: list[ValidationItem]`; each item has `level` (OK/WARN/ERROR), `code`, `message`

**Flask Blueprint:**
- Purpose: Modular HTTP routing; each domain gets its own `bp = Blueprint(...)` registered on the app
- Examples: All files in `routes/`
- Pattern: `bp = Blueprint("name", __name__)` at module top; decorators `@bp.get(...)` / `@bp.route(...)`; exported via `routes/__init__.py`

## Entry Points

**Application Factory:**
- Location: `app.py` → `create_app()`
- Triggers: Called by Gunicorn (`gunicorn app:create_app()`) or directly (`python app.py`)
- Responsibilities: Load `Config`, configure logging, init MySQL session factory, register all blueprints, register error handler for `NotImplementedError` → 501

**Development Server:**
- Location: `app.py` → `__main__` block
- Triggers: `python app.py`
- Responsibilities: Call `create_app()`, start Flask dev server on `PORT` env var (default 5000)

**Docker Container:**
- Location: `Dockerfile` → `CMD ["python", "app.py"]`
- Port: 5000 (container), mapped to host port 8081 via `docker-compose.yml`

## Error Handling

**Strategy:** Blueprint-level exception handling is minimal; the app-level handler converts any `NotImplementedError` to a 501 response rendering `templates/student_hint.html`. Service/repository errors propagate up to the route handler which should catch and `flash()` error messages.

**Patterns:**
- `app.py` registers `@app.errorhandler(NotImplementedError)` → returns `student_hint.html` with HTTP 501
- Repository methods raise `ValueError` for invalid SQL queries (non-SELECT or forbidden keywords)
- `ValidationReport` uses `ok: bool` + structured `ValidationItem` list rather than exceptions for schema validation results
- Request lifecycle errors are caught by `@app.teardown_request` and logged with request ID

## Cross-Cutting Concerns

**Logging:**
- Framework: Python `logging` module with a custom `DailyFileHandler` (defined in `app.py`)
- Output: `logs/YYYY-MM-DD.log` files, auto-rotating daily
- Request tracing: `before_request` assigns a `uuid4` request ID stored in Flask `g`; `after_request` logs method, path, status, duration_ms
- Pattern: Each module gets `log = logging.getLogger(__name__)` at top-level

**Validation:**
- Input coercion: `utils._get_int()` / `utils._get_optional_int()` used in route handlers for safe query param parsing
- Schema validation: `validation.validate_mysql(engine)` runs structural DB checks; produces `ValidationReport`
- SQL safety: `MySQLRepositoryImpl.execute_raw_query()` strips string literals and blocks forbidden keywords before executing user-supplied SQL

**Authentication:**
- Not implemented. No auth layer exists. All routes are publicly accessible.

**Configuration:**
- `config.py` defines `Config` class; all values sourced from environment variables via `os.getenv()`
- Loaded into Flask app with `app.config.from_object(Config)` in `create_app()`
- Accessed in services/repositories via `current_app.config.get("KEY")`

---

*Architecture analysis: 2026-04-02*
