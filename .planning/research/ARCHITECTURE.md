# Architecture Research

**Domain:** Flask 3-tier product catalog with MySQL transactions, Qdrant vector search, Neo4j graph RAG
**Researched:** 2026-04-02
**Confidence:** HIGH (based on direct codebase analysis)

---

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Controller Layer (routes/)                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │products  │ │ search   │ │  rag     │ │  index   │ │dashboard │  │
│  │.py       │ │.py       │ │.py       │ │.py       │ │.py       │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │
└───────┼─────────────┼────────────┼─────────────┼────────────┼────────┘
        │             │            │             │            │
        ▼             ▼            ▼             ▼            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Service Layer (services/)                         │
│  ┌───────────────┐  ┌──────────────────────────────────────────┐    │
│  │ ProductService│  │            ServiceFactory                │    │
│  │               │  │  _instances{}  _shared_resources{}       │    │
│  │ + CRUD logic  │  │  _get_embedding_model() ← SINGLETON      │    │
│  │ + relations   │  │  _get_llm_client()      ← SINGLETON      │    │
│  └───────────────┘  └──────────────────────────────────────────┘    │
│  ┌───────────────┐  ┌───────────────┐  ┌────────────────────────┐   │
│  │ SearchService │  │  IndexService │  │      PDFService        │   │
│  │ vector_search │  │  build_index  │  │  upload_pdf_to_qdrant  │   │
│  │ rag_search    │  │  embed_texts  │  │                        │   │
│  └───────────────┘  └───────────────┘  └────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
        │             │            │
        ▼             ▼            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 Repository Layer (repositories/)                     │
│  ┌─────────────────────┐ ┌─────────────────┐ ┌──────────────────┐  │
│  │ MySQLRepositoryImpl │ │QdrantRepository  │ │ Neo4jRepository  │  │
│  │  SQLAlchemy 2.0     │ │Impl              │ │ Impl             │  │
│  │  text() + sessions  │ │ qdrant_client    │ │ neo4j driver     │  │
│  │  explicit tx blocks │ │ HNSW COSINE      │ │ Cypher           │  │
│  └──────────┬──────────┘ └────────┬─────────┘ └────────┬─────────┘  │
└─────────────┼──────────────────────┼──────────────────────┼──────────┘
              │                      │                      │
              ▼                      ▼                      ▼
       ┌────────────┐        ┌──────────────┐       ┌──────────────┐
       │  MySQL 8.4 │        │  Qdrant      │       │  Neo4j 5     │
       │  (port 3306│        │  v1.16.2     │       │  (bolt 7687) │
       │  ACID txns │        │  vector DB   │       │  graph DB    │
       └────────────┘        └──────────────┘       └──────────────┘
```

### Component Responsibilities

| Component | Responsibility | Notes |
|-----------|----------------|-------|
| `routes/*.py` (Blueprints) | HTTP in/out, form parsing, flash messages, render templates | Never touch DB directly |
| `ProductService` | CRUD orchestration, brand/category/tag relations, dashboard stats | Calls `MySQLRepository` only |
| `SearchService` | Vector search, graph enrichment, LLM answer generation | Holds injected embedding model + LLM client |
| `IndexService` | ETL: MySQL → embed → Qdrant upsert → log | Also holds injected embedding model |
| `PDFService` | PDF text extraction, chunk embedding, Qdrant upload | Shares embedding model singleton |
| `ServiceFactory` | Singleton cache for all services + shared resources | `_shared_resources` = embedding model + LLM client |
| `MySQLRepositoryImpl` | All MySQL queries + **explicit transaction management** | Session-per-operation via `_get_session()` |
| `QdrantRepositoryImpl` | Qdrant collection mgmt, vector upsert/search/scroll | Stateless per call |
| `Neo4jRepositoryImpl` | Cypher queries, product relationship lookup | Driver is long-lived; close in teardown |
| `RepositoryFactory` | Singleton cache for all repository instances | Single source of truth for connection params |
| `db.py` | `mysql_session_factory` global; initialized once in `create_app()` | SQLAlchemy 2.0 `sessionmaker` |

---

## Transaction Boundary Decision

### WHERE: Repository Layer owns transaction boundaries

**Decision: Transaction boundaries belong in `MySQLRepositoryImpl`, NOT in `ProductService`.**

**Rationale:**

1. **The scaffold uses raw `text()` queries** — `MySQLRepositoryImpl` already uses `sqlalchemy.text()` for explicit SQL. Wrapping with `START TRANSACTION / COMMIT / ROLLBACK` fits naturally here.
2. **Session lifecycle is repository-owned** — `MySQLRepositoryImpl._get_session()` creates/manages sessions. Transactions that span multiple SQL statements are internal to a single repository method.
3. **Service layer stays clean** — `ProductService.create_product_with_relations()` calls one high-level repository method per logical operation, not multiple low-level statements it has to manually coordinate.
4. **Course requirement**: The assignment explicitly asks for `START TRANSACTION / COMMIT / ROLLBACK` in repository methods, which confirms repository-layer placement.

**The pattern:**

```python
# MySQLRepositoryImpl — transaction boundary lives HERE
def create_product(self, data: dict) -> int:
    with self._get_session() as session:
        try:
            session.execute(text("START TRANSACTION"))
            # 1. Insert product
            result = session.execute(text("INSERT INTO products ..."), data)
            product_id = result.lastrowid
            # 2. Link tags if any
            for tag_id in data.get("tag_ids", []):
                session.execute(text("INSERT INTO product_tags ..."), {...})
            session.execute(text("COMMIT"))
            return product_id
        except Exception as e:
            session.execute(text("ROLLBACK"))
            log.error("create_product rolled back: %s", e)
            raise

# ProductService — orchestrates, no transaction knowledge
def create_product_with_relations(self, form_data: dict) -> int:
    return self.mysql_repo.create_product(form_data)
    # If brand/category need creating first, those are separate repository calls
    # Each repository call is its own atomic operation
```

**When service layer CAN coordinate multiple repository calls:**
- Each call is already atomic at the repository level
- Cross-database writes (MySQL + Qdrant sync after product create) happen in the service layer sequentially; partial failures are acceptable for this academic project (no distributed transaction needed)

---

## Embedding Model Singleton Strategy

### Concrete Implementation in `ServiceFactory`

The embedding model (`sentence-transformers/all-MiniLM-L6-v2`) loads ~90 MB per instance. Three services need it (`SearchService`, `IndexService`, `PDFService`). The singleton must live in `ServiceFactory._shared_resources`.

```python
# services/__init__.py

class ServiceFactory:
    _instances = {}
    _shared_resources = {}

    @classmethod
    def reset(cls):
        cls._instances.clear()
        cls._shared_resources.clear()

    @classmethod
    def _get_embedding_model(cls) -> SentenceTransformer:
        if "embedding_model" not in cls._shared_resources:
            model_name = current_app.config.get(
                "EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2"
            )
            log.info("Loading embedding model: %s", model_name)
            cls._shared_resources["embedding_model"] = SentenceTransformer(model_name)
            log.info("Embedding model loaded")
        return cls._shared_resources["embedding_model"]

    @classmethod
    def _get_llm_client(cls) -> Optional[OpenAI]:
        if "llm_client" not in cls._shared_resources:
            api_key = current_app.config.get("OPENAI_API_KEY")
            if not api_key:
                log.warning("OPENAI_API_KEY not set — LLM disabled")
                cls._shared_resources["llm_client"] = None
            else:
                cls._shared_resources["llm_client"] = OpenAI(api_key=api_key)
        return cls._shared_resources["llm_client"]

    @classmethod
    def get_search_service(cls) -> SearchService:
        if "search" not in cls._instances:
            cls._instances["search"] = SearchService(
                qdrant_repo=RepositoryFactory.get_qdrant_repository(),
                neo4j_repo=RepositoryFactory.get_neo4j_repository(),
                embedding_model=cls._get_embedding_model(),   # ← shared singleton
                llm_client=cls._get_llm_client(),             # ← shared singleton
            )
        return cls._instances["search"]

    @classmethod
    def get_index_service(cls) -> IndexService:
        if "index" not in cls._instances:
            cls._instances["index"] = IndexService(
                qdrant_repo=RepositoryFactory.get_qdrant_repository(),
                mysql_repo=RepositoryFactory.get_mysql_repository(),
                embedding_model=cls._get_embedding_model(),   # ← same singleton
            )
        return cls._instances["index"]

    @classmethod
    def get_pdf_service(cls) -> PDFService:
        if "pdf" not in cls._instances:
            cls._instances["pdf"] = PDFService(
                qdrant_repo=RepositoryFactory.get_qdrant_repository(),
                embedding_model=cls._get_embedding_model(),   # ← same singleton
            )
        return cls._instances["pdf"]

    @classmethod
    def get_product_service(cls) -> ProductService:
        if "product" not in cls._instances:
            cls._instances["product"] = ProductService(
                mysql_repo=RepositoryFactory.get_mysql_repository(),
                qdrant_repo=RepositoryFactory.get_qdrant_repository(),
            )
        return cls._instances["product"]
```

**Why `_get_embedding_model()` is lazy (not eager at `create_app()` time):**
- First request bearing search/index triggers load. This avoids blocking app startup (especially in Docker where the model downloads on first use).
- The `_shared_resources` dict persists across requests within the same process — model loads once, reused forever.
- `reset()` clears it for test isolation.

**`SearchService._get_embedding_model()` behavior:**
Since `SearchService` receives the model injected at construction time, its internal `_get_embedding_model()` simply returns `self._embedding_model` (the injected instance). No second load occurs.

---

## Neo4j Sync Strategy

### Decision: On-Demand Batch Sync via `IndexService`

**Approach: Populate Neo4j during the same Index Build operation that populates Qdrant.**

The `IndexService.build_index()` already reads all products from MySQL. This is the natural sync point.

```
IndexService.build_index()
  ├── MySQLRepository.load_products_for_index()   → list[dict] with brand/category/tags
  ├── [embed products] → vectors
  ├── QdrantRepository.upsert_points()            → Qdrant updated
  ├── Neo4jRepository.sync_products(products)     → Neo4j updated  ← ADD THIS
  └── MySQLRepository.log_etl_run()               → audit logged
```

**Why not event-driven / trigger-based sync:**
- No message broker exists in the stack (no Kafka, Celery, Redis)
- MySQL triggers cannot reach Neo4j
- Academic project: demonstrability > real-time consistency
- Docker Compose scope: batch sync on index rebuild is sufficient

**Neo4j graph schema to sync:**

```cypher
// Nodes
(:Product {mysql_id: INT, name: STRING, sku: STRING, price: FLOAT, description: STRING})
(:Brand   {name: STRING})
(:Category{name: STRING})
(:Tag     {name: STRING})

// Relationships
(:Product)-[:MADE_BY]->(:Brand)
(:Product)-[:IN_CATEGORY]->(:Category)
(:Product)-[:HAS_TAG]->(:Tag)
(:Tag)<-[:HAS_TAG]-(:Product)   // inverse implied for traversal
```

**Sync Cypher pattern (MERGE for idempotency):**

```cypher
MERGE (b:Brand {name: $brand_name})
MERGE (c:Category {name: $category_name})
MERGE (p:Product {mysql_id: $mysql_id})
  ON CREATE SET p.name = $name, p.sku = $sku, p.price = $price
  ON MATCH  SET p.name = $name, p.sku = $sku, p.price = $price
MERGE (p)-[:MADE_BY]->(b)
MERGE (p)-[:IN_CATEGORY]->(c)
WITH p
UNWIND $tags AS tag_name
  MERGE (t:Tag {name: tag_name})
  MERGE (p)-[:HAS_TAG]->(t)
```

**Add to `Neo4jRepositoryImpl`:**

```python
def sync_products(self, products: list[dict]) -> int:
    """Sync products list from MySQL into Neo4j graph. Returns count synced."""
    synced = 0
    with self._driver.session() as session:
        for p in products:
            session.execute_write(self._merge_product, p)
            synced += 1
    return synced
```

**Note:** `sync_products()` is NOT in the current `Neo4jRepository` ABC. It should be added as an `@abstractmethod` (or a non-abstract helper on `Neo4jRepositoryImpl` if the ABC is meant to be fixed in scope).

---

## RAG Pipeline Component Order and Data Flow

### Complete RAG Flow

```
HTTP POST /rag?query=...
        │
        ▼
routes/rag.py
  └── SearchService.rag_search(strategy, query, topk, use_graph_enrichment=True)
              │
              ▼
        [1] EMBED QUERY
        model.encode([query])  →  query_vector: list[float] (384-dim)
              │
              ▼
        [2] VECTOR SEARCH (Qdrant)
        QdrantRepository.search(
            collection_name="products",
            query_vector=query_vector,
            limit=topk
        )  →  hits: list[ScoredPoint]
              │
              ▼
        [3] EXTRACT METADATA
        hits → mysql_ids: list[int]  (from point.payload["mysql_id"])
        hits → base_context: list[dict]  (name, sku, score, description)
              │
              ▼
        [4] GRAPH ENRICHMENT (Neo4j, optional)
        if use_graph_enrichment and neo4j_repo:
            Neo4jRepository.get_product_relationships(mysql_ids)
            →  enrichment: dict[int, dict]  {mysql_id: {brand, category, tags}}
            merge enrichment into base_context
              │
              ▼
        [5] BUILD LLM PROMPT
        Format context string from enriched hits:
          "Product: {name} | Brand: {brand} | Category: {category}
           Tags: {tags} | Description: {description} | Score: {score}"
              │
              ▼
        [6] LLM ANSWER (OpenAI)
        openai_client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user",   "content": f"Query: {query}\n\nContext:\n{context}"},
            ]
        )  →  answer: str
              │
              ▼
        return {"query": query, "answer": answer, "hits": enriched_hits}
              │
              ▼
routes/rag.py  →  render_template("rag.html", ...)
```

### `_generate_llm_answer()` Implementation Pattern

```python
def _generate_llm_answer(self, query: str, hits: list[dict]) -> str:
    client = self._get_llm_client()
    if client is None:
        return "[LLM nicht konfiguriert — OPENAI_API_KEY fehlt]"

    context_parts = []
    for i, hit in enumerate(hits, 1):
        context_parts.append(
            f"{i}. {hit.get('name', '?')} "
            f"(Brand: {hit.get('brand', '?')}, "
            f"Category: {hit.get('category', '?')}, "
            f"Tags: {', '.join(hit.get('tags', []))}) — "
            f"{hit.get('description', '')[:200]}"
        )
    context = "\n".join(context_parts)

    model_name = current_app.config.get("LLM_MODEL", "gpt-4.1-mini")
    response = client.chat.completions.create(
        model=model_name,
        messages=[
            {"role": "system", "content": (
                "Du bist ein Produktberater. Beantworte die Frage des Nutzers "
                "basierend ausschließlich auf den bereitgestellten Produktdaten."
            )},
            {"role": "user", "content": f"Frage: {query}\n\nProdukte:\n{context}"},
        ],
        max_tokens=512,
    )
    return response.choices[0].message.content.strip()
```

### Vector Search Only Flow (simpler path)

```
SearchService.vector_search(query, topk)
  [1] embed query → query_vector
  [2] QdrantRepository.search() → hits
  [3] format hits as list[dict]  (no LLM, no Neo4j)
  return hits
```

---

## Recommended Project Structure (current, with implementation slots)

```
Datenbanken-Projektarbeit/
├── app.py                      # Application factory — create_app()
├── db.py                       # mysql_session_factory singleton
├── config.py                   # Config from env vars
├── validation.py               # validate_mysql() → ValidationReport
├── utils.py                    # _get_int() helpers
│
├── repositories/
│   ├── __init__.py             # RepositoryFactory ← IMPLEMENT
│   ├── mysql_repository.py     # MySQLRepositoryImpl ← IMPLEMENT (txns here)
│   ├── qdrant_repository.py    # QdrantRepositoryImpl ← IMPLEMENT
│   ├── neo4j_repository.py     # Neo4jRepositoryImpl + NoOpNeo4jRepository ← IMPLEMENT
│   ├── product_repository.py   # Legacy thin wrapper (low priority)
│   ├── dashboard_repository.py # Legacy thin wrapper (low priority)
│   └── audit_repository.py     # Legacy thin wrapper (low priority)
│
├── services/
│   ├── __init__.py             # ServiceFactory ← IMPLEMENT (embedding singleton here)
│   ├── product_service.py      # ProductService ← IMPLEMENT (CRUD orchestration)
│   ├── search_service.py       # SearchService ← IMPLEMENT (RAG pipeline)
│   ├── index_service.py        # IndexService ← IMPLEMENT (ETL + Neo4j sync)
│   └── pdf_service.py          # PDFService ← IMPLEMENT
│
├── routes/
│   ├── products.py             # CRUD forms ← IMPLEMENT
│   ├── search.py               # Vector + SQL search ← IMPLEMENT
│   ├── rag.py                  # RAG UI ← IMPLEMENT
│   ├── index.py                # Index build form ← IMPLEMENT
│   └── ...                     # dashboard, audit, validate, pdf ← IMPLEMENT
│
└── templates/                  # Jinja2 — mostly done by scaffold
```

---

## Architectural Patterns

### Pattern 1: Session-Per-Operation (Repository Transaction Management)

**What:** Each repository method opens a session context manager, executes its SQL (including transaction control), and closes the session. No session leaks across method boundaries.

**When to use:** For all write operations in `MySQLRepositoryImpl` (create, update, delete).

**Trade-offs:**
- ✅ Clean: no session lifecycle bleed between calls
- ✅ Fits SQLAlchemy 2.0 `future=True` style (context manager sessions)
- ⚠️ Cannot span a transaction across two separate repository method calls (intentional — each operation is atomic)

**Example:**

```python
def _get_session(self):
    """Returns a new session from the factory (used as context manager)."""
    return self._session_factory()

def delete_product(self, product_id: int) -> bool:
    with self._get_session() as session:
        try:
            session.execute(text("START TRANSACTION"))
            # Remove junction rows first (FK constraint)
            session.execute(text("DELETE FROM product_tags WHERE product_id = :id"),
                            {"id": product_id})
            result = session.execute(text("DELETE FROM products WHERE id = :id"),
                                     {"id": product_id})
            session.execute(text("COMMIT"))
            return result.rowcount > 0
        except Exception as e:
            session.execute(text("ROLLBACK"))
            raise
```

### Pattern 2: Constructor Injection for Shared Resources

**What:** `ServiceFactory` constructs each service once and injects the shared embedding model/LLM client via constructor. Services store the reference as `self._embedding_model`.

**When to use:** Any resource that is expensive to initialize and safe to share (no mutable state, thread-safe inference).

**Trade-offs:**
- ✅ Single load of ~90 MB model — 3 services share it without 3x RAM cost
- ✅ Easy to swap in tests via `ServiceFactory.reset()` + inject mock
- ⚠️ Services get a module-level reference — do not reassign `self._embedding_model` after construction

**Example:**
```python
# Service's internal helper pattern:
def _get_embedding_model(self) -> SentenceTransformer:
    if self._embedding_model is None:
        # Fallback lazy-load only used if constructed without injection
        self._embedding_model = SentenceTransformer(
            current_app.config.get("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
        )
    return self._embedding_model
```

### Pattern 3: NoOp Repository Fallback

**What:** `NoOpNeo4jRepository` implements the `Neo4jRepository` ABC but returns safe empty values. `RepositoryFactory.get_neo4j_repository()` returns `NoOpNeo4jRepository` if Neo4j config is absent.

**When to use:** Any optional external service that may not be configured (Neo4j URI missing from env).

**Trade-offs:**
- ✅ App runs without Neo4j configured — RAG degrades gracefully
- ✅ `SearchService.rag_search(use_graph_enrichment=True)` still works (skips graph step if `neo4j_repo` is NoOp)

**Correct NoOp implementation** (replace `raise NotImplementedError`):
```python
class NoOpNeo4jRepository(Neo4jRepository):
    def get_product_relationships(self, mysql_ids: list[int]) -> dict[int, dict]:
        return {}   # empty enrichment — callers handle empty dict safely

    def execute_cypher(self, query: str, parameters=None) -> list:
        return []

    def close(self) -> None:
        pass        # nothing to close
```

---

## Recommended Build Order

Build in dependency order — each step is testable before the next begins.

| Step | What to Build | Why First |
|------|---------------|-----------|
| 1 | Fix `NoOpNeo4jRepository` (remove `NotImplementedError`) | Unblocks everything — app crashes on startup otherwise |
| 2 | `RepositoryFactory` — all `get_*()` methods | Foundation for all services |
| 3 | `ServiceFactory` — all `get_*()` + `_get_embedding_model()` + `_get_llm_client()` | Foundation for all routes |
| 4 | `MySQLRepositoryImpl` read methods (`get_products_with_joins`, `get_dashboard_stats`, `get_last_runs`, `has_column`, `execute_raw_query`) | Unblocks dashboard + product listing routes |
| 5 | `ProductService` read methods + `ProductService.list_products_joined()` + `routes/products.py` listing | First visible working page |
| 6 | `MySQLRepositoryImpl` write methods (`create_product`, `update_product`, `delete_product`) with explicit `START TRANSACTION / COMMIT / ROLLBACK` | A2 transaction requirement |
| 7 | `ProductService` write methods + `routes/products.py` CRUD forms | Full product management |
| 8 | MySQL DDL: triggers (`product_change_log`), stored procedure (`import_product`), B-tree indexes | A3, A4, A5 — pure SQL work |
| 9 | `QdrantRepositoryImpl` all methods + `IndexService.build_index()` + `routes/index.py` | Unblocks A6 |
| 10 | `SearchService.vector_search()` + `SearchService.embed_texts()` + `routes/search.py` | A6 semantic search |
| 11 | `Neo4jRepositoryImpl` + `Neo4jRepositoryImpl.sync_products()` + integrate into `IndexService.build_index()` | A7 graph population |
| 12 | `SearchService.rag_search()` + `_generate_llm_answer()` + `routes/rag.py` | A7 full RAG |
| 13 | Remaining routes: `dashboard.py`, `audit.py`, `validate.py`, `pdf.py` | Polish / secondary |

---

## Data Flow

### CRUD Write Flow (A2 — Transactions)

```
HTTP POST /products/create
    ↓
routes/products.py
  └── ProductService.create_product_with_relations(form_data)
        └── MySQLRepository.create_product(data)
              ├── session.execute("START TRANSACTION")
              ├── INSERT INTO products (...)           ← may raise on dup SKU → ROLLBACK
              ├── INSERT INTO product_tags (...)       ← may raise on FK violation → ROLLBACK
              ├── session.execute("COMMIT")
              └── return product_id
    ↓
flash("Produkt erstellt") → redirect /products
```

### Index Build Flow (A6 — Qdrant ETL)

```
HTTP POST /index (strategy=A)
    ↓
routes/index.py
  └── IndexService.build_index(strategy="A")
        ├── MySQLRepository.load_products_for_index()   → list[dict] (with tags)
        ├── [product_to_document(p) for p in products]  → list[str]
        ├── embedding_model.encode(docs, batch_size=64) → np.ndarray
        ├── QdrantRepository.ensure_collection("products", 384)
        ├── QdrantRepository.upsert_points("products", points)
        ├── Neo4jRepository.sync_products(products)      ← NEW (A7 prep)
        └── MySQLRepository.log_etl_run(strategy, processed, written)
    ↓
return {"status": "ok", "count": N, "elapsed_s": X}
```

### RAG Search Flow (A7 — Graph + LLM)

```
HTTP POST /rag?query="rotes Mountainbike unter 500 Euro"
    ↓
routes/rag.py
  └── SearchService.rag_search(query=..., topk=5, use_graph_enrichment=True)
        ├── model.encode([query])                           → vector[384]
        ├── QdrantRepository.search("products", vector, 5) → hits (ScoredPoint list)
        ├── extract mysql_ids from hit payloads
        ├── Neo4jRepository.get_product_relationships(mysql_ids)
        │     → {id: {brand, category, tags}}
        ├── merge graph enrichment into hits
        └── _generate_llm_answer(query, enriched_hits)
              └── OpenAI.chat.completions.create(model="gpt-4.1-mini", ...)
                    → answer: str
    ↓
render_template("rag.html", query=q, answer=a, hits=hits)
```

---

## Scaling Considerations

This is an academic/demo project — scaling is not a real requirement. Noted for completeness.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 developer, demo | Current Docker Compose monolith is correct — no changes needed |
| 10-100 users | Flask dev server → Gunicorn (already supported via `gunicorn app:create_app()`) |
| Real production | Separate embedding inference to a dedicated service; use connection pooling in SQLAlchemy; Neo4j sync via event queue |

### Actual Bottlenecks for Demo

1. **First search after startup:** Embedding model lazy-loads (~2-5s). Acceptable for demo. Could pre-warm at `create_app()` if needed.
2. **Index build on large catalog:** Batched embedding via `batch_size=64` mitigates. `IndexService.build_index()` should return progress stats.
3. **Neo4j sync in index build:** Synchronous — fine for demo catalog size. Would need async/batching for 100k+ products.

---

## Anti-Patterns

### Anti-Pattern 1: Transaction Management in Service Layer

**What people do:** `ProductService.create_product_with_relations()` calls `mysql_repo.insert_product()`, then `mysql_repo.insert_product_tag()` in sequence, and tries to manage a transaction between the two from the service layer.

**Why it's wrong:** The service layer doesn't own sessions. `MySQLRepositoryImpl._get_session()` returns a new session each call — you can't span a transaction across two different session objects. Also violates the "repository owns DB concerns" principle.

**Do this instead:** Put all the SQL steps for one logical operation inside a single `MySQLRepositoryImpl` method with its own `START TRANSACTION / COMMIT / ROLLBACK` block.

---

### Anti-Pattern 2: Loading Embedding Model Multiple Times

**What people do:** `SearchService._get_embedding_model()` and `IndexService._get_embedding_model()` each call `SentenceTransformer(model_name)` independently.

**Why it's wrong:** Each load takes 2-5 seconds and ~90 MB RAM. Three services = 270 MB wasted + 15s startup lag.

**Do this instead:** Always pass the shared instance from `ServiceFactory._get_embedding_model()` at construction time. The service's internal `_get_embedding_model()` should be a passthrough to `self._embedding_model`.

---

### Anti-Pattern 3: Neo4j Driver Per Request

**What people do:** `Neo4jRepositoryImpl.__init__()` is called on every request (not as singleton), creating a new Bolt driver connection each time.

**Why it's wrong:** Bolt connection establishment has significant overhead. Neo4j connections should be pooled.

**Do this instead:** `RepositoryFactory.get_neo4j_repository()` caches the `Neo4jRepositoryImpl` instance in `_instances`. The driver is created once and reused. Call `close()` only on application shutdown (Flask teardown), not after each query.

---

### Anti-Pattern 4: Skipping `MERGE` in Neo4j Sync (Using `CREATE` Instead)

**What people do:** `sync_products()` uses `CREATE` Cypher clauses, causing duplicate nodes on repeated index builds.

**Why it's wrong:** Every `build_index()` call recreates all nodes — Neo4j accumulates duplicates that break `get_product_relationships()` results.

**Do this instead:** Use `MERGE` with `ON CREATE SET` / `ON MATCH SET` for idempotent sync. Repeated index builds update existing nodes cleanly.

---

### Anti-Pattern 5: Raising `NotImplementedError` in `NoOpNeo4jRepository`

**What people do:** Leave the scaffold's `raise NotImplementedError(...)` in the NoOp class.

**Why it's wrong:** `RepositoryFactory.get_neo4j_repository()` returns `NoOpNeo4jRepository` when Neo4j is unconfigured. Any call to the returned object crashes with 501 — the NoOp pattern is defeated.

**Do this instead:** Implement safe returns: `get_product_relationships()` → `{}`, `execute_cypher()` → `[]`, `close()` → `pass`.

---

## Integration Points

### External Services

| Service | Integration Pattern | Initialization | Notes |
|---------|---------------------|----------------|-------|
| MySQL 8.4 | SQLAlchemy 2.0 `sessionmaker`, `text()` queries | `db.mysql_session_factory` set in `create_app()` | Use `autocommit=False`, explicit `START TRANSACTION` |
| Qdrant v1.16.2 | `QdrantClient(url=...)`, direct SDK calls | `QdrantRepositoryImpl.__init__()` | Client is stateless, safe to share |
| Neo4j 5 | `GraphDatabase.driver(uri, auth=(user, pw))` | `Neo4jRepositoryImpl.__init__()` | Driver is long-lived; pool via `max_connection_pool_size` |
| OpenAI `gpt-4.1-mini` | `openai.OpenAI(api_key=...)` | `ServiceFactory._get_llm_client()` | Returns `None` if key absent; services check for None |
| `all-MiniLM-L6-v2` | `SentenceTransformer(model_name)` | `ServiceFactory._get_embedding_model()` | 384-dim output; download on first call |

### Internal Boundaries

| Boundary | Communication | Contract |
|----------|---------------|----------|
| Route → Service | Direct method call via `ServiceFactory.get_*()` | Service returns plain `dict` or `list[dict]` |
| Service → Repository | Direct method call via `RepositoryFactory.get_*()` (injected) | Repository returns plain `dict` / `list[dict]` / scalar |
| Service → OpenAI | `openai.OpenAI` client method calls | Returns `ChatCompletion` object; extract `.choices[0].message.content` |
| `IndexService` → Neo4j | `Neo4jRepository.sync_products()` call within `build_index()` | Best-effort; failure logs and continues (doesn't abort Qdrant upsert) |
| `SearchService` → Neo4j | `Neo4jRepository.get_product_relationships(mysql_ids)` | Returns `{}` on NoOp or error; service merges with base hits |

---

## Sources

- Direct codebase analysis: `repositories/mysql_repository.py`, `neo4j_repository.py`, `qdrant_repository.py`, `services/__init__.py`, `services/search_service.py`, `services/index_service.py`, `db.py`, `app.py` (2026-04-02)
- Project requirements: `.planning/PROJECT.md` (2026-04-02)
- Existing architecture doc: `.planning/codebase/ARCHITECTURE.md` (2026-04-02)
- SQLAlchemy 2.0 session patterns: `future=True` style confirmed in `db.py`
- SentenceTransformers `all-MiniLM-L6-v2`: 384-dim, confirmed in project config
- OpenAI model: `gpt-4.1-mini`, confirmed in project constraints

---

*Architecture research for: Flask 3-tier product catalog with multi-database RAG*
*Researched: 2026-04-02*
