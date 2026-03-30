@echo off
REM ============================================================================
REM Datenbank Quick-Start Installation Script (Windows)
REM ============================================================================
REM Beschreibung: Automatisierte Installation der Produktdatenbank
REM Version: 1.0
REM Datum: 2026-03-29
REM ============================================================================

setlocal enabledelayedexpansion

echo ============================================
echo   Produktdatenbank Installation
echo   DHBW Stuttgart - Datenbanksysteme
echo ============================================
echo.

REM ============================================================================
REM Konfiguration
REM ============================================================================

set DB_HOST=localhost
set DB_PORT=3306
set DB_USER=root
set DB_NAME=produktdatenbank

echo Konfiguration:
echo.

set /p "input=MySQL Host [%DB_HOST%]: "
if not "!input!"=="" set DB_HOST=!input!

set /p "input=MySQL Port [%DB_PORT%]: "
if not "!input!"=="" set DB_PORT=!input!

set /p "input=MySQL User [%DB_USER%]: "
if not "!input!"=="" set DB_USER=!input!

set /p "input=Datenbank Name [%DB_NAME%]: "
if not "!input!"=="" set DB_NAME=!input!

set /p "DB_PASSWORD=MySQL Passwort: "
echo.

REM ============================================================================
REM Datenbankverbindung testen
REM ============================================================================

echo Teste Datenbankverbindung...

mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% -e "SELECT 1;" >nul 2>&1
if errorlevel 1 (
    echo [FEHLER] Verbindung fehlgeschlagen
    echo Bitte pruefen Sie Ihre Zugangsdaten
    exit /b 1
)

echo [OK] Verbindung erfolgreich
echo.

REM ============================================================================
REM Datenbank erstellen
REM ============================================================================

echo Erstelle Datenbank '%DB_NAME%' (falls nicht vorhanden)...

mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% -e "CREATE DATABASE IF NOT EXISTS %DB_NAME% CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo [OK] Datenbank bereit
echo.

REM ============================================================================
REM local_infile aktivieren
REM ============================================================================

echo Aktiviere local_infile...

mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% -e "SET GLOBAL local_infile = 1;" 2>nul
if errorlevel 1 (
    echo [WARNUNG] Konnte local_infile nicht global setzen
    echo           Versuche trotzdem fortzufahren...
)

echo.

REM ============================================================================
REM Schema erstellen
REM ============================================================================

echo Erstelle Datenbank-Schema...
echo --------------------------------------------

if not exist "schema.sql" (
    echo [FEHLER] schema.sql nicht gefunden
    exit /b 1
)

mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% --local-infile=1 %DB_NAME% < schema.sql

echo --------------------------------------------
echo [OK] Schema erfolgreich erstellt
echo.

REM ============================================================================
REM CSV-Dateien prüfen
REM ============================================================================

echo Pruefe CSV-Dateien...

set MISSING_FILES=0

if exist "data\brands.csv" (echo [OK] data\brands.csv) else (echo [FEHLER] data\brands.csv & set /a MISSING_FILES+=1)
if exist "data\categories.csv" (echo [OK] data\categories.csv) else (echo [FEHLER] data\categories.csv & set /a MISSING_FILES+=1)
if exist "data\tags.csv" (echo [OK] data\tags.csv) else (echo [FEHLER] data\tags.csv & set /a MISSING_FILES+=1)
if exist "data\products.csv" (echo [OK] data\products.csv) else (echo [FEHLER] data\products.csv & set /a MISSING_FILES+=1)
if exist "data\products_extended.csv" (echo [OK] data\products_extended.csv) else (echo [FEHLER] data\products_extended.csv & set /a MISSING_FILES+=1)
if exist "data\products_500_new.csv" (echo [OK] data\products_500_new.csv) else (echo [FEHLER] data\products_500_new.csv & set /a MISSING_FILES+=1)
if exist "data\product_tags.csv" (echo [OK] data\product_tags.csv) else (echo [FEHLER] data\product_tags.csv & set /a MISSING_FILES+=1)

if !MISSING_FILES! gtr 0 (
    echo [FEHLER] !MISSING_FILES! CSV-Datei(en) fehlen
    exit /b 1
)

echo.

REM ============================================================================
REM Daten importieren
REM ============================================================================

echo Importiere Daten...
echo --------------------------------------------

if not exist "import.sql" (
    echo [FEHLER] import.sql nicht gefunden
    exit /b 1
)

mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% --local-infile=1 %DB_NAME% < import.sql

echo --------------------------------------------
echo [OK] Daten erfolgreich importiert
echo.

REM ============================================================================
REM Verifikation
REM ============================================================================

echo Fuehre Verifikation durch...
echo --------------------------------------------

if exist "verify_database.sql" (
    mysql -h%DB_HOST% -P%DB_PORT% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% < verify_database.sql | findstr /C:"Status" /C:"Tabelle" /C:"Anzahl"
    echo --------------------------------------------
    echo [OK] Verifikation abgeschlossen
) else (
    echo [WARNUNG] verify_database.sql nicht gefunden, ueberspringe Verifikation
)

echo.

REM ============================================================================
REM Abschluss
REM ============================================================================

echo ============================================
echo   Installation erfolgreich abgeschlossen!
echo ============================================
echo.
echo Datenbank-Details:
echo   Host:     %DB_HOST%:%DB_PORT%
echo   User:     %DB_USER%
echo   Database: %DB_NAME%
echo.
echo Verbinden mit:
echo   mysql -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p %DB_NAME%
echo.
echo Tabellen:
echo   - brands (5 Datensaetze)
echo   - categories (4 Datensaetze)
echo   - tags (5 Datensaetze)
echo   - products (500 Datensaetze)
echo   - products_extended (500 Datensaetze)
echo   - products_500_new (500 Datensaetze)
echo   - product_tags (~995 Zuordnungen)
echo.
echo Naechste Schritte:
echo   1. Verbinde dich mit der Datenbank
echo   2. Fuehre Testabfragen aus
echo   3. Siehe DATABASE_IMPORT.md fuer Details
echo.
echo ============================================

pause
