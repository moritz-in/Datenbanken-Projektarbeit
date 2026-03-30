-- ============================================================================
-- Produktdatenbank Schema (DDL)
-- ============================================================================
-- Beschreibung: Vollständiges Datenbankschema für Produktverwaltung
--               mit Marken, Kategorien, Tags und verschiedenen Produktvarianten
-- Version: 1.0
-- Datum: 2026-03-29
-- Datenbank: MySQL 8.4
-- ============================================================================

-- ============================================================================
-- Schema-Vorbereitung: Altes Schema löschen (für Wiederholbarkeit)
-- ============================================================================

-- Deaktiviere Foreign Key Checks für sicheres Löschen
SET FOREIGN_KEY_CHECKS = 0;

-- Lösche bestehende Tabellen in umgekehrter Abhängigkeitsreihenfolge
DROP TABLE IF EXISTS product_tags;
DROP TABLE IF EXISTS products_500_new;
DROP TABLE IF EXISTS products_extended;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS brands;

-- Reaktiviere Foreign Key Checks
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- Stammdaten-Tabellen (Master Data Tables)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: brands
-- Beschreibung: Lagerhersteller (SKF, FAG, Schaeffler, INA, NSK)
-- ----------------------------------------------------------------------------
CREATE TABLE brands (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Constraints
    CONSTRAINT uq_brands_name UNIQUE (name),
    CONSTRAINT chk_brands_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Lagerhersteller und Marken';

-- ----------------------------------------------------------------------------
-- Tabelle: categories
-- Beschreibung: Produktkategorien (Wälzlager, Dichtungen, Kugellager, Rollenlager)
-- ----------------------------------------------------------------------------
CREATE TABLE categories (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Constraints
    CONSTRAINT uq_categories_name UNIQUE (name),
    CONSTRAINT chk_categories_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Produktkategorien';

-- ----------------------------------------------------------------------------
-- Tabelle: tags
-- Beschreibung: Beschreibende Schlagwörter (Industrie, Automotive, Premium, etc.)
-- ----------------------------------------------------------------------------
CREATE TABLE tags (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Constraints
    CONSTRAINT uq_tags_name UNIQUE (name),
    CONSTRAINT chk_tags_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Beschreibende Schlagwörter für Produkte';

-- ============================================================================
-- Produkttabellen (Product Tables)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: products
-- Beschreibung: Basis-Produkttabelle (IDs 1-500) mit 6 Basisattributen
-- ----------------------------------------------------------------------------
CREATE TABLE products (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    brand_id INT NOT NULL,
    category_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Foreign Keys
    CONSTRAINT fk_products_brand FOREIGN KEY (brand_id) 
        REFERENCES brands(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) 
        REFERENCES categories(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_products_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0),
    CONSTRAINT chk_products_description_not_empty CHECK (CHAR_LENGTH(TRIM(description)) > 0),
    CONSTRAINT chk_products_price_positive CHECK (price > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Basis-Produkttabelle mit 500 Produkten (IDs 1-500)';

-- Indizes für Performance-Optimierung
CREATE INDEX idx_products_brand ON products(brand_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_name ON products(name);

-- ----------------------------------------------------------------------------
-- Tabelle: products_extended
-- Beschreibung: Erweiterte Produkttabelle (IDs 1-500) mit 9 Attributen
--               inkl. technischer Spezifikationen
-- ----------------------------------------------------------------------------
CREATE TABLE products_extended (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    brand_id INT NOT NULL,
    category_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    load_class VARCHAR(50) NOT NULL,
    application VARCHAR(50) NOT NULL,
    temperature_range VARCHAR(50) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Foreign Keys
    CONSTRAINT fk_products_extended_brand FOREIGN KEY (brand_id) 
        REFERENCES brands(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_products_extended_category FOREIGN KEY (category_id) 
        REFERENCES categories(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_products_extended_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0),
    CONSTRAINT chk_products_extended_description_not_empty CHECK (CHAR_LENGTH(TRIM(description)) > 0),
    CONSTRAINT chk_products_extended_price_positive CHECK (price > 0),
    CONSTRAINT chk_products_extended_load_class CHECK (load_class IN ('high', 'medium', 'low')),
    CONSTRAINT chk_products_extended_application CHECK (application IN ('precision', 'automotive', 'industrial'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Erweiterte Produkttabelle mit technischen Spezifikationen (IDs 1-500)';

-- Indizes für Performance-Optimierung
CREATE INDEX idx_products_extended_brand ON products_extended(brand_id);
CREATE INDEX idx_products_extended_category ON products_extended(category_id);
CREATE INDEX idx_products_extended_price ON products_extended(price);
CREATE INDEX idx_products_extended_load_class ON products_extended(load_class);
CREATE INDEX idx_products_extended_application ON products_extended(application);
CREATE INDEX idx_products_extended_name ON products_extended(name);

-- ----------------------------------------------------------------------------
-- Tabelle: products_500_new
-- Beschreibung: Neue Produktvarianten (IDs 501-1000) mit 9 Attributen
--               "Variante B" mit vollständigen technischen Spezifikationen
-- ----------------------------------------------------------------------------
CREATE TABLE products_500_new (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    brand_id INT NOT NULL,
    category_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    load_class VARCHAR(50) NOT NULL,
    application VARCHAR(50) NOT NULL,
    temperature_range VARCHAR(50) NOT NULL,
    
    -- Primary Key
    PRIMARY KEY (id),
    
    -- Foreign Keys
    CONSTRAINT fk_products_500_new_brand FOREIGN KEY (brand_id) 
        REFERENCES brands(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_products_500_new_category FOREIGN KEY (category_id) 
        REFERENCES categories(id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_products_500_new_name_not_empty CHECK (CHAR_LENGTH(TRIM(name)) > 0),
    CONSTRAINT chk_products_500_new_description_not_empty CHECK (CHAR_LENGTH(TRIM(description)) > 0),
    CONSTRAINT chk_products_500_new_price_positive CHECK (price > 0),
    CONSTRAINT chk_products_500_new_load_class CHECK (load_class IN ('high', 'medium', 'low')),
    CONSTRAINT chk_products_500_new_application CHECK (application IN ('precision', 'automotive', 'industrial'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Neue Produktvarianten B mit technischen Spezifikationen (IDs 501-1000)';

-- Indizes für Performance-Optimierung
CREATE INDEX idx_products_500_new_brand ON products_500_new(brand_id);
CREATE INDEX idx_products_500_new_category ON products_500_new(category_id);
CREATE INDEX idx_products_500_new_price ON products_500_new(price);
CREATE INDEX idx_products_500_new_load_class ON products_500_new(load_class);
CREATE INDEX idx_products_500_new_application ON products_500_new(application);
CREATE INDEX idx_products_500_new_name ON products_500_new(name);

-- ============================================================================
-- Verknüpfungstabellen (Junction Tables)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelle: product_tags
-- Beschreibung: N:M-Beziehung zwischen Produkten (products) und Tags
--               Ein Produkt kann mehrere Tags haben
--               Ein Tag kann mehreren Produkten zugeordnet sein
-- ----------------------------------------------------------------------------
CREATE TABLE product_tags (
    product_id INT NOT NULL,
    tag_id INT NOT NULL,
    
    -- Composite Primary Key (verhindert Duplikate)
    PRIMARY KEY (product_id, tag_id),
    
    -- Foreign Keys
    CONSTRAINT fk_product_tags_product FOREIGN KEY (product_id) 
        REFERENCES products(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT fk_product_tags_tag FOREIGN KEY (tag_id) 
        REFERENCES tags(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='N:M-Verknüpfung zwischen Produkten und Tags';

-- Indizes für Performance-Optimierung (für Rückwärtssuche)
CREATE INDEX idx_product_tags_tag ON product_tags(tag_id);

-- ============================================================================
-- Schema-Information ausgeben
-- ============================================================================

SELECT 'Schema erfolgreich erstellt!' AS Status;
SELECT COUNT(*) AS Anzahl_Tabellen 
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
AND table_type = 'BASE TABLE';
