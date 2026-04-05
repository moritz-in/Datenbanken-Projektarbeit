---
phase: 01-mysql-crud-transaktionen-a2
plan: "01"
subsystem: mysql-read-layer
tags: [mysql, sqlalchemy, flask, repository-pattern, read-path]
dependency_graph:
  requires: []
  provides: [get_products_with_joins, get_dashboard_stats, get_last_runs, get_brands, get_categories, get_tags, dashboard-route, products-list-route]
  affects: [routes/dashboard.py, routes/products.py, services/product_service.py, repositories/mysql_repository.py]
tech_stack:
  added: []
  patterns: [session-context-manager, union-all-counts, tag-attachment-via-separate-query, read-delegate-pattern]
key_files:
  created: [docker-compose.override.yml]
  modified:
    - repositories/mysql_repository.py
    - services/product_service.py
    - routes/dashboard.py
    - routes/products.py
decisions:
  - "Use 'EUR' AS currency literal in SELECT since products table has no currency column"
  - "docker-compose.override.yml bind-mounts src dirs to avoid full image rebuild on every code change"
  - "get_dashboard_stats() uses try/except to return error dict on DB failure — dashboard degrades gracefully"
  - "Tags fetched in second query with WHERE IN :ids to avoid N+1 — batch join pattern"
metrics:
  duration: "17m"
  completed: "2026-04-05"
  tasks: 2
  files_changed: 5
requirements:
  - ROUTE-01
---

# Phase 01 Plan 01: MySQL Read Layer + Dashboard/Products Routes Summary

**One-liner:** SQLAlchemy read-path via `with session_factory() as session` pattern — paginated products with brand/category/tag joins, dashboard UNION ALL count query, `'EUR' AS currency` literal fix, live bind-mount override.

---

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Implement MySQLRepositoryImpl read methods | 489d9da (pre-existing) | repositories/mysql_repository.py |
| 2 | ProductService read methods + dashboard/products routes | 888320f | services/product_service.py, routes/dashboard.py, routes/products.py, docker-compose.override.yml |

---

## Verification Results

```
GET /     → 200 ✅  (dashboard with real MySQL counts)
GET /products → 200 ✅  (paginated product list)
GET /products?page=2 → 200 ✅  (pagination works)
```

Dashboard shows:
- Real MySQL counts (Produkte, Marken, Kategorien, Tags) ✅
- "Keine Runs vorhanden." for empty `etl_run_log` ✅
- Qdrant section with 0 indexed / "-" placeholders (not an error) ✅

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed missing `currency` column in products table**
- **Found during:** Task 2 end-to-end testing
- **Issue:** `get_products_with_joins()` selected `p.currency` but the `products` table has no `currency` column — causes `OperationalError (1054, "Unknown column 'p.currency'")` on GET /products
- **Fix:** Changed query to use `'EUR' AS currency` literal (matches what `create_product` hardcodes as `'EUR'` in Plan 02 stub; template only uses it for display)
- **Files modified:** `repositories/mysql_repository.py`
- **Commit:** 888320f

**2. [Rule 3 - Blocking] Added `docker-compose.override.yml` for live code bind-mount**
- **Found during:** Task 2 end-to-end verification
- **Issue:** App container bakes code at build time; `docker compose restart` reloads old image — changes not picked up without full rebuild (which times out at 5+ min)
- **Fix:** Created `docker-compose.override.yml` that bind-mounts `./repositories`, `./services`, `./routes` as read-only volumes — allows code changes without rebuild
- **Files modified:** docker-compose.override.yml (created)
- **Commit:** 888320f

### Note on Pre-existing Commit

Task 1's work (`get_brands`, `get_categories`, `get_tags`, write method stubs for Plan 02) was already committed as `489d9da feat(01-02)` before this plan executed — the repository had been partially worked on. The ABC abstract method declarations and all read method implementations were included in that commit. No duplication or conflict; plan completed correctly.

---

## Key Implementation Decisions

1. **`'EUR' AS currency` literal** — Schema omits currency column; using hardcoded literal keeps template compatibility without DDL change
2. **`docker-compose.override.yml` bind-mount** — Avoids 5+ minute image rebuild cycle for live development; overrides only app service volumes
3. **Separate tag query with `WHERE IN :ids`** — Prevents N+1 queries; batch-fetches all tags for current page in one round-trip
4. **`get_dashboard_stats()` try/except** — Dashboard degrades gracefully on DB failure (shows `{"error": "..."}` instead of crashing)
5. **`run_timestamp = str(started_at)`** — Template uses as string; SQLAlchemy returns datetime object; str() conversion keeps it simple

---

## Self-Check

Files exist:
- [x] repositories/mysql_repository.py (modified)
- [x] services/product_service.py (modified)
- [x] routes/dashboard.py (modified)
- [x] routes/products.py (modified)
- [x] docker-compose.override.yml (created)

Commits:
- [x] 489d9da — pre-existing Task 1 commit (read methods implemented)
- [x] 888320f — Task 2 commit (service + routes + currency fix)

## Self-Check: PASSED
