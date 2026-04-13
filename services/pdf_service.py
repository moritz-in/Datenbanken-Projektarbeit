"""
PDF Service - Business Logic for PDF Upload and Management

Handles PDF upload, chunking, and indexing into Qdrant.
"""
import logging
from typing import Optional

from flask import current_app
from sentence_transformers import SentenceTransformer

from repositories import QdrantRepository
from repositories.qdrant_repository import QdrantRepositoryImpl

log = logging.getLogger(__name__)

# Collection names
COLLECTION_PDF = "pdf_skripte"
COLLECTION_PDF_PRODUCTS = "pdf_produkte"


class PDFService:
    """Service for PDF upload and management"""

    def __init__(
        self,
        qdrant_repo: QdrantRepository,
        embedding_model: Optional[SentenceTransformer] = None,
    ):
        """
        Initialize PDF service.

        Args:
            qdrant_repo: Qdrant repository for vector operations
            embedding_model: Optional pre-initialized embedding model
        """
        self.qdrant_repo = qdrant_repo
        self._embedding_model = embedding_model

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
        return self._get_embedding_model().encode(texts, show_progress_bar=False).tolist()

    def upload_pdf_to_qdrant(
        self, pdf_file, collection_name: str = COLLECTION_PDF, chunk_size: int = 300
    ) -> str:
        """
        Upload a teaching PDF to Qdrant.

        Args:
            pdf_file: File object (Flask request.files)
            collection_name: Target collection name
            chunk_size: Size of text chunks in characters

        Returns:
            Status message string

        Raises:
            Exception: On upload errors
        """
        filename = getattr(pdf_file, 'filename', 'unknown.pdf')
        chunks = QdrantRepositoryImpl.extract_pdf_chunks(pdf_file, chunk_size)
        if not chunks:
            return "Keine Textinhalte gefunden"
        texts = [c['text'] for c in chunks]
        embeddings = self.embed_texts(texts)
        n = self.qdrant_repo.upload_pdf_chunks(collection_name, chunks, embeddings, filename)
        return f"{n} Chunks indexiert"

    def upload_product_pdf(self, pdf_file, chunk_size: int = 300) -> str:
        """
        Upload a product PDF to Qdrant.

        Args:
            pdf_file: File object (Flask request.files)
            chunk_size: Size of text chunks in characters

        Returns:
            Status message string

        Raises:
            Exception: On upload errors
        """
        return self.upload_pdf_to_qdrant(pdf_file, COLLECTION_PDF_PRODUCTS, chunk_size)

    def get_pdf_counts(self) -> dict:
        """
        Get count of unique PDF files in both collections.

        Returns:
            Dictionary with counts for teaching and product PDFs
        """
        return self.qdrant_repo.get_pdf_counts(COLLECTION_PDF, COLLECTION_PDF_PRODUCTS)

    def list_uploaded_pdfs(
        self, collection_name: Optional[str] = None
    ) -> list[str]:
        """
        List all uploaded PDF filenames.

        Args:
            collection_name: Optional collection name (defaults to teaching PDFs)

        Returns:
            Sorted list of unique PDF filenames
        """
        coll = collection_name or COLLECTION_PDF
        return self.qdrant_repo.list_uploaded_pdfs(coll)

    def list_teaching_pdfs(self) -> list[str]:
        """
        List all teaching PDFs.

        Returns:
            Sorted list of teaching PDF filenames
        """
        return self.qdrant_repo.list_uploaded_pdfs(COLLECTION_PDF)

    def list_product_pdfs(self) -> list[str]:
        """
        List all product PDFs.

        Returns:
            Sorted list of product PDF filenames
        """
        return self.qdrant_repo.list_uploaded_pdfs(COLLECTION_PDF_PRODUCTS)

    def ensure_collections(self) -> None:
        """
        Ensure both PDF collections exist.

        Creates the collections if they don't exist yet.
        """
        self.qdrant_repo.ensure_collection(COLLECTION_PDF, 384)
        self.qdrant_repo.ensure_collection(COLLECTION_PDF_PRODUCTS, 384)

    def get_collection_stats(self, collection_name: Optional[str] = None) -> dict:
        """
        Get statistics for a PDF collection.

        Args:
            collection_name: Optional collection name (defaults to teaching PDFs)

        Returns:
            Dictionary with collection statistics
        """
        collection = collection_name or COLLECTION_PDF
        return {'collection': collection, 'count': self.qdrant_repo.count(collection)}
