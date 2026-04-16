"""
Service Layer - Business Logic Factory

Provides centralized access to all services with dependency injection.
"""
import logging
import threading
from typing import Optional

from flask import current_app
from sentence_transformers import SentenceTransformer
from openai import OpenAI

from repositories import RepositoryFactory

# Import all services
from .search_service import SearchService
from .index_service import IndexService
from .pdf_service import PDFService
from .product_service import ProductService

log = logging.getLogger(__name__)


class ServiceFactory:
    """
    Factory for creating and managing service instances.

    Uses singleton pattern to reuse instances and shared resources (embedding models, LLM clients).
    Supports dependency injection for testing.
    """

    _instances = {}
    _shared_resources = {}
    _lock = threading.RLock()

    @classmethod
    def reset(cls):
        """Reset all cached instances (useful for testing)"""
        with cls._lock:
            cls._instances.clear()
            cls._shared_resources.clear()

    @classmethod
    def _get_embedding_model(cls) -> SentenceTransformer:
        """
        Get shared embedding model instance (expensive to load).

        Returns:
            SentenceTransformer instance
        """
        if 'embedding_model' not in cls._shared_resources:
            with cls._lock:
                if 'embedding_model' not in cls._shared_resources:
                    model_name = current_app.config.get(
                        "EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2"
                    )
                    log.info("Loading embedding model: %s", model_name)
                    cls._shared_resources['embedding_model'] = SentenceTransformer(model_name)
                    log.info("Embedding model loaded successfully")
        return cls._shared_resources['embedding_model']

    @classmethod
    def _get_llm_client(cls) -> Optional[OpenAI]:
        """
        Get shared OpenAI client instance.

        Returns:
            OpenAI client or None if API key not configured
        """
        if 'llm_client' not in cls._shared_resources:
            with cls._lock:
                if 'llm_client' not in cls._shared_resources:
                    api_key = current_app.config.get("OPENAI_API_KEY")
                    if api_key:
                        base_url = current_app.config.get("OPENAI_BASE_URL") or None
                        cls._shared_resources['llm_client'] = OpenAI(
                            api_key=api_key,
                            base_url=base_url,
                        )
                        log.info("OpenAI client initialized (base_url=%s)", base_url or "default")
                    else:
                        cls._shared_resources['llm_client'] = None
                        log.info("OPENAI_API_KEY not configured; LLM client is None")
        return cls._shared_resources['llm_client']

    @classmethod
    def get_search_service(cls) -> SearchService:
        """
        Get SearchService instance.

        Returns:
            SearchService instance with injected dependencies
        """
        if SearchService not in cls._instances:
            with cls._lock:
                if SearchService not in cls._instances:
                    qdrant_repo = RepositoryFactory.get_qdrant_repository()
                    neo4j_repo = RepositoryFactory.get_neo4j_repository()
                    model = cls._get_embedding_model()
                    llm = cls._get_llm_client()
                    cls._instances[SearchService] = SearchService(qdrant_repo, neo4j_repo, model, llm)
        return cls._instances[SearchService]

    @classmethod
    def get_index_service(cls) -> IndexService:
        """
        Get IndexService instance.

        Returns:
            IndexService instance with injected dependencies
        """
        if IndexService not in cls._instances:
            with cls._lock:
                if IndexService not in cls._instances:
                    qdrant_repo = RepositoryFactory.get_qdrant_repository()
                    mysql_repo = RepositoryFactory.get_mysql_repository()
                    neo4j_repo = RepositoryFactory.get_neo4j_repository()  # GRAPH-06
                    model = cls._get_embedding_model()
                    cls._instances[IndexService] = IndexService(
                        qdrant_repo, mysql_repo, model, neo4j_repo
                    )
        return cls._instances[IndexService]

    @classmethod
    def get_pdf_service(cls) -> PDFService:
        """
        Get PDFService instance.

        Returns:
            PDFService instance with injected dependencies
        """
        if PDFService not in cls._instances:
            with cls._lock:
                if PDFService not in cls._instances:
                    qdrant_repo = RepositoryFactory.get_qdrant_repository()
                    model = cls._get_embedding_model()
                    cls._instances[PDFService] = PDFService(qdrant_repo, model)
        return cls._instances[PDFService]

    @classmethod
    def get_product_service(cls) -> ProductService:
        """
        Get ProductService instance.

        Returns:
            ProductService instance with injected dependencies
        """
        if ProductService not in cls._instances:
            with cls._lock:
                if ProductService not in cls._instances:
                    mysql_repo = RepositoryFactory.get_mysql_repository()
                    qdrant_repo = RepositoryFactory.get_qdrant_repository()
                    cls._instances[ProductService] = ProductService(mysql_repo, qdrant_repo)
        return cls._instances[ProductService]


# Export all service classes and factory
__all__ = [
    # Service classes
    "SearchService",
    "IndexService",
    "PDFService",
    "ProductService",
    # Factory
    "ServiceFactory",
]
