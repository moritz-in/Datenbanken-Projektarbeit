# Datenbank Import-Struktur

Vollständige, wiederholbare und transaktionale Datenbankimport-Struktur für die Produktdatenbank.

## Übersicht

Diese Import-Struktur besteht aus zwei Hauptdateien:

1. **`schema.sql`** - DDL-Datei mit allen Tabellendefinitionen
2. **`import.sql`** - Transaktionale Import-Skripte für CSV-Daten

## Features

### ✅ Anforderungen erfüllt

- ✅ **Wiederholbar/Reusable**: Schema kann mehrfach ausgeführt werden (DROP IF EXISTS)
- ✅ **Saubere Primary Keys**: Alle Tabellen haben eindeutige Primärschlüssel
- ✅ **Foreign Keys**: Vollständige referentielle Integrität mit CASCADE/RESTRICT
- ✅ **N:M-Beziehungen**: Junction Table `product_tags` für Many-to-Many
- ✅ **Transaktionen**: Alle Imports in separaten Transaktionen mit COMMIT/ROLLBACK
- ✅ **Fehlerbehandlung**: Keine inkonsistenten Daten bei Fehlern
- ✅ **Validierungen**: Umfangreiche Integritätsprüfungen während des Imports

### 🎯 Zusätzliche Features

- ✅ **Performante Indizes**: Optimierte Indizes für häufige Abfragen
- ✅ **Check Constraints**: Datenvalidierung auf Datenbankebene
- ✅ **Zeichensatz**: UTF-8 (utf8mb4) für internationale Zeichen
- ✅ **InnoDB Engine**: Transaktionsunterstützung und Foreign Keys
- ✅ **Kommentare**: Umfangreiche Dokumentation im Code
- ✅ **Validierungen**: Automatische Prüfung der importierten Datenmengen

## Datenbank-Schema

### Stammdaten (Master Data)
```
brands (5 Datensätze)
├── id (PK)
└── name (UNIQUE)

categories (4 Datensätze)
├── id (PK)
└── name (UNIQUE)

tags (5 Datensätze)
├── id (PK)
└── name (UNIQUE)
```

### Produktdaten (Product Data)
```
products (500 Datensätze, IDs 1-500)
├── id (PK)
├── name
├── description
├── brand_id (FK → brands)
├── category_id (FK → categories)
└── price

products_extended (500 Datensätze, IDs 1-500)
├── id (PK)
├── name
├── description
├── brand_id (FK → brands)
├── category_id (FK → categories)
├── price
├── load_class (high/medium/low)
├── application (precision/automotive/industrial)
└── temperature_range

products_500_new (500 Datensätze, IDs 501-1000)
├── id (PK)
├── name
├── description
├── brand_id (FK → brands)
├── category_id (FK → categories)
├── price
├── load_class (high/medium/low)
├── application (precision/automotive/industrial)
└── temperature_range
```

### Verknüpfungstabellen (Junction Tables)
```
product_tags (~995 Zuordnungen)
├── product_id (FK → products, PK)
└── tag_id (FK → tags, PK)
```

## Beziehungen

### 1:N Beziehungen
- `brands` → `products` (1:N)
- `brands` → `products_extended` (1:N)
- `brands` → `products_500_new` (1:N)
- `categories` → `products` (1:N)
- `categories` → `products_extended` (1:N)
- `categories` → `products_500_new` (1:N)

### N:M Beziehungen
- `products` ↔ `tags` (N:M über `product_tags`)

## Installation

### Voraussetzungen

- MySQL 8.0 oder höher
- Zugriff auf die CSV-Dateien im `data/` Verzeichnis
- `local_infile` muss aktiviert sein

### MySQL local_infile aktivieren

```sql
-- In MySQL als Administrator:
SET GLOBAL local_infile = 1;
```

### 1. Schema erstellen

```bash
mysql -u root -p --local-infile=1 < schema.sql
```

Oder in MySQL:
```sql
SOURCE schema.sql;
```

### 2. Daten importieren

```bash
mysql -u root -p --local-infile=1 < import.sql
```

Oder in MySQL:
```sql
SOURCE import.sql;
```

### 3. Komplette Installation (Schema + Import)

```bash
mysql -u root -p --local-infile=1 < schema.sql
mysql -u root -p --local-infile=1 < import.sql
```

## Transaktionsstruktur

Der Import ist in 5 separate Transaktionen aufgeteilt:

### Transaction 1: Stammdaten
- `brands.csv` (5 Datensätze)
- `categories.csv` (4 Datensätze)
- `tags.csv` (5 Datensätze)

**Validierungen:**
- Prüfung auf erwartete Anzahl an Datensätzen
- Bei Fehler: ROLLBACK aller Stammdaten

### Transaction 2: Basis-Produkte
- `products.csv` (500 Datensätze, IDs 1-500)

**Validierungen:**
- Prüfung auf 500 Datensätze
- Prüfung des ID-Bereichs (1-500)
- Validierung aller Foreign Keys (brand_id, category_id)
- Bei Fehler: ROLLBACK

### Transaction 3: Erweiterte Produkte
- `products_extended.csv` (500 Datensätze, IDs 1-500)

**Validierungen:**
- Prüfung auf 500 Datensätze
- Prüfung des ID-Bereichs (1-500)
- Validierung aller Foreign Keys
- Bei Fehler: ROLLBACK

### Transaction 4: Neue Produktvarianten
- `products_500_new.csv` (500 Datensätze, IDs 501-1000)

**Validierungen:**
- Prüfung auf 500 Datensätze
- Prüfung des ID-Bereichs (501-1000)
- Validierung aller Foreign Keys
- Bei Fehler: ROLLBACK

### Transaction 5: Produkt-Tag-Verknüpfungen
- `product_tags.csv` (~995 Zuordnungen)

**Validierungen:**
- Validierung aller Foreign Keys (product_id, tag_id)
- Statistik: Durchschnittliche Tags pro Produkt
- Bei Fehler: ROLLBACK

## Fehlerbehandlung

### Automatisches Rollback bei Fehlern

Alle Transaktionen werden automatisch zurückgerollt, wenn:
- Die erwartete Anzahl an Datensätzen nicht übereinstimmt
- Ungültige Foreign Key Referenzen gefunden werden
- Check Constraints verletzt werden
- Unique Constraints verletzt werden
- Beliebige SQL-Fehler auftreten

### Beispiel-Fehlermeldungen

```
Fehler: Erwartete 5 Marken, aber andere Anzahl gefunden
Fehler: Ungültige brand_id Referenzen gefunden
Fehler: Produkt-IDs sollten von 1 bis 500 reichen
```

## Integritätsprüfung

Nach erfolgreichem Import führt das Skript automatisch eine vollständige Integritätsprüfung durch:

```sql
✓ Alle products.brand_id sind gültig
✓ Alle products.category_id sind gültig
✓ Alle products_extended.brand_id sind gültig
✓ Alle products_extended.category_id sind gültig
✓ Alle products_500_new.brand_id sind gültig
✓ Alle products_500_new.category_id sind gültig
✓ Alle product_tags.product_id sind gültig
✓ Alle product_tags.tag_id sind gültig
✓ Alle Integritätsprüfungen bestanden!
```

## Import-Ausgabe

Das Import-Skript gibt detaillierte Informationen aus:

```
============================================
Start des Datenbank-Imports
Zeitstempel: 2026-03-29 17:30:00
============================================

--------------------------------------------
TRANSACTION 1: Import Stammdaten
--------------------------------------------
Importiere brands.csv...
✓ 5 Datensätze in brands importiert
Importiere categories.csv...
✓ 4 Datensätze in categories importiert
Importiere tags.csv...
✓ 5 Datensätze in tags importiert
✓ TRANSACTION 1 erfolgreich abgeschlossen
  - 5 Marken
  - 4 Kategorien
  - 5 Tags

[... weitere Transaktionen ...]

============================================
Import erfolgreich abgeschlossen!
Zeitstempel: 2026-03-29 17:30:15
============================================

Zusammenfassung der importierten Daten:
----------------------------------------
Brands:              5 Datensätze
Categories:          4 Datensätze
Tags:                5 Datensätze
----------------------------------------
Products:            500 Datensätze (IDs 1-500)
Products Extended:   500 Datensätze (IDs 1-500)
Products 500 New:    500 Datensätze (IDs 501-1000)
----------------------------------------
Product Tags:        995 Zuordnungen
----------------------------------------
GESAMT:              2509 Datensätze
============================================
```

## Erweiterte Nutzung

### Schema neu erstellen (Reset)

```bash
# Löscht alle Tabellen und erstellt sie neu
mysql -u root -p --local-infile=1 < schema.sql
```

### Nur bestimmte Tabellen importieren

Sie können einzelne Transaktionen aus `import.sql` extrahieren und separat ausführen.

### Performance-Optimierung

Das Import-Skript enthält bereits Performance-Optimierungen:
```sql
SET autocommit = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;
```

Diese werden nach dem Import automatisch zurückgesetzt.

## Constraints und Validierungen

### Primary Keys
- Alle Tabellen haben einen `id`-Primärschlüssel
- `product_tags` hat einen zusammengesetzten Primärschlüssel (product_id, tag_id)

### Foreign Keys
- `ON DELETE RESTRICT` bei Stammdaten (verhindert Löschen bei Referenzen)
- `ON DELETE CASCADE` bei Verknüpfungstabellen (löscht abhängige Daten)
- `ON UPDATE CASCADE` überall (Updates werden weitergegeben)

### Check Constraints
- Namen dürfen nicht leer sein
- Preise müssen positiv sein
- Enum-Felder haben feste Wertelisten:
  - `load_class`: high, medium, low
  - `application`: precision, automotive, industrial

### Unique Constraints
- Markennamen sind eindeutig
- Kategorienamen sind eindeutig
- Tag-Namen sind eindeutig

## Indizes

Performante Indizes für häufige Abfragen:

```sql
-- Produktsuche nach Brand/Category
idx_products_brand
idx_products_category

-- Preisfilterung
idx_products_price

-- Volltextsuche
idx_products_name

-- Tag-Suche (Rückwärts)
idx_product_tags_tag

-- Erweiterte Attribute
idx_products_extended_load_class
idx_products_extended_application
```

## Datenmengen

| Tabelle | Datensätze | ID-Bereich |
|---------|-----------|-----------|
| brands | 5 | 1-5 |
| categories | 4 | 1-4 |
| tags | 5 | 1-5 |
| products | 500 | 1-500 |
| products_extended | 500 | 1-500 |
| products_500_new | 500 | 501-1000 |
| product_tags | ~995 | N/A |
| **GESAMT** | **~2.509** | |

## Troubleshooting

### Problem: "The used command is not allowed with this MySQL version"

**Lösung:** Aktivieren Sie `local_infile`:
```sql
SET GLOBAL local_infile = 1;
```

Oder starten Sie MySQL-Client mit:
```bash
mysql --local-infile=1 -u root -p
```

### Problem: "Can't get stat of 'data/brands.csv'"

**Lösung:** Stellen Sie sicher, dass:
1. Die CSV-Dateien im `data/` Verzeichnis liegen
2. Sie MySQL aus dem richtigen Verzeichnis starten
3. MySQL Leserechte auf das Verzeichnis hat

### Problem: Foreign Key Constraint Fehler

**Lösung:** Führen Sie `schema.sql` erneut aus, um die Tabellen in der richtigen Reihenfolge zu erstellen.

### Problem: Transaction rollt zurück

**Lösung:** Prüfen Sie die Fehlermeldung:
- Sind alle CSV-Dateien vorhanden?
- Haben die CSV-Dateien die erwartete Struktur?
- Sind die Datenmengen korrekt?

## CSV-Dateiformat

Alle CSV-Dateien müssen folgendes Format haben:
- **Trennzeichen:** Komma (`,`)
- **Textbegrenzung:** Doppelte Anführungszeichen (`"`)
- **Zeilenende:** `\n`
- **Header:** Erste Zeile enthält Spaltennamen
- **Zeichensatz:** UTF-8

## Best Practices

1. **Immer schema.sql vor import.sql ausführen**
2. **Backups vor Re-Import erstellen**
3. **Import-Ausgabe auf Fehler prüfen**
4. **Integritätsprüfungen beachten**
5. **Bei Produktiv-Datenbanken: Transaction-Log aktivieren**

## Lizenz

Dieses Projekt ist Teil der DHBW Stuttgart Datenbanken-Vorlesung.

---

**Autor:** DHBW Stuttgart - Datenbanksysteme  
**Version:** 1.0  
**Datum:** 2026-03-29  
**MySQL Version:** 8.4+
