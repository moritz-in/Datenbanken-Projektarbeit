"""
Qdrant Repository - Data Access Layer for Qdrant Vector Database
Handles all Qdrant-specific vector operations.
"""
from abc import ABC, abstractmethod
from typing import Optional
import logging
from datetime import datetime
import uuid
from io import BytesIO

from qdrant_client import QdrantClient
from qdrant_client.http.models import VectorParams, Distance, HnswConfigDiff, PointStruct, SearchParams
import pdfplumber

log = logging.getLogger(__name__)


class QdrantRepository(ABC):
    """Abstract base class for Qdrant vector database operations"""

    @abstractmethod
    def ensure_collection(
        self, collection_name: str, vector_size: int, distance: str = "COSINE"
    ) -> None:
        """Ensure a collection exists, create if not"""
        pass

    @abstractmethod
    def delete_collection(self, collection_name: str) -> None:
        """Delete a collection"""
        pass

    @abstractmethod
    def count(self, collection_name: str, exact: bool = True) -> int:
        """Count points in a collection"""
        pass

    @abstractmethod
    def upsert_points(
        self, collection_name: str, points: list[dict]
    ) -> None:
        """Upsert points into a collection"""
        pass

    @abstractmethod
    def search(
        self,
        collection_name: str,
        query_vector: list[float],
        limit: int,
        with_payload: bool = True,
    ) -> list:
        """Search for similar vectors"""
        pass

    @abstractmethod
    def scroll(
        self, collection_name: str, limit: int = 100, with_payload: bool = True
    ) -> tuple[list, Optional[str]]:
        """Scroll through all points in a collection"""
        pass

    @abstractmethod
    def get_collection_info(self, collection_name: str) -> dict:
        """Get information about a collection"""
        pass

    @abstractmethod
    def truncate_index(self, collection_name: "Optional[str]" = None) -> None:
        """Delete and recreate a collection (empty it completely)"""
        pass


class QdrantRepositoryImpl(QdrantRepository):
    """Concrete implementation of Qdrant repository"""

    def __init__(self, qdrant_url: str, default_collection: str = "products"):
        """
        Initialize Qdrant repository.

        Args:
            qdrant_url: Qdrant server URL
            default_collection: Default collection name for products
        """
        self._client = QdrantClient(url=qdrant_url)
        self._default_collection = default_collection
        log.debug("QdrantRepositoryImpl initialized, url=%s", qdrant_url)

    def ensure_collection(
        self,
        collection_name: str,
        vector_size: int,
        distance: str = "COSINE",
        hnsw_m: int = 16,
        hnsw_ef_construct: int = 128,
    ) -> None:
        """
        Ensure a collection exists, create if not.

        Args:
            collection_name: Name of the collection
            vector_size: Dimension of the embeddings
            distance: Distance metric (COSINE, DOT, EUCLID)
            hnsw_m: HNSW m parameter (connections per point)
            hnsw_ef_construct: HNSW ef_construct parameter (search width during build)
        """
        if self._client.collection_exists(collection_name):
            log.debug("ensure_collection: '%s' already exists, skipping", collection_name)
            return
        distance_enum = getattr(Distance, distance.upper())
        self._client.create_collection(
            collection_name,
            vectors_config=VectorParams(size=vector_size, distance=distance_enum),
            hnsw_config=HnswConfigDiff(m=hnsw_m, ef_construct=hnsw_ef_construct),
        )
        log.debug(
            "ensure_collection: created '%s' size=%d distance=%s m=%d ef=%d",
            collection_name, vector_size, distance, hnsw_m, hnsw_ef_construct,
        )

    def delete_collection(self, collection_name: str) -> None:
        """
        Delete a collection.

        Args:
            collection_name: Name of the collection to delete
        """
        try:
            self._client.delete_collection(collection_name)
            log.debug("delete_collection: deleted '%s'", collection_name)
        except Exception as e:
            # Swallow 404 / not-found — collection already absent is OK
            if "404" in str(e) or "not found" in str(e).lower() or "doesn't exist" in str(e).lower():
                log.debug("delete_collection: '%s' already absent", collection_name)
            else:
                raise

    def count(self, collection_name: str, exact: bool = True) -> int:
        """
        Count points in a collection.

        Args:
            collection_name: Name of the collection
            exact: Whether to use exact count (slower but accurate)

        Returns:
            Number of points in collection
        """
        try:
            result = self._client.count(collection_name, exact=exact)
            return result.count
        except Exception as e:
            log.debug("count: collection '%s' absent or error: %s", collection_name, e)
            return 0

    def upsert_points(self, collection_name: str, points: list[dict]) -> None:
        """
        Upsert points into a collection.

        Args:
            collection_name: Name of the collection
            points: List of point dictionaries with 'id', 'vector', 'payload'
        """
        if not points:
            log.debug("upsert_points: no points to upsert for '%s'", collection_name)
            return

        # Ensure collection exists first, using first vector's size
        vector_size = len(points[0]['vector'])
        self.ensure_collection(collection_name, vector_size=vector_size)

        structs = []
        for point in points:
            vector = point['vector']
            # Defensive .tolist() in case numpy array slips through
            if hasattr(vector, 'tolist'):
                vector = vector.tolist()
            structs.append(PointStruct(
                id=point['id'],
                vector=vector,
                payload=point.get('payload', {}),
            ))

        self._client.upsert(collection_name, points=structs, wait=True)
        log.debug("upsert_points: upserted %d points into '%s'", len(structs), collection_name)

    def search(
        self,
        collection_name: str,
        query_vector: list[float],
        limit: int,
        with_payload: bool = True,
        hnsw_ef: int = 64,
    ) -> list:
        """
        Search for similar vectors.

        Args:
            collection_name: Name of the collection
            query_vector: Query vector
            limit: Maximum number of results
            with_payload: Whether to include payload
            hnsw_ef: HNSW ef parameter (higher = more accurate but slower)

        Returns:
            List of search results (points)
        """
        results = self._client.query_points(
            collection_name,
            query=query_vector,
            limit=limit,
            with_payload=with_payload,
            search_params=SearchParams(hnsw_ef=hnsw_ef),
        ).points
        log.debug("search: got %d hits from '%s'", len(results), collection_name)
        return results

    def scroll(
        self,
        collection_name: str,
        limit: int = 100,
        with_payload: bool = True,
        offset: Optional[str] = None,
    ) -> tuple[list, Optional[str]]:
        """
        Scroll through all points in a collection.

        Args:
            collection_name: Name of the collection
            limit: Number of points to retrieve
            with_payload: Whether to include payload
            offset: Offset for pagination

        Returns:
            Tuple of (points, next_offset)
        """
        points, next_offset = self._client.scroll(
            collection_name,
            limit=limit,
            with_payload=with_payload,
            offset=offset,
        )
        log.debug("scroll: retrieved %d points from '%s'", len(points), collection_name)
        return points, next_offset

    def get_collection_info(self, collection_name: str) -> dict:
        """
        Get information about a collection.

        Args:
            collection_name: Name of the collection

        Returns:
            Dictionary with collection info
        """
        try:
            info = self._client.get_collection(collection_name)
            vectors_config = info.config.params.vectors
            # VectorParams is stored directly (not as dict) for single-vector collections
            if hasattr(vectors_config, 'size'):
                vector_size = vectors_config.size
                distance = str(vectors_config.distance)
            else:
                vector_size = 0
                distance = "COSINE"
            hnsw_config = info.config.hnsw_config
            hnsw_m = hnsw_config.m if hnsw_config and hnsw_config.m is not None else 16
            hnsw_ef = hnsw_config.ef_construct if hnsw_config and hnsw_config.ef_construct is not None else 128
            return {
                'name': collection_name,
                'vector_size': vector_size,
                'distance': distance,
                'points_count': info.points_count or 0,
                'hnsw_m': hnsw_m,
                'hnsw_ef_construct': hnsw_ef,
            }
        except Exception as e:
            log.debug("get_collection_info: collection '%s' absent or error: %s", collection_name, e)
            return {
                'name': collection_name,
                'vector_size': 0,
                'distance': 'COSINE',
                'points_count': 0,
                'hnsw_m': 16,
                'hnsw_ef_construct': 128,
            }

    # ======================
    # High-level operations
    # ======================

    def truncate_index(self, collection_name: Optional[str] = None) -> None:
        """
        Truncate (delete and recreate) a collection.

        Args:
            collection_name: Name of the collection (uses default if None)
        """
        target = collection_name or self._default_collection
        self.delete_collection(target)
        self.ensure_collection(target, vector_size=384, distance='COSINE', hnsw_m=16, hnsw_ef_construct=128)
        log.debug("truncate_index: truncated '%s'", target)

    def get_unique_sources(self, collection_name: str) -> set[str]:
        """
        Get unique source filenames from a collection.

        Useful for PDF collections to count unique uploaded files.

        Args:
            collection_name: Name of the collection

        Returns:
            Set of unique source filenames
        """
        sources = set()
        offset = None
        try:
            while True:
                points, next_offset = self.scroll(
                    collection_name, limit=100, with_payload=True, offset=offset
                )
                for point in points:
                    payload = point.payload or {}
                    source = payload.get('source')
                    if source:
                        sources.add(source)
                if next_offset is None:
                    break
                offset = next_offset
        except Exception as e:
            log.debug("get_unique_sources: collection '%s' absent or error: %s", collection_name, e)
        return sources

    # ======================
    # PDF-specific operations
    # ======================

    def upload_pdf_chunks(
        self,
        collection_name: str,
        chunks: list[dict],
        embeddings: list,
        source_filename: str,
    ) -> int:
        """
        Upload PDF chunks with embeddings to Qdrant.

        Args:
            collection_name: Name of the collection
            chunks: List of chunk dictionaries with 'text' and 'page'
            embeddings: List of embedding vectors
            source_filename: Source PDF filename

        Returns:
            Number of chunks uploaded
        """
        self.ensure_collection(collection_name, vector_size=384)
        structs = []
        for chunk, embedding in zip(chunks, embeddings):
            vector = embedding.tolist() if hasattr(embedding, 'tolist') else embedding
            structs.append(PointStruct(
                id=uuid.UUID(str(uuid.uuid4())),
                vector=vector,
                payload={
                    'text': chunk['text'],
                    'page': chunk['page'],
                    'source': source_filename,
                },
            ))
        self._client.upsert(collection_name, points=structs, wait=True)
        log.debug("upload_pdf_chunks: uploaded %d chunks to '%s'", len(structs), collection_name)
        return len(chunks)

    @staticmethod
    def extract_pdf_chunks(pdf_file, chunk_size: int = 300) -> list[dict]:
        """
        Extract text chunks from a PDF file.

        Args:
            pdf_file: File object or BytesIO
            chunk_size: Size of each text chunk in characters

        Returns:
            List of chunk dictionaries with 'text' and 'page'
        """
        chunks = []
        with pdfplumber.open(pdf_file) as pdf:
            for page_num, page in enumerate(pdf.pages, start=1):
                text = page.extract_text() or ""
                # Split into non-overlapping chunks of chunk_size characters
                for i in range(0, len(text), chunk_size):
                    chunk_text = text[i:i + chunk_size]
                    if chunk_text.strip():
                        chunks.append({'text': chunk_text, 'page': page_num})
        return chunks

    def get_pdf_counts(
        self, pdf_collection: str, pdf_products_collection: str
    ) -> dict:
        """
        Get count of unique PDF files in both collections.

        Args:
            pdf_collection: Name of the teaching PDF collection
            pdf_products_collection: Name of the product PDF collection

        Returns:
            Dictionary with counts for each collection and total
        """
        try:
            count1 = len(self.get_unique_sources(pdf_collection))
        except Exception:
            count1 = 0
        try:
            count2 = len(self.get_unique_sources(pdf_products_collection))
        except Exception:
            count2 = 0
        return {
            pdf_collection: count1,
            pdf_products_collection: count2,
            'total': count1 + count2,
        }

    def list_uploaded_pdfs(self, collection_name: str) -> list[str]:
        """
        List all uploaded PDF filenames in a collection.

        Args:
            collection_name: Name of the collection

        Returns:
            Sorted list of unique PDF filenames
        """
        try:
            sources = self.get_unique_sources(collection_name)
            return sorted(sources)
        except Exception:
            return []
