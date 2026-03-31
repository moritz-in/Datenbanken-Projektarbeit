-- ============================================================================
-- Datenbank Verifikations- und Test-Skript
-- ============================================================================
-- Beschreibung: Testet die Installation und Integrität der Datenbank
-- Version: 2.0
-- Datum: 2026-03-30
-- Angepasst für: brand, category, product, tag, product_tag
-- ============================================================================

SELECT '============================================' AS '';
SELECT 'Datenbank-Verifikation' AS '';
SELECT NOW() AS Zeitstempel;
SELECT DATABASE() AS Datenbank;
SELECT '============================================' AS '';

-- ============================================================================
-- 1. Tabellenexistenz prüfen
-- ============================================================================

SELECT '' AS '';
SELECT '1. TABELLENEXISTENZ' AS '';
SELECT '--------------------------------------------' AS '';

SELECT 
    table_name AS Tabelle,
    table_rows AS 'Geschätzte Zeilen',
    ROUND((data_length + index_length) / 1024, 2) AS 'Größe (KB)'
FROM information_schema.tables
WHERE table_schema = DATABASE()
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- ============================================================================
-- 2. Datenzählung und Plausibilitätsprüfung
-- ============================================================================

SELECT '' AS '';
SELECT '2. DATENZÄHLUNG' AS '';
SELECT '--------------------------------------------' AS '';

SELECT 'brand' AS Tabelle, COUNT(*) AS Anzahl, 5 AS Erwartet, 
    CASE WHEN COUNT(*) = 5 THEN '✓' ELSE '✗' END AS Status FROM brand
UNION ALL
SELECT 'category', COUNT(*), 4, 
    CASE WHEN COUNT(*) = 4 THEN '✓' ELSE '✗' END FROM category
UNION ALL
SELECT 'tag', COUNT(*), 5, 
    CASE WHEN COUNT(*) = 5 THEN '✓' ELSE '✗' END FROM tag
UNION ALL
SELECT 'product', COUNT(*), 1000, 
    CASE WHEN COUNT(*) = 1000 THEN '✓' ELSE '✗' END FROM product
UNION ALL
SELECT 'product_tag', COUNT(*), 995, 
    CASE WHEN COUNT(*) >= 900 THEN '✓' ELSE '✗' END FROM product_tag;

-- ============================================================================
-- 3. Referenzielle Integrität prüfen
-- ============================================================================

SELECT '' AS '';
SELECT '3. REFERENZIELLE INTEGRITÄT' AS '';
SELECT '--------------------------------------------' AS '';

-- Prüfe product.brand_id → brand.id
SELECT 
    'product.brand_id' AS 'Foreign Key',
    COUNT(*) AS 'Verwaiste Einträge',
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM product p
LEFT JOIN brand b ON p.brand_id = b.id
WHERE b.id IS NULL;

-- Prüfe product.category_id → category.id
SELECT 
    'product.category_id' AS 'Foreign Key',
    COUNT(*) AS 'Verwaiste Einträge',
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM product p
LEFT JOIN category c ON p.category_id = c.id
WHERE c.id IS NULL;

-- Prüfe product_tag.product_id → product.id
SELECT 
    'product_tag.product_id' AS 'Foreign Key',
    COUNT(*) AS 'Verwaiste Einträge',
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM product_tag pt
LEFT JOIN product p ON pt.product_id = p.id
WHERE p.id IS NULL;

-- Prüfe product_tag.tag_id → tag.id
SELECT 
    'product_tag.tag_id' AS 'Foreign Key',
    COUNT(*) AS 'Verwaiste Einträge',
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM product_tag pt
LEFT JOIN tag t ON pt.tag_id = t.id
WHERE t.id IS NULL;

-- ============================================================================
-- 4. UNIQUE Constraints prüfen
-- ============================================================================

SELECT '' AS '';
SELECT '4. UNIQUE CONSTRAINTS' AS '';
SELECT '--------------------------------------------' AS '';

-- Prüfe brand.name auf Duplikate
SELECT 
    'brand.name' AS Constraint,
    COUNT(*) - COUNT(DISTINCT name) AS Duplikate,
    CASE WHEN COUNT(*) = COUNT(DISTINCT name) THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM brand;

-- Prüfe category.name auf Duplikate
SELECT 
    'category.name' AS Constraint,
    COUNT(*) - COUNT(DISTINCT name) AS Duplikate,
    CASE WHEN COUNT(*) = COUNT(DISTINCT name) THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM category;

-- Prüfe tag.name auf Duplikate
SELECT 
    'tag.name' AS Constraint,
    COUNT(*) - COUNT(DISTINCT name) AS Duplikate,
    CASE WHEN COUNT(*) = COUNT(DISTINCT name) THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM tag;

-- Prüfe product_tag auf doppelte Verknüpfungen
SELECT 
    'product_tag (PK)' AS Constraint,
    SUM(CASE WHEN cnt > 1 THEN cnt - 1 ELSE 0 END) AS Duplikate,
    CASE WHEN SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM (
    SELECT product_id, tag_id, COUNT(*) as cnt
    FROM product_tag
    GROUP BY product_id, tag_id
) duplicates;

-- ============================================================================
-- 5. Datenqualität prüfen
-- ============================================================================

SELECT '' AS '';
SELECT '5. DATENQUALITÄT' AS '';
SELECT '--------------------------------------------' AS '';

-- Prüfe auf NULL-Werte in NOT NULL Spalten
SELECT 
    'product.name NOT NULL' AS Prüfung,
    COUNT(*) AS 'NULL-Werte',
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM product
WHERE name IS NULL OR TRIM(name) = '';

SELECT 
    'product.brand_id NOT NULL' AS Prüfung,
    COUNT(*) AS 'NULL-Werte',
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM product
WHERE brand_id IS NULL;

SELECT 
    'product.category_id NOT NULL' AS Prüfung,
    COUNT(*) AS 'NULL-Werte',
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM product
WHERE category_id IS NULL;

SELECT 
    'product.price NOT NULL' AS Prüfung,
    COUNT(*) AS 'NULL-Werte',
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM product
WHERE price IS NULL;

-- Prüfe auf negative Preise
SELECT 
    'product.price >= 0' AS Prüfung,
    COUNT(*) AS 'Negative Preise',
    CASE WHEN COUNT(*) = 0 THEN '✓ OK' ELSE '✗ FEHLER' END AS Status
FROM product
WHERE price < 0;

-- ============================================================================
-- 6. Statistiken
-- ============================================================================

SELECT '' AS '';
SELECT '6. STATISTIKEN' AS '';
SELECT '--------------------------------------------' AS '';

-- Produkte pro Marke
SELECT 
    b.name AS Marke,
    COUNT(p.id) AS 'Anzahl Produkte'
FROM brand b
LEFT JOIN product p ON b.id = p.brand_id
GROUP BY b.id, b.name
ORDER BY COUNT(p.id) DESC;

SELECT '--------------------------------------------' AS '';

-- Produkte pro Kategorie
SELECT 
    c.name AS Kategorie,
    COUNT(p.id) AS 'Anzahl Produkte'
FROM category c
LEFT JOIN product p ON c.id = p.category_id
GROUP BY c.id, c.name
ORDER BY COUNT(p.id) DESC;

SELECT '--------------------------------------------' AS '';

-- Tags Verwendung
SELECT 
    t.name AS Tag,
    COUNT(pt.product_id) AS 'Anzahl Produkte'
FROM tag t
LEFT JOIN product_tag pt ON t.id = pt.tag_id
GROUP BY t.id, t.name
ORDER BY COUNT(pt.product_id) DESC;

SELECT '--------------------------------------------' AS '';

-- Durchschnittliche Tags pro Produkt
SELECT 
    'Durchschnitt' AS Statistik,
    ROUND(COUNT(*) / (SELECT COUNT(DISTINCT product_id) FROM product_tag), 2) AS 'Tags pro Produkt'
FROM product_tag;

-- Produkte mit den meisten Tags
SELECT 
    p.id,
    p.name AS Produkt,
    COUNT(pt.tag_id) AS 'Anzahl Tags'
FROM product p
LEFT JOIN product_tag pt ON p.id = pt.product_id
GROUP BY p.id, p.name
ORDER BY COUNT(pt.tag_id) DESC
LIMIT 10;

SELECT '--------------------------------------------' AS '';

-- Preisstatistiken
SELECT 
    'Preis Minimum' AS Statistik,
    MIN(price) AS Wert,
    'EUR' AS Einheit
FROM product
UNION ALL
SELECT 'Preis Maximum', MAX(price), 'EUR' FROM product
UNION ALL
SELECT 'Preis Durchschnitt', ROUND(AVG(price), 2), 'EUR' FROM product
UNION ALL
SELECT 'Preis Median', 
    (SELECT price FROM (
        SELECT price, ROW_NUMBER() OVER (ORDER BY price) as rn,
               COUNT(*) OVER() as cnt
        FROM product
    ) t WHERE rn = FLOOR((cnt + 1) / 2)), 
    'EUR';

-- ============================================================================
-- 7. Schema-Informationen
-- ============================================================================

SELECT '' AS '';
SELECT '7. SCHEMA-INFORMATIONEN' AS '';
SELECT '--------------------------------------------' AS '';

-- Primary Keys
SELECT 
    table_name AS Tabelle,
    column_name AS Spalte,
    'PRIMARY KEY' AS Typ
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
AND constraint_name = 'PRIMARY'
ORDER BY table_name, ordinal_position;

SELECT '--------------------------------------------' AS '';

-- Foreign Keys
SELECT 
    kcu.table_name AS Tabelle,
    kcu.column_name AS Spalte,
    kcu.referenced_table_name AS 'Referenziert',
    kcu.referenced_column_name AS 'Spalte Referenz',
    rc.update_rule AS 'ON UPDATE',
    rc.delete_rule AS 'ON DELETE'
FROM information_schema.key_column_usage kcu
JOIN information_schema.referential_constraints rc
    ON kcu.constraint_name = rc.constraint_name
    AND kcu.constraint_schema = rc.constraint_schema
WHERE kcu.table_schema = DATABASE()
AND kcu.referenced_table_name IS NOT NULL
ORDER BY kcu.table_name, kcu.column_name;

SELECT '--------------------------------------------' AS '';

-- Indizes
SELECT 
    table_name AS Tabelle,
    index_name AS 'Index Name',
    GROUP_CONCAT(column_name ORDER BY seq_in_index) AS Spalten,
    CASE non_unique 
        WHEN 0 THEN 'UNIQUE'
        ELSE 'INDEX'
    END AS Typ
FROM information_schema.statistics
WHERE table_schema = DATABASE()
GROUP BY table_name, index_name, non_unique
ORDER BY table_name, index_name;

-- ============================================================================
-- Abschluss
-- ============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT '✓ Verifikation abgeschlossen' AS Status;
SELECT NOW() AS Zeitstempel;
SELECT '============================================' AS '';
