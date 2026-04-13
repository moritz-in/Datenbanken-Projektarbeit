"""
Search Service - Business Logic for Search Operations

Handles vector search, RAG (Retrieval-Augmented Generation), and graph enrichment.
"""
import logging
from typing import Optional, Iterable

from flask import current_app
from sentence_transformers import SentenceTransformer
from openai import OpenAI

from repositories import QdrantRepository, Neo4jRepository

log = logging.getLogger(__name__)


class SearchService:
    """Service for search operations with vector DB, graph enrichment, and LLM"""

    def __init__(
        self,
        qdrant_repo: QdrantRepository,
        neo4j_repo: Optional[Neo4jRepository],
        embedding_model: Optional[SentenceTransformer] = None,
        llm_client: Optional[OpenAI] = None,
    ):
        """
        Initialize search service.

        Args:
            qdrant_repo: Qdrant repository for vector search
            neo4j_repo: Optional Neo4j repository for graph enrichment
            embedding_model: Optional pre-initialized embedding model
            llm_client: Optional pre-initialized OpenAI client
        """
        self.qdrant_repo = qdrant_repo
        self.neo4j_repo = neo4j_repo
        self._embedding_model = embedding_model
        self._llm_client = llm_client

    def _get_embedding_model(self) -> SentenceTransformer:
        """Return injected embedding model singleton — never lazy-load here."""
        return self._embedding_model

    def _get_llm_client(self) -> OpenAI:
        """Return injected LLM client — may be None if no API key configured."""
        return self._llm_client

    def embed_texts(self, texts: list[str]) -> list:
        """
        Generate embeddings for a list of texts.

        Args:
            texts: List of text strings

        Returns:
            List of embedding vectors (list[float])
        """
        model = self._get_embedding_model()
        return model.encode(texts, show_progress_bar=False).tolist()

    def vector_search(
        self, query: str, topk: int = 5, collection_name: Optional[str] = None
    ) -> list[dict]:
        """
        Perform vector search on product collection.

        Args:
            query: Search query
            topk: Number of results to return
            collection_name: Optional collection name (uses default if None)

        Returns:
            List of product dictionaries with scores
        """
        coll = collection_name or current_app.config.get("QDRANT_COLLECTION", "products")
        query_vector = self.embed_texts([query])[0]
        hits = self.qdrant_repo.search(coll, query_vector, limit=topk, with_payload=True)
        results = []
        for h in hits:
            payload = h.payload or {}
            results.append({
                'title': payload.get('title', ''),
                'brand': payload.get('brand', ''),
                'price': payload.get('price', 0),
                'score': h.score,
                'doc_preview': payload.get('doc_preview', ''),
                'graph_source': None,  # enriched in Phase 4
            })
        return results

    def rag_search(
        self, strategy: str, query: str, topk: int = 5, use_graph_enrichment: bool = True
    ) -> dict:
        """
        Perform RAG (Retrieval-Augmented Generation) search with graph enrichment.
        Phase 4 — not yet implemented.
        """
        raise NotImplementedError("TODO: implement RAG search (Phase 4).")

    def pdf_rag_search(
        self, query: str, topk: int = 5, pdf_collection: str = "pdf_skripte"
    ) -> Optional[dict]:
        """
        Search in PDF documents with RAG.
        Phase 4 — not yet implemented.
        """
        raise NotImplementedError("TODO: implement PDF RAG search (Phase 4).")

    def search_product_pdfs(
        self, query: str, topk: int = 3, pdf_products_collection: str = "pdf_produkte"
    ) -> list[dict]:
        """
        Search in product PDF documents.
        Phase 4 — not yet implemented.
        """
        raise NotImplementedError("TODO: implement product PDF search (Phase 4).")

    def execute_sql_search(self, query: str) -> list[dict]:
        """
        Execute SQL search query (delegated to ProductService).

        Args:
            query: SQL query string

        Returns:
            List of result dictionaries
        """
        from services import ServiceFactory
        prod_svc = ServiceFactory.get_product_service()
        return prod_svc.execute_sql_query(query)

    def _generate_llm_answer(self, query: str, hits: list[dict]) -> str:
        """
        Generate LLM answer based on search hits.
        Phase 4 — not yet implemented.
        """
        raise NotImplementedError("TODO: implement LLM answer generation (Phase 4).")

    @staticmethod
    def _coerce_int(value) -> Optional[int]:
        """
        Coerce value to int, returning None on failure.

        Args:
            value: Value to coerce

        Returns:
            Integer value or None if conversion fails
        """
        try:
            return int(value)
        except (ValueError, TypeError):
            return None

    @classmethod
    def _coerce_ints(cls, values: Iterable) -> list[int]:
        """
        Coerce iterable of values to list of ints, skipping invalid values.

        Args:
            values: Iterable of values to coerce

        Returns:
            List of valid integers (invalid values excluded)
        """
        return [v for v in (cls._coerce_int(x) for x in values) if v is not None]
