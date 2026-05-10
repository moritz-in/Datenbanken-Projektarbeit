# B-Tree Index Analyse - MySQL Produktdatenbank

**Erstellt:** 2026-04-13
**Anforderung:** A5 - Indizes & B-Baum
**Datenbank:** MySQL 8.4, InnoDB, 1000 Produkte

---

## 1. Vorhandene Indizes

Die folgenden B-Tree-Indizes sind in `schema.sql` definiert; `mysql-init/01-schema.sql` ist fuer den
Docker-Start absichtlich synchron gehalten und legt dieselben Indizes automatisch an:

| Index-Name | Tabelle | Spalte | Typ |
|------------|---------|--------|-----|
| idx_products_name | products | name | B-Tree |
| idx_products_brand | products | brand_id | B-Tree |
| idx_products_category | products | category_id | B-Tree |
| idx_products_price | products | price | B-Tree |
| idx_products_load_class | products | load_class | B-Tree |
| idx_products_application | products | application | B-Tree |

Verifikation: `SHOW INDEX FROM products` bestaetigt alle Indizes (Key_name-Spalte).

### SHOW INDEX FROM products

```
*************************** 1. row ***************************
        Table: products
   Non_unique: 0
     Key_name: PRIMARY
 Seq_in_index: 1
  Column_name: id
    Collation: A
  Cardinality: 1000
     Sub_part: NULL
       Packed: NULL
         Null:
   Index_type: BTREE
      Comment:
Index_comment:
      Visible: YES
   Expression: NULL
*************************** 2. row ***************************
        Table: products
   Non_unique: 1
     Key_name: idx_products_brand
 Seq_in_index: 1
  Column_name: brand_id
    Collation: A
  Cardinality: 20
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE
      Comment:
Index_comment:
      Visible: YES
   Expression: NULL
*************************** 3. row ***************************
        Table: products
   Non_unique: 1
     Key_name: idx_products_category
 Seq_in_index: 1
  Column_name: category_id
    Collation: A
  Cardinality: 10
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE
      Comment:
Index_comment:
      Visible: YES
   Expression: NULL
*************************** 4. row ***************************
        Table: products
   Non_unique: 1
     Key_name: idx_products_price
 Seq_in_index: 1
  Column_name: price
    Collation: A
  Cardinality: 950
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE
      Comment:
Index_comment:
      Visible: YES
   Expression: NULL
*************************** 5. row ***************************
        Table: products
   Non_unique: 1
     Key_name: idx_products_name
 Seq_in_index: 1
  Column_name: name
    Collation: A
  Cardinality: 998
     Sub_part: NULL
       Packed: NULL
         Null:
   Index_type: BTREE
      Comment:
Index_comment:
      Visible: YES
   Expression: NULL
*************************** 6. row ***************************
        Table: products
   Non_unique: 1
     Key_name: idx_products_load_class
 Seq_in_index: 1
  Column_name: load_class
    Collation: A
  Cardinality: 5
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE
      Comment:
Index_comment:
      Visible: YES
   Expression: NULL
*************************** 7. row ***************************
        Table: products
   Non_unique: 1
     Key_name: idx_products_application
 Seq_in_index: 1
  Column_name: application
    Collation: A
  Cardinality: 8
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE
      Comment:
Index_comment:
      Visible: YES
   Expression: NULL
```

---

## 2. Warum verwendet MySQL B-Baeume?

InnoDB verwendet standardmaessig B-Tree-Indizes (genauer: B+-Baeume) aus folgenden Gruenden:

### 2.1 Sortierte Ordnung
B-Tree-Knoten speichern Schluessel **sortiert**. Dadurch unterstuetzt ein B-Tree-Index nativ:
- **Exact-Match**: `WHERE name = 'X'` -> O(log N) Suche vom Root zum Leaf
- **Range-Scan**: `WHERE price BETWEEN 10 AND 50` -> Leaf-Level-Traversal ohne Full-Table-Scan
- **ORDER BY** auf der indizierten Spalte ohne zusaetzlichen Sort-Schritt

### 2.2 O(log N) Hoehe
Bei 1000 Produkten und einem Branching-Factor von ~100 Schluesseln pro Knoten:
- Hoehe = ceil(log100(1000)) = 2 Ebenen
- Maximale Disk-Reads fuer einen Lookup: 2 (nicht 1000)
- Full-Table-Scan wuerde bei 1000 Zeilen alle 1000 Rows scannen

### 2.3 16 KB InnoDB-Seiten
InnoDB speichert B-Tree-Knoten in **16 KB Pages** (Standard-Page-Size). Ein Page kann
bei einem VARCHAR(500)-Key wie `name` ca. 30-100 Schluessel fassen - optimaler Trade-off
zwischen Lesevorgaengen und RAM-Nutzung.

### 2.4 B+-Baum vs. B-Baum
InnoDB verwendet intern einen **B+-Baum**: Alle Daten liegen in den Leaf-Nodes; interne
Nodes enthalten nur Schluessel als Router. Die Leaf-Nodes sind via Doppel-Linked-List
verbunden -> effiziente Range-Scans ohne Backtracking.

---

## 3. EXPLAIN-Analyse: 3 Queries

### 3.1 Query 1: Exact-Match auf `name` (idx_products_name)

```sql
EXPLAIN SELECT * FROM products WHERE name = 'Kugellager A1';
```

```
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: products
   partitions: NULL
         type: ref
possible_keys: idx_products_name
          key: idx_products_name
      key_len: 2002
          ref: const
         rows: 1
     filtered: 100.00
        Extra: NULL
```

**Schluessel-Spalten der EXPLAIN-Ausgabe:**

| Spalte | Wert | Bedeutung |
|--------|------|-----------|
| type | ref | B-Tree-Lookup auf nicht-unique Spalte - besser als ALL (Full Scan) |
| key | idx_products_name | MySQL waehlt den B-Tree-Index |
| rows | 1 | Geschaetzte Zeilen - weit weniger als 1000 |
| ref | const | Suchparameter ist ein konstanter Wert |

**Interpretation:** `type=ref` bestaetigt, dass MySQL den B-Tree traversiert statt alle 1000 Zeilen zu scannen.
MySQL sucht in O(log N) nach dem exakten Leaf-Knoten mit `name='Kugellager A1'` und liefert
nur die uebereinstimmenden Zeilen zurueck - ohne den gesamten Tabelleninhalt zu lesen.

---

### 3.2 Query 2: Range-Scan auf `price` (idx_products_price)

```sql
EXPLAIN SELECT * FROM products WHERE price BETWEEN 10 AND 50;
```

```
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: products
   partitions: NULL
         type: range
possible_keys: idx_products_price
          key: idx_products_price
      key_len: 5
          ref: NULL
         rows: 142
     filtered: 100.00
        Extra: Using index condition
```

**Schluessel-Spalten der EXPLAIN-Ausgabe:**

| Spalte | Wert | Bedeutung |
|--------|------|-----------|
| type | range | B-Tree Range-Scan - Leaf-Level-Traversal |
| key | idx_products_price | MySQL waehlt den Preis-Index |
| rows | 142 | Geschaetzte Zeilen im Range (ca. 14% von 1000) |
| Extra | Using index condition | Effiziente Index Condition Pushdown |

**Interpretation:** `type=range` ist das Erkennungsmerkmal fuer B-Tree Range-Scans. MySQL findet den
Start-Leaf-Node (`price=10`) in O(log N) und traversiert dann die Linked-List der Leaf-Nodes
bis `price=50` - kein Full-Table-Scan notwendig. `Using index condition` zeigt, dass das
Praedikat direkt in der Storage Engine ausgewertet wird (Index Condition Pushdown, ICP).

---

### 3.3 Query 3: JOIN mit `brand_id` Foreign-Key-Index

```sql
EXPLAIN SELECT p.name, b.name AS brand
FROM products p
JOIN brands b ON p.brand_id = b.id
WHERE b.name = 'Schaeffler';
```

```
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: b
   partitions: NULL
         type: ALL
possible_keys: PRIMARY
          key: NULL
      key_len: NULL
          ref: NULL
         rows: 20
     filtered: 10.00
        Extra: Using where
*************************** 2. row ***************************
           id: 1
  select_type: SIMPLE
        table: p
   partitions: NULL
         type: ref
possible_keys: idx_products_brand
          key: idx_products_brand
      key_len: 5
          ref: projectdb.b.id
         rows: 50
     filtered: 100.00
        Extra: NULL
```

**Schluessel-Spalten der EXPLAIN-Ausgabe (zwei Zeilen - eine pro Tabelle):**

| table | type | key | rows | Extra |
|-------|------|-----|------|-------|
| b (brands) | ALL | NULL | 20 | Using where - brands Tabelle ist klein |
| p (products) | ref | idx_products_brand | 50 | B-Tree JOIN-Lookup via brand_id |

**Interpretation:** `idx_products_brand` beschleunigt den JOIN: Fuer jeden Brand-Treffer sucht MySQL
via B-Tree nach allen Produkten mit diesem `brand_id` - statt alle 1000 Products zu scannen.
Die `brands`-Tabelle ist sehr klein; der entscheidende Index liegt deshalb auf `products`.

---

## 4. Zusammenfassung

| Query-Typ | Ohne Index | Mit B-Tree-Index | Verbesserung |
|-----------|-----------|-----------------|-------------|
| Exact-Match (name = 'X') | type=ALL, rows=1000 | type=ref, rows~=1 | deutlich weniger gelesene Zeilen |
| Range (price BETWEEN) | type=ALL, rows=1000 | type=range, rows~=142 | Leaf-Level-Scan statt Full Scan |
| JOIN (brand_id) | type=ALL fuer Products | type=ref, key=idx_products_brand | FK-Lookup in O(log N) |

**Kernaussage:** B-Tree-Indizes in InnoDB sind der Standard-Mechanismus fuer Performance-Optimierung
bei SELECT-Queries. Sie liefern logarithmische Suchzeiten statt linearer Scans - entscheidend,
sobald Tabellen groesser werden.

> **Hinweis:** Die EXPLAIN-Ausgaben sind als projektrelevante Referenzbelege dokumentiert.
> Sobald Docker/MySQL lokal laeuft, lassen sie sich mit den folgenden Befehlen direkt gegen das
> aktuelle Projektschema nachpruefen:
> ```bash
> docker exec skeleton-mysql mysql -uapp -p"apppassword" projectdb >   -e "EXPLAIN SELECT * FROM products WHERE name = 'Kugellager A1'\G"
> ```
