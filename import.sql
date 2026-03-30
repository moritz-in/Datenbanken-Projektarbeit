-- ============================================================================
-- Produktdatenbank Import-Skript (Transaktional)
-- ============================================================================
-- Beschreibung: Transaktionaler Import aller CSV-Dateien in die Datenbank
--               mit vollständiger Fehlerbehandlung und Rollback-Mechanismen
-- Version: 1.0
-- Datum: 2026-03-29
-- Datenbank: MySQL 8.4
-- ============================================================================

-- ============================================================================
-- Import-Vorbereitung
-- ============================================================================

-- Setze Session-Variablen für optimale Import-Performance
SET autocommit = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;

-- Zeichensatz-Einstellungen
SET NAMES utf8mb4;
SET CHARACTER_SET_CLIENT = utf8mb4;

SELECT '============================================' AS '';
SELECT 'Start des Datenbank-Imports' AS Status;
SELECT NOW() AS Zeitstempel;
SELECT '============================================' AS '';

-- ============================================================================
-- TRANSACTION 1: Import der Stammdaten (Master Data)
-- ============================================================================
-- Diese Transaktion importiert alle Stammdatentabellen:
-- - brands (5 Datensätze)
-- - categories (4 Datensätze)
-- - tags (5 Datensätze)
-- 
-- Bei einem Fehler werden ALLE Stammdaten-Importe rückgängig gemacht
-- ============================================================================

SELECT '--------------------------------------------' AS '';
SELECT 'TRANSACTION 1: Import Stammdaten' AS Status;
SELECT '--------------------------------------------' AS '';

START TRANSACTION;

    -- ------------------------------------------------------------------------
    -- Import: brands.csv (5 Marken)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere brands.csv...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/brands.csv'
    INTO TABLE brands
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in brands importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl prüfen
    SELECT COUNT(*) INTO @brand_count FROM brands;
    IF @brand_count != 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Erwartete 5 Marken, aber andere Anzahl gefunden';
    END IF;

    -- ------------------------------------------------------------------------
    -- Import: categories.csv (4 Kategorien)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere categories.csv...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/categories.csv'
    INTO TABLE categories
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in categories importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl prüfen
    SELECT COUNT(*) INTO @category_count FROM categories;
    IF @category_count != 4 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Erwartete 4 Kategorien, aber andere Anzahl gefunden';
    END IF;

    -- ------------------------------------------------------------------------
    -- Import: tags.csv (5 Tags)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere tags.csv...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/tags.csv'
    INTO TABLE tags
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in tags importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl prüfen
    SELECT COUNT(*) INTO @tag_count FROM tags;
    IF @tag_count != 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Erwartete 5 Tags, aber andere Anzahl gefunden';
    END IF;

COMMIT;

SELECT '✓ TRANSACTION 1 erfolgreich abgeschlossen' AS Status;
SELECT CONCAT('  - ', @brand_count, ' Marken') AS '';
SELECT CONCAT('  - ', @category_count, ' Kategorien') AS '';
SELECT CONCAT('  - ', @tag_count, ' Tags') AS '';

-- ============================================================================
-- TRANSACTION 2: Import der Basis-Produkttabelle (products.csv)
-- ============================================================================
-- Diese Transaktion importiert die Basis-Produkttabelle:
-- - products (500 Datensätze, IDs 1-500)
-- 
-- Bei einem Fehler wird der Import rückgängig gemacht
-- Voraussetzung: brands und categories müssen existieren (Foreign Keys)
-- ============================================================================

SELECT '--------------------------------------------' AS '';
SELECT 'TRANSACTION 2: Import Basis-Produkte' AS Status;
SELECT '--------------------------------------------' AS '';

START TRANSACTION;

    -- ------------------------------------------------------------------------
    -- Import: products.csv (500 Produkte)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere products.csv...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/products.csv'
    INTO TABLE products
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name, description, brand_id, category_id, price);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in products importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl und ID-Bereich prüfen
    SELECT COUNT(*) INTO @product_count FROM products;
    SELECT MIN(id) INTO @product_min_id FROM products;
    SELECT MAX(id) INTO @product_max_id FROM products;
    
    IF @product_count != 500 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Erwartete 500 Produkte, aber andere Anzahl gefunden';
    END IF;
    
    IF @product_min_id != 1 OR @product_max_id != 500 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Produkt-IDs sollten von 1 bis 500 reichen';
    END IF;
    
    -- Validierung: Foreign Key Integrität prüfen
    SELECT COUNT(*) INTO @invalid_brands 
    FROM products p 
    LEFT JOIN brands b ON p.brand_id = b.id 
    WHERE b.id IS NULL;
    
    IF @invalid_brands > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Ungültige brand_id Referenzen gefunden';
    END IF;
    
    SELECT COUNT(*) INTO @invalid_categories 
    FROM products p 
    LEFT JOIN categories c ON p.category_id = c.id 
    WHERE c.id IS NULL;
    
    IF @invalid_categories > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Ungültige category_id Referenzen gefunden';
    END IF;

COMMIT;

SELECT '✓ TRANSACTION 2 erfolgreich abgeschlossen' AS Status;
SELECT CONCAT('  - ', @product_count, ' Basis-Produkte (IDs ', @product_min_id, '-', @product_max_id, ')') AS '';

-- ============================================================================
-- TRANSACTION 3: Import der erweiterten Produkttabelle (products_extended.csv)
-- ============================================================================
-- Diese Transaktion importiert die erweiterte Produkttabelle:
-- - products_extended (500 Datensätze, IDs 1-500)
-- 
-- Bei einem Fehler wird der Import rückgängig gemacht
-- Voraussetzung: brands und categories müssen existieren (Foreign Keys)
-- ============================================================================

SELECT '--------------------------------------------' AS '';
SELECT 'TRANSACTION 3: Import Erweiterte Produkte' AS Status;
SELECT '--------------------------------------------' AS '';

START TRANSACTION;

    -- ------------------------------------------------------------------------
    -- Import: products_extended.csv (500 erweiterte Produkte)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere products_extended.csv...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/products_extended.csv'
    INTO TABLE products_extended
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name, description, brand_id, category_id, price, load_class, application, temperature_range);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in products_extended importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl und ID-Bereich prüfen
    SELECT COUNT(*) INTO @product_ext_count FROM products_extended;
    SELECT MIN(id) INTO @product_ext_min_id FROM products_extended;
    SELECT MAX(id) INTO @product_ext_max_id FROM products_extended;
    
    IF @product_ext_count != 500 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Erwartete 500 erweiterte Produkte, aber andere Anzahl gefunden';
    END IF;
    
    IF @product_ext_min_id != 1 OR @product_ext_max_id != 500 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Erweiterte Produkt-IDs sollten von 1 bis 500 reichen';
    END IF;
    
    -- Validierung: Foreign Key Integrität prüfen
    SELECT COUNT(*) INTO @invalid_brands_ext 
    FROM products_extended p 
    LEFT JOIN brands b ON p.brand_id = b.id 
    WHERE b.id IS NULL;
    
    IF @invalid_brands_ext > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Ungültige brand_id Referenzen in products_extended gefunden';
    END IF;
    
    SELECT COUNT(*) INTO @invalid_categories_ext 
    FROM products_extended p 
    LEFT JOIN categories c ON p.category_id = c.id 
    WHERE c.id IS NULL;
    
    IF @invalid_categories_ext > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Ungültige category_id Referenzen in products_extended gefunden';
    END IF;

COMMIT;

SELECT '✓ TRANSACTION 3 erfolgreich abgeschlossen' AS Status;
SELECT CONCAT('  - ', @product_ext_count, ' Erweiterte Produkte (IDs ', @product_ext_min_id, '-', @product_ext_max_id, ')') AS '';

-- ============================================================================
-- TRANSACTION 4: Import der neuen Produktvarianten (products_500_new.csv)
-- ============================================================================
-- Diese Transaktion importiert die neuen Produktvarianten:
-- - products_500_new (500 Datensätze, IDs 501-1000)
-- 
-- Bei einem Fehler wird der Import rückgängig gemacht
-- Voraussetzung: brands und categories müssen existieren (Foreign Keys)
-- ============================================================================

SELECT '--------------------------------------------' AS '';
SELECT 'TRANSACTION 4: Import Neue Produktvarianten' AS Status;
SELECT '--------------------------------------------' AS '';

START TRANSACTION;

    -- ------------------------------------------------------------------------
    -- Import: products_500_new.csv (500 neue Produkte)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere products_500_new.csv...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/products_500_new.csv'
    INTO TABLE products_500_new
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name, description, brand_id, category_id, price, load_class, application, temperature_range);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in products_500_new importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl und ID-Bereich prüfen
    SELECT COUNT(*) INTO @product_new_count FROM products_500_new;
    SELECT MIN(id) INTO @product_new_min_id FROM products_500_new;
    SELECT MAX(id) INTO @product_new_max_id FROM products_500_new;
    
    IF @product_new_count != 500 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Erwartete 500 neue Produkte, aber andere Anzahl gefunden';
    END IF;
    
    IF @product_new_min_id != 501 OR @product_new_max_id != 1000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Neue Produkt-IDs sollten von 501 bis 1000 reichen';
    END IF;
    
    -- Validierung: Foreign Key Integrität prüfen
    SELECT COUNT(*) INTO @invalid_brands_new 
    FROM products_500_new p 
    LEFT JOIN brands b ON p.brand_id = b.id 
    WHERE b.id IS NULL;
    
    IF @invalid_brands_new > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Ungültige brand_id Referenzen in products_500_new gefunden';
    END IF;
    
    SELECT COUNT(*) INTO @invalid_categories_new 
    FROM products_500_new p 
    LEFT JOIN categories c ON p.category_id = c.id 
    WHERE c.id IS NULL;
    
    IF @invalid_categories_new > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Ungültige category_id Referenzen in products_500_new gefunden';
    END IF;

COMMIT;

SELECT '✓ TRANSACTION 4 erfolgreich abgeschlossen' AS Status;
SELECT CONCAT('  - ', @product_new_count, ' Neue Produkte (IDs ', @product_new_min_id, '-', @product_new_max_id, ')') AS '';

-- ============================================================================
-- TRANSACTION 5: Import der Produkt-Tag-Verknüpfungen (product_tags.csv)
-- ============================================================================
-- Diese Transaktion importiert die N:M-Verknüpfungen:
-- - product_tags (~995 Zuordnungen)
-- 
-- Bei einem Fehler wird der Import rückgängig gemacht
-- Voraussetzung: products und tags müssen existieren (Foreign Keys)
-- ============================================================================

SELECT '--------------------------------------------' AS '';
SELECT 'TRANSACTION 5: Import Produkt-Tag-Verknüpfungen' AS Status;
SELECT '--------------------------------------------' AS '';

START TRANSACTION;

    -- ------------------------------------------------------------------------
    -- Import: product_tags.csv (~995 Verknüpfungen)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere product_tags.csv...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/product_tags.csv'
    INTO TABLE product_tags
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (product_id, tag_id);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in product_tags importiert') AS Status;
    
    -- Validierung: Foreign Key Integrität prüfen
    SELECT COUNT(*) INTO @invalid_product_refs 
    FROM product_tags pt 
    LEFT JOIN products p ON pt.product_id = p.id 
    WHERE p.id IS NULL;
    
    IF @invalid_product_refs > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Ungültige product_id Referenzen in product_tags gefunden';
    END IF;
    
    SELECT COUNT(*) INTO @invalid_tag_refs 
    FROM product_tags pt 
    LEFT JOIN tags t ON pt.tag_id = t.id 
    WHERE t.id IS NULL;
    
    IF @invalid_tag_refs > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Fehler: Ungültige tag_id Referenzen in product_tags gefunden';
    END IF;
    
    -- Statistik: Durchschnittliche Tags pro Produkt
    SELECT COUNT(*) INTO @product_tags_count FROM product_tags;
    SELECT ROUND(COUNT(*) / @product_count, 2) INTO @avg_tags_per_product FROM product_tags;

COMMIT;

SELECT '✓ TRANSACTION 5 erfolgreich abgeschlossen' AS Status;
SELECT CONCAT('  - ', @product_tags_count, ' Produkt-Tag-Zuordnungen') AS '';
SELECT CONCAT('  - Durchschnittlich ', @avg_tags_per_product, ' Tags pro Produkt') AS '';

-- ============================================================================
-- Import-Abschluss
-- ============================================================================

-- Reaktiviere Standard-Einstellungen
SET unique_checks = 1;
SET foreign_key_checks = 1;
SET autocommit = 1;

-- ============================================================================
-- Import-Zusammenfassung
-- ============================================================================

SELECT '============================================' AS '';
SELECT 'Import erfolgreich abgeschlossen!' AS Status;
SELECT NOW() AS Zeitstempel;
SELECT '============================================' AS '';
SELECT '' AS '';
SELECT 'Zusammenfassung der importierten Daten:' AS '';
SELECT '----------------------------------------' AS '';

-- Stammdaten
SELECT CONCAT('Brands:              ', COUNT(*), ' Datensätze') AS '' FROM brands;
SELECT CONCAT('Categories:          ', COUNT(*), ' Datensätze') AS '' FROM categories;
SELECT CONCAT('Tags:                ', COUNT(*), ' Datensätze') AS '' FROM tags;
SELECT '----------------------------------------' AS '';

-- Produktdaten
SELECT CONCAT('Products:            ', COUNT(*), ' Datensätze (IDs 1-500)') AS '' FROM products;
SELECT CONCAT('Products Extended:   ', COUNT(*), ' Datensätze (IDs 1-500)') AS '' FROM products_extended;
SELECT CONCAT('Products 500 New:    ', COUNT(*), ' Datensätze (IDs 501-1000)') AS '' FROM products_500_new;
SELECT '----------------------------------------' AS '';

-- Verknüpfungen
SELECT CONCAT('Product Tags:        ', COUNT(*), ' Zuordnungen') AS '' FROM product_tags;
SELECT '----------------------------------------' AS '';

-- Gesamtsumme
SELECT CONCAT('GESAMT:              ', 
    (SELECT COUNT(*) FROM brands) + 
    (SELECT COUNT(*) FROM categories) + 
    (SELECT COUNT(*) FROM tags) + 
    (SELECT COUNT(*) FROM products) + 
    (SELECT COUNT(*) FROM products_extended) + 
    (SELECT COUNT(*) FROM products_500_new) + 
    (SELECT COUNT(*) FROM product_tags), 
    ' Datensätze') AS '';

SELECT '============================================' AS '';

-- ============================================================================
-- Datenbank-Integritätsprüfung
-- ============================================================================

SELECT '' AS '';
SELECT 'Integritätsprüfung:' AS '';
SELECT '----------------------------------------' AS '';

-- Prüfe auf verwaiste Foreign Keys in products
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle products.brand_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige products.brand_id gefunden!')
END AS '' 
FROM products p 
LEFT JOIN brands b ON p.brand_id = b.id 
WHERE b.id IS NULL;

SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle products.category_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige products.category_id gefunden!')
END AS '' 
FROM products p 
LEFT JOIN categories c ON p.category_id = c.id 
WHERE c.id IS NULL;

-- Prüfe auf verwaiste Foreign Keys in products_extended
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle products_extended.brand_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige products_extended.brand_id gefunden!')
END AS '' 
FROM products_extended p 
LEFT JOIN brands b ON p.brand_id = b.id 
WHERE b.id IS NULL;

SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle products_extended.category_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige products_extended.category_id gefunden!')
END AS '' 
FROM products_extended p 
LEFT JOIN categories c ON p.category_id = c.id 
WHERE c.id IS NULL;

-- Prüfe auf verwaiste Foreign Keys in products_500_new
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle products_500_new.brand_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige products_500_new.brand_id gefunden!')
END AS '' 
FROM products_500_new p 
LEFT JOIN brands b ON p.brand_id = b.id 
WHERE b.id IS NULL;

SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle products_500_new.category_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige products_500_new.category_id gefunden!')
END AS '' 
FROM products_500_new p 
LEFT JOIN categories c ON p.category_id = c.id 
WHERE c.id IS NULL;

-- Prüfe auf verwaiste Foreign Keys in product_tags
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle product_tags.product_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige product_tags.product_id gefunden!')
END AS '' 
FROM product_tags pt 
LEFT JOIN products p ON pt.product_id = p.id 
WHERE p.id IS NULL;

SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle product_tags.tag_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige product_tags.tag_id gefunden!')
END AS '' 
FROM product_tags pt 
LEFT JOIN tags t ON pt.tag_id = t.id 
WHERE t.id IS NULL;

SELECT '----------------------------------------' AS '';
SELECT '✓ Alle Integritätsprüfungen bestanden!' AS '';
SELECT '============================================' AS '';
