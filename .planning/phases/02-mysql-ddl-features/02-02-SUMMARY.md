---
phase: "02-mysql-ddl-features"
plan: "02"
subsystem: "mysql-stored-procedures"
tags: ["stored-procedure", "mysql", "ddl", "out-parameters", "validation"]
dependency_graph:
  requires: ["01-03"]
  provides: ["PROC-01", "PROC-02", "PROC-03", "PROC-04", "ROUTE-03"]
  affects: ["repositories/mysql_repository.py", "services/product_service.py", "routes/validate.py"]
tech_stack:
  added: []
  patterns:
    - "Raw DBAPI cursor for stored procedure OUT parameters (cursor.nextset() flush)"
    - "DELIMITER $$ wrapper for MySQL multi-statement procedure in init scripts"
    - "proc_label: BEGIN...END proc_label with LEAVE for early exit"
key_files:
  created:
    - mysql-init/03-procedures.sql
    - templates/validate_procedure.html
  modified:
    - repositories/mysql_repository.py
    - services/product_service.py
    - routes/validate.py
decisions:
  - "Use raw pymysql cursor (not SQLAlchemy text()) for CALL with OUT params — user variable syntax requires it"
  - "cursor.nextset() loop mandatory after every CALL — MySQL returns implicit result set that corrupts pool without flush"
  - "Brand fallback to id=1 when brand name not found — procedure never returns error for unknown brand"
  - "Category NOT NULL enforced in procedure — result_code=2 with German message for unknown category"
metrics:
  duration: "3 minutes"
  completed: "2026-04-13"
  tasks_completed: 2
  files_created: 2
  files_modified: 3
---

# Phase 02 Plan 02: Stored Procedure import_product() — Summary

**One-liner:** MySQL stored procedure with IN/OUT params, SQLEXCEPTION handler, and /validate/procedure UI wired through repository→service→route layers.

---

## What Was Built

### Task 1: mysql-init/03-procedures.sql
Created the `import_product()` stored procedure DDL:
- `DROP PROCEDURE IF EXISTS` for idempotent re-init
- `DELIMITER $$` wrapper required for multi-statement procedure in MySQL init scripts
- 8 IN params: `p_name`, `p_description`, `p_brand_name`, `p_category_name`, `p_price`, `p_sku`, `p_load_class`, `p_application`
- 2 OUT params: `p_result_code INT`, `p_result_message VARCHAR(500)`
- `DECLARE EXIT HANDLER FOR SQLEXCEPTION` → result_code=3, message='Datenbankfehler'
- `proc_label: BEGIN...END proc_label` pattern with `LEAVE proc_label` for early exits
- Validation: empty name/category or negative price → result_code=2 (German message)
- Duplicate SKU check: `SELECT COUNT(*) INTO @sku_count` → result_code=1 + `CONCAT('Doppelte SKU: ', p_sku)`
- Brand fallback: if brand name not found, falls back to `SELECT id FROM brands ORDER BY id LIMIT 1`
- Category required: `SELECT id INTO @cat_id ... IF @cat_id IS NULL` → result_code=2 + CONCAT message
- `INSERT INTO products ... NULLIF(TRIM(...), '')` for optional fields
- result_code=0, message=`CONCAT('Produkt importiert: ', p_name)` on success

### Task 2: Repository + Service + Route + Template wiring
- **MySQLRepository ABC**: added `call_import_product()` abstractmethod with full typed signature
- **MySQLRepositoryImpl**: implemented `call_import_product()` using raw pymysql cursor
  - `SET @rc = 0, @rm = ''` before CALL
  - `CALL import_product(%s, ..., @rc, @rm)` with positional params
  - `while cursor.nextset(): pass` — Pitfall 12 (mandatory result set flush)
  - `SELECT @rc AS result_code, @rm AS result_message` to read OUT params
  - `finally: cursor.close()` to prevent cursor leak
- **ProductService**: added `import_product()` method delegating to `mysql_repo.call_import_product()`
- **routes/validate.py**: added `/validate/procedure` GET+POST route
  - Imports `request` and `ServiceFactory`
  - POST: builds `form_data` dict, calls `svc.import_product()`, catches Exception → result_code=3
  - Renders `validate_procedure.html` with `result` and `form_data`
- **templates/validate_procedure.html**: Bootstrap 5 form + result display
  - Fields: name (required), sku, description, brand_name, category_name (required), price (number), load_class (select), application (select)
  - Result badge: green(code=0), yellow(code=1/2), red(code=3) with German labels
  - A4 educational note always visible
  - Link back to /validate schema validation

---

## Commits

| Task | Commit  | Message                                                        |
|------|---------|----------------------------------------------------------------|
| 1    | 58dc36b | feat(02-02): add import_product() stored procedure DDL         |
| 2    | 3f50fba | feat(02-02): wire import_product() through repository, service, validate route and template |

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Requirements Satisfied

| Requirement | Description                                       | Status   |
|-------------|---------------------------------------------------|----------|
| PROC-01     | Stored procedure import_product() exists in DDL   | ✅ Done  |
| PROC-02     | OUT parameters p_result_code + p_result_message   | ✅ Done  |
| PROC-03     | SQLEXCEPTION handler, duplicate check, validation | ✅ Done  |
| PROC-04     | call_import_product() in repository (nextset)     | ✅ Done  |
| ROUTE-03    | /validate/procedure route + template in Flask     | ✅ Done  |

---

## Self-Check: PASSED

- [x] `mysql-init/03-procedures.sql` exists
- [x] `templates/validate_procedure.html` exists
- [x] Commit `58dc36b` exists (git log verified)
- [x] Commit `3f50fba` exists (git log verified)
- [x] `grep -c "CREATE PROCEDURE import_product" mysql-init/03-procedures.sql` → 1
- [x] `grep -c "cursor.nextset" repositories/mysql_repository.py` → 2
- [x] Python syntax check passes for all 3 modified .py files
