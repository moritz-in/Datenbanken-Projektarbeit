# External Integrations

**Analysis Date:** 2026-04-02

## APIs & External Services

**LLM / Generative AI:**
- OpenAI API - Used for RAG answer generation in `services/search_service.py`
  - SDK/Client: `openai>=1.0.0` (`from openai import OpenAI`)
  - Auth: `OPENAI_API_KEY` environment variable
  - Model: Configurable via `LLM_MODEL` env var (default: `gpt-4.1-mini`)
  - Usage: `_generate_llm_answer()` in `SearchService` produces natural language answers from vector search hits

## Data Storage

**Databases:**

- **MySQL 8.4** (Primary relational database)
  - Container: `skeleton-mysql` (image: `mysql:8.4`)
  - Connection: `MYSQL_URL` env var (`mysql+pymysql://user:pass@mysql:3306/productdb`)
  - Client: SQLAlchemy 2.0.32 with PyMySQL 1.1.1 driver
  - Session factory: `db.make_session()` → `db.mysql_session_factory` (initialized in `app.py`)
  - Repository: `repositories/mysql_repository.py` (`MySQLRepository` ABC + `MySQLRepositoryImpl`)
  - Schema: `schema.sql` — tables: `brand`, `category`, `tag`, `product`, `product_tag`
  - Init scripts: `mysql-init/` directory mounted at `/docker-entrypoint-initdb.d`
  - Host port: 3316 (remapped from 3306 to avoid conflicts)
  - Charset: `utf8mb4` / `utf8mb4_0900_ai_ci`

- **Qdrant v1.16.2** (Vector database for semantic search)
  - Container: `skeleton-qdrant` (image: `qdrant/qdrant:v1.16.2`)
  - Connection: `QDRANT_URL` env var (default: `http://qdrant:6333`)
  - Client: `qdrant-client>=1.7.0` (`from qdrant_client import QdrantClient`)
  - Repository: `repositories/qdrant_repository.py` (`QdrantRepository` ABC + `QdrantRepositoryImpl`)
  - Collections: `products` (default product index), `pdf_skripte` (teaching PDFs), `pdf_produkte` (product PDFs)
  - Distance metric: COSINE (default), configurable
  - Embedding dim: 384 (default, `all-MiniLM-L6-v2`)
  - HNSW params: `m=16`, `ef_construct=128`, `ef=64` (search)
  - Host ports: HTTP 6343 (→ 6333), gRPC 6344 (→ 6334)
  - HTTP API test file: `qdrant/qdrant.http`

- **Neo4j 5** (Graph database for relationship enrichment)
  - Container: `skeleton-neo4j` (image: `neo4j:5`)
  - Connection: `NEO4J_URI` env var (default: `bolt://neo4j:7687`)
  - Auth: `NEO4J_USER` / `NEO4J_PASSWORD` env vars
  - Client: `neo4j>=5.0` (`from neo4j import GraphDatabase`)
  - Repository: `repositories/neo4j_repository.py` (`Neo4jRepository` ABC + `Neo4jRepositoryImpl`)
  - Purpose: Graph enrichment for RAG results (product → brand, category, tag relationships)
  - Host ports: Web UI 7484 (→ 7474), Bolt 7697 (→ 7687)
  - Optional: app degrades gracefully when Neo4j is unavailable (`NoOpNeo4jRepository`)

- **PostgreSQL** (Optional, not yet used)
  - Connection: `PG_URL` env var
  - Session factory: `db.pg_session_factory` (initialized to `None` in `db.py`)
  - Driver: `psycopg2-binary==2.9.9` (installed but no active repositories)
  - Status: Placeholder for future use

**File Storage:**
- Local filesystem — PDF uploads stored at `PDF_UPLOAD_DIR` (default: `/data/pdfs`)
- Docker volume: `skeleton_pdf_uploads:/data/pdfs`
- Not cloud-backed (no S3/GCS/Azure integration)

**Caching:**
- None — No Redis, Memcached, or in-memory cache layer detected

## Authentication & Identity

**Auth Provider:**
- None — No user authentication system detected
- Flask `SECRET_KEY` is configured (`FLASK_SECRET_KEY`) for session/flash support only
- No login, registration, or OAuth flows present

## Monitoring & Observability

**Error Tracking:**
- None — No Sentry, Datadog, or similar error tracking service

**Logs:**
- Custom daily rotating file logger (`DailyFileHandler` in `app.py`)
- Log directory: `logs/YYYY-MM-DD.log` (auto-created, git-ignored)
- Format: `%(asctime)s | %(levelname)s | %(name)s | %(message)s`
- Request logging: start/end/error per-request via Flask `before_request` / `after_request` hooks
- Request IDs: 8-char hex UUID per request (`g.request_id`)

## CI/CD & Deployment

**Hosting:**
- Docker containers (self-hosted / local)
- No cloud provider integration detected

**CI Pipeline:**
- GitHub Actions — `.github/workflows/ci.yml`
  - Triggers: push to `main`, pull requests
  - Steps: Docker Buildx build → runs pytest inside Docker `test` stage
  - Cache: GitHub Actions cache (`type=gha`)
- Additional workflows: `.github/workflows/sql-ci.yml`, `sql-test.yml`, `sql-bootstrap-expected.yml` (SQL-specific CI)

## Environment Configuration

**Required env vars:**
```
MYSQL_URL          # mysql+pymysql://user:pass@host:port/db
QDRANT_URL         # http://qdrant:6333
OPENAI_API_KEY     # sk-... (required for RAG LLM features)
NEO4J_PASSWORD     # Neo4j password
MYSQL_ROOT_PASSWORD # MySQL root password (Docker only)
MYSQL_PASSWORD     # MySQL app user password (Docker only)
```

**Optional env vars:**
```
PG_URL             # PostgreSQL connection (unused)
QDRANT_COLLECTION  # Default: "products"
EMBEDDING_MODEL    # Default: "sentence-transformers/all-MiniLM-L6-v2"
EMBEDDING_DIM      # Default: 384
LLM_MODEL          # Default: "gpt-4.1-mini"
NEO4J_URI          # Default: "bolt://neo4j:7687"
NEO4J_USER         # Default: "neo4j"
FLASK_SECRET_KEY   # Default: "dev-secret"
PORT               # Default: 5000
FLASK_ENV          # Default: "development"
```

**Secrets location:**
- `.env` file at project root (git-ignored)
- Docker Compose injects env vars via `env_file: ../.env` and explicit `environment:` keys

## Webhooks & Callbacks

**Incoming:**
- None — No webhook receiver endpoints detected

**Outgoing:**
- None — No outgoing webhook calls detected

## Embedded ML Models

**Sentence Transformers:**
- Model: `sentence-transformers/all-MiniLM-L6-v2` (default, configurable)
- Purpose: Generates 384-dim embeddings for products and PDF chunks
- Loaded via `SentenceTransformer` in `services/` (lazy-loaded singleton in `ServiceFactory`)
- Used by: `SearchService`, `IndexService`, `PDFService`
- Downloaded from HuggingFace Hub at first use (not bundled)

**PDF Processing:**
- Library: `pdfplumber` (no external API — fully local)
- Used in: `repositories/qdrant_repository.py` (`extract_pdf_chunks()`)
- Chunk size: 300 characters (default, configurable)

---

*Integration audit: 2026-04-02*
