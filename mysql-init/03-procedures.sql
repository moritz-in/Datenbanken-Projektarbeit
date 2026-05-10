-- ============================================================================
-- A4 Stored-Procedure-Artefakt
-- ============================================================================
-- Docker-Init-Variante fuer import_product().
-- Inhaltlich identisch zur Standalone-Abgabedatei procedure.sql.
-- ============================================================================

DROP PROCEDURE IF EXISTS import_product;

DELIMITER $$

CREATE PROCEDURE import_product(
    IN  p_name           VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    IN  p_description    TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    IN  p_brand_name     VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    IN  p_category_name  VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    IN  p_price          DECIMAL(10,2),
    IN  p_sku            VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    IN  p_load_class     VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    IN  p_application    VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_result_code    INT,
    OUT p_result_message VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
)
proc_label: BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_result_code = 3;
        SET p_result_message = 'Datenbankfehler';
    END;

    SET p_result_code = 0;
    SET p_result_message = '';

    IF TRIM(p_name) = '' OR p_price < 0 OR TRIM(p_category_name) = '' THEN
        SET p_result_code = 2;
        SET p_result_message = 'Pflichtfelder fehlen: name, price und category sind erforderlich';
        LEAVE proc_label;
    END IF;

    IF p_sku IS NOT NULL AND p_sku <> '' THEN
        SELECT COUNT(*) INTO @sku_count
        FROM products
        WHERE sku = p_sku;

        IF @sku_count > 0 THEN
            SET p_result_code = 1;
            SET p_result_message = CONCAT('Doppelte SKU: ', p_sku);
            LEAVE proc_label;
        END IF;
    END IF;

    SET @brand_id = NULL;
    IF p_brand_name IS NOT NULL AND TRIM(p_brand_name) <> '' THEN
        SELECT id INTO @brand_id
        FROM brands
        WHERE name = p_brand_name
        LIMIT 1;
    END IF;

    IF @brand_id IS NULL THEN
        SELECT id INTO @brand_id FROM brands ORDER BY id LIMIT 1;
    END IF;

    IF @brand_id IS NULL THEN
        SET p_result_code = 2;
        SET p_result_message = 'Keine Brand vorhanden - bitte zuerst eine Brand anlegen';
        LEAVE proc_label;
    END IF;

    SET @cat_id = NULL;
    SELECT id INTO @cat_id
    FROM categories
    WHERE name = p_category_name
    LIMIT 1;

    IF @cat_id IS NULL THEN
        SET p_result_code = 2;
        SET p_result_message = CONCAT('Kategorie nicht gefunden: ', p_category_name);
        LEAVE proc_label;
    END IF;

    INSERT INTO products (name, description, brand_id, category_id, price, sku, load_class, application)
    VALUES (
        p_name,
        p_description,
        @brand_id,
        @cat_id,
        p_price,
        NULLIF(TRIM(p_sku), ''),
        NULLIF(TRIM(p_load_class), ''),
        NULLIF(TRIM(p_application), '')
    );

    SET p_result_code = 0;
    SET p_result_message = CONCAT('Produkt importiert: ', p_name);
END proc_label$$

DELIMITER ;
