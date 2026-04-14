"""
Neo4j Repository - Data Access Layer for Neo4j Graph Database
Handles all Neo4j-specific graph operations.
"""
from abc import ABC, abstractmethod
from typing import Optional
import logging

from neo4j import GraphDatabase

log = logging.getLogger(__name__)


class Neo4jRepository(ABC):
    """Abstract base class for Neo4j graph database operations"""

    @abstractmethod
    def get_product_relationships(self, mysql_ids: list[int]) -> dict[int, dict]:
        """Get product relationships and enrichment data from Neo4j"""
        pass

    @abstractmethod
    def execute_cypher(self, query: str, parameters: Optional[dict] = None) -> list:
        """Execute a raw Cypher query"""
        pass

    @abstractmethod
    def close(self) -> None:
        """Close the Neo4j driver connection"""
        pass

    @abstractmethod
    def sync_products(self, products: list[dict]) -> int:
        """Sync products to Neo4j graph. Returns count of products processed."""
        pass


class NoOpNeo4jRepository(Neo4jRepository):
    """No-op repository used when Neo4j is not configured."""

    def get_product_relationships(self, mysql_ids: list[int]) -> dict[int, dict]:
        log.debug("NoOpNeo4jRepository.get_product_relationships called (Neo4j not configured)")
        return {}

    def execute_cypher(self, query: str, parameters: Optional[dict] = None) -> list:
        log.debug("NoOpNeo4jRepository.execute_cypher called (Neo4j not configured)")
        return []

    def close(self) -> None:
        log.debug("NoOpNeo4jRepository.close called (Neo4j not configured)")
        pass

    def sync_products(self, products: list[dict]) -> int:
        log.debug("NoOpNeo4jRepository.sync_products called (Neo4j not configured)")
        return 0


class Neo4jRepositoryImpl(Neo4jRepository):
    """Concrete implementation of Neo4j repository"""

    def __init__(self, uri: str, user: str, password: str):
        """
        Initialize Neo4j repository.

        Args:
            uri: Neo4j URI (e.g., 'bolt://localhost:7687')
            user: Neo4j username
            password: Neo4j password
        """
        self._driver = GraphDatabase.driver(uri, auth=(user, password))
        self._driver.verify_connectivity()
        log.info("Neo4j driver connected to %s", uri)

    def execute_cypher(self, query: str, parameters: Optional[dict] = None) -> list:
        """
        Execute a raw Cypher query.

        Args:
            query: Cypher query string
            parameters: Optional query parameters

        Returns:
            List of result records as dicts (consumed inside session block)

        Raises:
            Exception: On query execution errors
        """
        with self._driver.session(database="neo4j") as session:
            result = session.run(query, parameters or {})
            return [dict(r) for r in result]  # MUST consume inside with block

    def close(self) -> None:
        """Close the Neo4j driver connection"""
        if self._driver is not None:
            self._driver.close()
            self._driver = None
            log.info("Neo4j driver closed")

    def get_product_relationships(self, mysql_ids: list[int]) -> dict[int, dict]:
        """
        Get product relationships and enrichment data from Neo4j.

        Loads additional product data from the graph database based on MySQL IDs.
        Adapts to the graph schema: uses relationships if available, falls back to properties.

        Args:
            mysql_ids: List of MySQL product IDs

        Returns:
            Dictionary mapping mysql_id to enrichment data (title, brand, category, tags, related_products)

        Example:
            {
                123: {
                    "title": "Product Name",
                    "brand": "Brand Name",
                    "category": "Category Name",
                    "tags": ["tag1", "tag2"],
                    "related_products": ["Other Product"]
                },
                ...
            }
        """
        if not mysql_ids:
            return {}
        cypher = """
        MATCH (p:Product)
        WHERE p.mysql_id IN $ids
        OPTIONAL MATCH (p)-[:MADE_BY]->(b:Brand)
        OPTIONAL MATCH (p)-[:IN_CATEGORY]->(c:Category)
        OPTIONAL MATCH (p)-[:HAS_TAG]->(t:Tag)
        OPTIONAL MATCH (p)-[:MADE_BY]->(b2:Brand)<-[:MADE_BY]-(other:Product)
        WHERE other.mysql_id <> p.mysql_id
        RETURN p.mysql_id AS mysql_id,
               p.name AS title,
               b.name AS brand,
               c.name AS category,
               collect(DISTINCT t.name) AS tags,
               collect(DISTINCT other.name)[0..3] AS related_products
        """
        rows = self.execute_cypher(cypher, {"ids": mysql_ids})
        result = {}
        for row in rows:
            mid = row.get("mysql_id")
            if mid is not None:
                result[int(mid)] = {
                    "title": row.get("title", ""),
                    "brand": row.get("brand", ""),
                    "category": row.get("category", ""),
                    "tags": row.get("tags") or [],
                    "related_products": row.get("related_products") or [],
                }
        return result

    def sync_products(self, products: list[dict]) -> int:
        """
        Sync products to Neo4j graph. Returns count of products processed.

        Args:
            products: List of product dicts with keys: id, name, brand, category, tags

        Returns:
            Count of products successfully synced
        """
        raise NotImplementedError("TODO: implement sync_products in Phase 4 Plan 02.")

    # ======================
    # High-level operations
    # ======================

    def get_product_by_mysql_id(self, mysql_id: int) -> Optional[dict]:
        """
        Get a single product from Neo4j by MySQL ID.

        Args:
            mysql_id: MySQL product ID

        Returns:
            Product dictionary or None if not found
        """
        raise NotImplementedError("TODO: implement single product lookup.")

    def get_products_by_category(self, category_name: str, limit: int = 10) -> list[dict]:
        """
        Get products in a specific category.

        Args:
            category_name: Category name
            limit: Maximum number of results

        Returns:
            List of product dictionaries
        """
        raise NotImplementedError("TODO: implement category lookup.")

    def get_products_by_brand(self, brand_name: str, limit: int = 10) -> list[dict]:
        """
        Get products from a specific brand.

        Args:
            brand_name: Brand name
            limit: Maximum number of results

        Returns:
            List of product dictionaries
        """
        raise NotImplementedError("TODO: implement brand lookup.")

    def get_related_products(self, mysql_id: int, limit: int = 5) -> list[dict]:
        """
        Get products related to a given product (same category or brand).

        Args:
            mysql_id: MySQL product ID
            limit: Maximum number of results

        Returns:
            List of related product dictionaries
        """
        raise NotImplementedError("TODO: implement related product lookup.")

    def count_products(self) -> int:
        """
        Count total number of products in Neo4j.

        Returns:
            Total product count
        """
        raise NotImplementedError("TODO: implement product count.")

    def count_products_by_category(self) -> dict[str, int]:
        """
        Count products grouped by category.

        Returns:
            Dictionary mapping category names to counts
        """
        raise NotImplementedError("TODO: implement category counts.")

    def count_products_by_brand(self) -> dict[str, int]:
        """
        Count products grouped by brand.

        Returns:
            Dictionary mapping brand names to counts
        """
        raise NotImplementedError("TODO: implement brand counts.")

    def __enter__(self):
        """Context manager entry"""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - closes connection"""
        self.close()
        return False
