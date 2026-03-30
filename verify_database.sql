-- ============================================================================
-- Datenbank Verifikations- und Test-Skript
-- ============================================================================
-- Beschreibung: Testet die Installation und Integrität der Datenbank
-- Version: 1.0
-- Datum: 2026-03-29
-- ============================================================================

SELECT '============================================' AS '';
SELECT 'Datenbank-Verifikation' AS '';
SELECT NOW() AS Zeitstempel;
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

SELECT 'brands' AS Tabelle, COUNT(*) AS Anzahl, 5 AS Erwartet, 
    CASE WHEN COUNT(*) = 5 THEN '✓' ELSE '✗' END AS Status FROM brands
UNION ALL
SELECT 'categories', COUNT(*), 4, 
    CASE WHEN COUNT(*) = 4 THEN '✓' ELSE '✗' END FROM categories
UNION ALL
SELECT 'tags', COUNT(*), 5, 
    CASE WHEN COUNT(*) = 5 THEN '✓' ELSE '✗' END FROM tags
UNION ALL
SELECT 'products', COUNT(*), 500, 
    CASE WHEN COUNT(*) = 500 THEN '✓' ELSE '✗' END FROM products
UNION ALL
SELECT 'products_extended', COUNT(*), 500, 
    CASE WHEN COUNT(*) = 500 THEN '✓' ELSE '✗' END FROM products_extended
UNION ALL
SELECT 'products_500_new', COUNT(*), 500, 
    CASE WHEN COUNT(*) = 500 THEN '✓' ELSE '✗' END FROM products_500_new
UNION ALL
SELECT 'product_tags', COUNT(*), 995, 
    CASE WHEN COUNT(*) >= 990 AND COUNT(*) <= 1000 THEN '✓' ELSE '✗' END FROM product_tags;

-- ============================================================================
-- 3. Foreign Key Integrität prüfen
-- ============================================================================

SELECT '' AS '';
SELECT '3. FOREIGN KEY INTEGRITÄT' AS '';
SELECT '--------------------------------------------' AS '';

-- Prüfe products
SELECT 
    'products → brands' AS Beziehung,
    COUNT(*) AS 'Ungültige Referenzen',
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END AS Status
FROM products p
LEFT JOIN brands b ON p.brand_id = b.id
WHERE b.id IS NULL

UNION ALL

SELECT 
    'products → categories',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
WHERE c.id IS NULL

UNION ALL

-- Prüfe products_extended
SELECT 
    'products_extended → brands',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products_extended p
LEFT JOIN brands b ON p.brand_id = b.id
WHERE b.id IS NULL

UNION ALL

SELECT 
    'products_extended → categories',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products_extended p
LEFT JOIN categories c ON p.category_id = c.id
WHERE c.id IS NULL

UNION ALL

-- Prüfe products_500_new
SELECT 
    'products_500_new → brands',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products_500_new p
LEFT JOIN brands b ON p.brand_id = b.id
WHERE b.id IS NULL

UNION ALL

SELECT 
    'products_500_new → categories',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products_500_new p
LEFT JOIN categories c ON p.category_id = c.id
WHERE c.id IS NULL

UNION ALL

-- Prüfe product_tags
SELECT 
    'product_tags → products',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM product_tags pt
LEFT JOIN products p ON pt.product_id = p.id
WHERE p.id IS NULL

UNION ALL

SELECT 
    'product_tags → tags',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM product_tags pt
LEFT JOIN tags t ON pt.tag_id = t.id
WHERE t.id IS NULL;

-- ============================================================================
-- 4. ID-Bereiche prüfen
-- ============================================================================

SELECT '' AS '';
SELECT '4. ID-BEREICHE' AS '';
SELECT '--------------------------------------------' AS '';

SELECT 
    'products' AS Tabelle,
    MIN(id) AS Min_ID,
    MAX(id) AS Max_ID,
    '1-500' AS 'Erwarteter Bereich',
    CASE WHEN MIN(id) = 1 AND MAX(id) = 500 THEN '✓' ELSE '✗' END AS Status
FROM products

UNION ALL

SELECT 
    'products_extended',
    MIN(id),
    MAX(id),
    '1-500',
    CASE WHEN MIN(id) = 1 AND MAX(id) = 500 THEN '✓' ELSE '✗' END
FROM products_extended

UNION ALL

SELECT 
    'products_500_new',
    MIN(id),
    MAX(id),
    '501-1000',
    CASE WHEN MIN(id) = 501 AND MAX(id) = 1000 THEN '✓' ELSE '✗' END
FROM products_500_new;

-- ============================================================================
-- 5. Preisvalidierung
-- ============================================================================

SELECT '' AS '';
SELECT '5. PREISVALIDIERUNG' AS '';
SELECT '--------------------------------------------' AS '';

SELECT 
    'products' AS Tabelle,
    MIN(price) AS Min_Preis,
    MAX(price) AS Max_Preis,
    ROUND(AVG(price), 2) AS Durchschnitt,
    CASE WHEN MIN(price) > 0 THEN '✓' ELSE '✗' END AS 'Alle > 0'
FROM products

UNION ALL

SELECT 
    'products_extended',
    MIN(price),
    MAX(price),
    ROUND(AVG(price), 2),
    CASE WHEN MIN(price) > 0 THEN '✓' ELSE '✗' END
FROM products_extended

UNION ALL

SELECT 
    'products_500_new',
    MIN(price),
    MAX(price),
    ROUND(AVG(price), 2),
    CASE WHEN MIN(price) > 0 THEN '✓' ELSE '✗' END
FROM products_500_new;

-- ============================================================================
-- 6. Enum-Werte prüfen (load_class, application)
-- ============================================================================

SELECT '' AS '';
SELECT '6. ENUM-WERTE VALIDIERUNG' AS '';
SELECT '--------------------------------------------' AS '';

-- Prüfe load_class in products_extended
SELECT 
    'products_extended.load_class' AS Feld,
    COUNT(*) AS 'Ungültige Werte',
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END AS Status
FROM products_extended
WHERE load_class NOT IN ('high', 'medium', 'low')

UNION ALL

-- Prüfe application in products_extended
SELECT 
    'products_extended.application',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products_extended
WHERE application NOT IN ('precision', 'automotive', 'industrial')

UNION ALL

-- Prüfe load_class in products_500_new
SELECT 
    'products_500_new.load_class',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products_500_new
WHERE load_class NOT IN ('high', 'medium', 'low')

UNION ALL

-- Prüfe application in products_500_new
SELECT 
    'products_500_new.application',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products_500_new
WHERE application NOT IN ('precision', 'automotive', 'industrial');

-- ============================================================================
-- 7. Stammdaten anzeigen
-- ============================================================================

SELECT '' AS '';
SELECT '7. STAMMDATEN ÜBERSICHT' AS '';
SELECT '--------------------------------------------' AS '';

SELECT 'BRANDS:' AS '';
SELECT id, name FROM brands ORDER BY id;

SELECT '' AS '';
SELECT 'CATEGORIES:' AS '';
SELECT id, name FROM categories ORDER BY id;

SELECT '' AS '';
SELECT 'TAGS:' AS '';
SELECT id, name FROM tags ORDER BY id;

-- ============================================================================
-- 8. Statistiken
-- ============================================================================

SELECT '' AS '';
SELECT '8. STATISTIKEN' AS '';
SELECT '--------------------------------------------' AS '';

-- Produkte pro Brand
SELECT 
    'Produkte pro Brand' AS Statistik,
    b.name AS Brand,
    COUNT(p.id) AS Anzahl
FROM brands b
LEFT JOIN products p ON b.id = p.brand_id
GROUP BY b.id, b.name
ORDER BY b.name;

SELECT '' AS '';

-- Produkte pro Category
SELECT 
    'Produkte pro Category' AS Statistik,
    c.name AS Category,
    COUNT(p.id) AS Anzahl
FROM categories c
LEFT JOIN products p ON c.id = p.category_id
GROUP BY c.id, c.name
ORDER BY c.name;

SELECT '' AS '';

-- Tags pro Produkt (Verteilung)
SELECT 
    'Tags pro Produkt' AS Statistik,
    tag_count AS 'Anzahl Tags',
    COUNT(*) AS 'Anzahl Produkte'
FROM (
    SELECT product_id, COUNT(*) AS tag_count
    FROM product_tags
    GROUP BY product_id
) AS tag_stats
GROUP BY tag_count
ORDER BY tag_count;

SELECT '' AS '';

-- Tag-Verwendung
SELECT 
    'Tag-Verwendung' AS Statistik,
    t.name AS Tag,
    COUNT(pt.product_id) AS 'Anzahl Produkte'
FROM tags t
LEFT JOIN product_tags pt ON t.id = pt.tag_id
GROUP BY t.id, t.name
ORDER BY COUNT(pt.product_id) DESC, t.name;

-- ============================================================================
-- 9. Beispiel-Abfragen (Datenqualität)
-- ============================================================================

SELECT '' AS '';
SELECT '9. DATENQUALITÄT-CHECKS' AS '';
SELECT '--------------------------------------------' AS '';

-- Prüfe auf leere Namen
SELECT 
    'Leere Namen (products)' AS Check,
    COUNT(*) AS Anzahl,
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END AS Status
FROM products
WHERE name IS NULL OR TRIM(name) = ''

UNION ALL

SELECT 
    'Leere Beschreibungen (products)',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products
WHERE description IS NULL OR TRIM(description) = ''

UNION ALL

-- Prüfe auf NULL-Werte in NOT NULL Feldern
SELECT 
    'NULL-Werte in brand_id (products)',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products
WHERE brand_id IS NULL

UNION ALL

SELECT 
    'NULL-Werte in category_id (products)',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products
WHERE category_id IS NULL

UNION ALL

SELECT 
    'NULL-Werte in price (products)',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓' ELSE '✗' END
FROM products
WHERE price IS NULL;

-- ============================================================================
-- 10. Beispiel-Joins testen
-- ============================================================================

SELECT '' AS '';
SELECT '10. JOIN-TESTS (erste 3 Produkte)' AS '';
SELECT '--------------------------------------------' AS '';

SELECT 
    p.id,
    p.name AS Produktname,
    b.name AS Brand,
    c.name AS Category,
    p.price AS Preis,
    GROUP_CONCAT(t.name ORDER BY t.name SEPARATOR ', ') AS Tags
FROM products p
JOIN brands b ON p.brand_id = b.id
JOIN categories c ON p.category_id = c.id
LEFT JOIN product_tags pt ON p.id = pt.product_id
LEFT JOIN tags t ON pt.tag_id = t.id
WHERE p.id <= 3
GROUP BY p.id, p.name, b.name, c.name, p.price
ORDER BY p.id;

-- ============================================================================
-- Zusammenfassung
-- ============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'Verifikation abgeschlossen!' AS Status;
SELECT NOW() AS Zeitstempel;
SELECT '============================================' AS '';
SELECT '' AS '';
SELECT 'Wenn alle Status-Checks ✓ zeigen, ist die' AS '';
SELECT 'Datenbank korrekt installiert und einsatzbereit.' AS '';
SELECT '============================================' AS '';
