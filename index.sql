-- ============================================================================
-- A5 Index-Artefakt
-- ============================================================================
-- Standalone-Abgabedatei fuer die im Projekt verwendeten B-Tree-Indizes.
-- Das Skript legt fehlende Indizes an und kann gefahrlos erneut ausgefuehrt werden.
-- ============================================================================

SET @schema_name = DATABASE();

SELECT 'Index-Pruefung fuer products und product_tags' AS status;

SELECT COUNT(*) INTO @idx_exists
FROM information_schema.statistics
WHERE table_schema = @schema_name
  AND table_name = 'products'
  AND index_name = 'idx_products_brand';
SET @sql = IF(@idx_exists = 0,
    'CREATE INDEX idx_products_brand ON products(brand_id)',
    'SELECT ''idx_products_brand bereits vorhanden'' AS status');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @idx_exists
FROM information_schema.statistics
WHERE table_schema = @schema_name
  AND table_name = 'products'
  AND index_name = 'idx_products_category';
SET @sql = IF(@idx_exists = 0,
    'CREATE INDEX idx_products_category ON products(category_id)',
    'SELECT ''idx_products_category bereits vorhanden'' AS status');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @idx_exists
FROM information_schema.statistics
WHERE table_schema = @schema_name
  AND table_name = 'products'
  AND index_name = 'idx_products_price';
SET @sql = IF(@idx_exists = 0,
    'CREATE INDEX idx_products_price ON products(price)',
    'SELECT ''idx_products_price bereits vorhanden'' AS status');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @idx_exists
FROM information_schema.statistics
WHERE table_schema = @schema_name
  AND table_name = 'products'
  AND index_name = 'idx_products_name';
SET @sql = IF(@idx_exists = 0,
    'CREATE INDEX idx_products_name ON products(name)',
    'SELECT ''idx_products_name bereits vorhanden'' AS status');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @idx_exists
FROM information_schema.statistics
WHERE table_schema = @schema_name
  AND table_name = 'products'
  AND index_name = 'idx_products_load_class';
SET @sql = IF(@idx_exists = 0,
    'CREATE INDEX idx_products_load_class ON products(load_class)',
    'SELECT ''idx_products_load_class bereits vorhanden'' AS status');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @idx_exists
FROM information_schema.statistics
WHERE table_schema = @schema_name
  AND table_name = 'products'
  AND index_name = 'idx_products_application';
SET @sql = IF(@idx_exists = 0,
    'CREATE INDEX idx_products_application ON products(application)',
    'SELECT ''idx_products_application bereits vorhanden'' AS status');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @idx_exists
FROM information_schema.statistics
WHERE table_schema = @schema_name
  AND table_name = 'product_tags'
  AND index_name = 'idx_product_tags_tag';
SET @sql = IF(@idx_exists = 0,
    'CREATE INDEX idx_product_tags_tag ON product_tags(tag_id)',
    'SELECT ''idx_product_tags_tag bereits vorhanden'' AS status');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT 'EXPLAIN-Referenzabfragen fuer die Dokumentation' AS status;
SELECT 'EXPLAIN SELECT * FROM products WHERE name = ''Kugellager A1'';' AS query_1;
SELECT 'EXPLAIN SELECT * FROM products WHERE price BETWEEN 10 AND 50;' AS query_2;
SELECT 'EXPLAIN SELECT p.name, b.name AS brand FROM products p JOIN brands b ON p.brand_id = b.id WHERE b.name = ''Schaeffler'';' AS query_3;
