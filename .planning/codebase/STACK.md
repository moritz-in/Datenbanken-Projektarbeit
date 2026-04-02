# Technology Stack

**Analysis Date:** 2026-04-02

## Languages

**Primary:**
- Python 3.12 - All application code, services, repositories, routes

**Secondary:**
- SQL (MySQL dialect) - Schema DDL, seed data, validation queries (`schema.sql`, `import.sql`, `src/sql/`, `mysql-init/`)
- Jinja2 (HTML templates) - Server-side rendering (`templates/`)

## Runtime

**Environment:**
- Python 3.12 (pinned via `FROM python:3.12-slim` in `Dockerfile`)
- Runs in Docker container (Alpine-based slim image)

**Package Manager:**
- pip (no lockfile; `requirements.txt` present)
- Lockfile: **Missing** — versions are partially pinned (exact for core packages, range-based for ML/AI libs)

## Frameworks

**Core:**
- Flask 3.0.3 - Web framework, application factory pattern (`app.py`)
- SQLAlchemy 2.0.32 - ORM/query layer for MySQL (`db.py`, `repositories/mysql_repository.py`)

**Testing:**
- pytest ≥ 7.4.0 - Test runner (config implicit; run via `tests/run_tests.sh` and Docker `test` stage)
- pytest-mock ≥ 3.11.0 - Mocking support
- pytest-cov ≥ 4.1.0 - Coverage reporting

**Build/Dev:**
- Docker + Docker Compose - Full containerized dev environment (`Dockerfile`, `docker-compose.yml`)
- Adminer - Database UI (containerized, port 8990)

## Key Dependencies

**Critical:**
- `PyMySQL==1.1.1` - MySQL driver for SQLAlchemy (`mysql+pymysql://` connection string)
- `psycopg2-binary==2.9.9` - PostgreSQL driver (optional PG support, `PG_URL` config)
- `sentence-transformers==3.0.1` - Embedding generation for vector search (`SentenceTransformer`, model `all-MiniLM-L6-v2`)
- `torch>=2.2.0` - PyTorch backend required by sentence-transformers
- `qdrant-client>=1.7.0` - Qdrant vector DB client (`repositories/qdrant_repository.py`)
- `openai>=1.0.0` - OpenAI API client for LLM-based RAG answers (`services/search_service.py`)
- `neo4j>=5.0` - Neo4j graph database driver (`repositories/neo4j_repository.py`)
- `pdfplumber` - PDF text extraction for RAG over uploaded PDFs (`repositories/qdrant_repository.py`)
- `python-dotenv==1.0.1` - `.env` file loading (`config.py`)
- `cryptography` - Cryptographic support (dependency of PyMySQL for SSL)

**Infrastructure:**
- `sqlalchemy.text` - Raw SQL execution with SQLAlchemy 2.x compatibility
- Flask Blueprints - Route modularization (`routes/` directory, 8 blueprints registered)

## Configuration

**Environment:**
- Loaded via `python-dotenv` from `.env` file at startup (`config.py` line 4)
- `.env` is git-ignored; exists locally

**Key environment variables (from `config.py`):**
```
FLASK_SECRET_KEY     # Flask session secret (default: "dev-secret")
MYSQL_URL            # Required: mysql+pymysql://user:pass@host:port/db
QDRANT_URL           # Required: http://qdrant:6333
PG_URL               # Optional: PostgreSQL connection (unused in current code)
QDRANT_COLLECTION    # Default: "products"
EMBEDDING_MODEL      # Default: "sentence-transformers/all-MiniLM-L6-v2"
EMBEDDING_DIM        # Default: 384
OPENAI_API_KEY       # Optional: required for RAG LLM answers
LLM_MODEL            # Default: "gpt-4.1-mini"
NEO4J_URI            # Default: "bolt://neo4j:7687"
NEO4J_USER           # Default: "neo4j"
NEO4J_PASSWORD       # Required for Neo4j
PDF_UPLOAD_DIR       # Default: /data/pdfs (set in docker-compose)
```

**Build:**
- `Dockerfile` — multi-stage: `base` → `test` (runs pytest) → `runtime` (runs `app.py`)
- `docker-compose.yml` — orchestrates 5 services: `mysql`, `adminer`, `qdrant`, `neo4j`, `app`

## Platform Requirements

**Development:**
- Docker + Docker Compose (primary development path)
- Python 3.12+ for local development without Docker
- `.env` file required at project root (see `config.py` for required vars)

**Production:**
- Docker container exposing port 5000 (mapped to host port 8081 by default)
- WSGI note in `app.py`: "For production, use Gunicorn: `gunicorn app:create_app()`"
- No Gunicorn dependency in `requirements.txt` — production WSGI not configured

---

*Stack analysis: 2026-04-02*
