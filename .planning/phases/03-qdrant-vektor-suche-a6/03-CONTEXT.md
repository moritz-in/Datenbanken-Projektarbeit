# Phase 3: Qdrant Vektor-Suche (A6) - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Vector ETL pipeline: embed all 1000 products as 384-dimensional vectors and upsert to Qdrant. Semantic search on `/search` (unified tabbed UI). Index build page at `/index` (strategy C full rebuild). PDF upload at `/pdf-upload` (two collections). ETL run logged to `etl_run_log`. RAG and Graph search are Phase 4 — only SQL + vector search are functional in Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Produkt-Textformat (product_to_document)

- Structured with labels: `"Name: {name} Beschreibung: {description} Marke: {brand} Kategorie: {category} Tags: {tag1} {tag2}"`
- Include all available fields: name, description, brand, category, all tags
- Skip fields that are None or empty — do NOT include "None" strings or blank label lines
- Payload fields stored per Qdrant point: OpenCode's Discretion (must include at minimum what `search_unified.html` renders: `title`, `brand`, `price`, `score`, `doc_preview`)

### Search-Route Verhalten

- Route handles all 6 tab types (`sql`, `vector`, `rag`, `graph`, `pdf`, `pdf_mgmt`) in a single handler
- For Phase 4 methods (`rag_search`, `pdf_rag_search`, `search_product_pdfs`): catch `NotImplementedError`, return empty results — tabs render but show "Keine Ergebnisse". No 501 errors.
- Default active tab when visiting `/search` with no type parameter: `?type=vector` (Vector tab)
- SQL results returned as `list[dict]` — dynamic-column table rendering already handled by `search_unified.html`
- Empty Qdrant index: flash message `'Qdrant-Index leer — bitte zuerst Index aufbauen unter /index'` with a link to `/index`

### PDF-Upload-Scope

- Two collections implemented: `pdf_skripte` (teaching PDFs) and `pdf_produkte` (product-catalog PDFs)
- Chunk size: 300 characters (default in `extract_pdf_chunks()` signature — keep it)
- After successful upload: redirect to `/pdf-upload` + green flash: `'{n} Chunks indexiert'` (PRG pattern)
- File validation: `.pdf` extension only, max 50 MB — both already enforced in the template

### Index-Seite Verhalten

- Index build runs synchronously (blocking request) — no JS, no async polling. Acceptable for a demo with 1000 products (~10–20 sec).
- After successful build: redirect to `GET /index` + green flash: `'{count} Produkte in {elapsed:.1f}s indexiert (Strategie C)'`
- Index strategy: Strategy C only (full rebuild: `delete_collection()` + `create_collection()` + upsert all). Template already shows only C in the dropdown.
- On build failure: red flash with error message — `'Index-Build fehlgeschlagen: {error}'`
- "Index leeren" button (truncate) also redirects + green flash on success, red flash on failure

### OpenCode's Discretion

- Exact payload fields stored per Qdrant point (beyond the minimum needed for template rendering)
- ETL logging detail (exact `started_at` / `finished_at` timing implementation)
- Whether `get_index_status()` calls Qdrant `count()` or uses cached value
- `truncate_index()` internal implementation (whether it re-creates the collection immediately or leaves it absent)
- How `execute_sql_search()` is delegated to `ProductService` from `SearchService`

</decisions>

<specifics>
## Specific Ideas

- The `search_unified.html` template is already fully scaffolded with all 6 tabs and result rendering — the route just needs to populate the right template variables (`search_type`, `query`, `results`, `answer`)
- The `index.html` template already shows collection info (`hnsw_m`, `hnsw_ef_construct`, `vector_size`, `distance`, `points_count`) — `get_index_status()` must return a dict with at least these keys
- Strategy C is the ONLY strategy exposed — "C" label in template dropdown is already correct, do not change it

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets

- `services/__init__.py` → `ServiceFactory.get_index_service()`, `get_search_service()`, `get_pdf_service()`: all wired with correct dependencies (qdrant_repo, mysql_repo, embedding_model). Call these in routes — do not construct services manually.
- `ServiceFactory._get_embedding_model()`: double-checked locking singleton already fully implemented (Phase 0). `IndexService` and `SearchService` receive the model at construction time — no lazy-loading needed in the service methods.
- `templates/search_unified.html`: fully built 6-tab UI with result rendering. Route must pass: `search_type` (string), `query` (string), `results` (list), `answer` (string or None).
- `templates/index.html`: expects `status` dict with keys: `count_indexed`, `last_indexed_at`, `embedding_model`, `collection_info` (sub-dict: `name`, `vector_size`, `distance`, `points_count`, `hnsw_m`, `hnsw_ef_construct`).
- `templates/pdf_upload.html`: exists — verify its variable expectations before implementing the route.
- `repositories/qdrant_repository.py` → `QdrantRepositoryImpl.__init__`: client already constructed (`QdrantClient(url=qdrant_url)`). All methods are stubs awaiting implementation.
- `pdfplumber`: already imported in `qdrant_repository.py` — PDF text extraction library is available.

### Established Patterns

- PRG pattern (POST → redirect → GET with flash): used consistently in Phase 1 and Phase 2. All POST handlers in Phase 3 must follow this.
- Flash: `flash(message, "success")` / `flash(message, "danger")` — same as Phase 1.
- Factory access in routes: `ServiceFactory.get_*()` — never construct services directly.
- Logger: `log = logging.getLogger(__name__)` at module top.
- Config access: `current_app.config.get("KEY")` — not `os.getenv()`.

### Integration Points

- `routes/index.py` → `ServiceFactory.get_index_service()` → `IndexService.build_index(strategy="C")` → `QdrantRepositoryImpl` + `MySQLRepositoryImpl.load_products_for_index()` + `MySQLRepositoryImpl.log_etl_run()`
- `routes/search.py` → `ServiceFactory.get_search_service()` → `SearchService.vector_search()` or `execute_sql_search()` — depending on `request.args.get("type")`
- `routes/pdf.py` → `ServiceFactory.get_pdf_service()` → `PDFService` → `QdrantRepositoryImpl.upload_pdf_chunks()`
- `etl_run_log` table: already in schema (Phase 0). Columns: `id`, `strategy`, `started_at`, `finished_at`, `products_processed`, `products_written`, `status`, `error_msg`. `MySQLRepositoryImpl.log_etl_run()` is already implemented.

### Key Pitfalls (from STATE.md Pitfall Index)

- **Pitfall 6**: `ensure_collection()` MUST be called before every `upsert_points()` — not once at startup
- **Pitfall 7**: Always `.tolist()` on `numpy.ndarray` before constructing `PointStruct`
- **`wait=True`**: Always pass to `client.upsert()` — without it, subsequent `count()` or `search()` returns stale 0
- **No `recreate_collection`**: removed in Qdrant client v1.1.1+. Use `delete_collection()` + `create_collection()`.

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 3 scope.

</deferred>

---

*Phase: 03-qdrant-vektor-suche-a6*
*Context gathered: 2026-04-13*
