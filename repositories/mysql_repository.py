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

    def get_products_with_joins(self, page: int, page_size: int) -> dict:
        """
        Get paginated products with brand, category, and tags joined.

        Args:
            page: Page number (1-based)
            page_size: Number of items per page

        Returns:
            dict with 'items' (list of products) and 'total' (total count)
        """
        raise NotImplementedError("TODO: implement product list query.")

    def get_dashboard_stats(self) -> dict:
        """
        Get dashboard statistics including MySQL counts, Qdrant status, and last runs.

        Note: This method only returns MySQL-related stats. Qdrant stats should be
        retrieved from QdrantRepository.

        Returns:
            dict with 'mysql_counts' and 'last_runs'
        """
        raise NotImplementedError("TODO: implement dashboard stats.")

    def get_audit_entries(self, page: int, page_size: int) -> dict:
        """
        Get paginated audit log entries from etl_run_log.

        Args:
            page: Page number (1-based)
            page_size: Number of items per page

        Returns:
            dict with 'items' (list of audit entries) and 'total' (total count)
        """
        raise NotImplementedError("TODO: implement audit entries query.")

    def get_last_runs(self, limit: int = 10) -> list[dict]:
        """
        Get last N ETL run log entries.

        Args:
            limit: Maximum number of entries to return

        Returns:
            List of run log dictionaries
        """
        raise NotImplementedError("TODO: implement last runs query.")

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
        raise NotImplementedError("TODO: implement raw SQL execution.")

    @staticmethod
    def _strip_string_literals(query: str) -> str:
        raise NotImplementedError("TODO: implement string literal stripping.")

    @staticmethod
    def _extract_table_names(query: str) -> list[str]:
        raise NotImplementedError("TODO: implement table name extraction.")

    def has_column(self, table: str, column: str) -> bool:
        """
        Check if a table has a specific column in current database.

        Args:
            table: Table name
            column: Column name

        Returns:
            True if column exists, False otherwise
        """
        raise NotImplementedError("TODO: implement column existence check.")

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
        raise NotImplementedError("TODO: implement product load for indexing.")

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
        raise NotImplementedError("TODO: implement ETL run logging.")
