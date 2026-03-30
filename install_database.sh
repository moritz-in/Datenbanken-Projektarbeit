#!/bin/bash

# ============================================================================
# Datenbank Quick-Start Installation Script
# ============================================================================
# Beschreibung: Automatisierte Installation der Produktdatenbank
# Version: 1.0
# Datum: 2026-03-29
# ============================================================================

set -e  # Exit on error

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Produktdatenbank Installation${NC}"
echo -e "${BLUE}  DHBW Stuttgart - Datenbanksysteme${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ============================================================================
# Konfiguration
# ============================================================================

# Standard-Werte
DB_HOST="localhost"
DB_PORT="3306"
DB_USER="root"
DB_NAME="produktdatenbank"

# Parameter aus Kommandozeile oder Eingabeaufforderung
echo -e "${YELLOW}Konfiguration:${NC}"
echo ""

read -p "MySQL Host [${DB_HOST}]: " input
DB_HOST=${input:-$DB_HOST}

read -p "MySQL Port [${DB_PORT}]: " input
DB_PORT=${input:-$DB_PORT}

read -p "MySQL User [${DB_USER}]: " input
DB_USER=${input:-$DB_USER}

read -p "Datenbank Name [${DB_NAME}]: " input
DB_NAME=${input:-$DB_NAME}

read -s -p "MySQL Passwort: " DB_PASSWORD
echo ""
echo ""

# ============================================================================
# Datenbankverbindung testen
# ============================================================================

echo -e "${YELLOW}Teste Datenbankverbindung...${NC}"

if mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Verbindung erfolgreich${NC}"
else
    echo -e "${RED}✗ Verbindung fehlgeschlagen${NC}"
    echo -e "${RED}Bitte prüfen Sie Ihre Zugangsdaten${NC}"
    exit 1
fi

echo ""

# ============================================================================
# Datenbank erstellen (falls nicht vorhanden)
# ============================================================================

echo -e "${YELLOW}Erstelle Datenbank '${DB_NAME}' (falls nicht vorhanden)...${NC}"

mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" << EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;
EOF

echo -e "${GREEN}✓ Datenbank bereit${NC}"
echo ""

# ============================================================================
# local_infile aktivieren
# ============================================================================

echo -e "${YELLOW}Aktiviere local_infile...${NC}"

mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" -e "SET GLOBAL local_infile = 1;" 2>/dev/null || {
    echo -e "${YELLOW}⚠ Konnte local_infile nicht global setzen (ggf. fehlende Rechte)${NC}"
    echo -e "${YELLOW}  Versuche trotzdem fortzufahren...${NC}"
}

echo ""

# ============================================================================
# Schema erstellen
# ============================================================================

echo -e "${YELLOW}Erstelle Datenbank-Schema...${NC}"
echo -e "${BLUE}--------------------------------------------${NC}"

if [ ! -f "schema.sql" ]; then
    echo -e "${RED}✗ schema.sql nicht gefunden${NC}"
    exit 1
fi

mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" --local-infile=1 "${DB_NAME}" < schema.sql

echo -e "${BLUE}--------------------------------------------${NC}"
echo -e "${GREEN}✓ Schema erfolgreich erstellt${NC}"
echo ""

# ============================================================================
# CSV-Dateien prüfen
# ============================================================================

echo -e "${YELLOW}Prüfe CSV-Dateien...${NC}"

CSV_FILES=(
    "data/brands.csv"
    "data/categories.csv"
    "data/tags.csv"
    "data/products.csv"
    "data/products_extended.csv"
    "data/products_500_new.csv"
    "data/product_tags.csv"
)

MISSING_FILES=0

for file in "${CSV_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ ${file}${NC}"
    else
        echo -e "${RED}✗ ${file} nicht gefunden${NC}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo -e "${RED}✗ ${MISSING_FILES} CSV-Datei(en) fehlen${NC}"
    exit 1
fi

echo ""

# ============================================================================
# Daten importieren
# ============================================================================

echo -e "${YELLOW}Importiere Daten...${NC}"
echo -e "${BLUE}--------------------------------------------${NC}"

if [ ! -f "import.sql" ]; then
    echo -e "${RED}✗ import.sql nicht gefunden${NC}"
    exit 1
fi

mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" --local-infile=1 "${DB_NAME}" < import.sql

echo -e "${BLUE}--------------------------------------------${NC}"
echo -e "${GREEN}✓ Daten erfolgreich importiert${NC}"
echo ""

# ============================================================================
# Verifikation ausführen
# ============================================================================

echo -e "${YELLOW}Führe Verifikation durch...${NC}"
echo -e "${BLUE}--------------------------------------------${NC}"

if [ -f "verify_database.sql" ]; then
    mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < verify_database.sql | grep -E "Status|✓|✗|Tabelle|Anzahl" || true
    echo -e "${BLUE}--------------------------------------------${NC}"
    echo -e "${GREEN}✓ Verifikation abgeschlossen${NC}"
else
    echo -e "${YELLOW}⚠ verify_database.sql nicht gefunden, überspringe Verifikation${NC}"
fi

echo ""

# ============================================================================
# Abschluss
# ============================================================================

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation erfolgreich abgeschlossen!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${BLUE}Datenbank-Details:${NC}"
echo -e "  Host:     ${DB_HOST}:${DB_PORT}"
echo -e "  User:     ${DB_USER}"
echo -e "  Database: ${DB_NAME}"
echo ""
echo -e "${BLUE}Verbinden mit:${NC}"
echo -e "  mysql -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} -p ${DB_NAME}"
echo ""
echo -e "${BLUE}Tabellen:${NC}"
echo -e "  - brands (5 Datensätze)"
echo -e "  - categories (4 Datensätze)"
echo -e "  - tags (5 Datensätze)"
echo -e "  - products (500 Datensätze)"
echo -e "  - products_extended (500 Datensätze)"
echo -e "  - products_500_new (500 Datensätze)"
echo -e "  - product_tags (~995 Zuordnungen)"
echo ""
echo -e "${BLUE}Nächste Schritte:${NC}"
echo -e "  1. Verbinde dich mit der Datenbank"
echo -e "  2. Führe Testabfragen aus"
echo -e "  3. Siehe DATABASE_IMPORT.md für Details"
echo ""
echo -e "${GREEN}============================================${NC}"
