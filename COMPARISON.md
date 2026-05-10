# Vergleich der Suchmethoden: SQL LIKE vs. Qdrant Vektor-Suche vs. Neo4j + RAG

**Projekt:** Datenbanken-Projektarbeit Teil 2  
**Datenbestand:** 500 Produkte aus einem seedeten Katalog für Lagertechnik und Industriebedarf  
**Stack:** Python 3.12, Flask 3.0.3, MySQL 8.4, Qdrant 1.16.2, Neo4j 5, sentence-transformers/all-MiniLM-L6-v2 (384 Dimensionen), GPT-4.1-mini  
**Datum:** 2026-04-14

---

## Überblick

Diese Ausarbeitung vergleicht die drei im Projekt implementierten Suchwege anhand von drei
konkreten Suchanfragen. Ziel ist nicht nur zu zeigen, dass alle drei Ansätze funktionieren,
sondern sichtbar zu machen, **wann welcher Ansatz gewinnt, welche Evidenz aus realen
Projektergebnissen stammt und wo die jeweiligen Grenzen liegen**.

Die Analyse folgt in jeder Anfrage derselben Logik:

1. **SQL LIKE** bzw. strukturierte relationale Filter als Baseline
2. **Qdrant Vektor-Suche** als semantische Suche über Embeddings
3. **Neo4j + RAG** als Vektor-Retrieval mit zusätzlichem Beziehungskontext

Alle Produktnamen, Scores, Kategorien, Tags und Preise stammen aus dem vorhandenen
Projektkatalog. Es wurden in diesem Review-Durchlauf **keine neuen Experimente, Screenshots
oder Messungen ergänzt**, sondern die vorhandene Evidenz sprachlich und strukturell
abgabereif aufbereitet.

### Bewertungsmaßstab

| Methode | Primärer Mechanismus | Liefert zuverlässig | Liefert nicht zuverlässig |
|---------|----------------------|---------------------|---------------------------|
| SQL LIKE / SQL-Filter | Zeichenkettenvergleich, strukturierte Spalten, JOINs, B-Tree-Indizes | Exakte Treffer, reproduzierbare Filter, klare Sortierung und Aggregation | Kein semantisches Verständnis, keine Synonyme, keine impliziten Konzepte |
| Qdrant Vektor-Suche | Embeddings + Kosinus-Ähnlichkeit im 384-dimensionalen Raum | Semantisch ähnliche Produkte auch ohne exakten Begriff | Keine garantierte Exaktheit, keine relationale Begründung, keine Antwort in Prosa |
| Neo4j + RAG | Qdrant-Retrieval + Graph-Kontext + optionale LLM-Antwort | Zusätzliche Beziehungen, Tags, Kategorien und erklärende Einordnung | Mehr Komplexität; Mehrwert hängt von vorhandenem Graph-Kontext und LLM-Konfiguration ab |

### Leitfrage für die Bewertung

Für jede Suchanfrage werden drei Fragen beantwortet:

- Welche Methode liefert die passendsten Treffer?
- Welche Evidenz dafür ist direkt im Projekt sichtbar?
- Welche technische Ursache erklärt das Ergebnis?

---

## Suchanfrage 1: „Kugellager für hohe Last"

**Ziel der Anfrage:** Diese Anfrage testet die semantische Lücke besonders deutlich. Im
Datensatz kommt die Formulierung „hohe Last" bzw. „Hochlast" nicht als verlässlicher
exakter String vor. Gleichzeitig enthält der Katalog Produkte, deren Beschreibungen
inhaltlich genau auf hohe Belastung ausgelegt sind. Damit ist diese Anfrage geeignet, um
den Unterschied zwischen String-Matching und semantischer Ähnlichkeit sichtbar zu machen.

### SQL LIKE

**Ansatz / Query:**
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

**Bewertung:** SQL LIKE liefert hier **0 Treffer**. Für diese Anfrage ist das Ergebnis trotz
korrekter Ausführung fachlich schwach, weil die Methode nur Zeichenketten vergleicht.
Der Katalog enthält laut bestehender Projektdokumentation 152 Produkte mit
`load_class = 'high'`, aber dieses Konzept ist nicht in derselben Wortform gespeichert wie
die Nutzereingabe. Genau hier zeigt sich der **semantic gap**: Das Suchbedürfnis ist im
Datensatz fachlich vorhanden, aber nicht als exakter String adressierbar.

---

### Qdrant Vektor-Suche

**Ansatz / Retrieval:** Query-Einbettung mit `all-MiniLM-L6-v2`, anschließend
Kosinus-Ähnlichkeitssuche in Qdrant.

**Ergebnisse:**

| Produkt | Marke | Ähnlichkeit | Preis |
|---------|-------|-------------|-------|
| INA GESTERN-1920 | INA | 48,4 % | 360,39 EUR |
| INA KÜCHE-6892 | INA | 47,6 % | 145,71 EUR |
| INA ANGST-6355 | INA | 47,6 % | 103,13 EUR |
| SKF JEDER-8381 | SKF | 47,2 % | 354,76 EUR |
| INA VERKAUFEN-7524 | INA | 46,9 % | 88,16 EUR |

**Bewertung:** Qdrant liefert hier die **inhaltlich überzeugendsten Treffer**, obwohl der
Suchstring nicht wörtlich in den Produktenamen vorkommt. Die Scores von rund 47 bis 48 %
zeigen keine perfekte, aber eine klar positive semantische Nähe. Genau das ist die Stärke
der Vektor-Suche: Beschreibungen wie „ausgelegt für hohe Belastungen" können als passend
erkannt werden, obwohl die Anfrage anders formuliert ist. Im direkten Vergleich zeigt diese
Anfrage somit: **Qdrant findet, was SQL LIKE wegen fehlender Wortgleichheit verfehlt.**

---

### Neo4j + RAG

**Ansatz / Pipeline:** Query-Einbettung → Qdrant-Retrieval → Neo4j-Graph-Anreicherung →
optionale Antwortgenerierung durch GPT-4.1-mini.

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

**Bewertung:** Neo4j + RAG verbessert bei dieser Anfrage **nicht das eigentliche Retrieval**,
denn die relevanten Treffer kommen weiterhin aus Qdrant. Der Mehrwert liegt in der
Einordnung: Tags wie `Heavy Duty`, `Premium` oder `Automotive` sowie die Kategorie
`Kugellager` machen nachvollziehbar, warum bestimmte Produkte in diesem Kontext plausibel
sind. Die reale Evidenz dafür liegt in den konkret zurückgegebenen Graph-Feldern: Mehrere
Treffer tragen explizit den Tag `Heavy Duty`, obwohl dieser nicht Teil der ursprünglichen
SQL-Abfrage war. Da der OpenAI-Schlüssel hier fehlt, ist die LLM-Komponente nicht beurteilbar;
beurteilbar ist jedoch die Graph-Anreicherung selbst. Für diese Anfrage gilt deshalb:
**Neo4j ergänzt Qdrant sinnvoll, ersetzt es aber nicht.**

**Zwischenfazit Anfrage 1:** Für semantisch formulierte Anforderungen ohne exakten
Schlüsselbegriff ist Qdrant der stärkste Suchweg. SQL scheitert an der Wortform, und
Neo4j liefert erst dann Mehrwert, wenn auf einem bereits brauchbaren Retrieval zusätzliche
Beziehungskontexte benötigt werden.

**Direkter Methodenvergleich:** SQL liefert keine Treffer und ist damit für diese Anfrage
didaktisch die klare Negativfolie. Qdrant schließt die semantische Lücke zuverlässig genug,
während Neo4j dieselben Kandidaten besser erklärbar macht, aber ohne Qdrant keinen eigenen
Suchvorteil erzeugt.

---

## Suchanfrage 2: „SKF Kugellager"

**Ziel der Anfrage:** Diese Anfrage prüft den Gegenfall zur ersten Suchanfrage. Hier enthält
die Nutzereingabe einen exakten Markenbegriff (`SKF`) und einen klaren Produktkontext.
Sie eignet sich daher, um zu zeigen, wann relationale Suche mit strukturierten Attributen
der semantischen Suche überlegen ist.

### SQL LIKE

**Ansatz / Query:**
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

**Bewertung:** Für diese Anfrage ist SQL die **methodisch beste Wahl**, weil ein exakter
Markenwert abgefragt wird. Der vorhandene EXPLAIN-Beleg zeigt, dass MySQL dazu den
`idx_products_brand`-B-Tree-Index nutzt (`type: ref`, `key: idx_products_brand`,
`rows: 104`). Das Ergebnis ist reproduzierbar, präzise und direkt an der relationalen
Datenstruktur ausgerichtet. Der entscheidende Punkt ist: **SQL garantiert hier Exaktheit,
während Vektor-Suche nur Ähnlichkeit anbietet.**

---

### Qdrant Vektor-Suche

**Ansatz / Retrieval:** semantische Suche nach dem String „SKF Kugellager" über Embeddings.

**Ergebnisse:**

| Produkt | Marke | Ähnlichkeit | Preis |
|---------|-------|-------------|-------|
| SKF FRÜHER-2406 | SKF | 68,3 % | 193,03 EUR |
| SKF ANDERE-9827 | SKF | 67,2 % | 244,20 EUR |
| SKF BRAUCHEN-9348 | SKF | 67,0 % | 100,40 EUR |
| SKF REICH-5291 | SKF | 66,5 % | 349,29 EUR |
| SKF VOR-5315 | SKF | 65,8 % | 203,49 EUR |

**Bewertung:** Qdrant funktioniert auch in diesem Fall gut, weil Marke und Produkttyp in den
Embeddings als starke Signale auftauchen. Die Treffer sind plausibel, aber das Verfahren
bleibt ein **Ähnlichkeitsverfahren**. Es kann nicht dieselbe harte Garantie geben wie SQL,
wenn beispielsweise ausschließlich exakt zur Marke `SKF` gehörende Datensätze oder eine
vollständige Ergebnismenge erwartet werden. Im direkten Vergleich ist Qdrant hier also
nützlich, aber **nicht die erste Wahl**, weil der Suchfall bereits ideal strukturiert ist.

---

### Neo4j + RAG

**Ansatz / Pipeline:** Qdrant-Retrieval derselben Anfrage, danach Anreicherung über Neo4j mit
Marke, Kategorie und Tags.

**Graph-angereicherte Treffer:**

| Produkt | Marke | Kategorie | Tags | Preis | Graph-Quelle |
|---------|-------|-----------|------|-------|--------------|
| SKF FRÜHER-2406 | SKF | Kugellager | Automotive, OEM, Premium | 193,03 EUR | Neo4j |
| SKF ANDERE-9827 | SKF | Kugellager | OEM, Premium | 244,20 EUR | Neo4j |
| SKF BRAUCHEN-9348 | SKF | Kugellager | OEM, Premium, Heavy Duty | 100,40 EUR | Neo4j |
| SKF REICH-5291 | SKF | Kugellager | OEM, Heavy Duty, Premium | 349,29 EUR | Neo4j |
| SKF VOR-5315 | SKF | Kugellager | OEM, Industrie | 203,49 EUR | Neo4j |

**Bewertung:** Für die reine Frage „Zeige mir SKF Kugellager" fügt Neo4j + RAG nur begrenzt
zusätzlichen Nutzen hinzu. Der Graph macht zwar Tags und Kategorien sichtbar, aber die
entscheidende Information — die Marke `SKF` — liegt bereits sauber relational vor. Der
Graph-Mehrwert beginnt erst bei Anschlussfragen wie „Welche verwandten Produkte desselben
Herstellers haben zusätzlich OEM- oder Heavy-Duty-Kontext?" Für den primären Lookup bleibt
SQL deshalb klar überlegen. Die reale Evidenz ist hier sogar gegen RAG interpretierbar:
Die zusätzlichen Tags sind nützlich, ändern aber nichts daran, dass bereits die relationale
Markenbedingung die eigentliche Fachfrage vollständig beantwortet.

**Zwischenfazit Anfrage 2:** Bei exakten Marken- oder Attributsuchen sollte dieses Projekt
primär SQL verwenden. Qdrant kann ähnliche Treffer liefern, ersetzt aber nicht die
Eindeutigkeit relationale Abfragen. Neo4j ist hier eher Ergänzung für weiterführende Fragen
als Kern der eigentlichen Suche.

**Direkter Methodenvergleich:** SQL gewinnt, weil die Anfrage ein exakt gespeichertes Attribut
adressiert. Qdrant zeigt, dass semantische Suche auch hier plausible Kandidaten liefert,
aber die Methode löst das Problem unnötig indirekt. Neo4j ergänzt Kontext, nicht Präzision.

---

## Suchanfrage 3: „Automotive Lager mit Korrosionsschutz"

**Ziel der Anfrage:** Diese Anfrage kombiniert mehrere Konzepte: Anwendungskontext
(`automotive`), Produkttyp (`Lager`) und eine Eigenschaft (`Korrosionsschutz`). Damit ist
sie anspruchsvoller als eine reine Marken- oder Einzelbegriffssuche. Sie eignet sich, um
zu zeigen, wie gut die drei Ansätze mit zusammengesetzten Informationsbedürfnissen umgehen.

### SQL LIKE

**Ansatz / Query:**
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

**Bewertung:** SQL liefert hier einen brauchbaren strukturierten Einstieg, weil `application`
und `category` als Spalten vorhanden sind. Die Anfrage löst aber nur einen Teil des
Informationsbedürfnisses: Der Aspekt „Korrosionsschutz" ist nicht als sauberes strukturiertes
Merkmal modelliert. SQL kann deshalb nur die explizit modellierten Teile der Anfrage
zuverlässig beantworten. Es zeigt hier eine typische Stärke-gleichzeitig-Schwäche-Kombination:
**Was strukturiert vorliegt, findet SQL sehr gut; was nur implizit im Text steckt, bleibt
schwer zugänglich.**

---

### Qdrant Vektor-Suche

**Ansatz / Retrieval:** semantische Suche über die kombinierte Freitextanfrage
„Automotive Lager mit Korrosionsschutz".

**Ergebnisse:**

| Produkt | Marke | Ähnlichkeit | Preis |
|---------|-------|-------------|-------|
| INA SCHAUEN-6260 | INA | 54,5 % | 189,67 EUR |
| SKF WELT-9779 | SKF | 54,4 % | 148,84 EUR |
| SKF IHM-7149 | SKF | 53,4 % | 263,35 EUR |
| SKF SCHLIMM-8826 | SKF | 53,2 % | 315,37 EUR |
| SKF NÄCHSTE-7642 | SKF | 52,7 % | 144,99 EUR |

**Bewertung:** Qdrant geht mit dieser zusammengesetzten Anfrage besser um als SQL, weil das
Embedding mehrere semantische Signale gleichzeitig berücksichtigen kann. Die Scores von rund
53 bis 54 % liegen sichtbar über den Werten aus Suchanfrage 1 und sprechen für brauchbare
inhaltliche Nähe. Gleichzeitig bleibt zu beachten: Vektor-Suche zeigt Relevanz, aber keine
harte Garantie dafür, **welcher Teil der Anfrage** den Ausschlag gegeben hat. Sie ist also
stark im Finden plausibler Kandidaten, aber schwächer im expliziten Begründen.

---

### Neo4j + RAG

**Ansatz / Pipeline:** semantisches Qdrant-Retrieval, anschließend Graph-Anreicherung über
Neo4j-Knoten und Beziehungen für Marke, Kategorie und Tags.

**Graph-angereicherte Treffer:**

| Produkt | Marke | Kategorie | Tags | Preis | Graph-Quelle |
|---------|-------|-----------|------|-------|--------------|
| INA SCHAUEN-6260 | INA | Kugellager | Automotive | 189,67 EUR | Neo4j |
| SKF WELT-9779 | SKF | Dichtungen | Automotive | 148,84 EUR | Neo4j |
| SKF IHM-7149 | SKF | Kugellager | Premium, Industrie, Automotive | 263,35 EUR | Neo4j |
| SKF SCHLIMM-8826 | SKF | Rollenlager | Heavy Duty | 315,37 EUR | Neo4j |
| SKF NÄCHSTE-7642 | SKF | Rollenlager | Industrie, OEM, Premium | 144,99 EUR | Neo4j |

**Bewertung:** Diese Anfrage zeigt den **größten praktischen Mehrwert** der Graph-Anreicherung.
Die Neo4j-Daten ergänzen die Qdrant-Treffer um Beziehungen wie Marke, Kategorie und Tags.
Dadurch wird besser sichtbar, warum ein Treffer in einem Automotive- oder Heavy-Duty-Kontext
interessant sein könnte. Gleichzeitig bleibt die Grenze wichtig: Ohne konfiguriertes LLM wird
keine natürliche Antwort erzeugt, und auch mit LLM wäre die Qualität davon abhängig, wie gut
der Graph-Kontext die konkrete Frage tatsächlich stützt. Für dieses Projekt ist die Aussage
deshalb bewusst vorsichtig: **Neo4j + RAG hilft hier bei der Einordnung stärker als bei der
reinen Trefferfindung.** Die reale Evidenz dafür sind die zusätzlichen Kontextfelder in den
Treffern selbst, etwa `Automotive`, `Heavy Duty`, `Industrie` oder `OEM`, die über eine reine
Ähnlichkeitsliste hinaus eine fachliche Einordnung erlauben.

**Zwischenfazit Anfrage 3:** Bei mehrteiligen, erklärungsbedürftigen Anfragen ist Qdrant für
das Retrieval stark und Neo4j für die Nachvollziehbarkeit hilfreich. SQL kann nur den
strukturierten Ausschnitt der Anfrage sicher abdecken.

**Direkter Methodenvergleich:** SQL beantwortet nur den strukturierten Teil der Frage.
Qdrant findet plausiblere Gesamtkandidaten für die kombinierte Anfrage. Neo4j liefert hier
den stärksten Zusatznutzen, weil der Graph die Treffer sichtbar kontextualisiert.

---

## Technische Hintergründe

### Warum MySQL B-Trees?

InnoDB speichert reguläre Indizes als B-Tree-Strukturen in 16-KB-Seiten. Für dieses Projekt
bedeutet das: Exakte Vergleiche, Präfixsuchen und strukturierte JOINs können effizient über
einen sortierten Suchbaum abgewickelt werden, statt alle Zeilen vollständig zu scannen.

Die vereinfachte Intuition lautet: Je besser eine Bedingung als strukturierter Schlüssel
formulierbar ist, desto eher kann MySQL einen B-Tree nutzen. Bei 500 Produkten ist der
absolute Unterschied zwar klein, aber der **didaktische Unterschied** ist klar sichtbar:
Indexzugriff bleibt gerichtet, Volltext mit führendem Wildcard nicht.

**EXPLAIN-Beleg (exakter Markenname `SKF`):**
```
id | select_type | table | type  | possible_keys           | key                | key_len | rows | Extra
---|-------------|-------|-------|-------------------------|--------------------|---------|------|------
1  | SIMPLE      | b     | const | PRIMARY, uq_brand_name  | uq_brand_name      | 402     | 1    | Using index
1  | SIMPLE      | p     | ref   | idx_products_brand      | idx_products_brand | 4       | 104  | NULL
```

**EXPLAIN-Beleg (LIKE-Suche `%Kugellager%`):**
```
id | select_type | table | type   | possible_keys      | key  | rows | Extra
---|-------------|-------|--------|--------------------|------|------|-------
1  | SIMPLE      | p     | ALL    | idx_products_brand | NULL | 500  | Using where
1  | SIMPLE      | b     | eq_ref | PRIMARY            | PRIMARY | 4 | 1    | NULL
```

| Spalte | Bedeutung | Exakter Treffer (`SKF`) | LIKE-Suche (`%Kugellager%`) |
|--------|-----------|-------------------------|-----------------------------|
| `type` | Zugriffstyp | `const` / `ref` | `ALL` |
| `key` | verwendeter Index | `uq_brand_name`, `idx_products_brand` | `NULL` |
| `rows` | geschätzte gelesene Zeilen | 1 + 104 | 500 |
| `Extra` | Zusatzinfo des Optimizers | `Using index` | `Using where` |

**Kernaussage:** B-Tree-Indizes sind ideal für exakte oder geordnete strukturierte Abfragen,
aber nicht für semantische Bedeutungsnähe. Genau deshalb ist SQL in Suchanfrage 2 stark und
in Suchanfrage 1 schwach.

---

### HNSW-Parameter (Qdrant)

Die Qdrant-Collection `products` wurde mit einem HNSW-Index erstellt. Für die im Projekt
verwendete Konfiguration sind zwei Parameter zentral:

- **`m = 16`** — maximale Zahl der Nachbarverbindungen je Knoten und Layer. Höhere Werte
  verbessern typischerweise den Recall, erhöhen aber Speicherverbrauch und Indexkosten.

- **`ef_construct = 128`** — Größe der Kandidatenliste beim Aufbau des HNSW-Graphen. Ein
  höherer Wert verbessert die Qualität des resultierenden Graphen, macht das Bauen aber
  teurer.

Für diesen Katalog mit 500 Produkten ist diese Konfiguration gut nachvollziehbar: Sie ist
nah am praktikablen Standard und liefert ausreichend gute Treffer, ohne dass im Projekt ein
spezielles Tuning belegt werden müsste.

**Einordnung:** HNSW ist keine exakte Vollsuche, sondern eine approximative Nachbarschaftssuche.
Das passt zur Aufgabe der Vektor-Suche: Nicht perfekte Wortgleichheit, sondern gute semantische
Kandidaten in vertretbarer Zeit zu liefern.

---

### Semantische Lücke (Semantic Gap)

Die drei Suchanfragen zeigen denselben Grundunterschied aus drei Blickwinkeln:

- **SQL** vergleicht strukturierte Werte und Zeichenketten.
- **Qdrant** vergleicht Nähe im Embedding-Raum.
- **Neo4j + RAG** ergänzt Treffer um Beziehungen und optional sprachliche Verdichtung.

Der Begriff **semantic gap** bezeichnet hier die Lücke zwischen der Formulierung einer
Nutzeranfrage und der konkreten Wortwahl im Datensatz. Suchanfrage 1 demonstriert dieses
Problem am klarsten: „hohe Last" ist als Bedürfnis vorhanden, aber nicht als exakter String
modelliert. Vektor-Suche kann diese Lücke über semantische Ähnlichkeit teilweise schließen,
während SQL dafür zusätzliche explizite Struktur bräuchte.

| Suchbegriff | SQL LIKE / SQL-Filter | Qdrant | Neo4j + RAG |
|-------------|-----------------------|--------|-------------|
| „hohe Last" | 0 direkte String-Treffer | semantisch passende Kandidaten | gleiche Kandidaten + zusätzliche Tags/Kategorien |
| „SKF" | exakte Markenauflösung | plausible ähnliche Treffer | plausible Treffer mit Beziehungskontext |
| „Automotive Lager mit Korrosionsschutz" | nur strukturierter Teil abbildbar | mehrere Konzepte gleichzeitig erfassbar | besser erklärbar durch Kontextanreicherung |

---

## Empfehlung

### Wann welche Methode in diesem Projekt eingesetzt werden sollte

| Anwendungsfall | Empfohlene Methode | Begründung |
|----------------|--------------------|------------|
| Exakte Marken-, SKU- oder Feldsuche | SQL | Relationale Struktur und B-Tree-Indizes liefern präzise und reproduzierbare Ergebnisse |
| Filter nach Marke, Kategorie, Preis oder Anwendung | SQL | Sortierung, JOINs und klare Bedingungen sind hier methodisch überlegen |
| Freitextsuche nach impliziten Konzepten | Qdrant Vektor-Suche | Schließt den semantic gap, wenn Begriffe nicht exakt im Datensatz stehen |
| Mehrteilige Suchanfragen mit unscharfer Formulierung | Qdrant Vektor-Suche | Kann mehrere semantische Signale gleichzeitig berücksichtigen |
| Treffer zusätzlich mit Beziehungswissen erklären | Neo4j + RAG | Ergänzt Retrieval um Kategorien, Tags und Herstellerkontext |
| Chat-artige Beratung mit Begründungstext | Neo4j + RAG, aber nur auf Basis guter Retrieval-Treffer | Der Graph verbessert die Einordnung; das LLM ersetzt jedoch keine saubere Kandidatensuche |

### Kritische Gesamtempfehlung

Für **dieses konkrete Projekt** sollte SQL weiterhin die Standardlösung für alle exakten,
strukturierten Abfragen bleiben. Dafür ist das relationale Modell bereits vorhanden, und die
EXPLAIN-Belege zeigen, dass MySQL mit B-Tree-Indizes genau in diesen Fällen effizient arbeitet.

Qdrant ist die beste Ergänzung für alle Anfragen, bei denen Nutzerinnen und Nutzer nicht den
exakten Datenbankwortlaut kennen. Die stärkste Evidenz dafür liefert Suchanfrage 1: SQL findet
nichts, Qdrant dagegen mehrere plausible Treffer. Für die eigentliche Produktsuche ist Qdrant
damit der wichtigste nicht-relationale Mehrwert des Systems.

Neo4j + RAG sollte in diesem Projekt **gezielt und nicht pauschal** eingesetzt werden. Die
Graph-Anreicherung macht Treffer verständlicher und kann Anschlussfragen unterstützen. Der
praktische Nutzen hängt aber davon ab, ob wirklich Beziehungskontext gebraucht wird und ob die
LLM-Komponente verfügbar ist. Die vorhandene Evidenz zeigt daher keinen generellen Ersatz für
SQL oder Qdrant, sondern einen **sinnvollen Zusatzlayer für erklärende und kontextreiche
Anfragen**.

**Endurteil:**

- **SQL gewinnt** bei exakten, strukturierten Abfragen.
- **Qdrant gewinnt** bei semantischen Freitextanfragen.
- **Neo4j + RAG gewinnt** dann, wenn die gefundenen Produkte zusätzlich in Beziehungskontext
  erklärt werden sollen.

Die drei Verfahren konkurrieren in diesem Projekt also nicht vollständig miteinander, sondern
decken unterschiedliche Teile desselben Suchproblems ab. Genau diese Kombination macht die
Architektur für die Abgabe überzeugend: **MySQL für Sicherheit und Präzision, Qdrant für
semantisches Retrieval, Neo4j + RAG für Kontext und Erklärung.**
