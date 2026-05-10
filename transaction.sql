-- ============================================================================
-- A2 Transaktions-Demonstration
-- ============================================================================
-- Dieses Skript zeigt die gleichen Grundprinzipien wie die A2-Implementierung im
-- Anwendungscode: explizite Transaktionen, Commit, Rollback und atomare Aenderungen
-- ueber `products` und `product_tags`.
--
-- Ausfuehrung aus dem Repo-Root:
-- mysql -u root -p productdb < transaction.sql
-- ============================================================================

SET @demo_sku = 'TXN-DEMO-001';

-- Vorherige Demo-Daten sicher entfernen (wiederholbar)
START TRANSACTION;
DELETE FROM product_tags
WHERE product_id IN (SELECT id FROM products WHERE sku = @demo_sku);
DELETE FROM products WHERE sku = @demo_sku;
COMMIT;

-- ============================================================================
-- 1. CREATE + COMMIT
-- ============================================================================
START TRANSACTION;

INSERT INTO products (
    name,
    description,
    brand_id,
    category_id,
    price,
    sku,
    load_class,
    application,
    temperature_range
) VALUES (
    'Transaktions-Demo Produkt',
    'Demodatensatz fuer Commit- und Rollback-Nachweis',
    1,
    3,
    99.99,
    @demo_sku,
    'high',
    'industrial',
    '-20-120C'
);

SET @demo_product_id = LAST_INSERT_ID();

INSERT INTO product_tags (product_id, tag_id) VALUES (@demo_product_id, 1);
INSERT INTO product_tags (product_id, tag_id) VALUES (@demo_product_id, 4);

COMMIT;

SELECT 'Nach CREATE + COMMIT' AS phase;
SELECT id, name, sku, price FROM products WHERE id = @demo_product_id;
SELECT COUNT(*) AS tag_links FROM product_tags WHERE product_id = @demo_product_id;

-- ============================================================================
-- 2. UPDATE + ROLLBACK
-- ============================================================================
START TRANSACTION;

UPDATE products
SET price = 149.99,
    description = 'Dieser Text wird gleich per ROLLBACK verworfen'
WHERE id = @demo_product_id;

SELECT 'Innerhalb UPDATE-Transaktion vor ROLLBACK' AS phase;
SELECT id, sku, price, description FROM products WHERE id = @demo_product_id;

ROLLBACK;

SELECT 'Nach UPDATE + ROLLBACK' AS phase;
SELECT id, sku, price, description FROM products WHERE id = @demo_product_id;

-- ============================================================================
-- 3. DELETE + ROLLBACK
-- ============================================================================
START TRANSACTION;

DELETE FROM product_tags WHERE product_id = @demo_product_id;
DELETE FROM products WHERE id = @demo_product_id;

SELECT 'Innerhalb DELETE-Transaktion vor ROLLBACK' AS phase;
SELECT COUNT(*) AS produkt_zeilen FROM products WHERE id = @demo_product_id;
SELECT COUNT(*) AS tag_zeilen FROM product_tags WHERE product_id = @demo_product_id;

ROLLBACK;

SELECT 'Nach DELETE + ROLLBACK' AS phase;
SELECT COUNT(*) AS produkt_zeilen FROM products WHERE id = @demo_product_id;
SELECT COUNT(*) AS tag_zeilen FROM product_tags WHERE product_id = @demo_product_id;

-- ============================================================================
-- 4. Aufraeumen
-- ============================================================================
START TRANSACTION;
DELETE FROM product_tags WHERE product_id = @demo_product_id;
DELETE FROM products WHERE id = @demo_product_id;
COMMIT;

SELECT 'Transaktions-Demonstration abgeschlossen' AS status;
