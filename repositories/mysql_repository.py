"""
MySQL Repository - Data Access Layer for MySQL Database
Handles all MySQL-specific database operations.
"""
from abc import ABC, abstractmethod
from typing import Optional
import re
import logging

from sqlalchemy import text
import db

log = logging.getLogger(__name__)


class MySQLRepository(ABC):
    """Abstract base class for MySQL data access operations"""

    @abstractmethod
    def get_products_with_joins(self, page: int, page_size: int) -> dict:
        """Get paginated products with brand, category, and tags"""
        pass

    @abstractmethod
    def get_dashboard_stats(self) -> dict:
        """Get dashboard statistics (counts, last runs, etc.)"""
        pass

    @abstractmethod
    def get_audit_entries(self, page: int, page_size: int) -> dict:
        """Get paginated audit log entries"""
        pass

    @abstractmethod
    def execute_raw_query(self, query: str) -> list[dict]:
        """Execute a raw SELECT query (read-only)"""
        pass

    @abstractmethod
    def get_last_runs(self, limit: int = 10) -> list[dict]:
        """Get last N ETL run log entries"""
        pass

    @abstractmethod
    def has_column(self, table: str, column: str) -> bool:
        """Check if a table has a specific column"""
        pass

    @abstractmethod
    def get_brands(self) -> list[dict]:
        """Get all brands"""
        pass

    @abstractmethod
    def get_categories(self) -> list[dict]:
        """Get all categories"""
        pass

    @abstractmethod
    def get_tags(self) -> list[dict]:
        """Get all tags"""
        pass

    @abstractmethod
    def create_product(self, data: dict) -> dict:
        """Create a new product"""
        pass

    @abstractmethod
    def update_product(self, product_id: int, data: dict) -> dict:
        """Update an existing product"""
        pass

    @abstractmethod
    def delete_product(self, product_id: int) -> None:
        """Delete a product"""
        pass

    @abstractmethod
    def get_product_by_id(self, product_id: int) -> "dict | None":
        """Get a product by its ID"""
        pass

    @abstractmethod
    def call_import_product(self, name: str, description: str, brand_name: str,
                             category_name: str, price: float, sku: str,
                             load_class: str, application: str) -> dict:
        """Call import_product() procedure. Returns {result_code: int, result_message: str}."""
        pass


class MySQLRepositoryImpl(MySQLRepository):
    """Concrete implementation of MySQL repository"""

    def __init__(self, session_factory=None):
        """
        Initialize MySQL repository.

        Args:
            session_factory: Optional SQLAlchemy session factory.
                           If None, uses db.mysql_session_factory
        """
        self._session_factory = session_factory or db.mysql_session_factory
        log.debug("MySQLRepositoryImpl initialized")

    def _get_session(self):
        """Get MySQL session from factory"""
        return self._session_factory

    # ------------------------------------------------------------------
    # Read methods (Plan 01)
    # ------------------------------------------------------------------

    def get_products_with_joins(self, page: int, page_size: int) -> dict:
        """
        Get paginated products with brand, category, and tags joined.

        Args:
            page: Page number (1-based)
            page_size: Number of items per page

        Returns:
            dict with 'items' (list of products) and 'total' (total count)
        """
        offset = (page - 1) * page_size
        with self._session_factory() as session:
            # Total count
            count_result = session.execute(
                text("SELECT COUNT(*) AS cnt FROM products")
            )
            total = count_result.mappings().one()["cnt"]

            # Main query with joins
            result = session.execute(
                text(
                    """
                    SELECT p.id AS product_id, p.name, p.price, 'EUR' AS currency,
                           b.name AS brand, c.name AS category
                    FROM products p
                    LEFT JOIN brands b ON p.brand_id = b.id
                    LEFT JOIN categories c ON p.category_id = c.id
                    ORDER BY p.id
                    LIMIT :limit OFFSET :offset
                    """
                ),
                {"limit": page_size, "offset": offset},
            )
            rows = [dict(r) for r in result.mappings().all()]

        if not rows:
            return {"items": [], "total": total}

        # Attach tags via separate query
        product_ids = [r["product_id"] for r in rows]
        tags_by_product: dict[int, list[str]] = {pid: [] for pid in product_ids}

        with self._session_factory() as session:
            tag_result = session.execute(
                text(
                    """
                    SELECT pt.product_id, t.name
                    FROM product_tags pt
                    JOIN tags t ON pt.tag_id = t.id
                    WHERE pt.product_id IN :ids
                    """
                ),
                {"ids": tuple(product_ids)},
            )
            for tag_row in tag_result.mappings().all():
                tags_by_product[tag_row["product_id"]].append(tag_row["name"])

        for row in rows:
            row["tags"] = tags_by_product.get(row["product_id"], [])

        return {"items": rows, "total": total}

    def get_dashboard_stats(self) -> dict:
        """
        Get dashboard statistics including MySQL counts.

        Returns:
            dict with 'mysql_counts' and 'last_runs'
        """
        try:
            with self._session_factory() as session:
                result = session.execute(
                    text(
                        """
                        SELECT 'products' AS tbl, COUNT(*) AS cnt FROM products
                        UNION ALL SELECT 'brands', COUNT(*) FROM brands
                        UNION ALL SELECT 'categories', COUNT(*) FROM categories
                        UNION ALL SELECT 'tags', COUNT(*) FROM tags
                        """
                    )
                )
                counts: dict[str, int] = {}
                for row in result.mappings().all():
                    counts[row["tbl"]] = row["cnt"]

            return {
                "mysql_counts": {
                    "products": counts.get("products", 0),
                    "brands": counts.get("brands", 0),
                    "categories": counts.get("categories", 0),
                    "tags": counts.get("tags", 0),
                },
                "last_runs": [],
            }
        except Exception as e:
            log.error("Error fetching dashboard stats: %s", e)
            return {"mysql_counts": {"error": str(e)}, "last_runs": []}

    def get_audit_entries(self, page: int, page_size: int) -> dict:
        """
        Get paginated audit log entries from etl_run_log.

        Args:
            page: Page number (1-based)
            page_size: Number of items per page

        Returns:
            dict with 'items' (list of audit entries) and 'total' (total count)
        """
        offset = (page - 1) * page_size
        with self._session_factory() as session:
            count_result = session.execute(
                text("SELECT COUNT(*) AS cnt FROM etl_run_log")
            )
            total = count_result.mappings().one()["cnt"]

            result = session.execute(
                text(
                    """
                    SELECT id, strategy, started_at, finished_at,
                           products_processed, products_written, status
                    FROM etl_run_log
                    ORDER BY started_at DESC
                    LIMIT :limit OFFSET :offset
                    """
                ),
                {"limit": page_size, "offset": offset},
            )
            items = []
            for row in result.mappings().all():
                entry = dict(row)
                entry["run_timestamp"] = str(entry.get("started_at", ""))
                items.append(entry)

        return {"items": items, "total": total}

    def get_last_runs(self, limit: int = 10) -> list[dict]:
        """
        Get last N ETL run log entries.

        Args:
            limit: Maximum number of entries to return

        Returns:
            List of run log dictionaries
        """
        with self._session_factory() as session:
            result = session.execute(
                text(
                    """
                    SELECT id, strategy, started_at, finished_at,
                           products_processed, products_written, status
                    FROM etl_run_log
                    ORDER BY started_at DESC
                    LIMIT :limit
                    """
                ),
                {"limit": limit},
            )
            runs = []
            for row in result.mappings().all():
                entry = dict(row)
                entry["run_timestamp"] = str(entry.get("started_at", ""))
                runs.append(entry)
        return runs

    def execute_raw_query(self, query: str) -> list[dict]:
        """
        Execute a raw SQL SELECT query on MySQL database.

        Security: Only SELECT queries are allowed. Forbidden keywords are blocked.

        Args:
            query: SQL query string (must be SELECT)

        Returns:
            List of result dictionaries

        Raises:
            ValueError: If query is not SELECT or contains forbidden keywords
            Exception: On SQL execution errors
        """
        stripped = self._strip_string_literals(query.upper())
        if not stripped.lstrip().startswith("SELECT"):
            raise ValueError("Only SELECT queries are allowed.")
        forbidden = re.compile(
            r"\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|EXEC)\b"
        )
        if forbidden.search(stripped):
            raise ValueError("Query contains forbidden keywords.")

        with self._session_factory() as session:
            result = session.execute(text(query))
            return [dict(r) for r in result.mappings()]

    @staticmethod
    def _strip_string_literals(query: str) -> str:
        """Replace string literal content with empty strings for security checks."""
        return re.sub(r"'[^']*'", "''", query)

    @staticmethod
    def _extract_table_names(query: str) -> list[str]:
        """Extract table names from FROM/JOIN clauses."""
        return re.findall(r"\b(?:FROM|JOIN)\s+(\w+)", query, re.IGNORECASE)

    def has_column(self, table: str, column: str) -> bool:
        """
        Check if a table has a specific column in current database.

        Args:
            table: Table name
            column: Column name

        Returns:
            True if column exists, False otherwise
        """
        with self._session_factory() as session:
            result = session.execute(
                text(
                    """
                    SELECT COUNT(*) AS cnt
                    FROM information_schema.columns
                    WHERE table_schema = DATABASE()
                      AND table_name = :table
                      AND column_name = :column
                    """
                ),
                {"table": table, "column": column},
            )
            cnt = result.mappings().one()["cnt"]
        return bool(cnt > 0)

    def load_products_for_index(
        self, limit: Optional[int] = None, include_tags: bool = True
    ) -> list[dict]:
        """
        Load products from MySQL for indexing purposes.

        Args:
            limit: Optional limit on number of products
            include_tags: Whether to load tags for each product

        Returns:
            List of product dictionaries with all fields
        """
        sql = """
            SELECT p.id, p.name, p.description, p.price, p.currency,
                   p.sku, p.load_class, p.application,
                   b.name AS brand, c.name AS category
            FROM products p
            LEFT JOIN brands b ON p.brand_id = b.id
            LEFT JOIN categories c ON p.category_id = c.id
        """
        params: dict = {}
        if limit is not None:
            sql += " LIMIT :limit"
            params["limit"] = limit

        with self._session_factory() as session:
            result = session.execute(text(sql), params)
            rows = [dict(r) for r in result.mappings().all()]

        if include_tags and rows:
            product_ids = [r["id"] for r in rows]
            tags_by_product: dict[int, list[str]] = {pid: [] for pid in product_ids}
            with self._session_factory() as session:
                tag_result = session.execute(
                    text(
                        """
                        SELECT pt.product_id, t.name
                        FROM product_tags pt
                        JOIN tags t ON pt.tag_id = t.id
                        WHERE pt.product_id IN :ids
                        """
                    ),
                    {"ids": tuple(product_ids)},
                )
                for tag_row in tag_result.mappings().all():
                    tags_by_product[tag_row["product_id"]].append(tag_row["name"])
            for row in rows:
                row["tags"] = tags_by_product.get(row["id"], [])

        return rows

    def log_etl_run(
        self, strategy: str, products_processed: int, products_written: int
    ) -> None:
        """
        Log an ETL run to etl_run_log table.

        Args:
            strategy: ETL strategy used (e.g., 'A', 'B', 'C')
            products_processed: Number of products processed
            products_written: Number of products written to index
        """
        with self._session_factory() as session:
            with session.begin():
                session.execute(
                    text(
                        """
                        INSERT INTO etl_run_log
                            (strategy, started_at, finished_at,
                             products_processed, products_written, status)
                        VALUES (:strategy, NOW(), NOW(), :proc, :written, 'success')
                        """
                    ),
                    {
                        "strategy": strategy,
                        "proc": products_processed,
                        "written": products_written,
                    },
                )

    # ------------------------------------------------------------------
    # Lookup helpers (Plan 01 — needed by Plan 02 for form dropdowns)
    # ------------------------------------------------------------------

    def get_brands(self) -> list[dict]:
        """Get all brands ordered by name."""
        with self._session_factory() as session:
            result = session.execute(
                text("SELECT id, name FROM brands ORDER BY name")
            )
            return [dict(r) for r in result.mappings().all()]

    def get_categories(self) -> list[dict]:
        """Get all categories ordered by name."""
        with self._session_factory() as session:
            result = session.execute(
                text("SELECT id, name FROM categories ORDER BY name")
            )
            return [dict(r) for r in result.mappings().all()]

    def get_tags(self) -> list[dict]:
        """Get all tags ordered by name."""
        with self._session_factory() as session:
            result = session.execute(
                text("SELECT id, name FROM tags ORDER BY name")
            )
            return [dict(r) for r in result.mappings().all()]

    # ------------------------------------------------------------------
    # Write methods (Plan 02)
    # ------------------------------------------------------------------

    def create_product(self, data: dict) -> dict:
        """Create a new product with tag associations in a single transaction.

        Args:
            data: dict with keys: name, sku, price, brand_id, category_id, tag_ids (list[int])

        Returns:
            dict with product_id of the newly created product

        Raises:
            sqlalchemy.exc.IntegrityError: On duplicate SKU — rolled back automatically
        """
        with self._session_factory() as session:
            with session.begin():
                result = session.execute(
                    text(
                        "INSERT INTO products (name, sku, price, brand_id, category_id) "
                        "VALUES (:name, :sku, :price, :brand_id, :category_id)"
                    ),
                    {
                        "name": data["name"],
                        "sku": data.get("sku"),
                        "price": data["price"],
                        "brand_id": data["brand_id"],
                        "category_id": data["category_id"],
                    },
                )
                product_id = result.lastrowid
                for tag_id in data.get("tag_ids", []):
                    session.execute(
                        text(
                            "INSERT INTO product_tags (product_id, tag_id) VALUES (:product_id, :tag_id)"
                        ),
                        {"product_id": product_id, "tag_id": tag_id},
                    )
        return {"product_id": product_id}

    def update_product(self, product_id: int, data: dict) -> dict:
        """Update an existing product — SKU is never updated.

        Args:
            product_id: Product primary key
            data: dict with keys: name, price, brand_id, category_id, tag_ids (list[int])

        Returns:
            dict with product_id

        Raises:
            sqlalchemy.exc.IntegrityError: On FK violation
        """
        with self._session_factory() as session:
            with session.begin():
                session.execute(
                    text(
                        "UPDATE products SET name = :name, price = :price, "
                        "brand_id = :brand_id, category_id = :category_id "
                        "WHERE id = :product_id"
                    ),
                    {
                        "name": data["name"],
                        "price": data["price"],
                        "brand_id": data["brand_id"],
                        "category_id": data["category_id"],
                        "product_id": product_id,
                    },
                )
                # Replace tags: delete existing then re-insert
                session.execute(
                    text("DELETE FROM product_tags WHERE product_id = :product_id"),
                    {"product_id": product_id},
                )
                for tag_id in data.get("tag_ids", []):
                    session.execute(
                        text(
                            "INSERT INTO product_tags (product_id, tag_id) VALUES (:product_id, :tag_id)"
                        ),
                        {"product_id": product_id, "tag_id": tag_id},
                    )
        return {"product_id": product_id}

    def delete_product(self, product_id: int) -> None:
        """Delete a product and its tag associations.

        Deletes product_tags first to avoid FK violation, then deletes the product row.

        Args:
            product_id: Product primary key

        Raises:
            sqlalchemy.exc.IntegrityError: If product referenced by other FKs
        """
        with self._session_factory() as session:
            with session.begin():
                session.execute(
                    text("DELETE FROM product_tags WHERE product_id = :product_id"),
                    {"product_id": product_id},
                )
                session.execute(
                    text("DELETE FROM products WHERE id = :product_id"),
                    {"product_id": product_id},
                )

    def get_product_by_id(self, product_id: int) -> "dict | None":
        """Get a product by ID with brand, category, and tags.

        Args:
            product_id: Product primary key

        Returns:
            dict with {product_id, name, sku, price, brand_id, category_id,
                       brand, category, tags_str} or None if not found
        """
        with self._session_factory() as session:
            row = session.execute(
                text(
                    "SELECT p.id AS product_id, p.name, p.sku, p.price, "
                    "p.brand_id, p.category_id, "
                    "b.name AS brand, c.name AS category "
                    "FROM products p "
                    "LEFT JOIN brands b ON p.brand_id = b.id "
                    "LEFT JOIN categories c ON p.category_id = c.id "
                    "WHERE p.id = :product_id"
                ),
                {"product_id": product_id},
            ).mappings().one_or_none()

            if row is None:
                return None

            product = dict(row)

            # Fetch tags as comma-separated string for form pre-fill
            tags = session.execute(
                text(
                    "SELECT t.name FROM tags t "
                    "JOIN product_tags pt ON t.id = pt.tag_id "
                    "WHERE pt.product_id = :product_id ORDER BY t.name"
                ),
                {"product_id": product_id},
            ).scalars().all()

            product["tags_str"] = ", ".join(tags)
            return product

    # ------------------------------------------------------------------
    # Stored Procedure methods (Plan 02-02)
    # ------------------------------------------------------------------

    def call_import_product(self, name: str, description: str, brand_name: str,
                             category_name: str, price: float, sku: str,
                             load_class: str, application: str) -> dict:
        """
        Call import_product() stored procedure using raw DBAPI cursor.

        Uses raw pymysql cursor (not SQLAlchemy text()) because OUT parameters
        require MySQL user variable syntax (@rc, @rm) which is incompatible with
        SQLAlchemy's bound parameter handling.

        CRITICAL (Pitfall 12): cursor.nextset() loop flushes all implicit result
        sets returned by CALL — without this the connection pool state is corrupted.

        Args:
            name: Product name
            description: Product description
            brand_name: Brand name (resolved to ID in procedure)
            category_name: Category name (must exist — result_code=2 if not found)
            price: Product price (must be >= 0)
            sku: Stock-keeping unit (duplicate → result_code=1)
            load_class: Load classification (e.g. 'high', 'medium', 'low')
            application: Application type (e.g. 'precision', 'automotive')

        Returns:
            dict with keys:
                result_code (int): 0=success, 1=duplicate SKU, 2=validation error, 3=db error
                result_message (str): German message describing the outcome
        """
        with self._session_factory() as session:
            conn = session.connection()
            cursor = conn.connection.cursor()  # raw pymysql cursor
            try:
                cursor.execute("SET @rc = 0, @rm = ''")
                cursor.execute(
                    "CALL import_product(%s, %s, %s, %s, %s, %s, %s, %s, @rc, @rm)",
                    (name, description, brand_name, category_name,
                     float(price), sku, load_class, application)
                )
                # CRITICAL (Pitfall 12): flush all result sets before reading OUT params
                while cursor.nextset():
                    pass
                cursor.execute("SELECT @rc AS result_code, @rm AS result_message")
                row = cursor.fetchone()
                return {"result_code": int(row[0] or 0), "result_message": str(row[1] or "")}
            finally:
                cursor.close()
