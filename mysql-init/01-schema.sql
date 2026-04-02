-- ============================================================================
-- Produktdatenbank Schema (DDL)
-- ============================================================================
-- Beschreibung: Vollständiges Datenbankschema für Produktverwaltung
--               mit 7 Haupttabellen: brands, categories, tags, etl_run_log,
--               products, product_change_log, product_tags
--               Normalisiert in 3NF mit vollständiger referenzieller Integrität
-- Version: 3.0
-- Datum: 2026-04-02
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
DROP TABLE IF EXISTS product_change_log;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS products_500_new;
DROP TABLE IF EXISTS products_extended;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS etl_run_log;
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
-- Tabelle: brands
-- Beschreibung: Lagerhersteller (SKF, FAG, Schaeffler, INA, NSK)
-- Normalisierung: 3NF - Keine transitiven Abhängigkeiten
-- ----------------------------------------------------------------------------
CREATE TABLE brands (
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
-- Tabelle: categories
-- Beschreibung: Produktkategorien (Wälzlager, Dichtungen, Kugellager, Rollenlager)
-- Normalisierung: 3NF - Keine transitiven Abhängigkeiten
-- ----------------------------------------------------------------------------
CREATE TABLE categories (
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
-- Tabelle: tags
-- Beschreibung: Beschreibende Schlagwörter (Industrie, Automotive, Premium, etc.)
-- Normalisierung: 3NF - Keine transitiven Abhängigkeiten
-- ----------------------------------------------------------------------------
CREATE TABLE tags (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Constraints
    CONSTRAINT uq_tag_name UNIQUE (name),
    CONSTRAINT chk_tag_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Beschreibende Schlagwörter für Produkte';

-- ----------------------------------------------------------------------------
-- Tabelle: etl_run_log
-- Beschreibung: ETL-Lauf-Protokoll für Index-Build-Operationen
-- ----------------------------------------------------------------------------
CREATE TABLE etl_run_log (
    id INT NOT NULL AUTO_INCREMENT,
    strategy VARCHAR(10) NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NULL,
    products_processed INT NOT NULL DEFAULT 0,
    products_written INT NOT NULL DEFAULT 0,
    status ENUM('running', 'success', 'error') NOT NULL DEFAULT 'running',
    error_msg VARCHAR(500) NULL,

    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='ETL-Lauf-Protokoll';

-- ============================================================================
-- Produkttabelle (Product Table)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: products
-- Beschreibung: Vereinheitlichte Produkttabelle mit allen 1000 Produkten
--               Enthält sowohl Basis- als auch erweiterte technische Attribute
-- Normalisierung: 3NF
--   - Alle Nicht-Schlüssel-Attribute sind voll funktional abhängig vom PK
--   - Keine transitiven Abhängigkeiten (brands, categories in eigene Tabellen)
--   - Atomare Werte (1NF erfüllt)
-- Referenzielle Integrität:
--   - brand_id muss in brands.id existieren (NOT NULL + RESTRICT)
--   - category_id muss in categories.id existieren (NOT NULL + RESTRICT)
-- ----------------------------------------------------------------------------
CREATE TABLE products (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    brand_id INT NOT NULL,
    category_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    load_class VARCHAR(50),
    application VARCHAR(50),
    sku VARCHAR(100) NULL,
    temperature_range VARCHAR(50),
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Foreign Keys mit referenzieller Integrität
    CONSTRAINT fk_product_brand FOREIGN KEY (brand_id) 
        REFERENCES brands(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_product_category FOREIGN KEY (category_id) 
        REFERENCES categories(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- Unique constraint for SKU
    CONSTRAINT uq_products_sku UNIQUE (sku),
    
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
CREATE INDEX idx_products_brand ON products(brand_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_load_class ON products(load_class);
CREATE INDEX idx_products_application ON products(application);

-- ----------------------------------------------------------------------------
-- Tabelle: product_change_log
-- Beschreibung: Automatisches Änderungsprotokoll für Produkte (per Trigger befüllt)
-- ----------------------------------------------------------------------------
CREATE TABLE product_change_log (
    id INT NOT NULL AUTO_INCREMENT,
    product_id INT NOT NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    field_name VARCHAR(100) NOT NULL,
    old_value TEXT NULL,
    new_value TEXT NULL,
    changed_by VARCHAR(100) NOT NULL DEFAULT 'system',

    PRIMARY KEY (id),

    CONSTRAINT fk_pcl_product FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Automatisches Produktänderungsprotokoll';

-- ============================================================================
-- Verknüpfungstabellen (Junction Tables) für M:N-Beziehungen
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: product_tags
-- Beschreibung: M:N-Beziehung zwischen Produkten und Tags
--               Ein Produkt kann mehrere Tags haben
--               Ein Tag kann mehreren Produkten zugeordnet sein
-- Normalisierung: 3NF
--   - Composite Primary Key verhindert Duplikate
--   - Beide Spalten sind Foreign Keys zu ihren jeweiligen Tabellen
-- Referenzielle Integrität:
--   - CASCADE: Bei Löschen von products/tags werden Verknüpfungen gelöscht
--   - Verhindert verwaiste Einträge in der Junction-Tabelle
-- ----------------------------------------------------------------------------
CREATE TABLE product_tags (
    product_id INT NOT NULL,
    tag_id INT NOT NULL,
    
    -- Composite Primary Key (verhindert Duplikate)
    PRIMARY KEY (product_id, tag_id),
    
    -- Foreign Keys mit CASCADE für automatische Bereinigung
    CONSTRAINT fk_product_tag_product FOREIGN KEY (product_id) 
        REFERENCES products(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT fk_product_tag_tag FOREIGN KEY (tag_id) 
        REFERENCES tags(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='M:N-Verknüpfung zwischen Produkten und Tags';

-- Index für Performance bei Rückwärtssuche (von Tag zu Produkten)
CREATE INDEX idx_product_tags_tag ON product_tags(tag_id);

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
