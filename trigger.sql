-- ============================================================================
-- A3 Trigger-Artefakt
-- ============================================================================
-- Standalone-Abgabedatei fuer den MySQL-Trigger.
-- Entspricht funktional mysql-init/02-triggers.sql.
-- ============================================================================

DROP TRIGGER IF EXISTS trg_products_after_update;

DELIMITER $$

CREATE TRIGGER trg_products_after_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF OLD.name <> NEW.name THEN
        INSERT INTO product_change_log (product_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'name', CAST(OLD.name AS CHAR), CAST(NEW.name AS CHAR), 'web_ui');
    END IF;

    IF (OLD.description IS NULL AND NEW.description IS NOT NULL)
       OR (OLD.description IS NOT NULL AND NEW.description IS NULL)
       OR (OLD.description IS NOT NULL AND NEW.description IS NOT NULL AND OLD.description <> NEW.description) THEN
        INSERT INTO product_change_log (product_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'description', CAST(OLD.description AS CHAR), CAST(NEW.description AS CHAR), 'web_ui');
    END IF;

    IF OLD.price <> NEW.price THEN
        INSERT INTO product_change_log (product_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'price', CAST(OLD.price AS CHAR), CAST(NEW.price AS CHAR), 'web_ui');
    END IF;

    IF (OLD.sku IS NULL AND NEW.sku IS NOT NULL)
       OR (OLD.sku IS NOT NULL AND NEW.sku IS NULL)
       OR (OLD.sku IS NOT NULL AND NEW.sku IS NOT NULL AND OLD.sku <> NEW.sku) THEN
        INSERT INTO product_change_log (product_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'sku', CAST(OLD.sku AS CHAR), CAST(NEW.sku AS CHAR), 'web_ui');
    END IF;

    IF (OLD.load_class IS NULL AND NEW.load_class IS NOT NULL)
       OR (OLD.load_class IS NOT NULL AND NEW.load_class IS NULL)
       OR (OLD.load_class IS NOT NULL AND NEW.load_class IS NOT NULL AND OLD.load_class <> NEW.load_class) THEN
        INSERT INTO product_change_log (product_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'load_class', CAST(OLD.load_class AS CHAR), CAST(NEW.load_class AS CHAR), 'web_ui');
    END IF;

    IF (OLD.application IS NULL AND NEW.application IS NOT NULL)
       OR (OLD.application IS NOT NULL AND NEW.application IS NULL)
       OR (OLD.application IS NOT NULL AND NEW.application IS NOT NULL AND OLD.application <> NEW.application) THEN
        INSERT INTO product_change_log (product_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'application', CAST(OLD.application AS CHAR), CAST(NEW.application AS CHAR), 'web_ui');
    END IF;

    IF OLD.brand_id <> NEW.brand_id THEN
        INSERT INTO product_change_log (product_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'brand_id', CAST(OLD.brand_id AS CHAR), CAST(NEW.brand_id AS CHAR), 'web_ui');
    END IF;

    IF OLD.category_id <> NEW.category_id THEN
        INSERT INTO product_change_log (product_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'category_id', CAST(OLD.category_id AS CHAR), CAST(NEW.category_id AS CHAR), 'web_ui');
    END IF;
END$$

DELIMITER ;
