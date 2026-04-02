# Feature Research

**Domain:** University database demo app — Flask + MySQL + Qdrant + Neo4j product catalog
**Researched:** 2026-04-02
**Confidence:** HIGH (derived directly from scaffold code, templates, and schema — no guessing required)

---

## Context Note

This is not a product with market competitors. The "users" are one professor and a grading rubric. "Table stakes" = what the course requires as minimum to pass. "Differentiators" = what earns full marks and makes the demo compelling. "Anti-features" = things that seem helpful but create grading risk or implementation debt.

All feature descriptions are grounded in the existing scaffold: routes, templates, ABCs, and schema are already defined — the work is implementing the stubs correctly.

---

## Feature Landscape by Assignment

### A2 — Transactions (MySQL)

**What the professor expects (table stakes):**
- `create_product()`, `update_product()`, `delete_product()` wrapped in explicit `START TRANSACTION / COMMIT / ROLLBACK` — not relying on SQLAlchemy autocommit
- At least two demonstrable failure/rollback scenarios visible in the UI:
  1. **Duplicate SKU insert** → transaction rolls back, flash message shows the violation, no partial write in DB
  2. **Referential integrity violation** → e.g. deleting a brand that still has products → FK constraint triggers rollback, error shown
- Flash messages: green for success, red for rollback with reason

**What "well-implemented" looks like:**
```
# Pattern: explicit transaction block with rollback on exception
with session.begin():
    session.execute(text("INSERT INTO products ..."))
    session.execute(text("INSERT INTO product_tags ..."))
    # All-or-nothing: if product_tags insert fails, product row is also rolled back
```
The key teaching moment: show that WITHOUT a transaction, a failed `product_tags` insert would leave a partial product row. WITH a transaction, both either succeed or both fail.

**Product fields required for CRUD forms (derived from schema):**
- `name` (VARCHAR 255, NOT NULL, must not be empty after TRIM)
- `brand_id` (FK → brands, required — populate dropdown from brands table)
- `category_id` (FK → categories, required — populate dropdown from categories table)
- `price` (DECIMAL 10,2, NOT NULL, must be ≥ 0)
- `description` (TEXT, optional)
- `load_class` (enum: 'high'/'medium'/'low', nullable)
- `application` (enum: 'precision'/'automotive'/'industrial', nullable)
- `temperature_range` (VARCHAR 50, optional)
- `tags` (M:N via `product_tag` junction — multi-select, resolved in same transaction)

**SKU note:** The current `schema.sql` does NOT include a `sku` column on `product`, but PROJECT.md mentions "duplicate SKU → Rollback" as a demo scenario. Resolution: add a `sku VARCHAR(100) UNIQUE` column to the schema, or demonstrate uniqueness via the product `name` UNIQUE constraint instead. **Recommendation:** add `sku` column — it's the cleaner teaching example and matches what `import_product()` procedure validates.

---

### A3 — Triggers (MySQL)

**What the professor expects:**

A trigger defined in DDL that fires automatically on UPDATE — no application code should be needed to create the log entry.

**Trigger definition:**
```sql
DELIMITER $$
CREATE TRIGGER trg_products_after_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    INSERT INTO product_change_log (
        product_id,
        changed_at,
        field_name,
        old_value,
        new_value,
        changed_by
    ) VALUES
        (NEW.id, NOW(), 'name',        OLD.name,        NEW.name,        'system'),
        (NEW.id, NOW(), 'price',       OLD.price,       NEW.price,       'system'),
        (NEW.id, NOW(), 'brand_id',    OLD.brand_id,    NEW.brand_id,    'system'),
        (NEW.id, NOW(), 'category_id', OLD.category_id, NEW.category_id, 'system'),
        (NEW.id, NOW(), 'description', OLD.description, NEW.description, 'system');
END$$
DELIMITER ;
```

**`product_change_log` table schema (must be added to schema.sql):**
```sql
CREATE TABLE product_change_log (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    product_id    INT          NOT NULL,
    changed_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    field_name    VARCHAR(100) NOT NULL,
    old_value     TEXT,
    new_value     TEXT,
    changed_by    VARCHAR(100) NOT NULL DEFAULT 'system',

    PRIMARY KEY (id),
    INDEX idx_pcl_product_id (product_id),
    INDEX idx_pcl_changed_at (changed_at),

    -- FK optional: ON DELETE CASCADE so logs don't orphan if product is deleted
    CONSTRAINT fk_pcl_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Automatisch befüllte Änderungshistorie via MySQL Trigger';
```

**Why this schema:**
- `field_name` + `old_value` + `new_value` (TEXT) supports any field without schema changes
- One row per changed field = granular history, easily queryable ("show me all price changes")
- `changed_by` placeholder for future auth context; 'system' is safe default
- `BIGINT AUTO_INCREMENT` for id — product_change_log can grow large (1000 products × 5 fields × many updates)
- `ON DELETE CASCADE` on the FK — prevents orphaned log rows and satisfies referential integrity

**Demo scenario:** Update a product's price in the UI → visit the audit/change log page → see the trigger-created row without any Python code having written it. This is the key demonstration.

**Conditional logging option (better for grading):**
```sql
-- Only log if value actually changed
IF OLD.price <> NEW.price THEN
    INSERT INTO product_change_log (product_id, changed_at, field_name, old_value, new_value)
    VALUES (NEW.id, NOW(), 'price', OLD.price, NEW.price);
END IF;
```
This avoids log spam when no fields changed, and shows the student understands conditional trigger logic.

---

### A4 — Stored Procedure (MySQL)

**What the professor expects:**

A `CALL import_product(...)` stored procedure that validates and inserts a product — demonstrating server-side business logic in the DB layer.

**Complete procedure signature:**
```sql
CREATE PROCEDURE import_product(
    IN  p_name            VARCHAR(255),
    IN  p_description     TEXT,
    IN  p_brand_name      VARCHAR(100),    -- resolved to brand_id inside procedure
    IN  p_category_name   VARCHAR(100),    -- resolved to category_id inside procedure
    IN  p_price           DECIMAL(10,2),
    IN  p_sku             VARCHAR(100),    -- for duplicate detection
    IN  p_load_class      VARCHAR(50),
    IN  p_application     VARCHAR(50),
    OUT p_result_code     INT,             -- 0=success, 1=duplicate, 2=validation_error, 3=db_error
    OUT p_result_message  VARCHAR(500)
)
```

**Validation rules the procedure must enforce (ordered by priority):**

| Rule | Check | Error Code |
|------|-------|-----------|
| Name required | `p_name IS NULL OR TRIM(p_name) = ''` | 2 |
| Price required and non-negative | `p_price IS NULL OR p_price < 0` | 2 |
| Category required | `p_category_name IS NULL OR TRIM(p_category_name) = ''` | 2 |
| Brand required | `p_brand_name IS NULL OR TRIM(p_brand_name) = ''` | 2 |
| load_class valid enum | Must be NULL, 'high', 'medium', or 'low' | 2 |
| application valid enum | Must be NULL, 'precision', 'automotive', or 'industrial' | 2 |
| SKU duplicate check | `SELECT COUNT(*) FROM products WHERE sku = p_sku` > 0 | 1 |
| Name duplicate check | `SELECT COUNT(*) FROM products WHERE TRIM(name) = TRIM(p_name)` > 0 | 1 |
| Brand must exist | `SELECT id FROM brands WHERE name = p_brand_name` found | 3 if not found |
| Category must exist | `SELECT id FROM categories WHERE name = p_category_name` found | 3 if not found |

**Procedure body skeleton:**
```sql
BEGIN
    DECLARE v_brand_id INT;
    DECLARE v_category_id INT;
    DECLARE v_dup_count INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_code = 3;
        SET p_result_message = 'Datenbankfehler beim Import';
    END;

    -- 1. Pflichtfeld-Validierung
    IF TRIM(p_name) = '' OR p_name IS NULL THEN
        SET p_result_code = 2;
        SET p_result_message = 'name ist ein Pflichtfeld';
        LEAVE proc_label;
    END IF;
    -- ... weitere Validierungen ...

    -- 2. Dublettenprüfung (SKU)
    SELECT COUNT(*) INTO v_dup_count FROM products WHERE sku = p_sku;
    IF v_dup_count > 0 THEN
        SET p_result_code = 1;
        SET p_result_message = CONCAT('SKU bereits vorhanden: ', p_sku);
        LEAVE proc_label;
    END IF;

    -- 3. Brand und Category auflösen
    SELECT id INTO v_brand_id FROM brands WHERE name = p_brand_name LIMIT 1;
    IF v_brand_id IS NULL THEN
        SET p_result_code = 3;
        SET p_result_message = CONCAT('Unbekannte Marke: ', p_brand_name);
        LEAVE proc_label;
    END IF;

    -- 4. Insert in Transaktion
    START TRANSACTION;
    INSERT INTO products (name, description, brand_id, category_id, price, sku, ...)
    VALUES (TRIM(p_name), p_description, v_brand_id, v_category_id, p_price, p_sku, ...);
    COMMIT;

    SET p_result_code = 0;
    SET p_result_message = 'Produkt erfolgreich importiert';
END;
```

**How to call from Python (ProductService):**
```python
result = session.execute(
    text("CALL import_product(:name, :desc, :brand, :category, :price, :sku, :lc, :app, @rc, @rm)"),
    {"name": name, "desc": desc, ...}
)
row = session.execute(text("SELECT @rc AS code, @rm AS message")).mappings().one()
```

**Demo scenario:** Show the validate route calling the procedure with intentionally bad data (empty name, negative price, duplicate SKU) and displaying the OUT parameter error messages.

---

### A5 — Indexes & B-Tree (MySQL)

**What the professor expects:**

1. B-Tree indexes defined in DDL (already partially done in current `schema.sql` for `product` table)
2. `EXPLAIN` output **before** and **after** index for a representative query
3. Markdown analysis explaining why MySQL uses B-Trees

**Note on current state:** `schema.sql` already creates indexes on `product(brand_id)`, `product(category_id)`, `product(name)`, `product(price)`. These are on table `product` (singular). After the schema rename to plural (`products`), these need to be recreated as `CREATE INDEX idx_products_name ON products(name)` etc.

**EXPLAIN comparison structure (the Markdown document):**

```markdown
## Before Index (Full Table Scan)
Query: SELECT * FROM products WHERE name = 'SKF 6305 Rillenkugellager'
EXPLAIN output:
| id | select_type | table    | type | possible_keys | key  | rows | Extra       |
|----|-------------|----------|------|---------------|------|------|-------------|
|  1 | SIMPLE      | products | ALL  | NULL          | NULL | 1000 | Using where |
→ type=ALL: full scan of 1000 rows

## After Index
CREATE INDEX idx_products_name ON products(name);
EXPLAIN output:
| id | select_type | table    | type | possible_keys      | key                | rows | Extra |
|----|-------------|----------|------|--------------------|--------------------|------|-------|
|  1 | SIMPLE      | products | ref  | idx_products_name  | idx_products_name  |    1 |       |
→ type=ref: B-Tree lookup, 1 row examined
```

**Key EXPLAIN columns to highlight for teaching:**
- `type`: `ALL` (bad) vs `ref`/`range`/`const` (good)
- `key`: which index was used (NULL = no index)
- `rows`: estimated rows examined (lower = better)
- `Extra`: `Using where` (no index), `Using index` (index-only scan — best case)

**Three queries to EXPLAIN (for full marks):**
1. Exact match on name: `WHERE name = 'X'` → shows eq_ref after index
2. Range on price: `WHERE price BETWEEN 10 AND 100` → shows range scan
3. JOIN query: `products JOIN brands ON brand_id = brands.id WHERE brand_name = 'SKF'` → shows how FK index helps join

**B-Tree explanation points for Markdown:**
- B-Tree keeps keys sorted → supports range queries, ORDER BY without filesort, LIKE 'prefix%'
- Height is O(log N) → 1000 rows needs ~3 levels, 1M rows ~6 levels
- Each InnoDB page = 16 KB → fan-out ~1000 keys per page
- Hash index alternative: O(1) lookup but NO range support, NO ORDER BY — MySQL only supports HASH for MEMORY engine
- Composite index column order matters: `(category_id, brand_id)` serves `WHERE category_id = ?` but not `WHERE brand_id = ?` alone

---

### A6 — Vector DB & Semantic Search (Qdrant)

**What the professor expects:**

1. Products indexed as vectors in Qdrant (all 1000 products)
2. Semantic search returning top-k results with cosine similarity scores
3. Side-by-side comparison with SQL search in the UI (the tabbed search interface already exists in `search_unified.html`)

**Product-to-document conversion (what gets embedded):**
```python
def product_to_document(product: dict) -> str:
    """Converts a product dict to a text document for embedding."""
    parts = [
        product.get("name", ""),
        product.get("description") or "",
        f"Marke: {product.get('brand', '')}",
        f"Kategorie: {product.get('category', '')}",
        f"Preis: {product.get('price', '')} EUR",
    ]
    if tags := product.get("tags"):
        parts.append(f"Tags: {', '.join(tags)}")
    if lc := product.get("load_class"):
        parts.append(f"Lastklasse: {lc}")
    if app := product.get("application"):
        parts.append(f"Anwendung: {app}")
    return " | ".join(p for p in parts if p.strip())
```

**Qdrant point structure (what gets stored):**
```python
{
    "id": product["id"],          # Use MySQL product ID as Qdrant point ID
    "vector": embedding_vector,   # 384-dim float list from all-MiniLM-L6-v2
    "payload": {
        "mysql_id": product["id"],
        "title": product["name"],
        "brand": product["brand"],
        "category": product["category"],
        "price": float(product["price"]),
        "tags": product.get("tags", []),
        "doc_preview": document_text[:200],  # First 200 chars for display
    }
}
```

**Collection configuration:**
- Collection name: `products` (as configured in scaffold)
- Vector size: 384 (all-MiniLM-L6-v2 output dimension)
- Distance metric: COSINE
- HNSW m=16, ef_construct=128 (defaults are fine for 1000 vectors)

**ETL run logging (what goes into `etl_run_log`):**
```sql
CREATE TABLE etl_run_log (
    id                 BIGINT       NOT NULL AUTO_INCREMENT,
    run_timestamp      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    strategy           VARCHAR(10)  NOT NULL,     -- 'A', 'B', or 'C'
    products_processed INT          NOT NULL DEFAULT 0,
    products_written   INT          NOT NULL DEFAULT 0,
    duration_seconds   DECIMAL(8,2),              -- optional but useful
    status             VARCHAR(20)  NOT NULL DEFAULT 'success',
    error_message      TEXT,

    PRIMARY KEY (id),
    INDEX idx_erl_timestamp (run_timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='ETL Run-Log für Qdrant-Indexierungen';
```

**Semantic vs SQL comparison — what makes it compelling:**

The template already renders both side-by-side via tabs. The comparison needs to demonstrate:

| Query | SQL Result | Vector Result | Teaching Point |
|-------|-----------|----------------|----------------|
| `"Rollenlager für hohe Last"` | 0 results (no LIKE match) | Top-5 relevant products | Vector finds semantic matches SQL cannot |
| `"SELECT * FROM products WHERE name LIKE '%6305%'"` | Exact SKU match | N/A | SQL finds exact matches vector cannot |
| `"Kugellager Automotive"` | Results only if exact words present | Results including related bearing types | Semantic search finds related concepts |

The COMPARISON.md document should show this table with actual query examples from the product data.

**Index build strategies (A/B/C):**
- Strategy A: Append/upsert existing collection (idempotent, safe for incremental updates)
- Strategy B: Incremental — only update products modified since last run (requires `updated_at` column or ETL log)
- Strategy C: Full rebuild — delete collection, recreate, re-index all (slowest but guaranteed fresh)

For the course demo, Strategy C is the most demonstrable — student can rebuild in ~10 seconds for 1000 products.

---

### A7 — Graph DB & LLM/RAG (Neo4j + OpenAI)

**What the professor expects:**

1. Neo4j graph populated with products and their relationships
2. RAG pipeline: vector search → graph enrichment → LLM answer
3. Visible `graph_source` badge in results showing data came from Neo4j

**Neo4j graph schema (nodes and relationships):**
```cypher
// Nodes
(:Product  {mysql_id: 1, name: "SKF 6305", price: 12.99, description: "..."})
(:Brand    {name: "SKF"})
(:Category {name: "Kugellager"})
(:Tag      {name: "industrial"})

// Relationships
(:Product)-[:MADE_BY]->(:Brand)
(:Product)-[:IN_CATEGORY]->(:Category)
(:Product)-[:TAGGED_WITH]->(:Tag)
// Derived relationships (optional, for richer graph)
(:Product)-[:RELATED_TO]->(:Product)  // same brand + category
```

**Graph sync approach (MySQL → Neo4j):**
```cypher
// Upsert pattern — idempotent, safe to re-run
MERGE (p:Product {mysql_id: $mysql_id})
SET p.name = $name, p.price = $price, p.description = $description

MERGE (b:Brand {name: $brand_name})
MERGE (p)-[:MADE_BY]->(b)

MERGE (c:Category {name: $category_name})
MERGE (p)-[:IN_CATEGORY]->(c)

FOREACH (tag_name IN $tags |
    MERGE (t:Tag {name: tag_name})
    MERGE (p)-[:TAGGED_WITH]->(t)
)
```

**`get_product_relationships()` return structure:**
```python
{
    123: {
        "title": "SKF 6305 Rillenkugellager",
        "brand": "SKF",
        "category": "Kugellager",
        "tags": ["industrial", "premium"],
        # Optional enrichment:
        "related_products": ["SKF 6205", "SKF 6405"],  # same brand+category
        "graph_source": "Neo4j"
    }
}
```

**RAG pipeline (the full flow):**
```
User Query: "Welches Kugellager eignet sich für Automotive?"
    ↓
1. Embed query with all-MiniLM-L6-v2
    ↓
2. Qdrant search → top-5 products by cosine similarity
   (Qdrant payload has: title, brand, category, price, doc_preview)
    ↓
3. Neo4j enrichment → get_product_relationships([id1, id2, ...])
   Adds: exact brand name, category, tags, related products
   Marks each hit with graph_source="Neo4j" (or "Qdrant" if no Neo4j data)
    ↓
4. Build LLM context:
   "Produkte aus dem Katalog: [name, brand, category, price, tags × 5 products]"
    ↓
5. OpenAI gpt-4.1-mini completion:
   System: "Du bist ein Produktberater. Antworte auf Deutsch..."
   User: "Frage: {query}\n\nKatalog-Kontext:\n{context}"
    ↓
6. Return: {query, answer, hits: [{title, brand, category, tags, price, score, graph_source}]}
```

**LLM prompt structure (concrete):**
```python
system_prompt = (
    "Du bist ein kompetenter Produktberater für Lager und Industriekomponenten. "
    "Beantworte Fragen auf Deutsch, präzise und strukturiert. "
    "Verweise auf konkrete Produkte aus dem Kontext wenn möglich."
)

context_lines = []
for hit in hits:
    context_lines.append(
        f"- {hit['title']} | Marke: {hit['brand']} | "
        f"Kategorie: {hit['category']} | Preis: {hit['price']} EUR | "
        f"Tags: {', '.join(hit.get('tags', []))}"
    )

user_message = f"Frage: {query}\n\nVerfügbare Produkte:\n" + "\n".join(context_lines)
```

**What makes the demo compelling:**
- Query `"Lager für Hochtemperaturanwendungen"` → vector finds thermally-rated products → graph shows their full relationship context → LLM gives a structured recommendation
- The `graph_source` badge in `rag.html` visually distinguishes Neo4j-enriched hits from Qdrant-only hits
- Show what happens WITHOUT graph enrichment (just vector hits) vs. WITH graph enrichment (enriched with brand/category/tag relationships)

---

## Table Stakes (Minimum to Pass)

Features the professor considers baseline. Missing these = incomplete submission.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Product list with pagination | Scaffold template already built | LOW | `products.html` renders `result["items"]` |
| Explicit transaction blocks in CRUD | Course requirement A2 | MEDIUM | `START TRANSACTION / COMMIT / ROLLBACK` in Python, not ORM autocommit |
| At least one rollback demo scenario | A2 — must be demonstrable | LOW | Duplicate SKU or FK violation |
| `product_change_log` table + trigger DDL | A3 — core requirement | LOW | DDL + `AFTER UPDATE` trigger |
| Trigger fires on product update (no Python code) | A3 — the whole point | LOW | Verify by checking log table after update |
| `import_product()` stored procedure with validation | A4 | MEDIUM | OUT parameters for result code + message |
| Procedure callable from Flask (`CALL import_product(...)`) | A4 | LOW | SQLAlchemy `text()` with output params |
| B-Tree indexes in schema DDL | A5 | LOW | Already partially done — needs rename to plural |
| EXPLAIN before/after index (Markdown doc) | A5 | LOW | Static Markdown with captured output |
| Products indexed as vectors in Qdrant | A6 | MEDIUM | all-MiniLM-L6-v2, 384-dim, cosine |
| Semantic search route working | A6 | MEDIUM | `search_unified.html` tabs already built |
| `etl_run_log` table + logging | A6 prerequisite | LOW | Referenced in code, missing from schema |
| RAG route returning LLM answer | A7 | MEDIUM | `rag.html` template already built |
| Neo4j graph populated with product relationships | A7 | MEDIUM | MERGE pattern, idempotent |
| Graph enrichment visible in results (`graph_source` badge) | A7 | LOW | Template already renders it |
| Dashboard showing system stats | Supporting | LOW | `dashboard.html` template already built |
| `RepositoryFactory` and `ServiceFactory` implemented | Blocker for everything | HIGH | All `get_*()` methods must work |

---

## Differentiators (What Earns Full Marks)

Features that show deeper understanding beyond minimum requirements.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Conditional trigger (only log when value changed) | Shows `IF OLD.field <> NEW.field` logic, avoids log spam | LOW | Add `IF` blocks inside trigger body |
| Procedure with `DECLARE EXIT HANDLER FOR SQLEXCEPTION` | Proper error handling pattern in stored procedures | LOW | Demonstrates MySQL exception handling |
| Three EXPLAIN queries (exact, range, JOIN) | Shows complete index understanding, not just one case | LOW | Capture in Markdown, annotate each row |
| HNSW parameter explanation in COMPARISON.md | Shows understanding of vector index internals | LOW | m=16 means 16 bi-directional links per point |
| Graph sync idempotency via MERGE (not CREATE) | Prevents duplicate nodes on repeated sync | LOW | `MERGE (p:Product {mysql_id: $id})` |
| `related_products` Cypher query in Neo4j | Shows graph traversal beyond simple property lookup | MEDIUM | `MATCH (p)-[:MADE_BY]->(b)<-[:MADE_BY]-(other)` |
| ETL run duration tracking | Shows awareness of performance monitoring | LOW | Add `duration_seconds` to `etl_run_log` |
| `product_to_document()` includes all fields (name + brand + category + tags + description) | Better embedding quality = better search results | LOW | More context → better semantic matching |
| Strategy A/B/C index build options | Shows incremental update awareness | MEDIUM | Only needed if time permits — C alone is fine for demo |
| `COMPARISON.md` with concrete query examples | Shows empirical analysis not just theory | MEDIUM | 3 queries × 3 search methods = full matrix |

---

## Anti-Features (Avoid These)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| SQLAlchemy ORM models (declarative base) | Seems like "proper" Flask/SQLAlchemy style | Scaffold uses raw `text()` queries — adding ORM creates two competing patterns and breaks ABCs | Stick to `session.execute(text(...))` throughout |
| Async routes (async/await) | Flask 3.x supports async | Production async needs Quart or ASGI; Flask dev server async support is incomplete and adds complexity for no demo value | Keep all routes synchronous |
| PostgreSQL revival | `pg_session_factory` and `psycopg2-binary` already dead code | Reactivating adds another DB to maintain; out of scope per PROJECT.md | Delete dead code |
| Auth/login layer | "Demo needs login to protect data" | Out of scope per course requirements; adds session management complexity | Leave all routes public |
| JavaScript-heavy frontend (AJAX for search) | Feels more modern | Breaks the Jinja2 + server-render pattern; Scaffold is 100% server-side HTML | Keep POST/redirect/GET pattern |
| Streaming LLM responses (SSE) | Looks impressive | Requires async or a background thread; gpt-4.1-mini responses are fast enough for blocking call | Blocking `openai.chat.completions.create()` |
| Full-text index (MySQL MATCH AGAINST) | Could improve SQL search | Adds a fourth search type to compare; the course only requires SQL + vector + RAG comparison | Keep SQL search as simple LIKE or custom SELECT |
| Background task queue (Celery/RQ) for index build | Index build takes time | Over-engineering for 1000-product demo; blocking HTTP for ~10s is acceptable | Run `build_index()` synchronously, show spinner in UI |
| `BEFORE UPDATE` trigger (instead of AFTER) | Seems equivalent | Cannot see NEW values in BEFORE trigger for logging; AFTER UPDATE is the correct pattern for audit logs | Use `AFTER UPDATE ON products` |
| Storing embeddings in MySQL (BLOB) | "Keep everything in MySQL" | Defeats the purpose of the Qdrant assignment; demonstrates lack of understanding of vector DB value | Keep embeddings in Qdrant only |
| Recreating Neo4j driver on every request | Simpler code | Neo4j driver creation is expensive; singleton pattern already designed into `ServiceFactory` | Initialize driver once, reuse via singleton |

---

## Feature Dependencies

```
[RepositoryFactory + ServiceFactory]  ← BLOCKER: everything else depends on this
    ├──enables──> [A2: CRUD with transactions]
    │                 └──requires──> [schema.sql plural rename]
    │                 └──requires──> [product_change_log table]
    │
    ├──enables──> [A3: Trigger]
    │                 └──requires──> [product_change_log table]
    │                 └──requires──> [A2 products CRUD route working]  ← need update to test trigger
    │
    ├──enables──> [A4: Stored Procedure]
    │                 └──requires──> [schema.sql plural rename]
    │                 └──optional──> [A2 CRUD route for manual testing]
    │
    ├──enables──> [A5: Indexes + EXPLAIN]
    │                 └──requires──> [schema.sql plural rename]  ← indexes reference plural table names
    │
    ├──enables──> [A6: Qdrant vector search]
    │                 └──requires──> [etl_run_log table]
    │                 └──requires──> [QdrantRepositoryImpl]
    │                 └──requires──> [IndexService.build_index()]
    │
    └──enables──> [A7: Neo4j + RAG]
                      └──requires──> [A6 Qdrant search working]  ← RAG starts with vector retrieval
                      └──requires──> [Neo4jRepositoryImpl]
                      └──requires──> [OpenAI API key in .env]
                      └──enhances──> [A6 search] ← graph enriches vector hits

[NoOpNeo4jRepository fixed]  ← required so app starts without Neo4j configured
    └──blocks──> [any route that calls ServiceFactory.get_neo4j_repo()]
```

### Dependency Notes

- **Schema rename (singular→plural) must happen first:** `validation.py` hardcodes plural table names (`products`, `brands`, etc.); all service/repository code expects plural; schema has singular. Everything else breaks until this is fixed.
- **`etl_run_log` must exist before IndexService runs:** `MySQLRepositoryImpl.log_etl_run()` is called at the end of `build_index()`. If the table doesn't exist, the entire index build fails — even if the Qdrant write succeeded.
- **A7 requires A6 to work:** The RAG flow starts with vector search (`QdrantRepository.search()`), then optionally enriches with Neo4j. Neo4j cannot substitute for Qdrant — both must work.
- **A3 trigger fires on A2 update:** The trigger demonstration requires a working update form (A2) to trigger it. These two must be implemented together.

---

## MVP Definition

This is a course submission, so "MVP" = minimum needed to demonstrate all six assignments.

### Launch With (Submission-Ready)

- [x] Blocker fixes: schema rename, `etl_run_log` table, RepositoryFactory, ServiceFactory, NoOpNeo4jRepository
- [x] A2: `create_product()` + `update_product()` + `delete_product()` with transaction blocks + 1 rollback demo
- [x] A3: `product_change_log` table + `AFTER UPDATE` trigger DDL + trigger visible in demo
- [x] A4: `import_product()` stored procedure with name/price/category/SKU validation
- [x] A5: B-Tree indexes in DDL + EXPLAIN before/after in Markdown
- [x] A6: All 1000 products indexed in Qdrant + semantic search tab working
- [x] A7: Neo4j graph populated + RAG route returning LLM answer with graph enrichment

### Add After Core Works

- [ ] Strategy B/C index build options — add only if Strategy A is already proven
- [ ] Conditional trigger logging (IF OLD.x <> NEW.x) — easy upgrade once basic trigger works
- [ ] `related_products` via Neo4j graph traversal — add after basic `get_product_relationships()` works
- [ ] COMPARISON.md with three concrete query examples — write last, after all search modes work

### Out of Scope (Do Not Implement)

- [ ] User authentication — explicitly out of scope per PROJECT.md
- [ ] REST API / mobile frontend — out of scope
- [ ] CSRF protection — out of scope
- [ ] Gunicorn/production WSGI — Docker dev server is sufficient
- [ ] PostgreSQL revival — delete dead code instead

---

## Feature Prioritization Matrix

| Feature | Grading Value | Implementation Cost | Priority |
|---------|--------------|---------------------|----------|
| Blocker fixes (schema, factories, NoOp) | HIGH | MEDIUM | P1 |
| A2: Transaction CRUD + rollback demo | HIGH | MEDIUM | P1 |
| A3: Trigger + change log table | HIGH | LOW | P1 |
| A4: `import_product()` procedure | HIGH | MEDIUM | P1 |
| A5: Indexes + EXPLAIN Markdown | HIGH | LOW | P1 |
| A6: Qdrant index + semantic search | HIGH | MEDIUM | P1 |
| A7: Neo4j RAG + LLM answer | HIGH | HIGH | P1 |
| Dashboard + audit routes | MEDIUM | LOW | P2 |
| COMPARISON.md analysis | MEDIUM | LOW | P2 |
| Conditional trigger logic | LOW | LOW | P2 |
| Strategy B/C index builds | LOW | MEDIUM | P3 |
| Related products graph traversal | LOW | MEDIUM | P3 |
| PDF upload + RAG | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Required for full submission — implement first
- P2: Improves grade — implement after P1 is working
- P3: Nice to have — only if time permits

---

## Sources

- `schema.sql` — actual table definitions, constraints, column types (v2.0, 2026-03-30)
- `.planning/PROJECT.md` — explicit assignment requirements A2-A7
- `.planning/codebase/ARCHITECTURE.md` — 3-tier pattern, data flow, error handling
- `repositories/mysql_repository.py` — `log_etl_run()` signature with `strategy`, `products_processed`, `products_written`
- `repositories/qdrant_repository.py` — collection config, point structure, HNSW parameters
- `repositories/neo4j_repository.py` — `get_product_relationships()` return shape with `title`, `brand`, `category`, `tags`
- `services/search_service.py` — `rag_search(strategy, query, topk, use_graph_enrichment)` signature
- `services/index_service.py` — strategies A/B/C, `product_to_document()`, batch embedding
- `templates/search_unified.html` — tabbed UI (sql/vector/rag/graph/pdf) — already built
- `templates/rag.html` — result table with `graph_source` badge column — already built
- `templates/products.html` — renders `result["items"]` with `product_id`, `name`, `brand`, `category`, `tags`, `price`, `currency`
- `validation.py` — expects plural table names (`products`, `brands`, `categories`, `tags`, `product_tags`)
- `import.sql` — shows transaction pattern (`START TRANSACTION / COMMIT`) for multi-table import

---

*Feature research for: Datenbanken-Projektarbeit Teil 2 — Flask + MySQL + Qdrant + Neo4j product catalog*
*Researched: 2026-04-02*
