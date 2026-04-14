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
        RAG search: vector retrieval → graph enrichment → LLM answer.

        Returns:
            {
                'query': str,
                'answer': str,
                'hits': list[dict],   # enriched with graph_source, tags, category, related_products
            }
        """
        coll = current_app.config.get("QDRANT_COLLECTION", "products")
        query_vector = self.embed_texts([query])[0]

        # Vector retrieval — call qdrant_repo.search() directly to access hit.id
        raw_hits = self.qdrant_repo.search(coll, query_vector, limit=topk, with_payload=True)

        # Build hit dicts, capturing mysql_id from point id
        hits = []
        mysql_ids = []
        for h in raw_hits:
            payload = h.payload or {}
            mysql_id = h.id if isinstance(h.id, int) else None
            if mysql_id is not None:
                mysql_ids.append(mysql_id)
            hits.append({
                'mysql_id': mysql_id,
                'title': payload.get('title', ''),
                'brand': payload.get('brand', ''),
                'price': payload.get('price', 0),
                'score': h.score,
                'doc_preview': payload.get('doc_preview', ''),
                'category': '',
                'tags': [],
                'related_products': [],
                'graph_source': None,
            })

        # Graph enrichment
        if use_graph_enrichment and self.neo4j_repo is not None and mysql_ids:
            try:
                enrichment = self.neo4j_repo.get_product_relationships(mysql_ids)
                for hit in hits:
                    mid = hit.get('mysql_id')
                    if mid is not None and mid in enrichment:
                        data = enrichment[mid]
                        hit['category'] = data.get('category', '')
                        hit['tags'] = data.get('tags') or []
                        hit['related_products'] = data.get('related_products') or []
                        # Override brand/title from graph if more complete
                        if data.get('brand'):
                            hit['brand'] = data['brand']
                        if data.get('title'):
                            hit['title'] = data['title']
                        hit['graph_source'] = 'Neo4j'
            except Exception as e:
                log.warning("Graph enrichment failed (non-fatal): %s", e)

        # Generate LLM answer
        answer = self._generate_llm_answer(query, hits)

        return {'query': query, 'answer': answer, 'hits': hits}

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
        Generate German-language LLM answer from query + enriched hits.
        Returns localized fallback string if LLM client is not configured.
        """
        client = self._get_llm_client()
        if client is None:
            return "[LLM nicht konfiguriert — OPENAI_API_KEY fehlt]"

        # Build context from enriched hits
        context_parts = []
        for i, h in enumerate(hits[:5], 1):
            tags_str = ', '.join(h.get('tags') or []) or '–'
            related_str = ', '.join(h.get('related_products') or []) or '–'
            context_parts.append(
                f"{i}. {h.get('title', '')} "
                f"(Marke: {h.get('brand', '–')}, "
                f"Kategorie: {h.get('category', '–')}, "
                f"Tags: {tags_str}, "
                f"Ähnliche Produkte: {related_str}, "
                f"Preis: {h.get('price', 0):.2f} EUR)"
            )
        context_text = '\n'.join(context_parts)

        prompt = (
            f"Du bist ein hilfreicher Produktberater. "
            f"Beantworte folgende Anfrage auf Deutsch in 2-3 Sätzen:\n\n"
            f"Anfrage: {query}\n\n"
            f"Relevante Produkte aus der Datenbank:\n{context_text}\n\n"
            f"Antworte auf Basis der Produktliste. Nenne konkrete Produktnamen."
        )

        model_name = current_app.config.get("LLM_MODEL", "gpt-4.1-mini")
        try:
            response = client.chat.completions.create(
                model=model_name,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=300,
                temperature=0.3,
            )
            return response.choices[0].message.content.strip()
        except Exception as e:
            log.warning("LLM answer generation failed: %s", e)
            return f"[LLM-Fehler: {e}]"

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
