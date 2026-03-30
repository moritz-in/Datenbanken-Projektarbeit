-- ============================================================================
-- SQL Quick Reference - Häufige Abfragen
-- ============================================================================
-- Beschreibung: Sammlung nützlicher SQL-Abfragen für die Produktdatenbank
-- Version: 1.0
-- Datum: 2026-03-29
-- ============================================================================

-- ============================================================================
-- 1. GRUNDLEGENDE SELECT-ABFRAGEN
-- ============================================================================

-- Alle Marken anzeigen
SELECT * FROM brands ORDER BY name;

-- Alle Kategorien anzeigen
SELECT * FROM categories ORDER BY name;

-- Alle Tags anzeigen
SELECT * FROM tags ORDER BY name;

-- Erste 10 Produkte mit Details
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    c.name AS category,
    p.price
FROM products p
JOIN brands b ON p.brand_id = b.id
JOIN categories c ON p.category_id = c.id
LIMIT 10;

-- ============================================================================
-- 2. FILTERN UND SUCHEN
-- ============================================================================

-- Produkte einer bestimmten Marke
SELECT * FROM products 
WHERE brand_id = (SELECT id FROM brands WHERE name = 'SKF')
ORDER BY name;

-- Produkte in einem Preisbereich
SELECT 
    p.name,
    b.name AS brand,
    p.price
FROM products p
JOIN brands b ON p.brand_id = b.id
WHERE p.price BETWEEN 100 AND 200
ORDER BY p.price;

-- Produktsuche nach Name (Partial Match)
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    p.price
FROM products p
JOIN brands b ON p.brand_id = b.id
WHERE p.name LIKE '%SKF%'
ORDER BY p.name;

-- Erweiterte Produkte mit bestimmter Belastungsklasse
SELECT 
    p.name,
    b.name AS brand,
    p.load_class,
    p.application,
    p.temperature_range
FROM products_extended p
JOIN brands b ON p.brand_id = b.id
WHERE p.load_class = 'high'
ORDER BY p.price DESC;

-- ============================================================================
-- 3. JOINS UND VERKNÜPFUNGEN
-- ============================================================================

-- Produkte mit allen verknüpften Daten
SELECT 
    p.id,
    p.name AS product_name,
    b.name AS brand,
    c.name AS category,
    p.price,
    GROUP_CONCAT(t.name ORDER BY t.name SEPARATOR ', ') AS tags
FROM products p
JOIN brands b ON p.brand_id = b.id
JOIN categories c ON p.category_id = c.id
LEFT JOIN product_tags pt ON p.id = pt.product_id
LEFT JOIN tags t ON pt.tag_id = t.id
GROUP BY p.id, p.name, b.name, c.name, p.price
ORDER BY p.id
LIMIT 20;

-- Produkte mit einem bestimmten Tag
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    p.price
FROM products p
JOIN brands b ON p.brand_id = b.id
JOIN product_tags pt ON p.id = pt.product_id
JOIN tags t ON pt.tag_id = t.id
WHERE t.name = 'Premium'
ORDER BY p.price DESC;

-- Produkte mit mehreren Tags (AND-Verknüpfung)
SELECT DISTINCT
    p.id,
    p.name,
    b.name AS brand,
    p.price
FROM products p
JOIN brands b ON p.brand_id = b.id
WHERE p.id IN (
    SELECT product_id FROM product_tags WHERE tag_id = (SELECT id FROM tags WHERE name = 'Premium')
)
AND p.id IN (
    SELECT product_id FROM product_tags WHERE tag_id = (SELECT id FROM tags WHERE name = 'Industrie')
)
ORDER BY p.price DESC;

-- ============================================================================
-- 4. AGGREGATIONEN UND STATISTIKEN
-- ============================================================================

-- Anzahl Produkte pro Marke
SELECT 
    b.name AS brand,
    COUNT(p.id) AS product_count,
    MIN(p.price) AS min_price,
    MAX(p.price) AS max_price,
    ROUND(AVG(p.price), 2) AS avg_price
FROM brands b
LEFT JOIN products p ON b.id = p.brand_id
GROUP BY b.id, b.name
ORDER BY product_count DESC;

-- Anzahl Produkte pro Kategorie
SELECT 
    c.name AS category,
    COUNT(p.id) AS product_count,
    ROUND(AVG(p.price), 2) AS avg_price
FROM categories c
LEFT JOIN products p ON c.id = p.category_id
GROUP BY c.id, c.name
ORDER BY product_count DESC;

-- Tag-Statistiken
SELECT 
    t.name AS tag,
    COUNT(pt.product_id) AS usage_count,
    ROUND(COUNT(pt.product_id) * 100.0 / (SELECT COUNT(*) FROM products), 2) AS usage_percentage
FROM tags t
LEFT JOIN product_tags pt ON t.id = pt.tag_id
GROUP BY t.id, t.name
ORDER BY usage_count DESC;

-- Durchschnittliche Anzahl Tags pro Produkt
SELECT 
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM products), 2) AS avg_tags_per_product
FROM product_tags;

-- Preisverteilung
SELECT 
    CASE 
        WHEN price < 100 THEN '0-100 EUR'
        WHEN price < 200 THEN '100-200 EUR'
        WHEN price < 300 THEN '200-300 EUR'
        WHEN price < 400 THEN '300-400 EUR'
        ELSE '400+ EUR'
    END AS price_range,
    COUNT(*) AS product_count
FROM products
GROUP BY 
    CASE 
        WHEN price < 100 THEN '0-100 EUR'
        WHEN price < 200 THEN '100-200 EUR'
        WHEN price < 300 THEN '200-300 EUR'
        WHEN price < 400 THEN '300-400 EUR'
        ELSE '400+ EUR'
    END
ORDER BY MIN(price);

-- ============================================================================
-- 5. ERWEITERTE ABFRAGEN (products_extended)
-- ============================================================================

-- Verteilung nach Belastungsklasse
SELECT 
    load_class,
    COUNT(*) AS count,
    ROUND(AVG(price), 2) AS avg_price
FROM products_extended
GROUP BY load_class
ORDER BY 
    CASE load_class
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        WHEN 'low' THEN 3
    END;

-- Verteilung nach Anwendungsbereich
SELECT 
    application,
    COUNT(*) AS count,
    ROUND(AVG(price), 2) AS avg_price
FROM products_extended
GROUP BY application
ORDER BY count DESC;

-- Produkte mit spezifischen technischen Eigenschaften
SELECT 
    p.name,
    b.name AS brand,
    p.load_class,
    p.application,
    p.temperature_range,
    p.price
FROM products_extended p
JOIN brands b ON p.brand_id = b.id
WHERE p.load_class = 'high'
  AND p.application = 'precision'
ORDER BY p.price DESC
LIMIT 10;

-- Temperaturbereich-Analyse
SELECT 
    temperature_range,
    COUNT(*) AS count,
    ROUND(AVG(price), 2) AS avg_price
FROM products_extended
GROUP BY temperature_range
ORDER BY count DESC;

-- ============================================================================
-- 6. VERGLEICHE ZWISCHEN TABELLEN
-- ============================================================================

-- Preisvergleich: Basis vs. Variante B (gleiche ID)
SELECT 
    p1.id,
    p1.name AS original_name,
    p1.price AS original_price,
    p2.name AS variant_name,
    p2.price AS variant_price,
    ROUND(p2.price - p1.price, 2) AS price_difference,
    ROUND((p2.price - p1.price) / p1.price * 100, 2) AS price_change_percent
FROM products p1
JOIN products_500_new p2 ON p2.id = p1.id + 500
WHERE p1.id BETWEEN 1 AND 10
ORDER BY p1.id;

-- Durchschnittliche Preisdifferenz zwischen Original und Variante B
SELECT 
    ROUND(AVG(p2.price - p1.price), 2) AS avg_price_difference,
    ROUND(AVG((p2.price - p1.price) / p1.price * 100), 2) AS avg_price_increase_percent,
    COUNT(*) AS comparison_count
FROM products p1
JOIN products_500_new p2 ON p2.id = p1.id + 500;

-- ============================================================================
-- 7. TOP/BOTTOM-ABFRAGEN
-- ============================================================================

-- Top 10 teuerste Produkte
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    c.name AS category,
    p.price
FROM products p
JOIN brands b ON p.brand_id = b.id
JOIN categories c ON p.category_id = c.id
ORDER BY p.price DESC
LIMIT 10;

-- Top 10 günstigste Produkte
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    c.name AS category,
    p.price
FROM products p
JOIN brands b ON p.brand_id = b.id
JOIN categories c ON p.category_id = c.id
ORDER BY p.price ASC
LIMIT 10;

-- Produkte mit den meisten Tags
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    COUNT(pt.tag_id) AS tag_count,
    GROUP_CONCAT(t.name ORDER BY t.name SEPARATOR ', ') AS tags
FROM products p
JOIN brands b ON p.brand_id = b.id
JOIN product_tags pt ON p.id = pt.product_id
JOIN tags t ON pt.tag_id = t.id
GROUP BY p.id, p.name, b.name
ORDER BY tag_count DESC, p.name
LIMIT 10;

-- ============================================================================
-- 8. SUBQUERIES UND KOMPLEXE ABFRAGEN
-- ============================================================================

-- Produkte teurer als der Durchschnitt ihrer Kategorie
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    c.name AS category,
    p.price,
    cat_avg.avg_price AS category_avg_price,
    ROUND(p.price - cat_avg.avg_price, 2) AS price_above_avg
FROM products p
JOIN brands b ON p.brand_id = b.id
JOIN categories c ON p.category_id = c.id
JOIN (
    SELECT category_id, AVG(price) AS avg_price
    FROM products
    GROUP BY category_id
) cat_avg ON p.category_id = cat_avg.category_id
WHERE p.price > cat_avg.avg_price
ORDER BY price_above_avg DESC
LIMIT 20;

-- Marken mit überdurchschnittlich teuren Produkten
SELECT 
    b.name AS brand,
    COUNT(p.id) AS product_count,
    ROUND(AVG(p.price), 2) AS avg_price,
    (SELECT ROUND(AVG(price), 2) FROM products) AS overall_avg_price
FROM brands b
JOIN products p ON b.id = p.brand_id
GROUP BY b.id, b.name
HAVING AVG(p.price) > (SELECT AVG(price) FROM products)
ORDER BY avg_price DESC;

-- Produkte ohne Tags
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    p.price
FROM products p
JOIN brands b ON p.brand_id = b.id
LEFT JOIN product_tags pt ON p.id = pt.product_id
WHERE pt.product_id IS NULL
ORDER BY p.name;

-- ============================================================================
-- 9. DATENÄNDERUNGEN (MIT VORSICHT VERWENDEN!)
-- ============================================================================

-- WARNUNG: Diese Befehle ändern Daten!
-- Immer in einer Transaktion testen:

-- Beispiel: Preiserhöhung um 10% für eine Marke (in Transaktion)
/*
START TRANSACTION;
UPDATE products 
SET price = price * 1.10
WHERE brand_id = (SELECT id FROM brands WHERE name = 'SKF');
ROLLBACK;  -- oder COMMIT; wenn gewünscht
*/

-- ============================================================================
-- 10. PERFORMANCE-ANALYSEN
-- ============================================================================

-- Anzahl der Datensätze in allen Tabellen
SELECT 'brands' AS table_name, COUNT(*) AS row_count FROM brands
UNION ALL SELECT 'categories', COUNT(*) FROM categories
UNION ALL SELECT 'tags', COUNT(*) FROM tags
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'products_extended', COUNT(*) FROM products_extended
UNION ALL SELECT 'products_500_new', COUNT(*) FROM products_500_new
UNION ALL SELECT 'product_tags', COUNT(*) FROM product_tags;

-- Index-Nutzung prüfen (EXPLAIN verwenden)
EXPLAIN SELECT 
    p.name, b.name, p.price
FROM products p
JOIN brands b ON p.brand_id = b.id
WHERE p.price > 300;

-- Tabellengrößen anzeigen
SELECT 
    table_name,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY (data_length + index_length) DESC;

-- ============================================================================
-- 11. EXPORT-ABFRAGEN (für Reports)
-- ============================================================================

-- Vollständiger Produktkatalog (CSV-Export ready)
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    c.name AS category,
    p.price,
    p.description
FROM products p
JOIN brands b ON p.brand_id = b.id
JOIN categories c ON p.category_id = c.id
ORDER BY b.name, c.name, p.name;

-- Erweiterte Produktliste mit allen Spezifikationen
SELECT 
    p.id,
    p.name,
    b.name AS brand,
    c.name AS category,
    p.price,
    p.load_class,
    p.application,
    p.temperature_range,
    GROUP_CONCAT(t.name ORDER BY t.name SEPARATOR '; ') AS tags
FROM products_extended p
JOIN brands b ON p.brand_id = b.id
JOIN categories c ON p.category_id = c.id
LEFT JOIN (
    SELECT * FROM product_tags WHERE product_id <= 500
) pt ON p.id = pt.product_id
LEFT JOIN tags t ON pt.tag_id = t.id
GROUP BY p.id, p.name, b.name, c.name, p.price, p.load_class, p.application, p.temperature_range
ORDER BY p.id;

-- ============================================================================
-- ENDE DER QUICK REFERENCE
-- ============================================================================
