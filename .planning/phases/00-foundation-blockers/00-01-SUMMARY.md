# Plan 00-01 Summary

## Objective
Rewrite schema.sql to fix all structural blockers: rename 5 tables to plural form everywhere, add etl_run_log DDL, add product_change_log DDL, add sku column to products.

## Tasks Completed

### Task 1: Rename tables to plural
- Renamed `brand` → `brands`, `category` → `categories`, `tag` → `tags`, `product` → `products`, `product_tag` → `product_tags`
- Updated all REFERENCES targets to plural names
- Updated all CREATE INDEX statements to use plural table names
- Kept both singular and plural DROP TABLE IF EXISTS for safe re-runs

### Task 2: Add etl_run_log, product_change_log DDL + sku column
- Added `etl_run_log` table BEFORE `products` (no FK dependency)
- Added `product_change_log` table AFTER `products` (FK to products.id)
- Added `sku VARCHAR(100) NULL` column to `products` with `UNIQUE` constraint

## Verification Results
- `CREATE TABLE` count: 7 (brands, categories, tags, etl_run_log, products, product_change_log, product_tags)
- All REFERENCES point to plural table names
- `sku VARCHAR(100)` column present in products
- `etl_run_log` and `product_change_log` CREATE TABLE statements present

## Requirements Covered
- FOUND-01: tables renamed to plural
- FOUND-02: etl_run_log DDL added
- FOUND-03: product_change_log DDL added
- FOUND-04: sku column added to products
