"""
Repository Layer - Data Access Factory

Provides centralized access to all repositories with dependency injection.
"""
import os
import logging
import threading
from typing import Optional

from flask import current_app

import db
from .mysql_repository import MySQLRepository, MySQLRepositoryImpl
from .qdrant_repository import QdrantRepository, QdrantRepositoryImpl
from .neo4j_repository import Neo4jRepository, Neo4jRepositoryImpl, NoOpNeo4jRepository
from .product_repository import ProductRepository, ProductRepositoryImpl
from .dashboard_repository import DashboardRepository, DashboardRepositoryImpl
from .audit_repository import AuditRepository, AuditRepositoryImpl

log = logging.getLogger(__name__)


class RepositoryFactory:
    """
    Factory for creating and managing repository instances.

    Uses singleton pattern to reuse instances across the application.
    Supports dependency injection for testing.
    """

    _instances = {}
    _lock = threading.Lock()

    @classmethod
    def reset(cls):
        """Reset all cached instances (useful for testing)"""
        with cls._lock:
            cls._instances.clear()

    @classmethod
    def get_mysql_repository(cls, session_factory=None) -> MySQLRepository:
        """
        Get MySQL repository instance.

        Args:
            session_factory: Optional SQLAlchemy session factory for testing

        Returns:
            MySQLRepository instance
        """
        if MySQLRepositoryImpl not in cls._instances:
            with cls._lock:
                if MySQLRepositoryImpl not in cls._instances:
                    sf = session_factory or db.mysql_session_factory
                    cls._instances[MySQLRepositoryImpl] = MySQLRepositoryImpl(sf)
        return cls._instances[MySQLRepositoryImpl]

    @classmethod
    def get_qdrant_repository(cls, qdrant_url: Optional[str] = None) -> QdrantRepository:
        """
        Get Qdrant repository instance.

        Args:
            qdrant_url: Optional Qdrant URL (uses config if None)

        Returns:
            QdrantRepository instance
        """
        if QdrantRepositoryImpl not in cls._instances:
            with cls._lock:
                if QdrantRepositoryImpl not in cls._instances:
                    url = qdrant_url or current_app.config.get("QDRANT_URL")
                    collection = current_app.config.get("QDRANT_COLLECTION", "products")
                    cls._instances[QdrantRepositoryImpl] = QdrantRepositoryImpl(url, collection)
        return cls._instances[QdrantRepositoryImpl]

    @classmethod
    def get_neo4j_repository(
        cls, uri: Optional[str] = None, user: Optional[str] = None, password: Optional[str] = None
    ) -> Neo4jRepository:
        """
        Get Neo4j repository instance.

        Args:
            uri: Optional Neo4j URI (uses config if None)
            user: Optional Neo4j user (uses config if None)
            password: Optional Neo4j password (uses config if None)

        Returns:
            Neo4jRepository instance
        """
        neo4j_uri = uri or current_app.config.get("NEO4J_URI")
        if not neo4j_uri:
            return NoOpNeo4jRepository()

        if Neo4jRepositoryImpl not in cls._instances:
            with cls._lock:
                if Neo4jRepositoryImpl not in cls._instances:
                    neo4j_user = user or current_app.config.get("NEO4J_USER", "neo4j")
                    neo4j_password = password or current_app.config.get("NEO4J_PASSWORD")
                    cls._instances[Neo4jRepositoryImpl] = Neo4jRepositoryImpl(
                        neo4j_uri, neo4j_user, neo4j_password
                    )
        return cls._instances[Neo4jRepositoryImpl]

    @classmethod
    def get_product_repository(cls) -> ProductRepository:
        """
        Get Product repository instance (legacy).

        Returns:
            ProductRepository instance
        """
        return cls.get_mysql_repository()

    @classmethod
    def get_dashboard_repository(cls) -> DashboardRepository:
        """
        Get Dashboard repository instance (legacy).

        Returns:
            DashboardRepository instance
        """
        return cls.get_mysql_repository()

    @classmethod
    def get_audit_repository(cls) -> AuditRepository:
        """
        Get Audit repository instance (legacy).

        Returns:
            AuditRepository instance
        """
        return cls.get_mysql_repository()


# Export all repository classes and factory
__all__ = [
    # Abstract base classes
    "MySQLRepository",
    "QdrantRepository",
    "Neo4jRepository",
    "ProductRepository",
    "DashboardRepository",
    "AuditRepository",
    # Concrete implementations
    "MySQLRepositoryImpl",
    "QdrantRepositoryImpl",
    "Neo4jRepositoryImpl",
    "NoOpNeo4jRepository",
    "ProductRepositoryImpl",
    "DashboardRepositoryImpl",
    "AuditRepositoryImpl",
    # Factory
    "RepositoryFactory",
]
