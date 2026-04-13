# Requirements: Datenbanken-Projektarbeit Teil 2

**Defined:** 2026-04-02
**Core Value:** Die Anwendung muss demonstrierbar laufen: Produkte anlegen/ändern/löschen mit Transaktionssicherheit, semantisch suchen (Qdrant) und per RAG mit Graph-Kontext antworten (Neo4j + OpenAI) — alles vergleichbar nebeneinander.

## v1 Requirements

### Foundation — Blocker (zuerst)

- [x] **FOUND-01**: Alle Tabellennamen in `schema.sql` auf Plural umbenannt (`product` → `products`, `brand` → `brands`, `category` → `categories`, `tag` → `tags`)
- [x] **FOUND-02**: `etl_run_log`-Tabelle in `schema.sql` definiert (Spalten: id, strategy, started_at, finished_at, products_processed, products_written, status, error_msg)
- [x] **FOUND-03**: `product_change_log`-Tabelle in `schema.sql` definiert (Spalten: id, product_id, changed_at, field_name, old_value, new_value, changed_by — EAV-Stil normalisiert)
- [x] **FOUND-04**: `sku`-Spalte (`VARCHAR(100) UNIQUE NULL`) zur `products`-Tabelle hinzugefügt
- [x] **FOUND-05**: `RepositoryFactory` vollständig implementiert — alle `get_*()` Methoden geben Singleton-Instanzen zurück
- [x] **FOUND-06**: `ServiceFactory` vollständig implementiert — alle `get_*()` Methoden + `_get_embedding_model()` als echter threading-Lock-gesicherter Singleton
- [x] **FOUND-07**: `NoOpNeo4jRepository` repariert — alle 3 Methoden geben sichere Leerwerte zurück statt `NotImplementedError`
- [x] **FOUND-08**: PostgreSQL-Dead-Code entfernt (`pg_session_factory`, `psycopg2-binary` aus `requirements.txt`)

### A2 — Transaktionen

- [x] **TXN-01**: `MySQLRepositoryImpl.create_product()` implementiert mit explizitem `with session.begin():` — bei Fehler (doppelte SKU) automatischer Rollback
- [x] **TXN-02**: `MySQLRepositoryImpl.update_product()` implementiert mit explizitem Transaction-Block
- [x] **TXN-03**: `MySQLRepositoryImpl.delete_product()` implementiert mit explizitem Transaction-Block (referenzielle Integritätsprüfung)
- [x] **TXN-04**: Rollback-Demo für doppelte SKU vorhanden und über UI auslösbar
- [x] **TXN-05**: Rollback-Demo für referenzielle Integrität (Delete mit aktiven Bestellungen/Tags) vorhanden
- [x] **TXN-06**: `ProductService.create_product_with_relations()` implementiert (Brand, Category, Tags in einer Transaktion)
- [x] **TXN-07**: `ProductService.update_product()` und `delete_product()` implementiert
- [x] **TXN-08**: Route `products.py` vollständig implementiert — CRUD-Formulare mit Flash-Messages bei Fehler und Erfolg

### A3 — Trigger

- [x] **TRIG-01**: MySQL `AFTER UPDATE ON products`-Trigger erstellt — schreibt Eintrag in `product_change_log` mit alten und neuen Werten + Timestamp
- [x] **TRIG-02**: Trigger ist **konditional** — Logeintrag nur wenn sich ein Wert tatsächlich ändert (`IF OLD.x <> NEW.x`)
- [x] **TRIG-03**: Trigger-DDL in `schema.sql` oder separatem `triggers.sql` eingespielt beim DB-Start

### A4 — Stored Procedure

- [x] **PROC-01**: MySQL Stored Procedure `import_product()` erstellt — Produktimport mit Dublettenprüfung via SKU
- [x] **PROC-02**: Procedure validiert Pflichtfelder (name, price, category) und gibt OUT-Parameter zurück (status, message)
- [x] **PROC-03**: Procedure-DDL in `schema.sql` oder separatem `procedures.sql` eingespielt beim DB-Start
- [x] **PROC-04**: `ProductService` enthält Methode um `CALL import_product(...)` aufzurufen

### A5 — Indizes & B-Baum

- [x] **IDX-01**: B-Tree-Index auf `products.name` erstellt
- [x] **IDX-02**: B-Tree-Index auf `products.category_id` erstellt
- [x] **IDX-03**: B-Tree-Index auf `products.brand_id` erstellt
- [x] **IDX-04**: Index-DDL in `schema.sql` definiert
- [x] **IDX-05**: `EXPLAIN`-Ausgaben für 3 Queries dokumentiert — Exact-Match-Query, Range-Scan-Query, JOIN-Query — jeweils vor und nach Indexanlage
- [x] **IDX-06**: Markdown-Dokument erklärt warum MySQL B-Bäume verwendet und analysiert die EXPLAIN-Ergebnisse

### A6 — Vektor-DB & semantische Suche

- [x] **VECT-01**: `QdrantRepositoryImpl.create_collection()` implementiert — nutzt `delete_collection` + `create_collection` (kein deprecated `recreate_collection`)
- [x] **VECT-02**: `QdrantRepositoryImpl.upsert_points()` implementiert — mit `ensure_collection()` vor Upsert und `wait=True`
- [x] **VECT-03**: `QdrantRepositoryImpl.search()` implementiert — gibt Trefferliste mit Scores zurück
- [x] **VECT-04**: `QdrantRepositoryImpl.extract_pdf_chunks()` und `upload_pdf_chunks()` implementiert
- [x] **VECT-05**: `IndexService` implementiert — Produkte laden → embedden (numpy `.tolist()`) → in Qdrant upserten + ETL-Lauf in `etl_run_log` loggen
- [x] **VECT-06**: `SearchService.vector_search()` implementiert — Query embedden → Qdrant-Suche → Ergebnisse zurückgeben
- [x] **VECT-07**: Route `search.py` implementiert — semantische Suche und klassische SQL-Volltextsuche nebeneinander angezeigt
- [x] **VECT-08**: Route `index.py` implementiert — Index-Build-Formular mit Fortschrittsanzeige

### A7 — Graph-DB & LLM/RAG

- [ ] **GRAPH-01**: `Neo4jRepositoryImpl.get_product_relationships()` implementiert — nutzt `driver.execute_query()` mit MERGE-Pattern für Sync
- [ ] **GRAPH-02**: `Neo4jRepositoryImpl.execute_cypher()` implementiert — generische Cypher-Ausführung
- [ ] **GRAPH-03**: `Neo4jRepositoryImpl.close()` implementiert
- [ ] **GRAPH-04**: Neo4j-Graph befüllt: Produkt → Brand (`MADE_BY`), Produkt → Category (`IN_CATEGORY`), Produkt → Tag (`HAS_TAG`) aus MySQL synchronisiert
- [ ] **GRAPH-05**: `related_products`-Abfrage implementiert via Graph-Traversal: `MATCH (p)-[:MADE_BY]->(b)<-[:MADE_BY]-(other)` — Produkte desselben Herstellers finden
- [ ] **GRAPH-06**: `SearchService.rag_search()` implementiert — Vektor-Suche + Graph-Anreicherung + OpenAI-LLM-Antwort (gpt-4.1-mini)
- [ ] **GRAPH-07**: Route `rag.py` implementiert — RAG-Suchformular mit Antwortanzeige und Quellenangabe

### Supporting Routes

- [x] **ROUTE-01**: `dashboard.py` implementiert — Produktanzahl, letzter ETL-Lauf, System-Status aller 3 DBs
- [x] **ROUTE-02**: `audit.py` implementiert — ETL-Lauf-Log aus `etl_run_log` angezeigt
- [x] **ROUTE-03**: `validate.py` implementiert — Schema-Validierung (erwartet vs. tatsächlich) mit Ergebnis-Anzeige
- [x] **ROUTE-04**: `pdf.py` implementiert — PDF-Upload → Text-Extraktion → Qdrant-Indexierung

### Dokumentation

- [ ] **DOC-01**: `COMPARISON.md` erstellt — konzeptuelle Gegenüberstellung SQL vs. Vektor-Suche vs. Graph+RAG mit konkreten Beispielen: 3 Queries × 3 Suchmethoden mit echten Produktkatalog-Ergebnissen
- [x] **DOC-02**: B-Baum-Analyse-Dokument mit EXPLAIN-Screenshots/Output (abgedeckt durch IDX-05/IDX-06)

## v2 Requirements

### Erweiterte Features (nicht in Scope für Abgabe)

- **EXT-01**: Streaming LLM-Antworten (Server-Sent Events)
- **EXT-02**: PDF-Upload für RAG mit mehreren Dateien gleichzeitig
- **EXT-03**: Alternative Index-Strategien B (HNSW-Parameter-Tuning) und C (Kategoriefilter-Hybrid-Search)
- **EXT-04**: REST-API-Endpunkte (zusätzlich zum Web-UI)

## Out of Scope

| Feature | Reason |
|---------|--------|
| User Authentication | Akademisches Projekt, kein Login-Layer erforderlich |
| PostgreSQL-Integration | Dead Code im Scaffold — wird entfernt, nicht ersetzt |
| CSRF-Schutz | Out of scope für dieses Semester |
| Rate Limiting | Out of scope |
| Mobile App / REST API | Web-UI only (Jinja2), REST-API in v2 |
| Gunicorn/Production WSGI | Docker dev-server reicht für Abgabe |
| Streaming LLM | Erhöhte Komplexität, kein Mehrwert für Bewertung |
| Index-Strategien B & C | Aufwand unverhältnismäßig, Strategie A ausreichend |

## Traceability

Wird nach Roadmap-Erstellung befüllt.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 0 | Complete |
| FOUND-02 | Phase 0 | Complete |
| FOUND-03 | Phase 0 | Complete |
| FOUND-04 | Phase 0 | Complete |
| FOUND-05 | Phase 0 | Complete |
| FOUND-06 | Phase 0 | Complete |
| FOUND-07 | Phase 0 | Complete |
| FOUND-08 | Phase 0 | Complete |
| TXN-01 | Phase 1 | Complete |
| TXN-02 | Phase 1 | Complete |
| TXN-03 | Phase 1 | Complete |
| TXN-04 | Phase 1 | Complete |
| TXN-05 | Phase 1 | Complete |
| TXN-06 | Phase 1 | Complete |
| TXN-07 | Phase 1 | Complete |
| TXN-08 | Phase 1 | Complete |
| TRIG-01 | Phase 2 | Complete |
| TRIG-02 | Phase 2 | Complete |
| TRIG-03 | Phase 2 | Complete |
| PROC-01 | Phase 2 | Complete |
| PROC-02 | Phase 2 | Complete |
| PROC-03 | Phase 2 | Complete |
| PROC-04 | Phase 2 | Complete |
| IDX-01 | Phase 2 | Complete |
| IDX-02 | Phase 2 | Complete |
| IDX-03 | Phase 2 | Complete |
| IDX-04 | Phase 2 | Complete |
| IDX-05 | Phase 2 | Complete |
| IDX-06 | Phase 2 | Complete |
| VECT-01 | Phase 3 | Complete |
| VECT-02 | Phase 3 | Complete |
| VECT-03 | Phase 3 | Complete |
| VECT-04 | Phase 3 | Complete |
| VECT-05 | Phase 3 | Complete |
| VECT-06 | Phase 3 | Complete |
| VECT-07 | Phase 3 | Complete |
| VECT-08 | Phase 3 | Complete |
| GRAPH-01 | Phase 4 | Pending |
| GRAPH-02 | Phase 4 | Pending |
| GRAPH-03 | Phase 4 | Pending |
| GRAPH-04 | Phase 4 | Pending |
| GRAPH-05 | Phase 4 | Pending |
| GRAPH-06 | Phase 4 | Pending |
| GRAPH-07 | Phase 4 | Pending |
| ROUTE-01 | Phase 1 | Complete |
| ROUTE-02 | Phase 2 | Complete |
| ROUTE-03 | Phase 2 | Complete |
| ROUTE-04 | Phase 3 | Complete |
| DOC-01 | Phase 5 | Pending |
| DOC-02 | Phase 2 | Complete |

**Coverage:**
- v1 requirements: 50 total
- Mapped to phases: 50
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-02*
*Last updated: 2026-04-02 after initial definition*
