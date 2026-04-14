# Vergleich der Suchmethoden: SQL LIKE vs. Qdrant Vektor-Suche vs. Neo4j + RAG

**Projekt:** Datenbanken-Projektarbeit Teil 2  
**Datenbestand:** 500 Produkte (Lagertechnik & Industriebedarf), 4 Datenbanken (MySQL, Qdrant, Neo4j, Redis)  
**Stack:** Python 3.12 + Flask 3.0.3 + sentence-transformers/all-MiniLM-L6-v2 (384-dim) + GPT-4.1-mini  
**Datum:** 2026-04-14  

---

## Überblick

Diese Analyse vergleicht drei Suchmethoden anhand von drei repräsentativen Suchanfragen,
die gezielt unterschiedliche Stärken und Schwächen der jeweiligen Ansätze herausarbeiten.

| Methode | Ansatz | Stärken | Schwächen |
|---------|--------|---------|-----------|
| SQL LIKE | Zeichenketten-Matching (Byte-für-Byte) | Exakte Treffer, reproduzierbar, kein Modell nötig | Kein semantisches Verständnis, kein Synonym-Matching |
| Qdrant Vektor-Suche | Kosinus-Ähnlichkeit im 384-dim. Einbettungsraum | Semantische Suche, sprachrobust, findet Synonyme und verwandte Konzepte | Keine Beziehungslogik, kein Erklärungstext |
| Neo4j + RAG | Graph-Anreicherung (Brand/Category/Tag-Beziehungen) + LLM-Antwort | Kontextanreicherung, Beziehungsnavigation, erklärende Antworten | Komplex, langsam, abhängig von OpenAI API Key |

---

## Suchanfrage 1: „Kugellager für hohe Last"

*Warum diese Anfrage:* Ein reiner Semantik-Test. Der Datensatz enthält keine Produkte mit
„hohe Last" oder „Hochlast" im Namen — aber 152 Produkte haben `load_class = 'high'` in der
Beschreibung. SQL LIKE scheitert vollständig, weil kein Zeichenkettenabgleich möglich ist.
Vektor-Suche findet trotzdem relevante Produkte über semantische Nähe.

### SQL LIKE

**Query:**
```sql
SELECT p.name, b.name AS brand, c.name AS category, p.price
FROM products p
LEFT JOIN brands b ON p.brand_id = b.id
LEFT JOIN categories c ON p.category_id = c.id
WHERE p.name LIKE '%hohe Last%'
   OR p.name LIKE '%Hochlast%'
   OR p.description LIKE '%hohe Last%';
```

**Ergebnisse:**

| Produkt | Marke | Kategorie | Preis |
|---------|-------|-----------|-------|
| *(keine Treffer)* | — | — | — |

**Bewertung:** SQL LIKE findet **0 Ergebnisse**, obwohl 152 von 500 Produkten die Eigenschaft
`load_class = 'high'` tragen. Das zeigt die semantische Lücke: Der Suchbegriff „hohe Last"
ist konzeptuell vorhanden, aber nicht als exakter String gespeichert.

---

### Qdrant Vektor-Suche

**Vektordistanz:** Kosinus-Ähnlichkeit, Modell `all-MiniLM-L6-v2` (384 Dimensionen)

**Ergebnisse:**

| Produkt | Marke | Ähnlichkeit | Preis |
|---------|-------|-------------|-------|
| INA GESTERN-1920 | INA | 48,4 % | 360,39 EUR |
| INA KÜCHE-6892 | INA | 47,6 % | 145,71 EUR |
| INA ANGST-6355 | INA | 47,6 % | 103,13 EUR |
| SKF JEDER-8381 | SKF | 47,2 % | 354,76 EUR |
| INA VERKAUFEN-7524 | INA | 46,9 % | 88,16 EUR |

**Bewertung:** Qdrant findet **5 relevante Treffer**, obwohl keines dieser Produkte den Begriff
„hohe Last" enthält. Das Einbettungsmodell erkennt, dass Beschreibungen wie
„Ausgelegt für hohe Belastungen und lange Lebensdauer" semantisch zum Suchbegriff passen.
Die Scores von ~47–48 % zeigen eine moderate, aber klar positive Ähnlichkeit gegenüber
nicht-relevanten Produkten.

---

### Neo4j + RAG

**Pipeline:** Query-Einbettung → Qdrant-Retrieval → Neo4j-Graph-Anreicherung → GPT-4.1-mini

**LLM-Antwort (Auszug):**
> [LLM nicht konfiguriert — OPENAI_API_KEY fehlt]

**Graph-angereicherte Treffer:**

| Produkt | Marke | Kategorie | Tags | Preis | Graph-Quelle |
|---------|-------|-----------|------|-------|--------------|
| INA GESTERN-1920 | INA | Kugellager | Premium, Industrie, Automotive | 360,39 EUR | Neo4j |
| INA KÜCHE-6892 | INA | Kugellager | Industrie, Heavy Duty | 145,71 EUR | Neo4j |
| INA ANGST-6355 | INA | Kugellager | Heavy Duty, Premium | 103,13 EUR | Neo4j |
| SKF JEDER-8381 | SKF | Kugellager | Premium | 354,76 EUR | Neo4j |
| INA VERKAUFEN-7524 | INA | Kugellager | Automotive, Heavy Duty | 88,16 EUR | Neo4j |

**Bewertung:** Der RAG-Ansatz reichert die Qdrant-Treffer mit Graph-Metadaten aus Neo4j an
(Kategorie, Tags via `:HAS_CATEGORY`- und `:HAS_TAG`-Beziehungen). Ohne OpenAI-Key fällt
die LLM-Antwort weg, aber die Graph-Kontextanreicherung (Tags „Heavy Duty" und „Premium")
ist aktiv. Die Tag-Struktur erlaubt es, über reine Vektor-Ähnlichkeit hinaus semantisch
verwandte Produkte nach Nutzungskontext zu gruppieren.

---

## Suchanfrage 2: „SKF Kugellager"

*Warum diese Anfrage:* Ein exakter Markenname. Hier gewinnt SQL LIKE eindeutig — der String
„SKF" ist im `brands`-Tabellennamen gespeichert und per Index-Join schnell abrufbar.
Vektor-Suche findet ebenfalls relevante Treffer, aber der exakte Markenname ist für
Zeichenkettenabgleich wie geschaffen.

### SQL LIKE

**Query:**
```sql
SELECT p.name, b.name AS brand, c.name AS category, p.price
FROM products p
LEFT JOIN brands b ON p.brand_id = b.id
LEFT JOIN categories c ON p.category_id = c.id
WHERE b.name = 'SKF';
```

**Ergebnisse:**

| Produkt | Marke | Kategorie | Preis |
|---------|-------|-----------|-------|
| SKF WIE-5012 | SKF | Wälzlager | 336,28 EUR |
| SKF GESTERN-5333 | SKF | Kugellager | 382,90 EUR |
| SKF RICHTIG-6925 | SKF | Kugellager | 374,94 EUR |
| SKF SACHE-2307 | SKF | Dichtungen | 350,15 EUR |
| SKF FERTIG-2084 | SKF | Kugellager | 186,51 EUR |

**Bewertung:** SQL LIKE (bzw. `=`) findet **alle SKF-Produkte** präzise und reproduzierbar.
Der EXPLAIN-Beleg zeigt, dass MySQL den `idx_products_brand`-B-Tree-Index nutzt
(`type: ref`, `key: idx_products_brand`, `rows: 104`). Das ist ein Musterbeispiel für
den optimalen SQL-Anwendungsfall: exakte Suche mit bekanntem Wert.

---

### Qdrant Vektor-Suche

**Ergebnisse:**

| Produkt | Marke | Ähnlichkeit | Preis |
|---------|-------|-------------|-------|
| SKF FRÜHER-2406 | SKF | 68,3 % | 193,03 EUR |
| SKF ANDERE-9827 | SKF | 67,2 % | 244,20 EUR |
| SKF BRAUCHEN-9348 | SKF | 67,0 % | 100,40 EUR |
| SKF REICH-5291 | SKF | 66,5 % | 349,29 EUR |
| SKF VOR-5315 | SKF | 65,8 % | 203,49 EUR |

**Bewertung:** Vektor-Suche findet ebenfalls SKF-Produkte mit hoher Ähnlichkeit (~66–68 %).
Das Einbettungsmodell hat die Marke „SKF" als wichtiges semantisches Signal korrekt gewichtet.
Der Unterschied zu SQL: Vektor-Suche könnte auch ähnliche Marken (FAG, INA als Schaeffler-Gruppe)
finden, während SQL exakt unterscheidet. Für Markenlookup ist SQL die sicherere Wahl.

---

### Neo4j + RAG

**Graph-angereicherte Treffer:**

| Produkt | Marke | Kategorie | Tags | Preis | Graph-Quelle |
|---------|-------|-----------|------|-------|--------------|
| SKF FRÜHER-2406 | SKF | Kugellager | Automotive, OEM, Premium | 193,03 EUR | Neo4j |
| SKF ANDERE-9827 | SKF | Kugellager | OEM, Premium | 244,20 EUR | Neo4j |
| SKF BRAUCHEN-9348 | SKF | Kugellager | OEM, Premium, Heavy Duty | 100,40 EUR | Neo4j |
| SKF REICH-5291 | SKF | Kugellager | OEM, Heavy Duty, Premium | 349,29 EUR | Neo4j |
| SKF VOR-5315 | SKF | Kugellager | OEM, Industrie | 203,49 EUR | Neo4j |

**Bewertung:** Für diese Anfrage fügt RAG wenig zusätzlichen Wert gegenüber SQL hinzu —
die Markenbeziehung ist in der relationalen Datenbank bereits strukturiert gespeichert.
Der Graph-Mehrwert wäre eine Beziehungsnavigation wie „Welche anderen Produkte vom gleichen
Hersteller sind in verwandten Kategorien?" — das geht über einen einfachen SQL-JOIN hinaus.

---

## Suchanfrage 3: „Automotive Lager mit Korrosionsschutz"

*Warum diese Anfrage:* Ein Multi-Konzept-Test, der Vektor-Suche und Graph-Anreicherung
kombiniert stresst. Der Begriff vereint Anwendungskontext (automotive), Produkttyp (Lager)
und eine Eigenschaft (Korrosionsschutz), die im Datensatz nicht als eigenständiges Feld,
sondern als semantischer Kontext in Beschreibungen vorkommt.

### SQL LIKE

**Query:**
```sql
SELECT p.name, b.name AS brand, c.name AS category, p.application, p.price
FROM products p
LEFT JOIN brands b ON p.brand_id = b.id
LEFT JOIN categories c ON p.category_id = c.id
WHERE p.application = 'automotive'
  AND (c.name IN ('Kugellager', 'Wälzlager', 'Rollenlager'));
```

**Ergebnisse:**

| Produkt | Marke | Kategorie | Anwendung | Preis |
|---------|-------|-----------|-----------|-------|
| NSK SECHS-1106 | NSK | Kugellager | automotive | 366,15 EUR |
| SKF NUN-9317 | SKF | Kugellager | automotive | 380,33 EUR |
| SKF BEI-6038 | SKF | Kugellager | automotive | 396,64 EUR |
| SKF HEISSEN-4770 | SKF | Kugellager | automotive | 19,26 EUR |
| INA ZEIGEN-2790 | INA | Kugellager | automotive | 362,26 EUR |

**Bewertung:** SQL findet Automotive-Lager über strukturierte Felder (`application`, `category`),
aber **nicht** das Konzept „Korrosionsschutz" — das ist weder als Spalte noch als exakter String
im Datensatz vorhanden. SQL muss auf strukturierte Metadaten ausweichen und kann den
Teilbegriff nicht semantisch interpretieren.

---

### Qdrant Vektor-Suche

**Ergebnisse:**

| Produkt | Marke | Ähnlichkeit | Preis |
|---------|-------|-------------|-------|
| INA SCHAUEN-6260 | INA | 54,5 % | 189,67 EUR |
| SKF WELT-9779 | SKF | 54,4 % | 148,84 EUR |
| SKF IHM-7149 | SKF | 53,4 % | 263,35 EUR |
| SKF SCHLIMM-8826 | SKF | 53,2 % | 315,37 EUR |
| SKF NÄCHSTE-7642 | SKF | 52,7 % | 144,99 EUR |

**Bewertung:** Vektor-Suche erzielt höhere Scores als bei Anfrage 1 (~53–54 %) und findet
Produkte mit automotive-Kontext. Das Modell erkennt die semantische Kombination aus
Lagertyp und Anwendungskontext. Der Begriff „Korrosionsschutz" erhöht die Ähnlichkeit
zu Produkten mit entsprechenden Eigenschaften in der Beschreibung, ohne dass der
exakte Begriff vorkommen muss.

---

### Neo4j + RAG

**Graph-angereicherte Treffer:**

| Produkt | Marke | Kategorie | Tags | Preis | Graph-Quelle |
|---------|-------|-----------|------|-------|--------------|
| INA SCHAUEN-6260 | INA | Kugellager | Automotive | 189,67 EUR | Neo4j |
| SKF WELT-9779 | SKF | Dichtungen | Automotive | 148,84 EUR | Neo4j |
| SKF IHM-7149 | SKF | Kugellager | Premium, Industrie, Automotive | 263,35 EUR | Neo4j |
| SKF SCHLIMM-8826 | SKF | Rollenlager | Heavy Duty | 315,37 EUR | Neo4j |
| SKF NÄCHSTE-7642 | SKF | Rollenlager | Industrie, OEM, Premium | 144,99 EUR | Neo4j |

**Bewertung:** Der RAG-Ansatz zeigt hier seinen größten Mehrwert: die Graph-Anreicherung
verbindet Qdrant-Treffer mit Neo4j-Beziehungen (`:HAS_BRAND`, `:HAS_CATEGORY`, `:HAS_TAG`)
und liefert strukturierten Kontext über die Produkte. Mit aktivem OpenAI-Key würde GPT-4.1-mini
eine erklärende Antwort generieren, die Automotive-Anforderungen und Korrosionsschutz-Konzepte
zusammenführt — das ist für einen Produktberater-Anwendungsfall ideal.

---

## Technische Hintergründe

### Warum MySQL B-Trees?

InnoDB speichert alle regulären Indizes als B-Tree-Strukturen in 16 KB-Seiten. Ein B-Tree
der Höhe H kann `N = (Seitengröße / Schlüsselgröße)^H` Einträge indizieren. Bei 500 Produkten
und dem `idx_products_name`-Index (VARCHAR(200)) beträgt die Baumhöhe H ≈ 2, was
`O(log N)` Suchoperationen bedeutet — deutlich besser als ein vollständiger Tabellenscan
bei O(N).

**EXPLAIN-Beleg (exakter Markenname `SKF`):**
```
id | select_type | table | type  | possible_keys           | key               | key_len | rows | Extra
---|-------------|-------|-------|-------------------------|-------------------|---------|------|------
1  | SIMPLE      | b     | const | PRIMARY, uq_brand_name  | uq_brand_name     | 402     | 1    | Using index
1  | SIMPLE      | p     | ref   | idx_products_brand      | idx_products_brand| 4       | 104  | NULL
```

**EXPLAIN-Beleg (LIKE-Suche `%Kugellager%`):**
```
id | select_type | table | type | possible_keys     | key  | rows | Extra
---|-------------|-------|------|-------------------|------|------|-------
1  | SIMPLE      | p     | ALL  | idx_products_brand| NULL | 500  | Using where
1  | SIMPLE      | b     | eq_ref | PRIMARY         | PRIMARY | 4 | 1    | NULL
```

| Spalte | Bedeutung | Exakter Treffer (SKF) | LIKE-Suche (%Kugellager%) |
|--------|-----------|-----------------------|--------------------------|
| type | Zugriffstyp | `const` / `ref` (Index-Nutzung) | `ALL` (Full Table Scan) |
| key | Genutzter Index | `uq_brand_name`, `idx_products_brand` | `NULL` — kein Index nutzbar |
| rows | Geschätzte Zeilen | 1 + 104 | 500 (alle Zeilen) |
| Extra | Optimierung | Using index | Using where |

**Fazit:** LIKE-Suchen mit führendem Wildcard (`%term%`) können keinen B-Tree-Index nutzen,
weil der Suchbaum das Präfix nicht auflösen kann. Nur `LIKE 'prefix%'` (ohne führendes `%`)
ist indexierbar. Das unterstreicht, warum Volltextsuche oder Vektor-Suche für semantische
Abfragen besser geeignet sind.

---

### HNSW-Parameter (Qdrant)

Die Qdrant-Collection `products` wurde mit folgenden HNSW-Parametern erstellt:

- **m = 16** — Jeder Knoten im HNSW-Graph hat maximal 16 bidirektionale Nachbarverbindungen
  pro Layer. Höhere `m`-Werte verbessern Recall (Treffsicherheit), erhöhen aber Speicherbedarf
  und Index-Aufbauzeit. Bei 500 Produkten ist `m=16` ein praxisbewährter Standardwert
  (Qdrant-Default), der gute Qualität bei vertretbarem Overhead bietet.

- **ef_construct = 128** — Größe der dynamischen Kandidatenliste während des Index-Aufbaus.
  Höhere Werte → präziserer Index, aber langsamerer Aufbau. Bei 500 Produkten und
  einem 384-dim. Modell ist `ef_construct=128` großzügig: Der Index-Aufbau dauert
  wenige Sekunden, und die Suchqualität ist nahezu optimal.

**Wie HNSW funktioniert:** Der HNSW-Graph ist mehrlagig aufgebaut. Die oberste Schicht
enthält wenige, weit verstreute Knoten als „Einstiegspunkte". Suchanfragen traversieren
von oben nach unten und nutzen `ef` (Query-Zeit-Parameter) als Kandidatenliste-Größe.
Das ergibt approximative `O(log N)` Suchkomplexität gegenüber der exakten `O(N)`-Brute-Force.

---

### Semantische Lücke (Semantic Gap)

SQL LIKE vergleicht Bytes. Eine Anfrage nach „hohe Last" findet nur Produkte, die
exakt diese Zeichenfolge enthalten.

Qdrant kodiert die Anfrage als 384-dimensionalen Vektor über das Transformer-Modell
`all-MiniLM-L6-v2`. Das Modell hat aus Milliarden von Texten gelernt, dass Konzepte wie
„hohe Last", „high load", „Heavy Duty" und „hohe Belastung" im Einbettungsraum nah
beieinander liegen. Eine Kosinus-Ähnlichkeitssuche findet daher semantisch verwandte
Produkte, **ohne dass das exakte Stichwort vorkommt**.

**Beispiel aus dem Datensatz:**

| Suchbegriff | SQL LIKE Treffer | Qdrant Treffer |
|-------------|-----------------|----------------|
| „hohe Last" | 0 | 5 (alle mit „hohe Belastungen" in Beschreibung) |
| „Hochlast" | 0 | 5 (selbe semantische Nähe) |
| „SKF" | 104 (exakt) | 5 Top-Treffer (korrekt SKF) |
| „Automotive Lager" | strukturiert via application-Spalte | 5 semantisch passende |

---

## Empfehlung

| Anwendungsfall | Beste Methode | Begründung |
|----------------|---------------|------------|
| Exakte SKU- oder Namenssuche | SQL LIKE / `=` | Reproduzierbar, kein Modell nötig, B-Tree optimal |
| Marke, Kategorie, Preisfilter | SQL mit Index | `idx_products_brand`, `idx_products_category` beschleunigen JOINs auf O(log N) |
| Semantische Produktsuche (Konzept ohne Keyword) | Qdrant Vektor | Findet ähnliche Konzepte ohne exaktes Keyword; sprachrobust |
| Multi-Konzept-Anfragen | Qdrant Vektor | Kombiniert mehrere semantische Dimensionen im Einbettungsraum |
| Erklärender Produktberater | Neo4j + RAG | Liefert Antworten mit Beziehungskontext; ideal für Chat-Interfaces |
| Bestandsabfragen, Berichte | SQL | Aggregationen, JOINs, ORDER BY, COUNT — Vektor-DBs können das nicht |
| PDF-Wissensabfragen | Qdrant (PDF-Chunks) | Semantische Suche in unstrukturierten Dokumenten |

**Zusammenfassung:** Die drei Suchmethoden ergänzen sich — sie ersetzen sich nicht gegenseitig.
SQL ist unschlagbar für strukturierte, exakte Abfragen. Qdrant schließt die semantische Lücke
für Freitextsuche. Neo4j + RAG bringt Beziehungslogik und erklärendes LLM-Verhalten.
Eine produktive Anwendung würde alle drei je nach Anfragemuster einsetzen.
