# Phase 1: MySQL CRUD & Transaktionen (A2) - Context

**Gathered:** 2026-04-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Web UI for creating, updating, and deleting products through separate form pages, with full transaction safety enforced at the repository layer. Includes two visible rollback demonstrations (duplicate SKU, referential integrity) surfaced through the standard CRUD error paths. Dashboard (ROUTE-01) shows real MySQL counts and placeholder status for all 3 DBs. No Qdrant or Neo4j implementation — those are Phases 3 and 4.

</domain>

<decisions>
## Implementation Decisions

### CRUD Form Layout

- **Separate pages** for create and edit forms: `GET /products/new`, `GET /products/<id>/edit`, `POST` for submit
- **Actions column** in the product list table at the far right — Edit and Delete buttons per row
- **Delete is single-click** — no confirmation dialog; POST form with delete action, immediate
- **Redirect to list + green flash** after successful create, update, or delete (PRG pattern)
- On validation/DB error: **re-render form pre-filled** with submitted data + red flash banner at top

### Rollback Demo UX

- **Natural CRUD error paths** — no dedicated demo section or page
  - Duplicate SKU: user tries to create/update with an existing SKU → MySQL unique constraint → SQLAlchemy IntegrityError → rollback → re-render form with red flash
  - Referential integrity: user tries to delete a product that has tags in product_tags → FK constraint → rollback → list page with red flash
- Error messages: **generic** — "Datenbankfehler" or similar; the rollback itself is the evidence, not a verbose message
- Form re-rendered pre-filled on error (user doesn't lose their input)

### Product Form Fields

- **Core fields only** on create/edit forms: name, SKU, price, brand (dropdown), category (dropdown), tags (comma-separated text input)
- Brand and category: **dropdowns populated from DB** (SELECT from brands / categories tables)
- Tags: **comma-separated text input** — service splits and resolves to tag IDs / inserts new tags
- **SKU is read-only on the edit form** — visible but not editable; prevents accidental unique constraint violations on update
- description, load_class, application, temperature_range — not in forms for Phase 1

### Dashboard (ROUTE-01) Phase 1 Scope

- MySQL counts: **products, brands, categories, tags** — exactly the 4 counts the template already shows
- ETL last_runs: **query etl_run_log table** (will be empty in Phase 1) — template shows "Keine Runs vorhanden." — no fake data
- Qdrant stats: **zeros/dashes placeholders** — `{"indexed": 0, "last_indexed_at": "-", "embedding_model": "-"}` — template renders without errors
- System status badges: **all 3 DBs shown** — MySQL: green (connected), Qdrant: grey ("nicht indexiert"), Neo4j: grey ("nicht verbunden") — satisfies ROUTE-01's "System-Status aller 3 DBs" without Phase 3/4 work

### OpenCode's Discretion

- Exact Bootstrap 5 component choices for edit/delete buttons in the actions column (btn-sm, btn-outline-*, icon or text)
- How tags are split and matched on the backend (exact string matching vs case-insensitive)
- Whether to add a "Create Product" button/link to the products list page header or a nav item
- Template file names for create and edit pages (e.g., `product_form.html` shared vs `product_create.html` + `product_edit.html`)
- Exact pagination behavior when a product is deleted from the last page

</decisions>

<specifics>
## Specific Ideas

- SKU read-only on edit is the mechanism that makes TXN-04's duplicate SKU demo fully reliable: the user must set SKU at create time, then try to create another with the same SKU — constraint fires, rollback visible
- "Keine Runs vorhanden" empty state on dashboard is fine — it honestly reflects the state before Phase 3 runs

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets

- `templates/products.html`: paginated product list already built (table with ID, Name, Brand, Category, Tags, Price columns + Bootstrap pagination). Needs an "Actions" column added.
- `templates/dashboard.html`: fully scaffolded with MySQL counts, Qdrant section, and ETL run log table. Just needs `get_dashboard_data()` to return the right shape.
- `templates/base.html`: Bootstrap 5, Flash message rendering already wired — `get_flashed_messages(with_categories=True)` likely used
- `repositories/__init__.py`: `RepositoryFactory.get_mysql_repository()` already implemented with threading.Lock singleton (Phase 0)
- `services/product_service.py`: stub class already exists with `list_products_joined()` and `get_dashboard_data()` signatures — needs all methods implemented

### Established Patterns

- Session: always `with self._session_factory() as session:` — never bare `session = factory()`
- Transactions: `with session.begin():` exclusively — no `text("COMMIT")`
- Config access: `current_app.config.get("KEY")` from within service/repo methods
- Logger: `log = logging.getLogger(__name__)` at module top
- Flash: `flash(message, "success")` / `flash(message, "danger")` + redirect (PRG pattern)
- Factory access in routes: `ServiceFactory.get_product_service()` → `RepositoryFactory.get_mysql_repository()`

### Integration Points

- `routes/products.py`: blueprint `bp = Blueprint("products", __name__)` already registered — needs GET /products, GET /products/new, POST /products/new, GET /products/<id>/edit, POST /products/<id>/edit, POST /products/<id>/delete
- `routes/dashboard.py`: blueprint already registered — needs GET / implemented
- `services/product_service.py`: `ProductService.__init__` takes `(mysql_repo, qdrant_repo)` — Phase 1 can pass a NoOp or None for qdrant_repo for dashboard placeholders
- `db.py`: `mysql_session_factory` available — `MySQLRepositoryImpl` already wired to it in Phase 0

### Write methods NOT yet in mysql_repository.py ABC

- `create_product()`, `update_product()`, `delete_product()` — must be added to both `MySQLRepository` ABC and `MySQLRepositoryImpl`
- `get_brands()`, `get_categories()`, `get_tags()` — needed to populate dropdown/tag options in forms
- `load_products_for_index()` is already stubbed in `MySQLRepositoryImpl` (Phase 3 dependency) but not in ABC — note for researcher

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within Phase 1 scope

</deferred>

---

*Phase: 01-mysql-crud-transaktionen-a2*
*Context gathered: 2026-04-04*
