# Projektarbeit: Relationale Datenbanken, semantische Suche und Kontextanreicherung

**Studiengang:** Informatik / Datenbanksysteme  
**Dozent:** Karsten Kessler, DHBW Stuttgart  
**Technologien:** MySQL 8.4, Qdrant, Neo4j, Python, SQL

---

## Ziel der Abgabe

Diese Projektarbeit vergleicht drei Ebenen derselben Anwendung:

- relationale Datenhaltung in MySQL als strukturierte Source of Truth
- semantische Suche ueber Embeddings in Qdrant
- optionale Kontextanreicherung ueber Neo4j und RAG

Der Schwerpunkt der Pflichtabgabe liegt auf dem relationalen Modell und den SQL-Artefakten. Qdrant und Neo4j erweitern das System, ersetzen das relationale Datenmodell aber nicht.

---

## Abgabeartefakte im Repo

Die geforderten Artefakte liegen im Projektwurzelverzeichnis bzw. in den angegebenen Unterordnern:

- `schema.sql` - vollstaendiges relationales DDL-Schema
- `import.sql` - kompletter CSV-Import fuer 1000 Produkte
- `transaction.sql` - explizite Transaktions- und Rollback-Demonstration fuer A2
- `trigger.sql` - Trigger-Artefakt fuer A3
- `procedure.sql` - Stored-Procedure-Artefakt fuer A4
- `index.sql` - Index-Artefakt fuer A5
- `verify_database.sql` - Verifikation des finalen Schemas und der importierten Daten
- `ER-Diagramm.md` - textuelle ER-Dokumentation
- `ER-Diagramm.pdf` - PDF-Version des ER-Diagramms
- `docs/INDEX_ANALYSIS.md` - B-Tree- und EXPLAIN-Analyse
- `COMPARISON.md` - Vergleichsanalyse SQL vs. Qdrant vs. Neo4j + RAG

Die Root-Dateien `trigger.sql`, `procedure.sql` und `index.sql` sind die abgabefertigen Einzelartefakte. Dieselbe Logik wird fuer den Docker-Start weiterhin ueber `mysql-init/` geladen.

---

## Datenbank-Setup ohne Docker

Die folgenden Befehle werden aus dem Repo-Root ausgefuehrt.

### Voraussetzungen

- MySQL 8.0 oder hoeher
- MySQL-CLI (`mysql`)
- Zugriff auf eine Datenbank, z. B. `productdb`
- lokale Dateifreigabe fuer `LOAD DATA LOCAL INFILE`

### 1. Datenbank anlegen und auswaehlen

```sql
CREATE DATABASE productdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE productdb;
```

### 2. Schema erstellen

```bash
mysql -u root -p productdb < schema.sql
```

### 3. Daten importieren

```bash
mysql --local-infile=1 -u root -p productdb < import.sql
```

Wichtig:

- `import.sql` verwendet `LOAD DATA LOCAL INFILE`
- das Skript erwartet die CSV-Dateien in `data/`
- aus dem Repo-Root gestartet werden `data/brands.csv`, `data/categories.csv`, `data/tags.csv`, `data/products_extended.csv`, `data/products_500_new.csv` und `data/product_tags.csv` korrekt gefunden

### 4. Datenbank verifizieren

```bash
mysql -u root -p productdb < verify_database.sql
```

Das Verifikationsskript prueft Tabellen, Datenmengen, Fremdschluessel, Constraints, Trigger, Procedure und Indizes.

---

## Docker-Setup

Die Demo laeuft ueber `docker-compose.yml`.

```bash
docker compose up --build
```

Exponierte Services:

- MySQL: `localhost:3316`
- App: `http://localhost:8081`
- Adminer: `http://localhost:8990`
- Qdrant HTTP: `http://localhost:6343`
- Neo4j Web UI: `http://localhost:7484`
- Neo4j Bolt: `bolt://localhost:7697`

Hinweis: Beim Docker-Start wird nur `mysql-init/` automatisch eingespielt. Der separate CSV-Vollimport bleibt bewusst in `import.sql`, damit er als eigenes Abgabeartefakt nachvollziehbar bleibt.

---

## SQL-Artefakte kurz eingeordnet

### A1 Datenmodell

- `schema.sql` definiert die Tabellen `brands`, `categories`, `tags`, `products`, `product_tags`, `product_change_log` und `etl_run_log`
- `ER-Diagramm.md` und `ER-Diagramm.pdf` dokumentieren das relationale Modell

### A1 Import

- `import.sql` importiert den kompletten Datenbestand mit 1000 Produkten in vier expliziten Transaktionen
- der Import nutzt beide Produktdateien (`products_extended.csv` und `products_500_new.csv`)

### A2 Transaktionen

- `transaction.sql` zeigt Commit- und Rollback-Verhalten explizit in SQL
- dieselbe fachliche Logik ist zusaetzlich im Anwendungscode umgesetzt (`repositories/mysql_repository.py`)

### A3 Trigger

- `trigger.sql` erstellt `trg_products_after_update`
- Triggerziel ist `product_change_log`

### A4 Stored Procedure

- `procedure.sql` erstellt `import_product(...)`
- die Procedure validiert Eingaben, prueft doppelte SKU und liefert OUT-Parameter

### A5 Indizes und B-Baum

- `index.sql` enthaelt die geforderten B-Tree-Indizes fuer `products` und `product_tags`
- `docs/INDEX_ANALYSIS.md` erklaert die EXPLAIN-Ausgaben und die Einordnung der B-Tree-Indizes

### A6/A7 Vergleich und Erweiterung

- `COMPARISON.md` beantwortet die geforderte kritische Reflexion und vergleicht SQL, Qdrant und Neo4j + RAG nebeneinander
- Neo4j/RAG ist als optionale Kontextschicht dokumentiert und nicht als Ersatz fuer MySQL dargestellt

---

## Erwartete Datenmengen nach dem Import

- `brands`: 5
- `categories`: 4
- `tags`: 5
- `products`: 1000
- `product_tags`: 995

---

## Hinweise zur Bewertung

- MySQL bleibt die verbindliche Datenquelle des Systems.
- Qdrant und Neo4j werden fuer Suche und Kontext genutzt, nicht fuer die primäre Datenhaltung.
- Die Abgabe trennt bewusst zwischen relationalem Modell, semantischem Retrieval und optionaler Kontextanreicherung.
