-- ============================================================================
-- Produktdatenbank Import-Skript (CSV-basiert)
-- ============================================================================
-- WICHTIG: Dieses Skript muss mit --local-infile=1 ausgeführt werden:
-- mysql --local-infile=1 -u username -p datenbankname < import.sql
--
-- Voraussetzungen:
-- 1. Datenbank und Tabellen müssen bereits existieren (schema.sql ausführen)
-- 2. CSV-Dateien müssen im Verzeichnis '/csv/' liegen
-- 3. MySQL muss local_infile aktiviert haben
--
-- Version: 6.0 - CSV Import mit LOAD DATA LOCAL INFILE
-- Datum: 2026-03-30
-- ============================================================================

SET autocommit = 0;
-- SET unique_checks = 0;
-- SET foreign_key_checks = 0;
-- SET NAMES utf8mb4;

-- ============================================================================
-- TRANSACTION 1: Stammdaten (Brands, Categories, Tags)
-- ============================================================================
START TRANSACTION;

-- Import Brands (5 Einträge)
LOAD DATA INFILE '/csv/brands.csv'
IGNORE INTO TABLE brand
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name);

-- Import Categories (4 Einträge)
LOAD DATA INFILE '/csv/categories.csv'
INTO TABLE category
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name);

-- Import Tags (5 Einträge)
LOAD DATA INFILE '/csv/tags.csv'
INTO TABLE tag
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name);

-- COMMIT;

-- ============================================================================
-- TRANSACTION 2: Produkte 1-500
-- ============================================================================
-- START TRANSACTION;

LOAD DATA INFILE '/csv/products_extended.csv'
INTO TABLE product
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(id, name, description, brand_id, category_id, price, load_class, application, temperature_range);

-- COMMIT;

-- ============================================================================
-- TRANSACTION 3: Produkte 501-1000
-- ============================================================================
-- START TRANSACTION;

-- LOAD DATA LOCAL INFILE '/csv/products_500_new.csv'
-- INTO TABLE product
-- FIELDS TERMINATED BY ',' 
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 LINES
-- (id, name, description, brand_id, category_id, price, load_class, application, temperature_range);

-- COMMIT;

-- ============================================================================
-- TRANSACTION 4: Product-Tag Beziehungen (M:N)
-- ============================================================================
-- START TRANSACTION;

LOAD DATA INFILE '/csv/product_tags.csv'
INTO TABLE product_tag
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, tag_id);

COMMIT;

-- ============================================================================
-- Abschluss
-- ============================================================================
-- SET foreign_key_checks = 1;
-- SET unique_checks = 1;
SET autocommit = 1;

-- Erfolgsstatistik anzeigen
-- SELECT 'Import erfolgreich abgeschlossen!' AS Status;
-- SELECT COUNT(*) AS 'Brands importiert' FROM brand;
-- SELECT COUNT(*) AS 'Categories importiert' FROM category;
-- SELECT COUNT(*) AS 'Tags importiert' FROM tag;
-- SELECT COUNT(*) AS 'Produkte importiert' FROM product;
-- SELECT COUNT(*) AS 'Product-Tag Verknüpfungen importiert' FROM product_tag;
