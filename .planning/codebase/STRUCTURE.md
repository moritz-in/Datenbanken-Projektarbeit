# Codebase Structure

**Analysis Date:** 2026-04-02

## Directory Layout

```
Datenbanken-Projektarbeit/       # Project root
├── app.py                       # Flask application factory + entry point
├── config.py                    # Config class (env var loading)
├── db.py                        # SQLAlchemy session factory globals
├── utils.py                     # Stateless helper functions
├── validation.py                # MySQL schema validation logic
├── requirements.txt             # Python dependencies
├── Dockerfile                   # Multi-stage build (base, test, runtime)
├── docker-compose.yml           # MySQL, Qdrant, Neo4j, Adminer, app services
├── schema.sql                   # DDL for MySQL database (canonical schema)
├── import.sql                   # Data import SQL script
├── verify_database.sql          # Database verification queries
├── install_database.sh          # Shell script for DB setup (Unix)
├── install_database.bat         # Batch script for DB setup (Windows)
├── __init__.py                  # Root package marker (empty)
│
├── routes/                      # Controller layer — Flask blueprints
│   ├── __init__.py              # Re-exports all blueprint objects
│   ├── dashboard.py             # GET /
│   ├── products.py              # GET /products
│   ├── search.py                # GET|POST /search
│   ├── rag.py                   # GET|POST /rag, /graph-rag
│   ├── audit.py                 # GET /audit
│   ├── index.py                 # GET|POST /index, POST /truncate-index
│   ├── pdf.py                   # GET|POST /pdf-upload, /upload-teaching-pdf, /upload-product-pdf, /api/pdf-stats
│   └── validate.py              # POST /validate
│
├── services/                    # Business logic layer
│   ├── __init__.py              # ServiceFactory + re-exports all service classes
│   ├── product_service.py       # ProductService — product listing, dashboard, audit, SQL, validation
│   ├── search_service.py        # SearchService — vector search, RAG, graph enrichment, PDF RAG
│   ├── index_service.py         # IndexService — build/truncate Qdrant index, ETL logging
│   └── pdf_service.py           # PDFService — PDF upload, chunking, Qdrant ingestion
│
├── repositories/                # Data access layer
│   ├── __init__.py              # RepositoryFactory + re-exports all ABC and Impl classes
│   ├── mysql_repository.py      # MySQLRepository ABC + MySQLRepositoryImpl (SQLAlchemy)
│   ├── qdrant_repository.py     # QdrantRepository ABC + QdrantRepositoryImpl (qdrant_client)
│   ├── neo4j_repository.py      # Neo4jRepository ABC + Neo4jRepositoryImpl + NoOpNeo4jRepository
│   ├── product_repository.py    # ProductRepository ABC + ProductRepositoryImpl (legacy)
│   ├── dashboard_repository.py  # DashboardRepository ABC + DashboardRepositoryImpl (legacy)
│   └── audit_repository.py      # AuditRepository ABC + AuditRepositoryImpl (legacy)
│
├── templates/                   # Jinja2 HTML templates
│   ├── base.html                # Base layout (Bootstrap 5.3, navbar)
│   ├── dashboard.html           # Dashboard overview
│   ├── products.html            # Product table with pagination
│   ├── search.html              # Simple search page
│   ├── search_unified.html      # Unified search (vector/RAG/graph/SQL)
│   ├── rag.html                 # RAG results
│   ├── graph_rag.html           # Graph-RAG with PDF upload support
│   ├── audit.html               # Audit log table
│   ├── index.html               # Index management (build/truncate/status)
│   ├── pdf_upload.html          # PDF upload form
│   ├── validation_result.html   # MySQL schema validation report
│   └── student_hint.html        # 501 error page for unimplemented routes
│
├── static/                      # Static assets served by Flask
│   └── images/                  # Image files (DHBW logo etc.)
│
├── data/                        # CSV seed data for MySQL import
│   ├── products.csv
│   ├── products_500_new.csv
│   ├── products_extended.csv
│   ├── brands.csv
│   ├── categories.csv
│   ├── tags.csv
│   └── product_tags.csv
│
├── catalog/                     # Sample product PDF files
│   ├── Produktkatalog_2025-1.pdf
│   └── Produktkatalog_2025-2.pdf
│
├── src/sql/                     # Additional SQL workspace files
│   └── foo.sql                  # Student SQL scratch file
│
├── qdrant/                      # Qdrant HTTP API examples
│   └── qdrant.http              # HTTP collection/query examples (IDE REST client)
│
├── mysql-init/                  # MySQL Docker init scripts (mounted as initdb.d)
│   └── (empty — populated by student or CI)
│
├── logs/                        # Runtime log files (daily rotation)
│   └── YYYY-MM-DD.log           # Auto-created by DailyFileHandler in app.py
│
├── tests/                       # Test harness
│   ├── run_tests.sh             # Test runner shell script
│   ├── fixtures/seed.sql        # SQL seed data for tests
│   └── expected/foo.csv         # Expected output CSV for tests
│
├── .planning/codebase/          # GSD architecture documents (this directory)
│
├── Vorlesung/                   # Lecture/course materials
│   └── Übungen/                 # Exercise files
│
└── .github/workflows/           # CI/CD workflow definitions
```

## Directory Purposes

**`routes/`:**
- Purpose: HTTP request handling; one file per domain feature
- Contains: Flask blueprint modules, each with one or more route handler functions
- Key files: `routes/__init__.py` (barrel exports all blueprints)

**`services/`:**
- Purpose: Business logic; orchestrates repositories and external AI clients
- Contains: Service classes and `ServiceFactory` (singleton manager)
- Key files: `services/__init__.py` (ServiceFactory + barrel exports)

**`repositories/`:**
- Purpose: Database-specific data access; one file per DB backend
- Contains: Abstract base classes (ABCs) and concrete `Impl` classes; `RepositoryFactory` for DI
- Key files: `repositories/__init__.py` (RepositoryFactory + barrel exports)

**`templates/`:**
- Purpose: Jinja2 server-rendered HTML views
- Contains: All `.html` templates; `base.html` provides the shared layout
- Key files: `templates/base.html` (layout), `templates/student_hint.html` (501 page)

**`data/`:**
- Purpose: CSV source data for seeding the MySQL database
- Contains: Flat CSV files matching the schema tables (`products`, `brands`, `categories`, `tags`, `product_tags`)
- Generated: No — these are static input files

**`logs/`:**
- Purpose: Application runtime logs
- Contains: Daily log files named `YYYY-MM-DD.log`
- Generated: Yes — by `DailyFileHandler` in `app.py`; not committed

**`tests/`:**
- Purpose: Integration test harness (minimal — scaffolding only)
- Contains: `fixtures/seed.sql` for DB state, `expected/` for CSV comparison, `run_tests.sh`

**`mysql-init/`:**
- Purpose: SQL scripts auto-executed when the MySQL Docker container is first created
- Contains: Empty by default; student adds schema/seed scripts here
- Mounted as: `/docker-entrypoint-initdb.d` inside the MySQL container

**`src/sql/`:**
- Purpose: Scratch space for student SQL queries
- Contains: `foo.sql` placeholder

**`catalog/`:**
- Purpose: Sample PDF product catalogs for PDF upload exercises
- Contains: Two PDF files (`Produktkatalog_2025-*.pdf`)

## Key File Locations

**Entry Points:**
- `app.py`: Flask application factory (`create_app()`) and `__main__` dev server block
- `Dockerfile`: Multi-stage Docker build; `CMD ["python", "app.py"]` for runtime

**Configuration:**
- `config.py`: `Config` class — all environment variable definitions
- `docker-compose.yml`: Service definitions for MySQL, Qdrant, Neo4j, Adminer, app
- `.env`: Runtime environment variables (not committed; `dotenv` loads at startup)

**Database Schema:**
- `schema.sql`: Canonical MySQL DDL (`brand`, `category`, `tag`, `product`, `product_tags` tables)
- `import.sql`: Data import script (LOAD DATA INFILE from `/csv/*.csv`)

**Core Logic:**
- `db.py`: `make_session()` factory; `mysql_session_factory` / `pg_session_factory` globals
- `validation.py`: `validate_mysql(engine)` → `ValidationReport`
- `utils.py`: `_get_int()`, `_get_optional_int()` — used in every route handler

**Factories (DI):**
- `repositories/__init__.py`: `RepositoryFactory`
- `services/__init__.py`: `ServiceFactory`

## Naming Conventions

**Files:**
- Route modules: `<domain>.py` (lowercase noun, e.g., `products.py`, `dashboard.py`)
- Service modules: `<domain>_service.py` (e.g., `product_service.py`, `search_service.py`)
- Repository modules: `<domain>_repository.py` (e.g., `mysql_repository.py`, `qdrant_repository.py`)
- Templates: `<domain>.html` (lowercase; multi-word uses underscore, e.g., `graph_rag.html`, `pdf_upload.html`)

**Classes:**
- Abstract repositories: `<Backend>Repository` (e.g., `MySQLRepository`, `QdrantRepository`)
- Concrete implementations: `<Backend>RepositoryImpl` (e.g., `MySQLRepositoryImpl`)
- No-op fallbacks: `NoOp<Backend>Repository` (e.g., `NoOpNeo4jRepository`)
- Services: `<Domain>Service` (e.g., `ProductService`, `SearchService`)
- Factory classes: `<Layer>Factory` (e.g., `ServiceFactory`, `RepositoryFactory`)

**Functions/Methods:**
- Private helpers: `_snake_case` with leading underscore (e.g., `_get_int`, `_rotate_if_needed`, `_configure_logging`)
- Route handlers: `snake_case` matching the resource (e.g., `def products()`, `def dashboard()`)
- Blueprint objects: `bp` (module-local) re-exported as `<domain>_bp` in `routes/__init__.py`

**Blueprints:**
- Blueprint name string matches module name: `Blueprint("products", __name__)` in `products.py`
- Blueprint variable exported as `<domain>_bp` from `routes/__init__.py`

## Where to Add New Code

**New Route/Page:**
1. Create `routes/<domain>.py` with `bp = Blueprint("<domain>", __name__)`
2. Add handler functions with `@bp.get(...)` / `@bp.route(...)` decorators
3. Import and re-export from `routes/__init__.py`: `from .<domain> import bp as <domain>_bp`
4. Register in `app.py`: `app.register_blueprint(<domain>_bp)`
5. Create `templates/<domain>.html` that extends `base.html`

**New Service:**
1. Create `services/<domain>_service.py` with a class `<Domain>Service`
2. Accept repository ABCs as `__init__` parameters (dependency injection)
3. Add `get_<domain>_service()` classmethod to `ServiceFactory` in `services/__init__.py`
4. Add class to `__all__` in `services/__init__.py`

**New Repository:**
1. Create `repositories/<backend>_repository.py`
2. Define ABC with `@abstractmethod` signatures
3. Define `<Backend>RepositoryImpl` with concrete implementation
4. Add `get_<backend>_repository()` classmethod to `RepositoryFactory` in `repositories/__init__.py`
5. Add both ABC and Impl to `__all__` in `repositories/__init__.py`

**Database Schema Changes:**
- Update `schema.sql` (primary DDL source)
- Update `import.sql` if import is affected
- Update `validation.py` to include new tables/constraints in checks
- Update `data/` CSV files if seed data changes

**Utilities:**
- Shared helpers with no dependencies: add to `utils.py`
- Shared helpers that depend on Flask context: add private `_method()` to the relevant service

## Special Directories

**`logs/`:**
- Purpose: Daily rotating application logs
- Generated: Yes — at runtime by `app.py`
- Committed: No (in `.gitignore`)

**`mysql-init/`:**
- Purpose: Docker MySQL init scripts
- Generated: No — manually placed
- Committed: Yes (directory committed; scripts added by student)

**`.planning/codebase/`:**
- Purpose: GSD architecture documents for AI-assisted development
- Generated: Yes — by GSD codebase mapper
- Committed: Yes

**`Vorlesung/`:**
- Purpose: Lecture and exercise materials (course context, not application code)
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-04-02*
