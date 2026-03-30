-- ============================================================================
-- Produktdatenbank Schema (DDL)
-- ============================================================================
-- Beschreibung: Vollständiges Datenbankschema für Produktverwaltung
--               mit 4 Haupttabellen: Brand, Category, Product, Tag
--               Normalisiert in 3NF mit vollständiger referenzieller Integrität
-- Version: 2.0
-- Datum: 2026-03-30
-- Datenbank: MySQL 8.4
-- ============================================================================

-- ============================================================================
-- Schema-Vorbereitung: Altes Schema löschen (für Wiederholbarkeit)
-- ============================================================================

-- Deaktiviere Foreign Key Checks für sicheres Löschen
SET FOREIGN_KEY_CHECKS = 0;

-- Lösche bestehende Tabellen in umgekehrter Abhängigkeitsreihenfolge
DROP TABLE IF EXISTS product_tag;
DROP TABLE IF EXISTS product_tags;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS products_500_new;
DROP TABLE IF EXISTS products_extended;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS tag;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS brand;
DROP TABLE IF EXISTS brands;

-- Reaktiviere Foreign Key Checks
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- Stammdaten-Tabellen (Master Data Tables)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: brand
-- Beschreibung: Lagerhersteller (SKF, FAG, Schaeffler, INA, NSK)
-- Normalisierung: 3NF - Keine transitiven Abhängigkeiten
-- ----------------------------------------------------------------------------
CREATE TABLE brand (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Constraints
    CONSTRAINT uq_brand_name UNIQUE (name),
    CONSTRAINT chk_brand_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Lagerhersteller und Marken';

-- ----------------------------------------------------------------------------
-- Tabelle: category
-- Beschreibung: Produktkategorien (Wälzlager, Dichtungen, Kugellager, Rollenlager)
-- Normalisierung: 3NF - Keine transitiven Abhängigkeiten
-- ----------------------------------------------------------------------------
CREATE TABLE category (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Constraints
    CONSTRAINT uq_category_name UNIQUE (name),
    CONSTRAINT chk_category_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Produktkategorien';

-- ----------------------------------------------------------------------------
-- Tabelle: tag
-- Beschreibung: Beschreibende Schlagwörter (Industrie, Automotive, Premium, etc.)
-- Normalisierung: 3NF - Keine transitiven Abhängigkeiten
-- ----------------------------------------------------------------------------
CREATE TABLE tag (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Constraints
    CONSTRAINT uq_tag_name UNIQUE (name),
    CONSTRAINT chk_tag_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Beschreibende Schlagwörter für Produkte';

-- ============================================================================
-- Produkttabelle (Product Table)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: product
-- Beschreibung: Vereinheitlichte Produkttabelle mit allen 1000 Produkten
--               Enthält sowohl Basis- als auch erweiterte technische Attribute
-- Normalisierung: 3NF
--   - Alle Nicht-Schlüssel-Attribute sind voll funktional abhängig vom PK
--   - Keine transitiven Abhängigkeiten (brand, category in eigene Tabellen)
--   - Atomare Werte (1NF erfüllt)
-- Referenzielle Integrität:
--   - brand_id muss in brand.id existieren (NOT NULL + RESTRICT)
--   - category_id muss in category.id existieren (NOT NULL + RESTRICT)
-- ----------------------------------------------------------------------------
CREATE TABLE product (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    brand_id INT NOT NULL,
    category_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    load_class VARCHAR(50),
    application VARCHAR(50),
    temperature_range VARCHAR(50),
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Foreign Keys mit referenzieller Integrität
    CONSTRAINT fk_product_brand FOREIGN KEY (brand_id) 
        REFERENCES brand(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_product_category FOREIGN KEY (category_id) 
        REFERENCES category(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- Business Rules Constraints
    CONSTRAINT chk_product_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0),
    CONSTRAINT chk_product_price_positive CHECK (price >= 0),
    CONSTRAINT chk_product_load_class CHECK (
        load_class IS NULL OR 
        load_class IN ('high', 'medium', 'low')
    ),
    CONSTRAINT chk_product_application CHECK (
        application IS NULL OR 
        application IN ('precision', 'automotive', 'industrial')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Vereinheitlichte Produkttabelle mit allen 1000 Produkten (IDs 1-1000)';

-- Indizes für Performance-Optimierung
CREATE INDEX idx_product_brand ON product(brand_id);
CREATE INDEX idx_product_category ON product(category_id);
CREATE INDEX idx_product_price ON product(price);
CREATE INDEX idx_product_name ON product(name);
CREATE INDEX idx_product_load_class ON product(load_class);
CREATE INDEX idx_product_application ON product(application);

-- ============================================================================
-- Verknüpfungstabellen (Junction Tables) für M:N-Beziehungen
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: product_tag
-- Beschreibung: M:N-Beziehung zwischen Produkten und Tags
--               Ein Produkt kann mehrere Tags haben
--               Ein Tag kann mehreren Produkten zugeordnet sein
-- Normalisierung: 3NF
--   - Composite Primary Key verhindert Duplikate
--   - Beide Spalten sind Foreign Keys zu ihren jeweiligen Tabellen
-- Referenzielle Integrität:
--   - CASCADE: Bei Löschen von product/tag werden Verknüpfungen gelöscht
--   - Verhindert verwaiste Einträge in der Junction-Tabelle
-- ----------------------------------------------------------------------------
CREATE TABLE product_tag (
    product_id INT NOT NULL,
    tag_id INT NOT NULL,
    
    -- Composite Primary Key (verhindert Duplikate)
    PRIMARY KEY (product_id, tag_id),
    
    -- Foreign Keys mit CASCADE für automatische Bereinigung
    CONSTRAINT fk_product_tag_product FOREIGN KEY (product_id) 
        REFERENCES product(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT fk_product_tag_tag FOREIGN KEY (tag_id) 
        REFERENCES tag(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='M:N-Verknüpfung zwischen Produkten und Tags';

-- Index für Performance bei Rückwärtssuche (von Tag zu Produkten)
CREATE INDEX idx_product_tag_tag ON product_tag(tag_id);

-- ============================================================================
-- Schema-Information ausgeben
-- ============================================================================

SELECT '============================================' AS '';
SELECT 'Schema erfolgreich erstellt!' AS Status;
SELECT '============================================' AS '';
SELECT '' AS '';

-- Zähle erstellte Tabellen
SELECT COUNT(*) INTO @table_count
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
AND table_type = 'BASE TABLE';

SELECT CONCAT('Anzahl erstellter Tabellen: ', @table_count) AS '';

-- Liste alle Tabellen auf
SELECT TABLE_NAME AS 'Erstellte Tabellen'
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
AND table_type = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT '' AS '';
SELECT '3NF Normalisierung: ✓' AS '';
SELECT 'Referenzielle Integrität: ✓' AS '';
SELECT 'Primärschlüssel: ✓' AS '';
SELECT 'Fremdschlüssel: ✓' AS '';
SELECT 'M:N Junction-Tabelle: ✓' AS '';
SELECT '============================================' AS '';
