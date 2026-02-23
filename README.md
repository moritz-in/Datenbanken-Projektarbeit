Studiengang: Informatik STG-TINF24ITA  
Modul: Datenbanksysteme  
Dozent: Karsten Keßler  
Bearbeitungsform: Gruppenarbeit  
Abgabe: Skripte + PDF + Lauffähige App + Kurzpräsentation  

---

📦 Projektarbeit: Relationale Datenbank und darauf aufbauend Vektorsuche (optional Graph-RAG-Erweiterung)

🎯 Ziel der Projektarbeit

Ziel dieser Projektarbeit ist es, klassische relationale Datenbanksysteme mit modernen semantischen Suchverfahren zu kombinieren und deren unterschiedliche Stärken, Grenzen und Einsatzgebiete praktisch zu analysieren.  
Die Studierenden sollen zeigen: 
- Strukturierte Daten sauber relational modellieren
- Transaktionen, Trigger und Stored Procedures gezielt einsetzen 
- Indizes verstehen und begründen 
- Strukturierte Produktdaten in semantische Vektoren überführen 
- Suchergebnisse analysieren, vergleichen und kritisch reflektieren 
- Moderne Architekturen einordnen

🧱 Ausgangslage 

- Alle Studierenden arbeiten auf dem gleichen Produktdatenbestand  
- Der Datenbestand wird nicht inhaltlich verändert, sondern nur erweitert  
- Die relationale Datenbank ist die Source of Truth 
- Vektor- und RAG-Komponenten dienen ausschließlich der Suche und Analyse
- Fokus liegt auf Datenbank- und Architekturverständnis

---
🔄 Aufgabe 1.1: DB-Schema erstellen

Analysieren Sie den bereitgestellten CSV-Produktdatenbestand und erstellen Sie ein relationales Datenbankschema, das die folgenden Entitäten und Beziehungen umfasst:
1. products
2. brands
3. categories
4. tags
5. etl_run_logs

✏️  Aufgabe 1.2: Import von Daten

Importieren Sie die bereitgestellten Daten in Ihre relationale Datenbank. Achten Sie dabei auf die Einhaltung der Normalformen und die Vermeidung von Redundanzen.

🧮 Aufgabe 2.1: Transaktionen

Implementieren Sie **eine Transaktion**, die ein komplettes Produkt mit allen Beziehungen anlegt:

1. **Neues Produkt** einfügen
2. **Marke** zuordnen (ggf. neu anlegen)
3. **Kategorie** verknüpfen
4. **Mindestens 2 Tags** verknüpfen (N:M Beziehung)

⚙️ Aufgabe 2.2: Trigger

Implementieren Sie **2 Trigger** mit fachlichem Mehrwert.

🧠 Aufgabe 2.3: Stored Procedures

Implementieren Sie **eine Stored Procedure** mit Geschäftslogik.

🚀 Aufgabe 2.4: Indizes & Performance

Erstellen Sie **2 sinnvolle Indizes** für häufige Queries.

🔍 Aufgabe 2.5: Vektor-Datenbank & Semantische Suche

...


🧠 Optionale Bonusarbeit: Graph-RAG

....

🎤 Präsentation (10–15 Minuten):

- Lauffähige App mit entsprechenden Docker-Containern
- Architekturüberblick
- Designentscheidung
- Lessons Learnt

---
Termine:

Abgabe Teil 1 ➡️ 12.04.2026  
Alle SQL-Skripte aus 1. und ERM als PDF

Abgabe Teil 2 ➡️ 17.05.2026
    
...

---

