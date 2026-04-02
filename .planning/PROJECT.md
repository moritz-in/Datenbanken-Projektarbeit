# Datenbanken-Projektarbeit Teil 2

## What This Is

Ein Flask-basiertes Lehrprojekt für fortgeschrittene Datenbankkonzepte. Die Anwendung verwaltet einen Produktkatalog und demonstriert Transaktionen, Trigger, Stored Procedures, Indexierung sowie semantische und graph-basierte Suche — mit MySQL, Qdrant (Vektor-DB) und Neo4j (Graph-DB). Die Abgabe umfasst eine voll lauffähige App (Docker) und eine konzeptuelle Vergleichsanalyse als Markdown.

## Core Value

Die Anwendung muss am Ende demonstrierbar laufen: Produkte anlegen/ändern/löschen mit Transaktionssicherheit, Produkte semantisch suchen (Qdrant) und per RAG mit Graph-Kontext antworten (Neo4j + OpenAI) — alles vergleichbar nebeneinander.

## Requirements

### Validated

<!-- Was im Scaffold bereits existiert und funktioniert. -->

- ✓ Flask Application Factory mit Logging und Error Handling — existing
- ✓ 3-Tier-Architektur (Routes → Services → Repositories) mit ABCs — existing
- ✓ Blueprint-Routing für alle Domains (dashboard, products, search, rag, audit, validate, index, pdf) — existing
- ✓ ServiceFactory und RepositoryFactory Singleton-Pattern — existing (strukturell)
- ✓ Docker Compose mit allen 5 Services (mysql, adminer, qdrant, neo4j, app) — existing
- ✓ Config-Loading aus Environment Variables — existing
- ✓ Datenbankschema DDL für Produktkatalog (brand, category, tag, product, product_tag) — existing (mit Namenskonflikt)
- ✓ Seed-Daten (import.sql) — existing
- ✓ CI Pipeline (GitHub Actions) — existing

### Active

<!-- Was gebaut werden muss. -->

**Voraussetzungen (Blocker — zuerst fixen):**
- [ ] Schema-Namenskonflikt beheben: `schema.sql` verwendet Singular (`product`, `brand`), Code erwartet Plural (`products`, `brands`) — alle Tabellennamen in `schema.sql` auf Plural umbenennen
- [ ] `etl_run_log`-Tabelle zu `schema.sql` hinzufügen (referenced by `MySQLRepositoryImpl.log_etl_run()` but missing from schema)
- [ ] `RepositoryFactory` implementieren (alle `get_*()` Methoden — Voraussetzung für alles)
- [ ] `ServiceFactory` implementieren (alle `get_*()` Methoden + `_get_embedding_model()` als echtes Singleton)
- [ ] `NoOpNeo4jRepository` reparieren (alle 3 Methoden sollen leere/sichere Werte zurückgeben statt `NotImplementedError`)

**A2 — Transaktionen:**
- [ ] `MySQLRepositoryImpl` implementieren: `create_product()`, `update_product()`, `delete_product()` mit expliziten `START TRANSACTION / COMMIT / ROLLBACK`-Blöcken
- [ ] Fehlerfall-Demonstrationen: doppelte SKU → Rollback, referenzielle Integrität → Rollback
- [ ] `ProductService` implementieren: `create_product_with_relations()`, `update_product()`, `delete_product()` (inkl. Brand, Category, Tags)
- [ ] Route `products.py` implementieren: CRUD-Formulare + Flash-Messages bei Fehler/Erfolg

**A3 — Trigger:**
- [ ] MySQL-Trigger erstellen: `AFTER UPDATE ON products` → Eintrag in `product_change_log` mit alten/neuen Werten + Timestamp
- [ ] `product_change_log`-Tabelle in `schema.sql` definieren
- [ ] Trigger-DDL in `schema.sql` oder separatem `triggers.sql` (wird beim DB-Start eingespielt)

**A4 — Stored Procedure:**
- [ ] MySQL Stored Procedure `import_product()`: Produktimport mit Dublettenprüfung (SKU oder Name) und Validierung von Pflichtfeldern (name, price, category)
- [ ] Procedure-DDL in `schema.sql` oder separatem `procedures.sql`
- [ ] Procedure aus `ProductService` aufrufbar (via `CALL import_product(...)`)

**A5 — Indizes & B-Baum:**
- [ ] B-Tree-Indizes anlegen: `products.name`, `products.category_id`, `products.brand_id`
- [ ] Index-DDL in `schema.sql`
- [ ] `EXPLAIN`-Ausgaben für relevante Queries dokumentieren (vor/nach Index)
- [ ] Markdown-Dokument: Erklärung warum MySQL B-Bäume verwendet, Analyse-Ergebnisse

**A6 — Vektor-DB & semantische Suche:**
- [ ] `QdrantRepositoryImpl` implementieren: `create_collection()`, `upsert_points()`, `search()`, `extract_pdf_chunks()`, `upload_pdf_chunks()`
- [ ] `IndexService` implementieren: Produkte laden → embedden → in Qdrant upserten + ETL-Lauf loggen
- [ ] `SearchService.vector_search()` implementieren: Query embedden → Qdrant-Suche → Ergebnisse zurückgeben
- [ ] Route `search.py` implementieren: semantische Suche + klassische SQL-Suche nebeneinander anzeigen
- [ ] Route `index.py` implementieren: Index-Build-Formular

**A7 — Graph-DB & LLM/RAG:**
- [ ] `Neo4jRepositoryImpl` implementieren: `get_product_relationships()`, `execute_cypher()`, `close()`
- [ ] Neo4j-Graph befüllen: Produkt → Brand-, Category-, Tag-Beziehungen aus MySQL synchronisieren
- [ ] `SearchService.rag_search()` implementieren: Vektor-Suche + Graph-Anreicherung + OpenAI LLM-Antwort
- [ ] Route `rag.py` implementieren: RAG-Suchformular + Antwortanzeige

**Weitere Routes & Cleanup:**
- [ ] `dashboard.py` implementieren: Produktanzahl, ETL-Lauf-Statistiken, System-Status
- [ ] `audit.py` implementieren: ETL-Lauf-Log anzeigen
- [ ] `validate.py` implementieren: Schema-Validierung ausführen und Ergebnis anzeigen
- [ ] `pdf.py` implementieren: PDF-Upload → Qdrant-Indexierung

**Vergleichsanalyse:**
- [ ] `COMPARISON.md` erstellen: konzeptuelle Gegenüberstellung SQL vs. Vektor-Suche vs. Graph+RAG — Stärken, Schwächen, wann welcher Ansatz

### Out of Scope

- User Authentication — kein Login/Auth-Layer geplant (akademisches Projekt)
- PostgreSQL-Integration — `pg_session_factory` und `psycopg2-binary` sind Dead Code, werden entfernt
- CSRF-Schutz — out of scope für dieses Semester
- Rate Limiting — out of scope
- Mobile-App / REST-API — Web-UI only (Jinja2)
- Gunicorn/Production WSGI — Docker dev-server reicht für Abgabe

## Context

- Das Projekt ist Semester-Kursarbeit (Datenbanken, deutschsprachige Uni)
- Das Scaffold wurde vom Lehrenden bereitgestellt — alle ABCs, Factories, Blueprints und Templates existieren bereits
- Jede Methode, die implementiert werden muss, ist als `raise NotImplementedError("TODO: ...")` markiert
- Der App-Level-Error-Handler fängt `NotImplementedError` ab und rendert `student_hint.html` mit HTTP 501
- Die App startet, gibt aber für jede Route 501 zurück bis die Stubs implementiert sind
- Docker Compose orchestriert alle Abhängigkeiten — Entwicklung läuft ausschließlich via Docker
- OpenAI API Key muss in `.env` gesetzt werden für A7 (RAG-Antworten)

## Constraints

- **Tech Stack**: Python 3.12 + Flask 3.0.3 + SQLAlchemy 2.0.32 — vorgegeben durch Scaffold, nicht verhandelbar
- **Databases**: MySQL 8.4 + Qdrant v1.16.2 + Neo4j 5 — alle drei Datenbanken sind Pflicht (Kursanforderung)
- **Embedding Model**: `sentence-transformers/all-MiniLM-L6-v2` (384-dim) — bereits konfiguriert
- **LLM**: OpenAI `gpt-4.1-mini` — bereits konfiguriert, OPENAI_API_KEY in `.env` erforderlich
- **Deadline**: Ende Semester (> 4 Wochen)
- **Deliverable**: Laufende App via `docker compose up` + Markdown-Vergleichsanalyse

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Scaffold-Architektur beibehalten, keine Neuentwicklung | Zeitersparnis, Lehrende erwarten die Struktur | — Pending |
| Schema-Tabellennamen auf Plural umbenennen | Code-seitig sind Plural-Namen fest verdrahtet; Anpassung im SQL ist der kleinere Eingriff | — Pending |
| etl_run_log-Tabelle zu schema.sql hinzufügen | Methoden referenzieren die Tabelle; ohne sie crasht der Index-Build | — Pending |
| A7 (Neo4j + LLM) voll implementieren (nicht optional) | Bewertungsrelevant, ausreichend Zeit bis Ende Semester | — Pending |
| Embedding-Modell als echtes Singleton in ServiceFactory | Verhindert dreifaches Laden (~90 MB × 3 = 270 MB RAM-Overhead) | — Pending |
| PostgreSQL-Dead-Code entfernen | Reduziert Verwirrung, psycopg2-binary ist unnötiger Build-Overhead | — Pending |

---
*Last updated: 2026-04-02 after initialization*
