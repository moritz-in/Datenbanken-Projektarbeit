# Projektarbeit: Relationale Datenbanken, semantische Suche

**Studiengang:** Informatik / Datenbanksysteme  
**Dozent:** Karsten Keßler, DHBW Stuttgart    
**Technologien:** MySQL 8.4 · Qdrant · Python · SQL

---

## Branch

Dieser Branch enthält nur die Klassen- und Methodensignaturen in `routes/`, `services/` und `repositories/`. Die Implementierungen müssen von den Studierenden ergänzt werden. Tests sind für die Studierenden nicht verpflichtend. Konfigurationen werden mit einer Dummy-`.env` mitgeliefert; `.env.example` enthält leere Platzhalter.

### Mindest-Konfiguration (.env)

Zum Start der App genügt die mitgelieferte Dummy-`.env` (die App zeigt dann nur den Hinweis). Sobald die Features implementiert sind, benötigt man mindestens:

**Pflicht (für DB-Funktionen):**
-   `MYSQL_URL`

**Pflicht (für Vektorsuche):**
-   `QDRANT_URL`
-   `EMBEDDING_MODEL`
-   `EMBEDDING_DIM`

**Optional (nur wenn genutzt):**
-   `OPENAI_API_KEY` und `LLM_MODEL` für RAG/LLM-Antworten
-   `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD` für Graph-Enrichment

---

## 🎯 Ziel der Projektarbeit

Ziel dieser Projektarbeit ist es, klassische relationale Datenbanksysteme mit modernen semantischen Such- und Kontextverfahren zu kombinieren und deren jeweilige Stärken, Grenzen und Einsatzgebiete zu verstehen. Im Mittelpunkt steht nicht der Einsatz einzelner Tools, sondern das Zusammenspiel unterschiedlicher Datenbank- und Suchparadigmen:

-   relationale Datenbanken als strukturierte, konsistente Source of Truth
-   Vektor-Datenbanken zur semantischen Ähnlichkeitssuche
-   optionale graphbasierte Modelle zur Kontext- und Beziehungsanreicherung

## 🧠 Lernziele

Die Studierenden sollen im Rahmen des Projekts zeigen, dass sie:

-   einen realistischen Produktdatenbestand sauber relational modellieren
-   klassische Datenbankmechanismen wie Transaktionen, Trigger und Stored Procedures gezielt einsetzen
-   Indizes verstehen, begründen und im Kontext von Performance bewerten können
-   strukturierte Daten in textuelle Repräsentationen und semantische Vektoren überführen
-   semantische Suchanfragen implementieren, analysieren und kritisch bewerten
-   moderne Sucharchitekturen fachlich einordnen, statt sie nur anzuwenden
-   den Unterschied zwischen Datenhaltung, Suche und Kontextinterpretation klar trennen können

## 🧱 Projektcharakter und Rahmenbedingungen

Alle Studierenden arbeiten mit dem gleichen Ausgangsdatenbestand. Die Datenbasis wird nicht inhaltlich verändert, sondern logisch erweitert. Die relationale Datenbank bildet die verbindliche Datenquelle. Semantische und weitere Komponenten dienen ausschließlich der Suche, Analyse und Kontextbildung. Unterschiedliche Lösungsansätze sind ausdrücklich erwünscht. Wichtig: Der Datenbestand ist identisch – die Lösungen sind es nicht.

**Gesamt-Workflow (konzeptionell)**
Das Projekt orientiert sich an folgendem konzeptionellen Daten- und Verarbeitungsfluss: 
*CSV → Relationale Datenbank (MySQL) → strukturierte & textuelle Repräsentationen → Embeddings → Vektor-Datenbank (Qdrant) → semantische Suche → optionale Kontextanreicherung (z. B. Graph-basierte Modelle) → RAG-gestützte LLM-Antworten.*

## 🧩 Einordnung moderner Verfahren (optional)

Das Projekt bietet Raum und Grundlage, moderne Konzepte wie Retrieval-Augmented Generation (RAG) einzuordnen:

-   Vektorsuche liefert relevante Inhalte
-   relationale Strukturen sichern Korrektheit und Konsistenz
-   graphbasierte Modelle können Beziehungen und Kontext sichtbar machen 

Diese Konzepte sind kein Selbstzweck, sondern dienen der reflektierten Analyse moderner Datenarchitekturen. 

> 💡 **Weiterführende Materialien zu LLMs:** Ergänzende Informationen, Erklärungen und Hintergründe zum Thema Large Language Models (LLM) findet man unter: **[https://tutor.kkessler.de/llm](https://tutor.kkessler.de/llm)**

## 🧭 Leitgedanke des Projekts

*Relationale Datenbanken sichern Wahrheit – semantische Verfahren erweitern den Blick.*

*(Hinweis: GraphDB- und LLM-gestützte RAG-Verfahren sind optional. Der Schwerpunkt des Projekts liegt auf relationalen Datenbanken.)*


---

## 📦 Datenbank Setup

### Voraussetzungen
- MySQL 8.0 oder höher
- Zugriff auf MySQL CLI

### Installation der Datenbank

**Schritt 1: Schema erstellen**
```bash
mysql -u root -p < schema.sql
```
Dies erstellt die Datenbank mit allen Tabellen, Foreign Keys, Indizes und Constraints.

**Schritt 2: Daten importieren**
```bash
mysql --local-infile=1 -u root -p datenbankname < import.sql
```
**WICHTIG:** Das `--local-infile=1` Flag ist erforderlich, da die Daten aus lokalen CSV-Dateien importiert werden.

**Schritt 3: Datenbank überprüfen**
```bash
mysql -u root -p datenbankname < verify_database.sql
```
Dieses Skript prüft die referentielle Integrität und zeigt Statistiken über die importierten Daten.

### Erwartete Datenmengen
- 5 Brands (Marken)
- 4 Categories (Kategorien)
- 5 Tags
- 1000 Products (Produkte)
- 995 Product-Tag Verknüpfungen

Weitere Details zur Datenbankstruktur finden Sie in:
- `ER-Diagramm.md` - Visualisierung der Datenbankstruktur
- `DATABASE_IMPORT.md` - Detaillierte Importanleitung
- `schema.sql` - Vollständiges DDL-Schema

---

## 🌐 Services

- App: http://localhost:8081
- Adminer: http://localhost:8990
- Qdrant: http://localhost:6343
- Neo4j: http://localhost:7848

---

**Student:** [Name]  
**Matrikelnummer:** [MatNr]  
**Datum:** 30.03.2026

Passwörter Adminer:
mysql
root
admin123
productdb