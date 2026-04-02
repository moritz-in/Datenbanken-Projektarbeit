# Requirements: Datenbanken-Projektarbeit Teil 2

**Defined:** 2026-04-02
**Core Value:** Die Anwendung muss demonstrierbar laufen: Produkte anlegen/ändern/löschen mit Transaktionssicherheit, semantisch suchen (Qdrant) und per RAG mit Graph-Kontext antworten (Neo4j + OpenAI) — alles vergleichbar nebeneinander.

## v1 Requirements

### Foundation — Blocker (zuerst)

- [ ] **FOUND-01**: Alle Tabellennamen in `schema.sql` auf Plural umbenannt (`product` → `products`, `brand` → `brands`, `category` → `categories`, `tag` → `tags`)
- [ ] **FOUND-02**: `etl_run_log`-Tabelle in `schema.sql` definiert (Spalten: id, run_at, products_indexed, duration_seconds, status)
- [ ] **FOUND-03**: `product_change_log`-Tabelle in `schema.sql` definiert (Spalten: id, product_id, changed_at, old_name, new_name, old_price, new_price, old_description, new_description)
- [ ] **FOUND-04**: `sku`-Spalte (`VARCHAR(100) UNIQUE NULL`) zur `products`-Tabelle hinzugefügt
- [ ] **FOUND-05**: `RepositoryFactory` vollständig implementiert — alle `get_*()` Methoden geben Singleton-Instanzen zurück
- [ ] **FOUND-06**: `ServiceFactory` vollständig implementiert — alle `get_*()` Methoden + `_get_embedding_model()` als echter threading-Lock-gesicherter Singleton
- [ ] **FOUND-07**: `NoOpNeo4jRepository` repariert — alle 3 Methoden geben sichere Leerwerte zurück statt `NotImplementedError`
- [ ] **FOUND-08**: PostgreSQL-Dead-Code entfernt (`pg_session_factory`, `psycopg2-binary` aus `requirements.txt`)

### A2 — Transaktionen

- [ ] **TXN-01**: `MySQLRepositoryImpl.create_product()` implementiert mit explizitem `with session.begin():` — bei Fehler (doppelte SKU) automatischer Rollback
- [ ] **TXN-02**: `MySQLRepositoryImpl.update_product()` implementiert mit explizitem Transaction-Block
- [ ] **TXN-03**: `MySQLRepositoryImpl.delete_product()` implementiert mit explizitem Transaction-Block (referenzielle Integritätsprüfung)
- [ ] **TXN-04**: Rollback-Demo für doppelte SKU vorhanden und über UI auslösbar
- [ ] **TXN-05**: Rollback-Demo für referenzielle Integrität (Delete mit aktiven Bestellungen/Tags) vorhanden
- [ ] **TXN-06**: `ProductService.create_product_with_relations()` implementiert (Brand, Category, Tags in einer Transaktion)
- [ ] **TXN-07**: `ProductService.update_product()` und `delete_product()` implementiert
- [ ] **TXN-08**: Route `products.py` vollständig implementiert — CRUD-Formulare mit Flash-Messages bei Fehler und Erfolg

### A3 — Trigger

- [ ] **TRIG-01**: MySQL `AFTER UPDATE ON products`-Trigger erstellt — schreibt Eintrag in `product_change_log` mit alten und neuen Werten + Timestamp
- [ ] **TRIG-02**: Trigger ist **konditional** — Logeintrag nur wenn sich ein Wert tatsächlich ändert (`IF OLD.x <> NEW.x`)
- [ ] **TRIG-03**: Trigger-DDL in `schema.sql` oder separatem `triggers.sql` eingespielt beim DB-Start

### A4 — Stored Procedure

- [ ] **PROC-01**: MySQL Stored Procedure `import_product()` erstellt — Produktimport mit Dublettenprüfung via SKU
- [ ] **PROC-02**: Procedure validiert Pflichtfelder (name, price, category) und gibt OUT-Parameter zurück (status, message)
- [ ] **PROC-03**: Procedure-DDL in `schema.sql` oder separatem `procedures.sql` eingespielt beim DB-Start
- [ ] **PROC-04**: `ProductService` enthält Methode um `CALL import_product(...)` aufzurufen

### A5 — Indizes & B-Baum

- [ ] **IDX-01**: B-Tree-Index auf `products.name` erstellt
- [ ] **IDX-02**: B-Tree-Index auf `products.category_id` erstellt
- [ ] **IDX-03**: B-Tree-Index auf `products.brand_id` erstellt
- [ ] **IDX-04**: Index-DDL in `schema.sql` definiert
- [ ] **IDX-05**: `EXPLAIN`-Ausgaben für 3 Queries dokumentiert — Exact-Match-Query, Range-Scan-Query, JOIN-Query — jeweils vor und nach Indexanlage
- [ ] **IDX-06**: Markdown-Dokument erklärt warum MySQL B-Bäume verwendet und analysiert die EXPLAIN-Ergebnisse

### A6 — Vektor-DB & semantische Suche

- [ ] **VECT-01**: `QdrantRepositoryImpl.create_collection()` implementiert — nutzt `delete_collection` + `create_collection` (kein deprecated `recreate_collection`)
- [ ] **VECT-02**: `QdrantRepositoryImpl.upsert_points()` implementiert — mit `ensure_collection()` vor Upsert und `wait=True`
- [ ] **VECT-03**: `QdrantRepositoryImpl.search()` implementiert — gibt Trefferliste mit Scores zurück
- [ ] **VECT-04**: `QdrantRepositoryImpl.extract_pdf_chunks()` und `upload_pdf_chunks()` implementiert
- [ ] **VECT-05**: `IndexService` implementiert — Produkte laden → embedden (numpy `.tolist()`) → in Qdrant upserten + ETL-Lauf in `etl_run_log` loggen
- [ ] **VECT-06**: `SearchService.vector_search()` implementiert — Query embedden → Qdrant-Suche → Ergebnisse zurückgeben
- [ ] **VECT-07**: Route `search.py` implementiert — semantische Suche und klassische SQL-Volltextsuche nebeneinander angezeigt
- [ ] **VECT-08**: Route `index.py` implementiert — Index-Build-Formular mit Fortschrittsanzeige

### A7 — Graph-DB & LLM/RAG

- [ ] **GRAPH-01**: `Neo4jRepositoryImpl.get_product_relationships()` implementiert — nutzt `driver.execute_query()` mit MERGE-Pattern für Sync
- [ ] **GRAPH-02**: `Neo4jRepositoryImpl.execute_cypher()` implementiert — generische Cypher-Ausführung
- [ ] **GRAPH-03**: `Neo4jRepositoryImpl.close()` implementiert
- [ ] **GRAPH-04**: Neo4j-Graph befüllt: Produkt → Brand (`MADE_BY`), Produkt → Category (`IN_CATEGORY`), Produkt → Tag (`HAS_TAG`) aus MySQL synchronisiert
- [ ] **GRAPH-05**: `related_products`-Abfrage implementiert via Graph-Traversal: `MATCH (p)-[:MADE_BY]->(b)<-[:MADE_BY]-(other)` — Produkte desselben Herstellers finden
- [ ] **GRAPH-06**: `SearchService.rag_search()` implementiert — Vektor-Suche + Graph-Anreicherung + OpenAI-LLM-Antwort (gpt-4.1-mini)
- [ ] **GRAPH-07**: Route `rag.py` implementiert — RAG-Suchformular mit Antwortanzeige und Quellenangabe

### Supporting Routes

- [ ] **ROUTE-01**: `dashboard.py` implementiert — Produktanzahl, letzter ETL-Lauf, System-Status aller 3 DBs
- [ ] **ROUTE-02**: `audit.py` implementiert — ETL-Lauf-Log aus `etl_run_log` angezeigt
- [ ] **ROUTE-03**: `validate.py` implementiert — Schema-Validierung (erwartet vs. tatsächlich) mit Ergebnis-Anzeige
- [ ] **ROUTE-04**: `pdf.py` implementiert — PDF-Upload → Text-Extraktion → Qdrant-Indexierung

### Dokumentation

- [ ] **DOC-01**: `COMPARISON.md` erstellt — konzeptuelle Gegenüberstellung SQL vs. Vektor-Suche vs. Graph+RAG mit konkreten Beispielen: 3 Queries × 3 Suchmethoden mit echten Produktkatalog-Ergebnissen
- [ ] **DOC-02**: B-Baum-Analyse-Dokument mit EXPLAIN-Screenshots/Output (abgedeckt durch IDX-05/IDX-06)

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
| FOUND-01 | Phase 0 | Pending |
| FOUND-02 | Phase 0 | Pending |
| FOUND-03 | Phase 0 | Pending |
| FOUND-04 | Phase 0 | Pending |
| FOUND-05 | Phase 0 | Pending |
| FOUND-06 | Phase 0 | Pending |
| FOUND-07 | Phase 0 | Pending |
| FOUND-08 | Phase 0 | Pending |
| TXN-01 | Phase 1 | Pending |
| TXN-02 | Phase 1 | Pending |
| TXN-03 | Phase 1 | Pending |
| TXN-04 | Phase 1 | Pending |
| TXN-05 | Phase 1 | Pending |
| TXN-06 | Phase 1 | Pending |
| TXN-07 | Phase 1 | Pending |
| TXN-08 | Phase 1 | Pending |
| TRIG-01 | Phase 2 | Pending |
| TRIG-02 | Phase 2 | Pending |
| TRIG-03 | Phase 2 | Pending |
| PROC-01 | Phase 2 | Pending |
| PROC-02 | Phase 2 | Pending |
| PROC-03 | Phase 2 | Pending |
| PROC-04 | Phase 2 | Pending |
| IDX-01 | Phase 2 | Pending |
| IDX-02 | Phase 2 | Pending |
| IDX-03 | Phase 2 | Pending |
| IDX-04 | Phase 2 | Pending |
| IDX-05 | Phase 2 | Pending |
| IDX-06 | Phase 2 | Pending |
| VECT-01 | Phase 3 | Pending |
| VECT-02 | Phase 3 | Pending |
| VECT-03 | Phase 3 | Pending |
| VECT-04 | Phase 3 | Pending |
| VECT-05 | Phase 3 | Pending |
| VECT-06 | Phase 3 | Pending |
| VECT-07 | Phase 3 | Pending |
| VECT-08 | Phase 3 | Pending |
| GRAPH-01 | Phase 4 | Pending |
| GRAPH-02 | Phase 4 | Pending |
| GRAPH-03 | Phase 4 | Pending |
| GRAPH-04 | Phase 4 | Pending |
| GRAPH-05 | Phase 4 | Pending |
| GRAPH-06 | Phase 4 | Pending |
| GRAPH-07 | Phase 4 | Pending |
| ROUTE-01 | Phase 1 | Pending |
| ROUTE-02 | Phase 2 | Pending |
| ROUTE-03 | Phase 2 | Pending |
| ROUTE-04 | Phase 3 | Pending |
| DOC-01 | Phase 5 | Pending |
| DOC-02 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 50 total
- Mapped to phases: 50
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-02*
*Last updated: 2026-04-02 after initial definition*
