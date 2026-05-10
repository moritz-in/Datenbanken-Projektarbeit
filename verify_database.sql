-- ============================================================================
-- Datenbank Verifikations- und Test-Skript
-- ============================================================================
-- Beschreibung: Prueft das finale relationale Schema mit pluralisierten Tabellen
--               sowie Trigger, Procedure und Import-Ergebnis.
-- Version: 3.0
-- Datum: 2026-05-10
-- ============================================================================

SELECT '============================================' AS '';
SELECT 'Datenbank-Verifikation' AS '';
SELECT NOW() AS zeitstempel;
SELECT DATABASE() AS datenbank;
SELECT '============================================' AS '';

-- ============================================================================
-- 1. Tabellenexistenz pruefen
-- ============================================================================
SELECT '' AS '';
SELECT '1. TABELLENEXISTENZ' AS '';
SELECT '--------------------------------------------' AS '';

SELECT
    table_name AS tabelle,
    table_rows AS geschaetzte_zeilen,
    ROUND((data_length + index_length) / 1024, 2) AS groesse_kb
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- ============================================================================
-- 2. Datenzaehlung und Plausibilitaetspruefung
-- ============================================================================
SELECT '' AS '';
SELECT '2. DATENZAEHLUNG' AS '';
SELECT '--------------------------------------------' AS '';

SELECT 'brands' AS tabelle, COUNT(*) AS anzahl, 5 AS erwartet,
    CASE WHEN COUNT(*) = 5 THEN 'OK' ELSE 'FEHLER' END AS status FROM brands
UNION ALL
SELECT 'categories', COUNT(*), 4,
    CASE WHEN COUNT(*) = 4 THEN 'OK' ELSE 'FEHLER' END FROM categories
UNION ALL
SELECT 'tags', COUNT(*), 5,
    CASE WHEN COUNT(*) = 5 THEN 'OK' ELSE 'FEHLER' END FROM tags
UNION ALL
SELECT 'products', COUNT(*), 1000,
    CASE WHEN COUNT(*) = 1000 THEN 'OK' ELSE 'FEHLER' END FROM products
UNION ALL
SELECT 'product_tags', COUNT(*), 995,
    CASE WHEN COUNT(*) = 995 THEN 'OK' ELSE 'FEHLER' END FROM product_tags;

-- ============================================================================
-- 3. Referenzielle Integritaet pruefen
-- ============================================================================
SELECT '' AS '';
SELECT '3. REFERENZIELLE INTEGRITAET' AS '';
SELECT '--------------------------------------------' AS '';

SELECT
    'products.brand_id -> brands.id' AS foreign_key_name,
    COUNT(*) AS verwaiste_eintraege,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FEHLER' END AS status
FROM products p
LEFT JOIN brands b ON p.brand_id = b.id
WHERE b.id IS NULL
UNION ALL
SELECT
    'products.category_id -> categories.id',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FEHLER' END
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
WHERE c.id IS NULL
UNION ALL
SELECT
    'product_tags.product_id -> products.id',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FEHLER' END
FROM product_tags pt
LEFT JOIN products p ON pt.product_id = p.id
WHERE p.id IS NULL
UNION ALL
SELECT
    'product_tags.tag_id -> tags.id',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FEHLER' END
FROM product_tags pt
LEFT JOIN tags t ON pt.tag_id = t.id
WHERE t.id IS NULL;

-- ============================================================================
-- 4. Constraints und Datenqualitaet pruefen
-- ============================================================================
SELECT '' AS '';
SELECT '4. CONSTRAINTS UND DATENQUALITAET' AS '';
SELECT '--------------------------------------------' AS '';

SELECT
    'brands.name UNIQUE' AS pruefung,
    COUNT(*) - COUNT(DISTINCT name) AS abweichungen,
    CASE WHEN COUNT(*) = COUNT(DISTINCT name) THEN 'OK' ELSE 'FEHLER' END AS status
FROM brands
UNION ALL
SELECT
    'categories.name UNIQUE',
    COUNT(*) - COUNT(DISTINCT name),
    CASE WHEN COUNT(*) = COUNT(DISTINCT name) THEN 'OK' ELSE 'FEHLER' END
FROM categories
UNION ALL
SELECT
    'tags.name UNIQUE',
    COUNT(*) - COUNT(DISTINCT name),
    CASE WHEN COUNT(*) = COUNT(DISTINCT name) THEN 'OK' ELSE 'FEHLER' END
FROM tags
UNION ALL
SELECT
    'products.sku UNIQUE',
    COUNT(sku) - COUNT(DISTINCT sku),
    CASE WHEN COUNT(sku) = COUNT(DISTINCT sku) THEN 'OK' ELSE 'FEHLER' END
FROM products
UNION ALL
SELECT
    'product_tags PK (product_id, tag_id)',
    SUM(CASE WHEN cnt > 1 THEN cnt - 1 ELSE 0 END),
    CASE WHEN SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END) = 0 THEN 'OK' ELSE 'FEHLER' END
FROM (
    SELECT product_id, tag_id, COUNT(*) AS cnt
    FROM product_tags
    GROUP BY product_id, tag_id
) duplicates;

SELECT
    'products.name NOT EMPTY' AS pruefung,
    COUNT(*) AS abweichungen,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FEHLER' END AS status
FROM products
WHERE name IS NULL OR TRIM(name) = ''
UNION ALL
SELECT
    'products.price >= 0',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FEHLER' END
FROM products
WHERE price < 0
UNION ALL
SELECT
    'products.brand_id NOT NULL',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FEHLER' END
FROM products
WHERE brand_id IS NULL
UNION ALL
SELECT
    'products.category_id NOT NULL',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FEHLER' END
FROM products
WHERE category_id IS NULL;

-- ============================================================================
-- 5. Trigger und Stored Procedure pruefen
-- ============================================================================
SELECT '' AS '';
SELECT '5. TRIGGER UND PROCEDURE' AS '';
SELECT '--------------------------------------------' AS '';

SELECT
    trigger_name AS objekt,
    event_object_table AS bezug,
    action_timing AS timing,
    event_manipulation AS ereignis
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
ORDER BY trigger_name;

SELECT
    routine_name AS objekt,
    routine_type AS typ,
    data_type AS rueckgabetyp
FROM information_schema.routines
WHERE routine_schema = DATABASE()
ORDER BY routine_name;

-- ============================================================================
-- 6. Statistiken
-- ============================================================================
SELECT '' AS '';
SELECT '6. STATISTIKEN' AS '';
SELECT '--------------------------------------------' AS '';

SELECT
    b.name AS marke,
    COUNT(p.id) AS anzahl_produkte
FROM brands b
LEFT JOIN products p ON b.id = p.brand_id
GROUP BY b.id, b.name
ORDER BY COUNT(p.id) DESC;

SELECT '--------------------------------------------' AS '';

SELECT
    c.name AS kategorie,
    COUNT(p.id) AS anzahl_produkte
FROM categories c
LEFT JOIN products p ON c.id = p.category_id
GROUP BY c.id, c.name
ORDER BY COUNT(p.id) DESC;

SELECT '--------------------------------------------' AS '';

SELECT
    t.name AS tag_name,
    COUNT(pt.product_id) AS anzahl_produkte
FROM tags t
LEFT JOIN product_tags pt ON t.id = pt.tag_id
GROUP BY t.id, t.name
ORDER BY COUNT(pt.product_id) DESC;

SELECT '--------------------------------------------' AS '';

SELECT
    'Preis Minimum' AS statistik,
    MIN(price) AS wert,
    'EUR' AS einheit
FROM products
UNION ALL
SELECT 'Preis Maximum', MAX(price), 'EUR' FROM products
UNION ALL
SELECT 'Preis Durchschnitt', ROUND(AVG(price), 2), 'EUR' FROM products;

-- ============================================================================
-- 7. Schema-Informationen
-- ============================================================================
SELECT '' AS '';
SELECT '7. SCHEMA-INFORMATIONEN' AS '';
SELECT '--------------------------------------------' AS '';

SELECT
    table_name AS tabelle,
    column_name AS spalte,
    'PRIMARY KEY' AS typ
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND constraint_name = 'PRIMARY'
ORDER BY table_name, ordinal_position;

SELECT '--------------------------------------------' AS '';

SELECT
    kcu.table_name AS tabelle,
    kcu.column_name AS spalte,
    kcu.referenced_table_name AS referenziert,
    kcu.referenced_column_name AS referenzspalte,
    rc.update_rule AS on_update_regel,
    rc.delete_rule AS on_delete_regel
FROM information_schema.key_column_usage kcu
JOIN information_schema.referential_constraints rc
  ON kcu.constraint_name = rc.constraint_name
 AND kcu.constraint_schema = rc.constraint_schema
WHERE kcu.table_schema = DATABASE()
  AND kcu.referenced_table_name IS NOT NULL
ORDER BY kcu.table_name, kcu.column_name;

SELECT '--------------------------------------------' AS '';

SELECT
    table_name AS tabelle,
    index_name AS index_name,
    GROUP_CONCAT(column_name ORDER BY seq_in_index) AS spalten,
    CASE non_unique WHEN 0 THEN 'UNIQUE' ELSE 'INDEX' END AS typ
FROM information_schema.statistics
WHERE table_schema = DATABASE()
GROUP BY table_name, index_name, non_unique
ORDER BY table_name, index_name;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'Verifikation abgeschlossen' AS status;
SELECT NOW() AS zeitstempel;
SELECT '============================================' AS '';
