# Live-Demo-Leitfaden

## Was live funktionieren muss

Ziel dieses Leitfadens: Du zeigst **nur das, was dieses Repo nachweislich implementiert**. Die Demo startet nicht mit Folien, sondern mit einem laufenden Stack und klaren Klickpfaden.

### 1. Stack vor dem Vortrag starten

**Startkommando:**

```bash
docker compose up --build
```

Warte, bis die Container fuer `mysql`, `qdrant`, `neo4j` und `app` hoch sind.

### 2. URLs und Ports, die du vorab pruefen solltest

| Dienst | URL / Port | Wofuer du ihn in der Demo brauchst | Prioritaet |
|---|---|---|---|
| App | `http://localhost:8081` | Hauptdemo im Browser | Kern |
| MySQL | `localhost:3316` | Falls du DB-Naehe oder Adminer-Zugriff erwaehnst | Kern |
| Adminer | `http://localhost:8990` | Optionaler Sichtbeleg fuer relationale Daten | Fallback |
| Qdrant | `http://localhost:6343` | Optionaler Sichtbeleg fuer Vektor-Index | Fallback |
| Neo4j Web UI | `http://localhost:7484` | Optionaler Sichtbeleg fuer Graph-Knoten | Fallback |
| Neo4j Bolt | `bolt://localhost:7697` | Technischer Anschlussport, nur erwaehnen | Optional |

### 3. Browser-Tabs, die vor dem Start offen sein sollten

1. `http://localhost:8081`
2. `http://localhost:8081/products`
3. `http://localhost:8081/validate`
4. `http://localhost:8081/validate/procedure`
5. `http://localhost:8081/index`
6. `http://localhost:8081/search`
7. `http://localhost:8081/rag`
8. optional `http://localhost:7484`

### 4. Kernbeweis: laufende App

| Bereich | Konkreter Pfad | Was sichtbar sein muss | Repo-Beleg |
|---|---|---|---|
| Dashboard | `/` | Startseite rendert ohne 501/Crash | `routes/dashboard.py` |
| Produktverwaltung | `/products` | Produktliste mit Pagination, Marke, Kategorie, Preis | `routes/products.py` |
| Validierung | `/validate` | Schema-/Index-Ansicht rendert | `routes/validate.py` |
| Procedure-Demo | `/validate/procedure` | Formular nimmt Testdaten an und zeigt Result-Code/Message | `routes/validate.py` |
| ETL / Index | `/index` | Seite fuer Qdrant-Indexaufbau rendert | `routes/index.py` |
| Vergleichssuche | `/search` | Suchoberflaeche fuer SQL + Vektor | `routes/search.py` |
| RAG | `/rag` | Antwortbereich + Trefferliste mit Graph-Kontext | `routes/rag.py` |

**Live-Satz:** „Wenn diese sieben Routen ohne Fehler laden, ist die Anwendung als integrierte Demo nachweislich lauffaehig." 

### 5. MySQL muss sichtbar funktionieren

MySQL ist laut `README.md` die **Source of Truth**. Deshalb muss dein Live-Pfad immer zuerst die relationale Basis zeigen.

#### Minimaler Live-Beweis

1. Oeffne `/products`.
2. Zeige, dass Produkte mit Marke und Kategorie geladen werden.
3. Oeffne „Neues Produkt" oder den Bearbeiten-Pfad.
4. Erklaere: CRUD laeuft ueber transaktionssichere Repository-Methoden.

#### Was als sichtbarer Beweis zaehlt

| Thema | Klickpfad | Sichtbarer Beweis |
|---|---|---|
| Lesen | `/products` | Liste rendert mit Produktdaten |
| Create/Update | `/products/new` bzw. `/products/<id>/edit` | Formular existiert und ist an die Produktlogik angeschlossen |
| Delete/Rollback | `/products` | Loeschpfad mit Flash-Messages bei Erfolg/Fehler |
| Transaktionssicherheit | Fehlerfall bei doppelter SKU oder FK-Problem | rote Flash-Message statt halbfertigem Zustand |

#### Was du dazu sagen kannst

- „Die Produktoperationen laufen ueber Flask-Route -> Service -> MySQL-Repository."
- „Die Rollback-Demos fuer doppelte SKU und referenzielle Integritaet sind bewertungsrelevant und im Projekt explizit umgesetzt."
- „`with session.begin()` ist der Kern, damit SQLAlchemy und MySQL denselben Transaktionszustand sehen."

### 6. Validierung, Procedure und Index-Beweis

#### `/validate`

Nutze `/validate`, um zu zeigen, dass das relationale Schema und die B-Tree-Indizes sichtbar im System angekommen sind.

**Was sichtbar sein soll:**

- Validierungsansicht laedt
- Indexliste fuer `products` wird angezeigt
- du kannst auf Trigger/Procedure/Index-Verifikation verweisen

#### `/validate/procedure`

Nutze die Procedure-Seite fuer einen kurzen, kontrollierten DB-Demo-Moment.

**Empfohlener Live-Pfad:**

1. Oeffne `/validate/procedure`
2. Fuehre entweder einen gueltigen Import oder absichtlich fehlerhafte Eingabe aus
3. Zeige den Rueckgabecode / die Nachricht

**Worauf du hinauswillst:**

- Validierung steckt in MySQL, nicht nur in Python
- Dublettenpruefung fuer SKU ist sichtbar
- OUT-Parameter machen das Ergebnis vorzeigbar

#### `/index`

Das ist dein Qdrant-Einstieg.

**Was live zaehlt:**

- Seite laedt
- Build-Formular ist vorhanden
- im Idealfall wurde der Index schon vorab einmal aufgebaut, damit `/search` sofort funktioniert

**Praxisregel fuer die Vorfuehrung:** Fuehre den eigentlichen Build nur live aus, wenn die Maschine stabil ist. Sonst sage offen: „Der Index-Build ist im Projekt vorhanden, ich nutze jetzt den bereits vorbereiteten Stand fuer die Suchdemo." 

### 7. Qdrant muss als semantische Suche sichtbar sein

Pfad: `/search`

**Was du live zeigen solltest:**

1. Eine semantische Anfrage eingeben
2. Daneben erklaeren, dass dieselbe Oberflaeche auch SQL-Suche anbietet
3. Den Unterschied zwischen String-Matching und semantischer Naehe betonen

**Geeignete Anfrage aus dem Repo-Kontext:**

- „Kugellager fuer hohe Last"

**Beweis, dass Qdrant beteiligt ist:**

- Route `routes/search.py` spricht `SearchService.vector_search()` an
- `README.md` trennt MySQL als Quelle von Qdrant als semantischer Suchschicht
- `COMPARISON.md` liefert bereits konkrete Vergleichsfaelle

### 8. Neo4j und RAG muessen ehrlich demonstriert werden

Pfad: `/rag`

**Was garantiert demonstrierbar ist:**

- RAG-Seite laedt
- Trefferliste kommt aus Retrieval + Graph-Anreicherung
- `graph_source` bzw. Neo4j-Kontext kann erklaert werden

**Was nur optional garantiert ist:**

- echte LLM-Textantwort mit OpenAI

Wenn OpenAI **nicht** konfiguriert ist, ist der korrekte Repo-Fallback:

> `[LLM nicht konfiguriert — OPENAI_API_KEY fehlt]`

Das ist kein Demo-Fehler, sondern die im Projekt implementierte degradierte Laufzeit.

### 9. Kern vs. Fallback fuer die Live-Demo

| Bereich | Muss live klappen | Guter Fallback, wenn es langsam ist |
|---|---|---|
| App-Start | `docker compose up --build` | schon vorher starten und nur laufende Container zeigen |
| Dashboard | `/` laedt | direkt auf `/products` springen |
| CRUD / Transaktion | `/products` + kurzer Fehlerfall | nur Formular und Flash-Logik erklaeren |
| Procedure | `/validate/procedure` | Result-Codes verbal erklaeren und auf Route verweisen |
| B-Tree / Indexe | `/validate` | `docs/INDEX_ANALYSIS.md` als Beleg nennen |
| Qdrant | `/search` mit semantischer Anfrage | `COMPARISON.md` mit Query „Kugellager fuer hohe Last" nennen |
| Neo4j / RAG | `/rag` Trefferliste | Neo4j Web UI oder `graph_source` erklaeren |
| OpenAI-Antwort | nur wenn Key gesetzt | exakten Fallback-String zeigen und offen benennen |

## 15-Minuten-Live-Demo

### Minute 0-2 — Einstieg und Scope setzen

**Zeigen:** laufende App auf `http://localhost:8081`

**Sagen:**

- „Das Projekt vergleicht drei Ebenen derselben Anwendung: MySQL als Source of Truth, Qdrant fuer semantische Suche und Neo4j als Kontextschicht fuer RAG."
- „Ich zeige jetzt zuerst die lauffaehige Web-App, dann die Architektur und am Ende eine konkrete Designentscheidung plus Lessons Learned."

### Minute 2-5 — MySQL-gestuetzte Produktdemo

**Zeigen:** `/products`

**Sprechzettel:**

- Produktliste mit relationalen Daten laden
- kurz auf Create/Edit/Delete verweisen
- erwaehnen, dass die Fehlerfaelle fuer Rollback sichtbar ueber Flash-Messages demonstriert werden

**Kernsatz:** „Hier sieht man den operativen Kern des Systems: Produktdaten liegen in MySQL und werden transaktionssicher ueber die Web-Oberflaeche bearbeitet."

### Minute 5-8 — Validierung, Procedure und Index-Bezug

**Zeigen:** `/validate` und danach kurz `/validate/procedure`

**Sagen:**

- „Diese Seite zeigt, dass das erwartete relationale Schema und die Indexe wirklich im laufenden System vorhanden sind."
- „Die Procedure-Demo ist interessant, weil Validierung und Dublettenpruefung nicht nur in Python, sondern direkt in MySQL umgesetzt sind."

Wenn die Procedure-Ausfuehrung zu riskant ist, zeige nur das Formular und erklaere den Rueckgabecode-Mechanismus.

### Minute 8-11 — Semantische Suche und RAG-Pfad

**Zeigen:** zuerst `/search`, dann `/rag`

**Empfohlene Anfrage:** „Kugellager fuer hohe Last"

**Sagen:**

- „SQL findet exakte Zeichenketten oder strukturierte Attribute sehr gut, aber nicht immer semantisch aehnliche Formulierungen."
- „Qdrant schliesst genau diese Luecke ueber Embeddings."
- „Die RAG-Seite nutzt dieselben Retrieval-Treffer und reichert sie zusaetzlich mit Neo4j-Kontext an."

Wenn OpenAI nicht gesetzt ist, sage direkt:

> „Die LLM-Antwort ist in diesem Lauf bewusst im Fallback-Modus; das Projekt zeigt dann den implementierten Hinweis `[LLM nicht konfiguriert — OPENAI_API_KEY fehlt]`, aber Retrieval und Graph-Kontext bleiben demonstrierbar." 

### Minute 11-13 — Architekturüberblick

## Architekturüberblick

**Architektur in einem Satz:** `Routes → Services → Repositories`

### Routes → Services → Repositories

| Ebene | Rolle im Projekt | Repo-Beispiele |
|---|---|---|
| Routes | HTTP-Endpunkte und UI-Fluss | `routes/products.py`, `routes/search.py`, `routes/rag.py` |
| Services | Fachlogik und Orchestrierung | `services/product_service.py`, `services/search_service.py`, `services/index_service.py` |
| Repositories | direkter DB-Zugriff | `repositories/mysql_repository.py`, `repositories/qdrant_repository.py`, `repositories/neo4j_repository.py` |

**So erklaerst du die Architektur live:**

1. Flask-Route nimmt Request an
2. Service kapselt die Fachlogik
3. Repository spricht die konkrete Datenbank an
4. MySQL bleibt Quelle, Qdrant und Neo4j erweitern Such- und Kontextfaehigkeit

**Praxis-Satz:** „Ich habe nicht drei getrennte Apps gebaut, sondern eine Architektur, in der dieselbe Web-Oberflaeche gezielt verschiedene Datenbankrollen anspricht." 

### Minute 13-15 — Designentscheidung und Lessons Learned

## Designentscheidung

**Gewaehlte Entscheidung:** `with session.begin()` fuer Transaktionssicherheit in MySQL

**Warum genau diese Entscheidung gut erklaerbar ist:**

- sie ist bewertungsnah, weil sie direkt mit A2 / Rollback zusammenhaengt
- sie ist in `STATE.md` explizit als Schluesselentscheidung dokumentiert
- sie hat einen klaren technischen Grund: kein manueller `COMMIT`, keine Desynchronisation mit SQLAlchemy 2.0

**Repo-Evidenz:**

- `STATE.md`: „`with session.begin():` exclusively — no `text("COMMIT")`"
- `repositories/mysql_repository.py`: Transaktionsbloecke in `create_product()`, `update_product()`, `delete_product()` und `log_etl_run()`

**So erklaerst du die Entscheidung in 30-45 Sekunden:**

„Wir haben uns fuer `with session.begin()` entschieden, weil SQLAlchemy 2.0 die Session intern selbst verwaltet. Ein rohes `COMMIT` im SQL haette den ORM-Zustand desynchronisiert. Mit diesem Pattern sind Create, Update und Delete atomar, und Fehler wie doppelte SKU fuehren sauber zu einem Rollback statt zu halben Datenbankaenderungen." 

**Falls du lieber auf Index-Theorie ausweichst:** Verweise kurz auf `docs/INDEX_ANALYSIS.md` und den B-Tree-Nachweis, aber bleibe bei genau **einer** Designentscheidung.

## Lessons Learned

1. **Transaktionslogik gehoert ins Repository, nicht in die Route.**
   - Quelle: `STATE.md` und `repositories/mysql_repository.py`
   - Lerneffekt: Die UI bleibt simpel, waehrend die atomare DB-Operation an einer Stelle abgesichert wird.

2. **MySQL bleibt die verbindliche Datenquelle, auch wenn Qdrant und Neo4j spannend wirken.**
   - Quelle: `README.md`
   - Lerneffekt: Die Erweiterungen sind Such- und Kontextschichten, kein Ersatz fuer das relationale Modell.

3. **Idempotenz war bei den Zusatzsystemen entscheidend.**
   - Quelle: `STATE.md` Entscheidungen zu `ensure_collection()` und `MERGE`
   - Lerneffekt: Wiederholte Index-Builds duerfen weder Qdrant noch Neo4j kaputt oder doppelt machen.

4. **Graceful Degradation ist fuer eine Live-Demo wichtiger als perfekte Optional-Features.**
   - Quelle: `STATE.md` Entscheidung zum OpenAI-Fallback und `services/search_service.py`
   - Lerneffekt: Auch ohne API-Key bleibt `/rag` demonstrierbar, weil der Fallback sauber implementiert ist.

### Schlusssatz fuer die letzten 20 Sekunden

„Die eigentliche Leistung des Projekts ist nicht nur, dass drei Datenbanksysteme eingebunden sind, sondern dass ihre Rollen sauber getrennt sind: MySQL fuer korrekte Datenhaltung, Qdrant fuer semantisches Retrieval und Neo4j fuer erklaerbaren Kontext." 
