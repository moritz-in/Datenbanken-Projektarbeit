-- ============================================================================
-- Produktdatenbank Import-Skript fuer Docker/Adminer (CSV-basiert, validiert)
-- ============================================================================
-- Ausfuehrung in Adminer oder im MySQL-Container:
--   Dieses Skript nutzt serverseitiges LOAD DATA INFILE.
--
-- Voraussetzungen:
-- 1. Der MySQL-Container laeuft ueber docker compose.
-- 2. ./data ist im Container unter /csv gemountet.
-- 3. Das Schema wurde bereits erstellt.
-- ============================================================================

SET autocommit = 0;
SET NAMES utf8mb4;

-- ============================================================================
-- TRANSACTION: Vollimport mit Abschlussvalidierung
-- ============================================================================
START TRANSACTION;

LOAD DATA INFILE '/csv/brands.csv'
INTO TABLE brands
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name);

LOAD DATA INFILE '/csv/categories.csv'
INTO TABLE categories
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name);

LOAD DATA INFILE '/csv/tags.csv'
INTO TABLE tags
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name);

LOAD DATA INFILE '/csv/products_extended.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name, description, brand_id, category_id, price, load_class, application, temperature_range);

LOAD DATA INFILE '/csv/products_500_new.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name, description, brand_id, category_id, price, load_class, application, temperature_range);

LOAD DATA INFILE '/csv/product_tags.csv'
INTO TABLE product_tags
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, tag_id);

SELECT COUNT(*) INTO @brands_count FROM brands;
SELECT COUNT(*) INTO @categories_count FROM categories;
SELECT COUNT(*) INTO @tags_count FROM tags;
SELECT COUNT(*) INTO @products_count FROM products;
SELECT COUNT(*) INTO @product_tags_count FROM product_tags;

SET @import_ok = (
    @brands_count = 5
    AND @categories_count = 4
    AND @tags_count = 5
    AND @products_count = 1000
    AND @product_tags_count = 995
);

SET @finalize_sql = IF(@import_ok = 1, 'COMMIT', 'ROLLBACK');
PREPARE finalize_stmt FROM @finalize_sql;
EXECUTE finalize_stmt;
DEALLOCATE PREPARE finalize_stmt;

SET autocommit = 1;

SELECT CASE
    WHEN @import_ok = 1 THEN 'Import erfolgreich abgeschlossen'
    ELSE 'Import wegen Validierungsfehlern per ROLLBACK abgebrochen'
END AS Status;

SELECT 'brands' AS tabelle, @brands_count AS importiert, 5 AS erwartet,
    CASE WHEN @brands_count = 5 THEN 'OK' ELSE 'FEHLER' END AS status
UNION ALL
SELECT 'categories', @categories_count, 4,
    CASE WHEN @categories_count = 4 THEN 'OK' ELSE 'FEHLER' END
UNION ALL
SELECT 'tags', @tags_count, 5,
    CASE WHEN @tags_count = 5 THEN 'OK' ELSE 'FEHLER' END
UNION ALL
SELECT 'products', @products_count, 1000,
    CASE WHEN @products_count = 1000 THEN 'OK' ELSE 'FEHLER' END
UNION ALL
SELECT 'product_tags', @product_tags_count, 995,
    CASE WHEN @product_tags_count = 995 THEN 'OK' ELSE 'FEHLER' END;
