---
phase: 01-mysql-crud-transaktionen-a2
plan: "02"
subsystem: mysql-repository-service
tags: [mysql, sqlalchemy, crud, transactions, product-service, forms]
dependency_graph:
  requires: []
  provides:
    - MySQLRepositoryImpl.create_product()
    - MySQLRepositoryImpl.update_product()
    - MySQLRepositoryImpl.delete_product()
    - MySQLRepositoryImpl.get_product_by_id()
    - MySQLRepositoryImpl.get_brands()
    - MySQLRepositoryImpl.get_categories()
    - MySQLRepositoryImpl.get_tags()
    - ProductService.create_product_with_relations()
    - ProductService.update_product()
    - ProductService.delete_product()
    - ProductService.get_product_by_id()
    - ProductService.get_brands()
    - ProductService.get_categories()
    - templates/product_form.html
  affects:
    - routes/products.py (Plan 03 depends on these methods)
tech_stack:
  added: []
  patterns:
    - "with session.begin(): — SQLAlchemy 2.0 transaction management"
    - "Service layer assembles data dict; repository owns transaction"
    - "Tag resolution: comma-split → case-insensitive lookup → silent ignore unknown"
    - "SKU read-only: never in UPDATE SET clause"
key_files:
  created:
    - templates/product_form.html
  modified:
    - repositories/mysql_repository.py
    - services/product_service.py
decisions:
  - "SKU is immutable after creation — update_product() receives no sku argument and repo UPDATE SET excludes sku"
  - "Unknown tag names are silently ignored in _resolve_tag_ids() — no auto-create in Phase 1"
  - "IntegrityError propagates naturally from with session.begin() context manager — not caught in repo layer"
  - "delete_product() deletes product_tags FK first to avoid constraint violation before deleting products row"
metrics:
  duration: "3 minutes"
  completed: "2026-04-05"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
---

# Phase 01 Plan 02: MySQL Write Methods + Product Form Summary

**One-liner:** SQLAlchemy 2.0 transactional write methods (create/update/delete) for products using `with session.begin():`, with service-layer tag resolution and Bootstrap 5 shared create/edit form.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement MySQLRepositoryImpl write methods | 489d9da | repositories/mysql_repository.py |
| 2 | Implement ProductService write methods + product_form.html | 901635d | services/product_service.py, templates/product_form.html |

---

## What Was Built

### MySQLRepositoryImpl (repositories/mysql_repository.py)

**Lookup helpers:**
- `get_brands()` — `SELECT id, name FROM brands ORDER BY name` → `list[dict]`
- `get_categories()` — `SELECT id, name FROM categories ORDER BY name` → `list[dict]`
- `get_tags()` — `SELECT id, name FROM tags ORDER BY name` → `list[dict]`

**Read:**
- `get_product_by_id(product_id)` — LEFT JOIN brands/categories + separate tag fetch; returns `tags_str` for form pre-fill

**Write (all use `with session.begin():`):**
- `create_product(data)` — INSERT into products then product_tags for each tag_id; IntegrityError propagates (duplicate SKU rolls back automatically)
- `update_product(product_id, data)` — UPDATE products (no SKU); DELETE existing product_tags; re-INSERT new tags
- `delete_product(product_id)` — DELETE product_tags first (FK safety), then DELETE products; returns None

### ProductService (services/product_service.py)

- `create_product_with_relations(name, sku, price, brand_id, category_id, tags_str)` — assembles data dict after resolving tag IDs; delegates to repo
- `update_product(product_id, name, price, brand_id, category_id, tags_str)` — no SKU parameter (read-only); delegates to repo
- `delete_product(product_id)` — simple delegation
- `_resolve_tag_ids(tags_str)` — comma-split → strip → lowercase → match against `get_tags()`; unknown tags silently ignored
- `get_product_by_id(product_id)`, `get_brands()`, `get_categories()` — delegation methods

### templates/product_form.html

Shared Bootstrap 5 create/edit form template:
- Extends `base.html`
- `mode` variable controls title, form action URL, submit button label
- **Brand dropdown**: `<select name="brand_id">` populated from `brands` variable, pre-selected on edit
- **Category dropdown**: `<select name="category_id">` populated from `categories` variable, pre-selected on edit
- **SKU field**: visible always, `readonly` attribute added when `mode == "edit"` with informational hint text
- **Tags input**: `<input name="tags_str">` with placeholder "tag1, tag2, tag3"
- Cancel link → `url_for('products.products')`

---

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| SKU immutable after creation | CONTEXT.md locked decision — update_product() has no sku param, repo UPDATE excludes sku column |
| Unknown tags silently ignored | Phase 1 scope — no auto-create; tags must pre-exist; simpler UX without error |
| IntegrityError propagates to route layer | Plan 03 (routes/products.py) catches it and shows flash message — repository stays clean |
| product_tags deleted before products | FK constraint safety — MySQL enforces referential integrity; must clean join table first |
| Transaction in repository, not service | CONTEXT.md locked decision — service is stateless, repository owns session lifecycle |

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Requirements Fulfilled

| Requirement | Status |
|-------------|--------|
| TXN-01 | ✅ create_product() in transaction with rollback on IntegrityError |
| TXN-02 | ✅ update_product() SKU read-only enforced |
| TXN-03 | ✅ delete_product() product_tags-first deletion |
| TXN-06 | ✅ ProductService write methods delegate to repo |
| TXN-07 | ✅ product_form.html shared create/edit template with brand/category dropdowns |

---

## Self-Check: PASSED

Files exist:
- ✅ repositories/mysql_repository.py (modified)
- ✅ services/product_service.py (modified)  
- ✅ templates/product_form.html (created)

Commits exist:
- ✅ 489d9da — feat(01-02): implement MySQLRepositoryImpl write methods
- ✅ 901635d — feat(01-02): implement ProductService write methods + product_form.html
