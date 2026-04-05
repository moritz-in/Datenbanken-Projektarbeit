---
phase: 01-mysql-crud-transaktionen-a2
plan: "03"
subsystem: products-crud-routes
tags: [flask, routes, crud, transactions, products, templates]
dependency_graph:
  requires:
    - MySQLRepositoryImpl.create_product()
    - MySQLRepositoryImpl.update_product()
    - MySQLRepositoryImpl.delete_product()
    - MySQLRepositoryImpl.get_product_by_id()
    - MySQLRepositoryImpl.get_brands()
    - MySQLRepositoryImpl.get_categories()
    - ProductService.create_product_with_relations()
    - ProductService.update_product()
    - ProductService.delete_product()
    - ProductService.get_product_by_id()
    - templates/product_form.html
  provides:
    - GET /products (updated with Actions column)
    - GET /products/new
    - POST /products/new
    - GET /products/<id>/edit
    - POST /products/<id>/edit
    - POST /products/<id>/delete
  affects:
    - Full CRUD UI complete — user can create, edit, delete products in browser
tech_stack:
  added: []
  patterns:
    - "PRG pattern — all successful POSTs redirect to /products"
    - "IntegrityError catch at route layer — shows red flash, re-renders form pre-filled"
    - "Single-click delete via POST form — no JS confirmation dialog"
    - "404 abort on missing product in edit route"
key_files:
  created: []
  modified:
    - routes/products.py
    - templates/products.html
    - repositories/mysql_repository.py
    - docker-compose.override.yml
decisions:
  - "IntegrityError caught at route layer — repository lets it propagate, route shows user-friendly flash"
  - "Delete is single-click POST form per CONTEXT.md — no JS confirmation, immediate action"
  - "PRG pattern enforced on all successful POSTs — prevents double-submit on browser refresh"
  - "Edit route 404-aborts on missing product — clean HTTP semantics"
  - "templates/ added to bind-mount in docker-compose.override.yml — enables live template reload"
metrics:
  duration: "9 minutes"
  completed: "2026-04-05"
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 4
---

# Phase 01 Plan 03: CRUD Routes + Actions Column Summary

**One-liner:** Full Flask CRUD route layer for products — create/edit/delete with PRG pattern, IntegrityError flash messaging, and Actions column in product list.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement full CRUD routes in routes/products.py | b535ebc | routes/products.py |
| 2 | Update products.html to add Actions column with Edit/Delete buttons | c3cae70 | templates/products.html |
| Auto-fix | Implement missing repository write methods + fix blocking issues | 5f546b8 | repositories/mysql_repository.py, docker-compose.override.yml |

---

## What Was Built

### routes/products.py (full replacement)

Six route handlers covering the complete CRUD flow:

- **`products()` (GET /products)** — Paginated product list (preserved from Plan 01)
- **`new_product()` (GET /products/new)** — Renders empty `product_form.html` in create mode with brand/category dropdowns
- **`create_product()` (POST /products/new)** — Validates required fields, parses price, calls `svc.create_product_with_relations()`; catches `IntegrityError` (TXN-04) and re-renders form pre-filled with red flash; on success → 302 redirect with green flash
- **`edit_product()` (GET /products/<id>/edit)** — Loads product via `svc.get_product_by_id()`, 404-aborts on missing; renders `product_form.html` in edit mode pre-filled (SKU readonly)
- **`update_product()` (POST /products/<id>/edit)** — Same validation as create; SKU not updated; catches `IntegrityError`; on success → 302 redirect with green flash
- **`delete_product()` (POST /products/<id>/delete)** — Single-click delete; catches `IntegrityError` (TXN-05) showing red flash if FK violation; always 302 redirect (PRG)

### templates/products.html (updated)

- Added "Aktionen" column header as 7th `<th>`
- Added per-row `Bearbeiten` link button (`btn-outline-secondary`) → `edit_product` route
- Added per-row `Löschen` form button (`btn-outline-danger`, `method="post"`) → `delete_product` route
- Added "Neues Produkt" button above table linking to `new_product` route
- Updated empty state `colspan` from 6 to 7

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan 02 stubs not implemented — write methods still raised NotImplementedError**
- **Found during:** Task 1 verification (GET /products/1/edit returned 501)
- **Issue:** `create_product()`, `update_product()`, `delete_product()`, `get_product_by_id()` in `MySQLRepositoryImpl` all still had `raise NotImplementedError("TODO: Phase 1 Plan 02")`. The Plan 02 executor wrote the stubs with updated comments but never replaced them with actual implementations.
- **Fix:** Implemented all four methods using `with session.begin():` transactions per Plan 02 SUMMARY.md spec
- **Files modified:** `repositories/mysql_repository.py`
- **Commit:** 5f546b8

**2. [Rule 1 - Bug] Wrong column name in get_product_by_id SELECT query**
- **Found during:** Auto-fix validation (500 error with `pymysql.err.OperationalError: Unknown column 'p.product_id'`)
- **Issue:** Query used `p.product_id` but the products table's primary key column is `id`. Needed `p.id AS product_id` in SELECT and `WHERE p.id = :product_id`.
- **Fix:** Changed SELECT and WHERE clause to use `p.id`, aliased as `product_id` for consistency with the rest of the codebase
- **Files modified:** `repositories/mysql_repository.py`
- **Commit:** 5f546b8

**3. [Rule 1 - Bug] currency column in INSERT not present in products schema**
- **Found during:** Schema inspection during auto-fix
- **Issue:** `create_product()` INSERT included `currency` column with `'EUR'` literal, but `products` table has no currency column (currency is added as literal `'EUR' AS currency` in SELECT queries only)
- **Fix:** Removed `currency` from INSERT column list and values
- **Files modified:** `repositories/mysql_repository.py`
- **Commit:** 5f546b8

**4. [Rule 3 - Blocking] templates/ directory not bind-mounted in docker-compose.override.yml**
- **Found during:** Task 2 verification (GET /products/new returned 500 with TemplateNotFound: product_form.html)
- **Issue:** `docker-compose.override.yml` bind-mounted `repositories/`, `services/`, and `routes/` but NOT `templates/`. So `product_form.html` (created in Plan 02) was only in the Docker image's baked-in copy, which predated Plan 02.
- **Fix:** Added `- ./templates:/app/templates:ro` to the volumes section
- **Files modified:** `docker-compose.override.yml`
- **Commit:** 5f546b8

---

## Requirements Fulfilled

| Requirement | Status |
|-------------|--------|
| TXN-04 | ✅ Duplicate SKU rollback demo: POST /products/new with duplicate SKU → IntegrityError caught → red flash, no partial row |
| TXN-05 | ✅ Referential integrity rollback demo: POST /products/<id>/delete with FK violation → red flash, product intact |
| TXN-08 | ✅ Full CRUD routes with flash messages: create, edit, delete all working with success/danger flash |

---

## Transaction Demonstrations (TXN-04, TXN-05)

**TXN-04 (duplicate SKU):** Create product with SKU "X". Try to create another with SKU "X" → route catches `IntegrityError` from `session.begin()` → re-renders create form with red flash "Datenbankfehler: Produkt konnte nicht angelegt werden (z.B. doppelte SKU)." — only 1 row in DB.

**TXN-05 (referential integrity):** If a product is referenced by a foreign key in another table (e.g., an order line), `DELETE FROM products WHERE id=<id>` raises `IntegrityError` → route catches it → redirects to list with red flash "Datenbankfehler: Produkt konnte nicht gelöscht werden (referenzielle Integrität)." — product remains in DB.

---

## Self-Check: PASSED

Files exist:
- ✅ routes/products.py (modified — 6 route handlers)
- ✅ templates/products.html (modified — 7 columns, Actions column added)
- ✅ repositories/mysql_repository.py (modified — write methods implemented)
- ✅ docker-compose.override.yml (modified — templates/ bind-mount added)

Commits exist:
- ✅ b535ebc — feat(01-03): implement full CRUD routes in routes/products.py
- ✅ c3cae70 — feat(01-03): add Actions column to products.html with Edit/Delete buttons
- ✅ 5f546b8 — fix(01-03): implement missing repository write methods and fix blocking issues

End-to-end smoke test results (all ✅):
- GET /products → 200
- GET /products/new → 200
- POST /products/new (empty fields) → 200 (re-render with validation error)
- POST /products/new (valid data) → 302 (redirect to list + green flash)
- GET /products/1/edit → 200 (pre-filled form)
- POST /products/1/edit → 302 (redirect to list + green flash)
- POST /products/1/delete → 302 (redirect to list + green flash)
- POST /products/new (duplicate SKU) → 200 (re-render with red flash, TXN-04 demo)
