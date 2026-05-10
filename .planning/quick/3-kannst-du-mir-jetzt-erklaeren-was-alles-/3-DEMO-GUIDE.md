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
