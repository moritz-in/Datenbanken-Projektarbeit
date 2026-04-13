---
phase: "03"
plan: "03"
subsystem: pdf-service
tags: [pdf, chunking, pdfplumber, qdrant, flask-route, json-api]
dependency_graph:
  requires: [QdrantRepositoryImpl-core-methods]
  provides: [PDFService-complete, /pdf-upload-route, /api/pdf-stats]
  affects: [templates/pdf_upload.html]
tech_stack:
  added: []
  patterns: [PRG-pattern, static-method-for-pdf-extraction, uuid-IDs-for-chunks]
key_files:
  created: []
  modified: [services/pdf_service.py, routes/pdf.py]
decisions:
  - "extract_pdf_chunks is @staticmethod — no self needed, used by PDFService via class reference"
  - "upload_pdf_chunks uses uuid.UUID(str(uuid.uuid4())) for Qdrant point IDs"
  - "GET /api/pdf-stats returns safe zeros on exception — JS fetch never fails"
  - "pdf_upload GET route does not pass template variables — counts loaded via JS fetch"
metrics:
  duration: "5min"
  completed: "2026-04-13"
  tasks_completed: 2
  files_modified: 2
---

# Phase 03 Plan 03: PDF Pipeline + /pdf-upload Route Summary

**One-liner:** PDF chunking pipeline implemented via pdfplumber (300-char non-overlapping chunks with page numbers), PDFService wires extract/embed/upload, and /pdf-upload route provides teaching + product PDF upload with /api/pdf-stats JSON endpoint for live counts.

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | QdrantRepositoryImpl PDF methods (extract_pdf_chunks, upload_pdf_chunks, get_pdf_counts, list_uploaded_pdfs) | 0c8bdb1 (Plan 01) | ✅ |
| 2 | Implement PDFService + routes/pdf.py | cd5bd65 | ✅ |

## Key Implementation Details

### extract_pdf_chunks (QdrantRepositoryImpl @staticmethod)
- Opens PDF with `pdfplumber.open(pdf_file)` (accepts file object or BytesIO)
- For each page: `extract_text() or ""` → split into `chunk_size`-char chunks
- Each chunk: `{'text': chunk_text, 'page': page_num}` (1-based page number)
- Skips chunks where `chunk_text.strip()` is empty

### upload_pdf_chunks
- Calls `ensure_collection(collection_name, vector_size=384)` first
- UUID point IDs: `uuid.UUID(str(uuid.uuid4()))`
- `.tolist()` guard on embeddings
- `wait=True` for synchronous completion
- Returns `len(chunks)` count

### PDFService.upload_pdf_to_qdrant
1. `filename = getattr(pdf_file, 'filename', 'unknown.pdf')`
2. `chunks = QdrantRepositoryImpl.extract_pdf_chunks(pdf_file, chunk_size)`
3. If no chunks: return `"Keine Textinhalte gefunden"`
4. Embed all chunk texts
5. Upload chunks → return `"{n} Chunks indexiert"`

### routes/pdf.py
- `GET /pdf-upload`: renders `pdf_upload.html` (counts loaded via JS)
- `POST /upload-teaching-pdf`: validates `.pdf` extension, flashes msg, PRG
- `POST /upload-product-pdf`: same pattern for product PDF collection
- `GET /api/pdf-stats`: returns `{"pdf_skripte": N, "pdf_produkte": M}` or zeros on error

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED
- `services/pdf_service.py` exists with no NotImplementedError stubs ✅
- `routes/pdf.py` exists with no NotImplementedError stubs ✅
- Commit `cd5bd65` exists ✅
- routes/pdf.py has flash, redirect, jsonify ✅
- QdrantRepositoryImpl not abstract ✅
