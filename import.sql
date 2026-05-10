-- ============================================================================
-- Produktdatenbank Import-Skript (CSV-basiert)
-- ============================================================================
-- Ausfuehrung aus dem Repo-Root:
-- mysql --local-infile=1 -u root -p productdb < import.sql
--
-- Voraussetzungen:
-- 1. Das Schema aus schema.sql wurde bereits erstellt.
-- 2. Das Skript wird aus dem Projektverzeichnis ausgefuehrt.
-- 3. Die CSV-Dateien liegen im Ordner data/.
-- ============================================================================

SET autocommit = 0;
SET NAMES utf8mb4;

-- ============================================================================
-- TRANSACTION 1: Stammdaten importieren
-- ============================================================================
START TRANSACTION;

LOAD DATA LOCAL INFILE 'data/brands.csv'
INTO TABLE brands
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name);

LOAD DATA LOCAL INFILE 'data/categories.csv'
INTO TABLE categories
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name);

LOAD DATA LOCAL INFILE 'data/tags.csv'
INTO TABLE tags
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name);

COMMIT;

-- ============================================================================
-- TRANSACTION 2: Produktbatch 1 (IDs 1-500)
-- ============================================================================
START TRANSACTION;

LOAD DATA LOCAL INFILE 'data/products_extended.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name, description, brand_id, category_id, price, load_class, application, temperature_range);

COMMIT;

-- ============================================================================
-- TRANSACTION 3: Produktbatch 2 (IDs 501-1000)
-- ============================================================================
START TRANSACTION;

LOAD DATA LOCAL INFILE 'data/products_500_new.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name, description, brand_id, category_id, price, load_class, application, temperature_range);

COMMIT;

-- ============================================================================
-- TRANSACTION 4: M:N-Beziehungen importieren
-- ============================================================================
START TRANSACTION;

LOAD DATA LOCAL INFILE 'data/product_tags.csv'
INTO TABLE product_tags
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, tag_id);

COMMIT;

SET autocommit = 1;

SELECT 'Import erfolgreich abgeschlossen' AS Status;
SELECT COUNT(*) AS brands_importiert FROM brands;
SELECT COUNT(*) AS categories_importiert FROM categories;
SELECT COUNT(*) AS tags_importiert FROM tags;
SELECT COUNT(*) AS products_importiert FROM products;
SELECT COUNT(*) AS product_tags_importiert FROM product_tags;
