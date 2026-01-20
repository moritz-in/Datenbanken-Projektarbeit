-- -----------------------------------------------
-- Szenario 3: Starke und schwache Entität
-- 1. Starke Entität: Bestellung
-- 2. Schwache Entität: Bestellposition
--
--    Starke Entität: Die Tabelle Bestellung ist die starke Entität, 
--    da sie eine eindeutige Bestellung darstellt, die unabhängig existieren kann.
--    Schwache Entität: Die Tabelle Bestellposition ist eine schwache Entität, 
--    weil sie keine eigenständige Existenz hat. Jede Bestellposition ist nur 
--    durch die Beziehung zur Tabelle Bestellung gültig, was durch den 
--    Fremdschlüssel BestellungID dargestellt wird.
--
-- Besonderheiten der schwachen Entität:
--
--    Die Bestellposition ist auf den Fremdschlüssel BestellungID angewiesen.
--    Eine schwache Entität wie Bestellposition hat oft keinen eigenen 
--    eindeutigen Schlüssel (wie BestellpositionID) oder benötigt zusätzlich 
--    den Schlüssel der starken Entität, um eindeutig identifiziert zu werden.
-- -----------------------------------------------

-- -----------------------------------------------
-- Schwache Entität: Bestellposition
CREATE TABLE Bestellposition (
    BestellpositionID INT,
    BestellungID INT,
    ArtikelID INT,
    Menge INT,
    PRIMARY KEY (BestellpositionID, BestellungID),
    FOREIGN KEY (BestellungID) REFERENCES Bestellung(BestellungID)
);
-- -----------------------------------------------
CREATE TABLE Bestellung (
    BestellungID INT PRIMARY KEY,
    KundeID INT,
    Bestelldatum DATE
);
-- -----------------------------------------------
-- Befüllung der starken Entität: Bestellung
INSERT INTO Bestellung (BestellungID, KundeID, Bestelldatum) VALUES (1, 101, '2023-10-01');
INSERT INTO Bestellung (BestellungID, KundeID, Bestelldatum) VALUES (2, 102, '2023-10-02');

-- Befüllung der schwachen Entität: Bestellpositionen (abhängig von Bestellung)
INSERT INTO Bestellposition (BestellpositionID, BestellungID, ArtikelID, Menge) VALUES (1, 1, 201, 3);
INSERT INTO Bestellposition (BestellpositionID, BestellungID, ArtikelID, Menge) VALUES (2, 1, 202, 1);
INSERT INTO Bestellposition (BestellpositionID, BestellungID, ArtikelID, Menge) VALUES (1, 2, 203, 5);
-- -----------------------------------------------
SELECT 
    b.BestellungID,
    bp.BestellpositionID,
    bp.ArtikelID,
    bp.Menge
FROM 
    Bestellung b
JOIN 
    Bestellposition bp ON b.BestellungID = bp.BestellungID
WHERE 
    b.BestellungID = 1;
-- -----------------------------------------------