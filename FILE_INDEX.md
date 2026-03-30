# 📚 Datenbank Import-Struktur - Datei-Index

## Schnellzugriff

| Datei | Zweck | Für wen? |
|-------|-------|----------|
| **QUICK_START.md** | Schnellstart-Anleitung | ⭐ Einsteiger |
| **DATABASE_IMPORT.md** | Vollständige Dokumentation | Entwickler |
| **schema.sql** | Tabellendefinitionen (DDL) | ⭐ Alle |
| **import.sql** | Daten-Import (DML) | ⭐ Alle |
| **verify_database.sql** | Verifikation & Tests | Qualitätssicherung |
| **sql_quick_reference.sql** | 50+ Beispiel-Abfragen | Entwickler |
| **install_database.sh** | Auto-Install (Linux/Mac) | ⭐ Einsteiger |
| **install_database.bat** | Auto-Install (Windows) | ⭐ Einsteiger |

---

## 1. schema.sql (11 KB)

**Zweck:** Vollständige Datenbankstruktur (DDL)

**Enthält:**
- 7 Tabellendefinitionen
- 8 Foreign Key Constraints
- 17 Check Constraints
- 18 Performance-Indizes
- DROP TABLE IF EXISTS (Wiederholbarkeit)

**Wichtigste Tabellen:**
- `brands` - Marken (5)
- `categories` - Kategorien (4)
- `tags` - Tags (5)
- `products` - Basis-Produkte (500)
- `products_extended` - Erweiterte Produkte (500)
- `products_500_new` - Neue Varianten (500)
- `product_tags` - N:M-Verknüpfungen (~995)

**Ausführen:**
```bash
mysql -u root -p --local-infile=1 < schema.sql
```

---

## 2. import.sql (20 KB)

**Zweck:** Transaktionaler Daten-Import aus CSV-Dateien

**Enthält:**
- 5 separate Transaktionen
- LOAD DATA LOCAL INFILE für alle CSV-Dateien
- Automatische Validierungen
- ROLLBACK bei Fehlern
- Integritätsprüfungen

**Transaktionsstruktur:**
1. **Transaction 1:** Stammdaten (brands, categories, tags)
2. **Transaction 2:** products.csv (500 Datensätze)
3. **Transaction 3:** products_extended.csv (500 Datensätze)
4. **Transaction 4:** products_500_new.csv (500 Datensätze)
5. **Transaction 5:** product_tags.csv (~995 Datensätze)

**Ausführen:**
```bash
mysql -u root -p --local-infile=1 < import.sql
```

---

## 3. DATABASE_IMPORT.md (11 KB)

**Zweck:** Vollständige technische Dokumentation

**Inhalt:**
- Übersicht der Features
- Datenbank-Schema-Diagramme
- Installation (Schritt-für-Schritt)
- Transaktionsstruktur (detailliert)
- Fehlerbehandlung
- Integritätsprüfung
- Troubleshooting
- Best Practices
- CSV-Dateiformat
- Constraints & Validierungen
- Indizes & Performance

**Wann lesen?**
- Bei Problemen mit der Installation
- Für technische Details
- Für Verständnis der Architektur

---

## 4. verify_database.sql (12 KB)

**Zweck:** Umfangreiche Verifikation der Datenbank nach Import

**Prüft:**
1. ✓ Tabellenexistenz
2. ✓ Datenzählung (erwartete Mengen)
3. ✓ Foreign Key Integrität
4. ✓ ID-Bereiche (1-500, 501-1000)
5. ✓ Preisvalidierung (alle > 0)
6. ✓ Enum-Werte (load_class, application)
7. ✓ Stammdaten-Übersicht
8. ✓ Statistiken (Produkte pro Brand/Category)
9. ✓ Datenqualität (NULL-Werte, leere Strings)
10. ✓ Join-Tests (3 Beispiel-Produkte)

**Ausführen:**
```bash
mysql -u root -p < verify_database.sql
```

**Output:** Detaillierter Report mit ✓/✗ für jeden Check

---

## 5. sql_quick_reference.sql (12 KB)

**Zweck:** Sammlung von 50+ nützlichen Beispiel-Abfragen

**Kategorien:**
1. Grundlegende SELECT-Abfragen
2. Filtern und Suchen
3. JOINs und Verknüpfungen
4. Aggregationen und Statistiken
5. Erweiterte Abfragen (products_extended)
6. Vergleiche zwischen Tabellen
7. TOP/BOTTOM-Abfragen
8. Subqueries und komplexe Abfragen
9. Datenänderungen (UPDATE/DELETE)
10. Performance-Analysen
11. Export-Abfragen

**Verwendung:**
- Als Lernressource
- Als Basis für eigene Abfragen
- Als Referenz für häufige Patterns

**Beispiele:**
```sql
-- Produkte mit allen Details
SELECT p.id, p.name, b.name AS brand, ...

-- Produkte pro Marke (Statistik)
SELECT b.name, COUNT(p.id), AVG(p.price) ...

-- Top 10 teuerste Produkte
SELECT * FROM products ORDER BY price DESC LIMIT 10;
```

---

## 6. install_database.sh (7 KB)

**Zweck:** Automatisierte Installation für Linux/Mac

**Features:**
- Interaktive Konfiguration (Host, Port, User, Database)
- Datenbankverbindung testen
- Datenbank erstellen (falls nicht vorhanden)
- local_infile aktivieren
- Schema erstellen
- CSV-Dateien prüfen
- Daten importieren
- Verifikation durchführen
- Farbige Ausgabe (✓/✗)

**Ausführen:**
```bash
chmod +x install_database.sh
./install_database.sh
```

**Interaktive Eingabe:**
```
MySQL Host [localhost]: 
MySQL Port [3306]: 
MySQL User [root]: 
Datenbank Name [produktdatenbank]: 
MySQL Passwort: ****
```

---

## 7. install_database.bat (7 KB)

**Zweck:** Automatisierte Installation für Windows

**Features:** (identisch zu .sh)
- Interaktive Konfiguration
- Datenbankverbindung testen
- Datenbank erstellen
- Schema + Import + Verifikation
- Detaillierte Ausgabe

**Ausführen:**
```cmd
install_database.bat
```

---

## 8. QUICK_START.md (8 KB)

**Zweck:** Schnellstart-Anleitung für Einsteiger

**Inhalt:**
- Übersicht der Dateien
- Erfüllte Anforderungen
- Schnellstart (2 Optionen)
- Datenbank-Struktur
- Wichtige Konzepte
- Beispiel-Abfragen
- Verifikation
- Fehlerbehandlung
- Troubleshooting
- Best Practices
- Nächste Schritte

**Wann lesen?**
- Vor der ersten Installation
- Als Übersicht über das Projekt
- Für schnellen Einstieg

---

## Empfohlene Reihenfolge

### Für Einsteiger:

1. **QUICK_START.md** lesen (5 Minuten)
2. **install_database.sh/.bat** ausführen (2 Minuten)
3. **verify_database.sql** Output prüfen (1 Minute)
4. **sql_quick_reference.sql** durchsehen (10 Minuten)
5. Eigene Abfragen entwickeln

### Für Entwickler:

1. **DATABASE_IMPORT.md** lesen (15 Minuten)
2. **schema.sql** studieren (10 Minuten)
3. **import.sql** studieren (10 Minuten)
4. Manuelle Installation durchführen
5. **verify_database.sql** analysieren
6. **sql_quick_reference.sql** als Referenz nutzen

### Für Datenbank-Designer:

1. **schema.sql** analysieren (20 Minuten)
2. **import.sql** Transaktionsstruktur verstehen (15 Minuten)
3. **verify_database.sql** Validierungslogik prüfen (10 Minuten)
4. **DATABASE_IMPORT.md** für Details (10 Minuten)

---

## Datei-Abhängigkeiten

```
schema.sql (unabhängig)
    ↓
import.sql (benötigt: schema.sql ausgeführt + CSV-Dateien)
    ↓
verify_database.sql (benötigt: import.sql ausgeführt)

install_database.sh/.bat (verwendet alle obigen + Automatisierung)

DATABASE_IMPORT.md (Dokumentation, unabhängig)
QUICK_START.md (Dokumentation, unabhängig)
sql_quick_reference.sql (Beispiele, benötigt importierte Daten)
```

---

## CSV-Dateien (Voraussetzung)

Alle Import-Skripte erwarten diese CSV-Dateien im `data/` Verzeichnis:

```
data/
├── brands.csv           (5 Zeilen + Header)
├── categories.csv       (4 Zeilen + Header)
├── tags.csv             (5 Zeilen + Header)
├── products.csv         (500 Zeilen + Header)
├── products_extended.csv (500 Zeilen + Header)
├── products_500_new.csv (500 Zeilen + Header)
└── product_tags.csv     (~995 Zeilen + Header)
```

**Format:** UTF-8, Comma-separated, Header in Zeile 1

---

## Cheat Sheet

### Schnellinstallation:
```bash
./install_database.sh  # Linux/Mac
install_database.bat   # Windows
```

### Manuelle Installation:
```bash
mysql -u root -p --local-infile=1 < schema.sql
mysql -u root -p --local-infile=1 < import.sql
mysql -u root -p < verify_database.sql
```

### Neu-Installation (Reset):
```bash
mysql -u root -p --local-infile=1 < schema.sql  # Löscht alte Daten!
mysql -u root -p --local-infile=1 < import.sql
```

### Nur Verifikation:
```bash
mysql -u root -p < verify_database.sql
```

### Verbindung zur Datenbank:
```bash
mysql -u root -p produktdatenbank
```

---

## Technische Spezifikationen

| Merkmal | Wert |
|---------|------|
| **Dateien** | 8 |
| **Gesamtgröße** | ~87 KB |
| **Code-Zeilen** | ~2.100 |
| **Tabellen** | 7 |
| **Datensätze** | ~2.509 |
| **Foreign Keys** | 8 |
| **Check Constraints** | 17 |
| **Indizes** | 18 |
| **Transaktionen** | 5 |
| **Validierungen** | 20+ |

---

## Support & Troubleshooting

**Bei Problemen:**

1. **Fehlermeldung lesen** - Meist selbsterklärend
2. **DATABASE_IMPORT.md** → Troubleshooting-Sektion
3. **verify_database.sql** → Zeigt welche Checks fehlschlagen
4. **CSV-Dateien prüfen** - Vorhanden? Korrekt formatiert?
5. **local_infile aktiviert?** - `SET GLOBAL local_infile = 1;`

**Häufige Fehler:**

- "The used command is not allowed" → local_infile fehlt
- "Can't get stat of 'data/brands.csv'" → Falsches Verzeichnis
- Foreign Key Constraint → Schema nicht geladen
- Transaction rollt zurück → CSV-Datei fehlerhaft

---

## Status

✅ **Alle Anforderungen erfüllt**  
✅ **Produktionsbereit**  
✅ **Vollständig dokumentiert**  
✅ **Getestet**

---

**DHBW Stuttgart | Datenbanksysteme**  
**Version 1.0 | 2026-03-29 | MySQL 8.4+**
