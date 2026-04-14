"""
Index Service - Business Logic for Index Management

Handles building, truncating, and monitoring the Qdrant vector index.
"""
import logging
import time
from typing import Optional
from datetime import datetime

from flask import current_app
from sentence_transformers import SentenceTransformer

from repositories import QdrantRepository, MySQLRepository, Neo4jRepository

log = logging.getLogger(__name__)


class IndexService:
    """Service for managing the product vector index"""

    def __init__(
        self,
        qdrant_repo: QdrantRepository,
        mysql_repo: MySQLRepository,
        embedding_model: Optional[SentenceTransformer] = None,
        neo4j_repo: Optional[Neo4jRepository] = None,
    ):
        """
        Initialize index service.

        Args:
            qdrant_repo: Qdrant repository for vector operations
            mysql_repo: MySQL repository for loading products
            embedding_model: Optional pre-initialized embedding model
            neo4j_repo: Optional Neo4j repository for graph sync
        """
        self.qdrant_repo = qdrant_repo
        self.mysql_repo = mysql_repo
        self._embedding_model = embedding_model
        self.neo4j_repo = neo4j_repo

    def _get_embedding_model(self) -> SentenceTransformer:
        """Return injected embedding model singleton — never lazy-load here."""
        return self._embedding_model

    def embed_texts(self, texts: list[str]) -> list:
        """
        Generate embeddings for a list of texts.

        Args:
            texts: List of text strings

        Returns:
            List of embedding vectors (list[float])
        """
        model = self._get_embedding_model()
        return model.encode(texts, batch_size=64, show_progress_bar=False).tolist()

    @staticmethod
    def product_to_document(product: dict) -> str:
        """
        Convert a product dictionary to a searchable document string.

        Skips any label+value where value is None or empty string.
        Never includes the word "None" as a value.

        Args:
            product: Product dictionary with fields

        Returns:
            Formatted document string
        """
        parts = []
        name = product.get('name')
        if name:
            parts.append(f"Name: {name}")
        description = product.get('description')
        if description:
            parts.append(f"Beschreibung: {description}")
        brand = product.get('brand')
        if brand:
            parts.append(f"Marke: {brand}")
        category = product.get('category')
        if category:
            parts.append(f"Kategorie: {category}")
        tags = product.get('tags')
        if tags:
            if isinstance(tags, list):
                tags_str = ', '.join(str(t) for t in tags if t)
            else:
                tags_str = str(tags)
            if tags_str:
                parts.append(f"Tags: {tags_str}")
        return ' '.join(parts)

    def build_index(
        self, strategy: str = "A", limit: Optional[int] = None, batch_size: int = 64
    ) -> dict:
        """
        Build the product vector index.

        Strategy C: Complete rebuild (delete and recreate) — the only exposed strategy.

        Args:
            strategy: Indexing strategy (only 'C' used in Phase 3)
            limit: Optional limit on number of products to index
            batch_size: Batch size for embedding generation

        Returns:
            Dictionary with indexing statistics: count, elapsed, strategy
        """
        started_at = datetime.utcnow()
        collection_name = current_app.config.get("QDRANT_COLLECTION", "products")
        try:
            # Strategy C: delete + recreate collection
            if strategy == "C":
                self.qdrant_repo.delete_collection(collection_name)
                self.qdrant_repo.ensure_collection(collection_name, 384, 'COSINE', 16, 128)

            # Load products from MySQL
            products = self.mysql_repo.load_products_for_index()
            if limit:
                products = products[:limit]

            # Build document strings
            docs = [self.product_to_document(p) for p in products]

            # Batch embed
            model = self._get_embedding_model()
            embeddings = []
            for i in range(0, len(docs), batch_size):
                batch = docs[i:i + batch_size]
                embeddings.extend(model.encode(batch, show_progress_bar=False).tolist())

            # Build point dicts
            points = [
                {
                    'id': p['id'],
                    'vector': embeddings[i],
                    'payload': {
                        'title': p.get('name', ''),
                        'brand': p.get('brand', ''),
                        'price': float(p.get('price', 0) or 0),
                        'doc_preview': doc[:200],
                        'score': None,
                    },
                }
                for i, (p, doc) in enumerate(zip(products, docs))
            ]

            # Upsert into Qdrant
            self.qdrant_repo.upsert_points(collection_name, points)

            # Sync to Neo4j graph (GRAPH-06)
            neo4j_count = 0
            if self.neo4j_repo is not None:
                try:
                    neo4j_count = self.neo4j_repo.sync_products(products)
                    log.info("build_index: synced %d products to Neo4j", neo4j_count)
                except Exception as neo4j_err:
                    log.warning("build_index: Neo4j sync failed (non-fatal): %s", neo4j_err)

            finished_at = datetime.utcnow()
            elapsed = (finished_at - started_at).total_seconds()

            # Log ETL run
            self.mysql_repo.log_etl_run(
                strategy=strategy,
                started_at=started_at,
                finished_at=finished_at,
                products_processed=len(products),
                products_written=len(products),
                status='success',
                error_msg=None,
            )
            log.debug(
                "build_index: strategy=%s indexed=%d elapsed=%.1fs",
                strategy, len(products), elapsed,
            )
            return {'count': len(products), 'elapsed': elapsed, 'strategy': strategy, 'neo4j_count': neo4j_count}

        except Exception as e:
            finished_at = datetime.utcnow()
            log.error("build_index failed: %s", e, exc_info=True)
            try:
                self.mysql_repo.log_etl_run(
                    strategy=strategy,
                    started_at=started_at,
                    finished_at=finished_at,
                    products_processed=0,
                    products_written=0,
                    status='error',
                    error_msg=str(e),
                )
            except Exception as log_err:
                log.error("Failed to log ETL error: %s", log_err)
            raise

    def get_index_status(self) -> dict:
        """
        Get current index status.

        Returns:
            Dictionary with index statistics
        """
        collection_name = current_app.config.get("QDRANT_COLLECTION", "products")
        info = self.qdrant_repo.get_collection_info(collection_name)
        model_name = current_app.config.get(
            "EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2"
        )
        return {
            'count_indexed': info.get('points_count', 0),
            'last_indexed_at': None,
            'embedding_model': model_name,
            'collection_info': info,
        }

    def truncate_index(self, collection_name: Optional[str] = None) -> None:
        """
        Truncate (delete and recreate) the index.

        Args:
            collection_name: Optional collection name (uses default if None)
        """
        self.qdrant_repo.truncate_index(collection_name)

    def get_collection_info(self, collection_name: Optional[str] = None) -> dict:
        """
        Get detailed information about a collection.

        Args:
            collection_name: Optional collection name (uses default if None)

        Returns:
            Dictionary with collection information
        """
        coll = collection_name or current_app.config.get("QDRANT_COLLECTION", "products")
        return self.qdrant_repo.get_collection_info(coll)
