-- ============================================================================
-- Produktdatenbank Import-Skript (Transaktional & Wiederholbar)
-- ============================================================================
-- Beschreibung: Transaktionaler Import aller CSV-Dateien in die Datenbank
--               mit vollständiger Fehlerbehandlung und Rollback-Mechanismen
-- Version: 2.0
-- Datum: 2026-03-30
-- Datenbank: MySQL 8.4
-- ============================================================================
-- ANFORDERUNGEN:
--   ✓ Wiederholbar aufsetzbar (idempotent)
--   ✓ Saubere Primär- und Fremdschlüssel
--   ✓ M:N-Zuordnungstabelle (product_tag)
--   ✓ Verwendung von Transaktionen (START TRANSACTION / COMMIT / ROLLBACK)
--   ✓ Bei Fehlern keine inkonsistenten Daten
-- ============================================================================

-- ============================================================================
-- Import-Vorbereitung
-- ============================================================================

-- Setze Session-Variablen für optimale Import-Performance
SET autocommit = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;

-- Zeichensatz-Einstellungen für UTF-8 Unterstützung
SET NAMES utf8mb4;
SET CHARACTER_SET_CLIENT = utf8mb4;

SELECT '============================================' AS '';
SELECT 'Start des Datenbank-Imports' AS Status;
SELECT NOW() AS Zeitstempel;
SELECT DATABASE() AS Datenbank;
SELECT '============================================' AS '';

-- ============================================================================
-- TRANSACTION 1: Import der Stammdaten (Master Data)
-- ============================================================================
-- Importiert alle Stammdatentabellen:
-- - brand (5 Datensätze)
-- - category (4 Datensätze)
-- - tag (5 Datensätze)
-- 
-- ATOMARITÄT: Bei einem Fehler werden ALLE Stammdaten-Importe zurückgerollt
-- ============================================================================

SELECT '--------------------------------------------' AS '';
SELECT 'TRANSACTION 1: Import Stammdaten' AS Status;
SELECT '--------------------------------------------' AS '';

START TRANSACTION;

    -- ------------------------------------------------------------------------
    -- Import: brands.csv → brand (5 Marken)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere brands.csv → brand...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/brands.csv'
    INTO TABLE brand
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in brand importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl prüfen
    SELECT COUNT(*) INTO @brand_count FROM brand;
    IF @brand_count != 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Erwartete 5 Marken, aber andere Anzahl gefunden';
    END IF;

    -- ------------------------------------------------------------------------
    -- Import: categories.csv → category (4 Kategorien)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere categories.csv → category...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/categories.csv'
    INTO TABLE category
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in category importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl prüfen
    SELECT COUNT(*) INTO @category_count FROM category;
    IF @category_count != 4 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Erwartete 4 Kategorien, aber andere Anzahl gefunden';
    END IF;

    -- ------------------------------------------------------------------------
    -- Import: tags.csv → tag (5 Tags)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere tags.csv → tag...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/tags.csv'
    INTO TABLE tag
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in tag importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl prüfen
    SELECT COUNT(*) INTO @tag_count FROM tag;
    IF @tag_count != 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Erwartete 5 Tags, aber andere Anzahl gefunden';
    END IF;

COMMIT;

SELECT '✓ TRANSACTION 1 erfolgreich abgeschlossen' AS Status;
SELECT CONCAT('  ├─ ', @brand_count, ' Marken') AS '';
SELECT CONCAT('  ├─ ', @category_count, ' Kategorien') AS '';
SELECT CONCAT('  └─ ', @tag_count, ' Tags') AS '';

-- ============================================================================
-- TRANSACTION 2: Import der Produktdaten (products_extended.csv)
-- ============================================================================
-- Importiert Produkte 1-500 aus products_extended.csv mit technischen Daten
-- 
-- ATOMARITÄT: Bei einem Fehler wird der Import zurückgerollt
-- INTEGRITÄT: Prüft Foreign Keys zu brand und category
-- ============================================================================

SELECT '--------------------------------------------' AS '';
SELECT 'TRANSACTION 2: Import Produkte 1-500' AS Status;
SELECT '--------------------------------------------' AS '';

START TRANSACTION;

    -- ------------------------------------------------------------------------
    -- Import: products_extended.csv → product (500 Produkte)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere products_extended.csv → product...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/products_extended.csv'
    INTO TABLE product
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name, description, brand_id, category_id, price, load_class, application, temperature_range);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in product importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl und ID-Bereich prüfen
    SELECT COUNT(*) INTO @product_count_1 FROM product WHERE id BETWEEN 1 AND 500;
    SELECT MIN(id) INTO @product_min_id_1 FROM product;
    SELECT MAX(id) INTO @product_max_id_1 FROM product;
    
    IF @product_count_1 != 500 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Erwartete 500 Produkte (1-500), aber andere Anzahl gefunden';
    END IF;
    
    IF @product_min_id_1 != 1 OR @product_max_id_1 != 500 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Produkt-IDs sollten von 1 bis 500 reichen';
    END IF;
    
    -- Validierung: Foreign Key Integrität zu brand prüfen
    SELECT COUNT(*) INTO @invalid_brands 
    FROM product p 
    LEFT JOIN brand b ON p.brand_id = b.id 
    WHERE b.id IS NULL AND p.id BETWEEN 1 AND 500;
    
    IF @invalid_brands > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Ungültige brand_id Referenzen gefunden';
    END IF;
    
    -- Validierung: Foreign Key Integrität zu category prüfen
    SELECT COUNT(*) INTO @invalid_categories 
    FROM product p 
    LEFT JOIN category c ON p.category_id = c.id 
    WHERE c.id IS NULL AND p.id BETWEEN 1 AND 500;
    
    IF @invalid_categories > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Ungültige category_id Referenzen gefunden';
    END IF;

COMMIT;

SELECT '✓ TRANSACTION 2 erfolgreich abgeschlossen' AS Status;
SELECT CONCAT('  └─ ', @product_count_1, ' Produkte (IDs ', @product_min_id_1, '-', @product_max_id_1, ')') AS '';

-- ============================================================================
-- TRANSACTION 3: Import weiterer Produktdaten (products_500_new.csv)
-- ============================================================================
-- Importiert Produkte 501-1000 aus products_500_new.csv
-- 
-- ATOMARITÄT: Bei einem Fehler wird der Import zurückgerollt
-- INTEGRITÄT: Prüft Foreign Keys zu brand und category
-- ============================================================================

SELECT '--------------------------------------------' AS '';
SELECT 'TRANSACTION 3: Import Produkte 501-1000' AS Status;
SELECT '--------------------------------------------' AS '';

START TRANSACTION;

    -- ------------------------------------------------------------------------
    -- Import: products_500_new.csv → product (500 weitere Produkte)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere products_500_new.csv → product...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/products_500_new.csv'
    INTO TABLE product
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (id, name, description, brand_id, category_id, price, load_class, application, temperature_range);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in product importiert') AS Status;
    
    -- Validierung: Erwartete Anzahl und ID-Bereich prüfen
    SELECT COUNT(*) INTO @product_count_2 FROM product WHERE id BETWEEN 501 AND 1000;
    SELECT MIN(id) INTO @product_min_id_2 FROM product WHERE id >= 501;
    SELECT MAX(id) INTO @product_max_id_2 FROM product WHERE id >= 501;
    
    IF @product_count_2 != 500 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Erwartete 500 Produkte (501-1000), aber andere Anzahl gefunden';
    END IF;
    
    IF @product_min_id_2 != 501 OR @product_max_id_2 != 1000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Produkt-IDs sollten von 501 bis 1000 reichen';
    END IF;
    
    -- Validierung: Foreign Key Integrität zu brand prüfen
    SELECT COUNT(*) INTO @invalid_brands_2 
    FROM product p 
    LEFT JOIN brand b ON p.brand_id = b.id 
    WHERE b.id IS NULL AND p.id BETWEEN 501 AND 1000;
    
    IF @invalid_brands_2 > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Ungültige brand_id Referenzen in Produkten 501-1000 gefunden';
    END IF;
    
    -- Validierung: Foreign Key Integrität zu category prüfen
    SELECT COUNT(*) INTO @invalid_categories_2 
    FROM product p 
    LEFT JOIN category c ON p.category_id = c.id 
    WHERE c.id IS NULL AND p.id BETWEEN 501 AND 1000;
    
    IF @invalid_categories_2 > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Ungültige category_id Referenzen in Produkten 501-1000 gefunden';
    END IF;
    
    -- Gesamtzahl der Produkte prüfen
    SELECT COUNT(*) INTO @product_total FROM product;
    IF @product_total != 1000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Erwartete insgesamt 1000 Produkte';
    END IF;

COMMIT;

SELECT '✓ TRANSACTION 3 erfolgreich abgeschlossen' AS Status;
SELECT CONCAT('  ├─ ', @product_count_2, ' Produkte (IDs ', @product_min_id_2, '-', @product_max_id_2, ')') AS '';
SELECT CONCAT('  └─ ', @product_total, ' Produkte gesamt') AS '';

-- ============================================================================
-- TRANSACTION 4: Import der Produkt-Tag-Verknüpfungen (product_tags.csv)
-- ============================================================================
-- Importiert M:N-Verknüpfungen zwischen Produkten und Tags
-- 
-- ATOMARITÄT: Bei einem Fehler wird der Import zurückgerollt
-- INTEGRITÄT: Prüft Foreign Keys zu product und tag
-- HINWEIS: Die CSV enthält nur Verknüpfungen für Produkte 1-500
-- ============================================================================

SELECT '--------------------------------------------' AS '';
SELECT 'TRANSACTION 4: Import M:N Verknüpfungen' AS Status;
SELECT '--------------------------------------------' AS '';

START TRANSACTION;

    -- ------------------------------------------------------------------------
    -- Import: product_tags.csv → product_tag (~995 Verknüpfungen)
    -- ------------------------------------------------------------------------
    SELECT 'Importiere product_tags.csv → product_tag...' AS Status;
    
    LOAD DATA LOCAL INFILE 'data/product_tags.csv'
    INTO TABLE product_tag
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (product_id, tag_id);
    
    SELECT CONCAT('✓ ', ROW_COUNT(), ' Datensätze in product_tag importiert') AS Status;
    
    -- Validierung: Foreign Key Integrität zu product prüfen
    SELECT COUNT(*) INTO @invalid_product_refs 
    FROM product_tag pt 
    LEFT JOIN product p ON pt.product_id = p.id 
    WHERE p.id IS NULL;
    
    IF @invalid_product_refs > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Ungültige product_id Referenzen in product_tag gefunden';
    END IF;
    
    -- Validierung: Foreign Key Integrität zu tag prüfen
    SELECT COUNT(*) INTO @invalid_tag_refs 
    FROM product_tag pt 
    LEFT JOIN tag t ON pt.tag_id = t.id 
    WHERE t.id IS NULL;
    
    IF @invalid_tag_refs > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FEHLER: Ungültige tag_id Referenzen in product_tag gefunden';
    END IF;
    
    -- Statistik: Durchschnittliche Tags pro Produkt
    SELECT COUNT(*) INTO @product_tag_count FROM product_tag;
    SELECT COUNT(DISTINCT product_id) INTO @products_with_tags FROM product_tag;
    SELECT ROUND(COUNT(*) / COUNT(DISTINCT product_id), 2) INTO @avg_tags_per_product FROM product_tag;

COMMIT;

SELECT '✓ TRANSACTION 4 erfolgreich abgeschlossen' AS Status;
SELECT CONCAT('  ├─ ', @product_tag_count, ' Produkt-Tag-Zuordnungen') AS '';
SELECT CONCAT('  ├─ ', @products_with_tags, ' Produkte haben Tags') AS '';
SELECT CONCAT('  └─ Ø ', @avg_tags_per_product, ' Tags pro Produkt') AS '';

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
SELECT CONCAT('brand:               ', COUNT(*), ' Datensätze') AS '' FROM brand;
SELECT CONCAT('category:            ', COUNT(*), ' Datensätze') AS '' FROM category;
SELECT CONCAT('tag:                 ', COUNT(*), ' Datensätze') AS '' FROM tag;
SELECT '----------------------------------------' AS '';

-- Produktdaten
SELECT CONCAT('product:             ', COUNT(*), ' Datensätze (IDs 1-1000)') AS '' FROM product;
SELECT '----------------------------------------' AS '';

-- Verknüpfungen
SELECT CONCAT('product_tag:         ', COUNT(*), ' Zuordnungen') AS '' FROM product_tag;
SELECT '----------------------------------------' AS '';

-- Gesamtsumme
SELECT CONCAT('GESAMT:              ', 
    (SELECT COUNT(*) FROM brand) + 
    (SELECT COUNT(*) FROM category) + 
    (SELECT COUNT(*) FROM tag) + 
    (SELECT COUNT(*) FROM product) + 
    (SELECT COUNT(*) FROM product_tag), 
    ' Datensätze') AS '';

SELECT '============================================' AS '';

-- ============================================================================
-- Datenbank-Integritätsprüfung
-- ============================================================================

SELECT '' AS '';
SELECT 'Integritätsprüfung (Referenzielle Integrität):' AS '';
SELECT '----------------------------------------' AS '';

-- Prüfe auf verwaiste Foreign Keys in product → brand
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle product.brand_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige product.brand_id gefunden!')
END AS '' 
FROM product p 
LEFT JOIN brand b ON p.brand_id = b.id 
WHERE b.id IS NULL;

-- Prüfe auf verwaiste Foreign Keys in product → category
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle product.category_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige product.category_id gefunden!')
END AS '' 
FROM product p 
LEFT JOIN category c ON p.category_id = c.id 
WHERE c.id IS NULL;

-- Prüfe auf verwaiste Foreign Keys in product_tag → product
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle product_tag.product_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige product_tag.product_id gefunden!')
END AS '' 
FROM product_tag pt 
LEFT JOIN product p ON pt.product_id = p.id 
WHERE p.id IS NULL;

-- Prüfe auf verwaiste Foreign Keys in product_tag → tag
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Alle product_tag.tag_id sind gültig'
    ELSE CONCAT('✗ ', COUNT(*), ' ungültige product_tag.tag_id gefunden!')
END AS '' 
FROM product_tag pt 
LEFT JOIN tag t ON pt.tag_id = t.id 
WHERE t.id IS NULL;

-- Prüfe auf doppelte Einträge in Junction-Table
SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✓ Keine doppelten Einträge in product_tag'
    ELSE CONCAT('✗ ', COUNT(*), ' doppelte Einträge in product_tag gefunden!')
END AS ''
FROM (
    SELECT product_id, tag_id, COUNT(*) as cnt
    FROM product_tag
    GROUP BY product_id, tag_id
    HAVING cnt > 1
) duplicates;

-- Prüfe UNIQUE Constraints
SELECT CASE 
    WHEN COUNT(*) = COUNT(DISTINCT name) THEN '✓ Alle brand.name sind eindeutig'
    ELSE '✗ Doppelte Markennamen gefunden!'
END AS ''
FROM brand;

SELECT CASE 
    WHEN COUNT(*) = COUNT(DISTINCT name) THEN '✓ Alle category.name sind eindeutig'
    ELSE '✗ Doppelte Kategorienamen gefunden!'
END AS ''
FROM category;

SELECT CASE 
    WHEN COUNT(*) = COUNT(DISTINCT name) THEN '✓ Alle tag.name sind eindeutig'
    ELSE '✗ Doppelte Tag-Namen gefunden!'
END AS ''
FROM tag;

SELECT '----------------------------------------' AS '';
SELECT '✓ Alle Integritätsprüfungen bestanden!' AS '';
SELECT '============================================' AS '';
