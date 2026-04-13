"""
Product Service - Business Logic for Product Operations

Handles product listing, dashboard data, validation, and SQL queries.
"""
import logging

from flask import current_app

from repositories import MySQLRepository, QdrantRepository
from validation import validate_mysql as _validate_mysql
from validation import ValidationItem, ValidationReport

log = logging.getLogger(__name__)


class ProductService:
    """Service for product-related operations"""

    def __init__(self, mysql_repo: MySQLRepository, qdrant_repo: QdrantRepository):
        """
        Initialize product service.

        Args:
            mysql_repo: MySQL repository for database operations
            qdrant_repo: Qdrant repository for vector index stats
        """
        self.mysql_repo = mysql_repo
        self.qdrant_repo = qdrant_repo

    # ------------------------------------------------------------------
    # Write methods (Plan 02)
    # ------------------------------------------------------------------

    def get_product_by_id(self, product_id: int) -> dict | None:
        """
        Get a single product by ID with brand, category, and tags.

        Args:
            product_id: Product primary key

        Returns:
            dict with product fields (incl. tags_str) or None if not found
        """
        return self.mysql_repo.get_product_by_id(product_id)

    def get_brands(self) -> list[dict]:
        """Get all brands ordered by name."""
        return self.mysql_repo.get_brands()

    def get_categories(self) -> list[dict]:
        """Get all categories ordered by name."""
        return self.mysql_repo.get_categories()

    def create_product_with_relations(
        self,
        name: str,
        sku: str | None,
        price: float,
        brand_id: int,
        category_id: int,
        tags_str: str,
    ) -> dict:
        """
        Create a new product resolving tag names to IDs.

        Transaction ownership is in the repository; this method assembles data.

        Args:
            name: Product name
            sku: Stock-keeping unit (optional)
            price: Product price
            brand_id: Brand FK
            category_id: Category FK
            tags_str: Comma-separated tag names

        Returns:
            dict with product_id of newly created product

        Raises:
            sqlalchemy.exc.IntegrityError: On duplicate SKU or FK violation
        """
        tag_ids = self._resolve_tag_ids(tags_str)
        data = {
            "name": name.strip(),
            "sku": sku.strip() if sku and sku.strip() else None,
            "price": float(price),
            "brand_id": int(brand_id),
            "category_id": int(category_id),
            "tag_ids": tag_ids,
        }
        return self.mysql_repo.create_product(data)

    def update_product(
        self,
        product_id: int,
        name: str,
        price: float,
        brand_id: int,
        category_id: int,
        tags_str: str,
    ) -> dict:
        """
        Update an existing product (SKU is never changed).

        Args:
            product_id: Product primary key
            name: New product name
            price: New price
            brand_id: New brand FK
            category_id: New category FK
            tags_str: Comma-separated tag names (replaces existing tags)

        Returns:
            dict with product_id
        """
        tag_ids = self._resolve_tag_ids(tags_str)
        data = {
            "name": name.strip(),
            "price": float(price),
            "brand_id": int(brand_id),
            "category_id": int(category_id),
            "tag_ids": tag_ids,
        }
        return self.mysql_repo.update_product(product_id, data)

    def delete_product(self, product_id: int) -> None:
        """
        Delete a product and its tag associations.

        Args:
            product_id: Product primary key
        """
        self.mysql_repo.delete_product(product_id)

    def import_product(self, name: str, description: str, brand_name: str,
                       category_name: str, price: float, sku: str,
                       load_class: str = '', application: str = '') -> dict:
        """
        Call import_product() stored procedure.

        Demonstrates A4: the procedure runs entirely in MySQL — validation,
        duplicate check, and INSERT — without Python business logic.

        Args:
            name: Product name (required)
            description: Product description
            brand_name: Brand name (procedure falls back to first brand if not found)
            category_name: Category name (required — procedure returns code 2 if missing)
            price: Product price (must be >= 0)
            sku: Stock-keeping unit (procedure returns code 1 on duplicate)
            load_class: Load classification ('high', 'medium', 'low')
            application: Application type ('precision', 'automotive', 'industrial')

        Returns:
            dict with keys:
                result_code (int): 0=success, 1=duplicate, 2=validation_error, 3=db_error
                result_message (str): German outcome message
        """
        return self.mysql_repo.call_import_product(
            name=name, description=description, brand_name=brand_name,
            category_name=category_name, price=price, sku=sku,
            load_class=load_class, application=application
        )

    def _resolve_tag_ids(self, tags_str: str) -> list[int]:
        """
        Resolve comma-separated tag names to tag IDs.

        Tags not found in the database are silently ignored (no auto-create).

        Args:
            tags_str: Comma-separated tag names, e.g. "sale, new, featured"

        Returns:
            List of matched tag IDs
        """
        if not tags_str or not tags_str.strip():
            return []
        names = [t.strip().lower() for t in tags_str.split(",") if t.strip()]
        existing_tags = self.mysql_repo.get_tags()  # [{"id": N, "name": "..."}]
        existing_map = {t["name"].lower(): t["id"] for t in existing_tags}
        return [existing_map[n] for n in names if n in existing_map]

    def list_products_joined(self, page: int = 1, page_size: int = 20) -> dict:
        """
        Get paginated products with brand, category, and tags.

        Args:
            page: Page number (1-based)
            page_size: Number of items per page

        Returns:
            Dictionary with 'items' (list of products) and 'total' (total count)
        """
        return self.mysql_repo.get_products_with_joins(page, page_size)

    def get_dashboard_data(self) -> dict:
        """
        Get dashboard statistics.

        Combines MySQL counts, Qdrant index stats, and recent ETL runs.

        Returns:
            Dictionary with 'mysql_counts', 'qdrant_counts', 'last_runs'
        """
        stats = self.mysql_repo.get_dashboard_stats()
        last_runs = self.mysql_repo.get_last_runs(limit=5)
        return {
            "mysql_counts": stats.get("mysql_counts", {}),
            "qdrant_counts": {
                "indexed": 0,
                "last_indexed_at": "-",
                "embedding_model": "-",
            },
            "last_runs": last_runs,
        }

    def get_audit_log(self, page: int = 1, page_size: int = 10) -> dict:
        """
        Get paginated audit log entries.

        Args:
            page: Page number (1-based)
            page_size: Number of items per page

        Returns:
            Dictionary with 'items' (list of audit entries) and 'total' (total count)
        """
        return self.mysql_repo.get_audit_entries(page, page_size)

    def get_last_runs(self, limit: int = 10) -> list[dict]:
        """
        Get last N ETL run log entries.

        Args:
            limit: Maximum number of entries to return

        Returns:
            List of run log dictionaries
        """
        return self.mysql_repo.get_last_runs(limit)

    def execute_sql_query(self, query: str) -> list[dict]:
        """
        Execute a raw SQL SELECT query.

        Security: Only SELECT queries are allowed.

        Args:
            query: SQL query string (must be SELECT)

        Returns:
            List of result dictionaries

        Raises:
            ValueError: If query is not SELECT or contains forbidden keywords
            Exception: On SQL execution errors
        """
        return self.mysql_repo.execute_raw_query(query)

    def validate_mysql(self) -> dict:
        """
        Validate MySQL database schema and data integrity.

        Returns:
            Validation report dictionary
        """
        raise NotImplementedError("TODO: implement MySQL validation.")

    def get_product_count(self) -> int:
        """
        Get total number of products in MySQL.

        Returns:
            Total product count
        """
        raise NotImplementedError("TODO: implement product count.")

    def get_brand_count(self) -> int:
        """
        Get total number of brands in MySQL.

        Returns:
            Total brand count
        """
        raise NotImplementedError("TODO: implement brand count.")

    def get_category_count(self) -> int:
        """
        Get total number of categories in MySQL.

        Returns:
            Total category count
        """
        raise NotImplementedError("TODO: implement category count.")

    def get_summary_stats(self) -> dict:
        """
        Get summary statistics for products, brands, categories, and index.

        Returns:
            Dictionary with summary statistics
        """
        raise NotImplementedError("TODO: implement summary stats.")
