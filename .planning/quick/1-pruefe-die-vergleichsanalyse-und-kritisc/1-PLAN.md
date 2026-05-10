---
phase: quick-1-pruefe-die-vergleichsanalyse-und-kritisc
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - COMPARISON.md
autonomous: true
requirements:
  - DOC-01
must_haves:
  truths:
    - "A grader can compare SQL LIKE, Qdrant vector search, and Neo4j + RAG side-by-side using three concrete query examples."
    - "Each query section contains real result evidence and a clear explanation of where the method succeeds or fails."
    - "The document includes a critical recommendation section that states when each approach should be used for this project."
    - "The Markdown is submission-ready: consistent headings, tables, terminology, and no placeholder language."
  artifacts:
    - path: "COMPARISON.md"
      provides: "Final comparative analysis and critical reflection for submission"
      min_lines: 250
      contains: "## Empfehlung"
  key_links:
    - from: "COMPARISON.md#suchanfrage-sections"
      to: "COMPARISON.md#empfehlung"
      via: "Per-query Bewertungen feeding final recommendation"
      pattern: "## Suchanfrage 1|## Suchanfrage 2|## Suchanfrage 3|## Empfehlung"
    - from: "COMPARISON.md#technische-hintergrunde"
      to: "DOC-01 acceptance context in ROADMAP/REQUIREMENTS"
      via: "B-Tree and HNSW explanations supporting the comparison"
      pattern: "Warum MySQL B-Trees|HNSW-Parameter"
---

<objective>
Prüfe `COMPARISON.md` gegen die dokumentierten Abgabekriterien und bringe die Vergleichsanalyse sprachlich, strukturell und inhaltlich in eine eindeutig abgabereife Form.

Purpose: Die Datei ist das finale Bewertungsartefakt für DOC-01 und muss deshalb nicht nur fachlich korrekt, sondern auch klar nachvollziehbar und formal sauber sein.
Output: Eine überarbeitete `COMPARISON.md`, die die Kriterien aus ROADMAP/REQUIREMENTS sichtbar erfüllt und ohne Platzhalter oder Uneindeutigkeiten abgegeben werden kann.
</objective>

<execution_context>
@$HOME/.config/opencode/get-shit-done/workflows/execute-plan.md
@$HOME/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@COMPARISON.md

No `AGENTS.md` found in project root.
No project skill directories found in `.OpenCode/skills/` or `.agents/skills/`.

Relevant acceptance context:
- ROADMAP Phase 5 goal: reader can compare all three search approaches side-by-side with concrete query examples, understand when each wins, and why.
- REQUIREMENTS `DOC-01`: 3 queries × 3 search methods with concrete examples using real catalog results.
- STATE says `COMPARISON.md` is the final deliverable, so this pass is polish/verification only — do not invent new experiments or research.
</context>

<tasks>

<task type="auto">
  <name>task 1: audit structure against DOC-01 and close visible criterion gaps</name>
  <files>COMPARISON.md</files>
  <action>Review the document directly against Phase 5 / DOC-01 expectations from `.planning/ROADMAP.md` and `.planning/REQUIREMENTS.md`. Keep the existing three-query comparison structure, but rewrite headings, section ordering, and explanatory transitions wherever needed so the rubric is satisfied at a glance. Preserve only claims that are already supported by the document context; do not add fabricated measurements, screenshots, or new research. If any section currently implies unsupported evidence, rephrase it into bounded, defensible wording.</action>
  <verify>
    <automated>python - <<'PY'
from pathlib import Path
text = Path('COMPARISON.md').read_text()
required = [
    '## Suchanfrage 1',
    '## Suchanfrage 2',
    '## Suchanfrage 3',
    '### SQL LIKE',
    '### Qdrant Vektor-Suche',
    '### Neo4j + RAG',
    '## Empfehlung'
]
missing = [item for item in required if item not in text]
assert not missing, f'Missing required comparison sections: {missing}'
assert text.count('## Suchanfrage ') >= 3, 'Need at least 3 query sections'
PY</automated>
  </verify>
  <done>The document visibly contains the complete 3×3 comparison structure with an explicit recommendation section and no rubric-relevant omissions.</done>
</task>

<task type="auto">
  <name>task 2: strengthen evidence and critical reflection per search method</name>
  <files>COMPARISON.md</files>
  <action>Tighten each query section so every method includes all three elements: concrete approach/query, real result evidence, and a short critical interpretation of strengths/limits. Make the contrast explicit: what SQL guarantees that vector search does not, what vector search finds that SQL misses, and what graph enrichment adds beyond retrieval. Keep the reflection grounded in this project's seeded catalog and implemented stack; avoid vague generalities and avoid overstating RAG value where the current document already shows limited benefit.</action>
  <verify>
    <automated>python - <<'PY'
from pathlib import Path
text = Path('COMPARISON.md').read_text()
assert text.count('**Bewertung:**') >= 9, 'Each of 3 queries x 3 methods should have a Bewertung block'
for needle in ['semantic gap', 'B-Tree', 'HNSW', 'Qdrant', 'Neo4j']:
    assert needle.lower() in text.lower(), f'Missing critical concept: {needle}'
PY</automated>
  </verify>
  <done>Each method subsection contains concrete evidence plus a critical, method-specific interpretation that supports the final comparison.</done>
</task>

<task type="auto">
  <name>task 3: final markdown polish for submission readiness</name>
  <files>COMPARISON.md</files>
  <action>Do a final editorial pass for submission quality: consistent terminology, quote style, punctuation, table formatting, and section language. Remove placeholder phrasing, redundancy, and wording that sounds like notes instead of final prose. Keep the document in German, preserve technical terms where needed, and ensure the document reads as one coherent final submission rather than an internal draft.</action>
  <verify>
    <automated>python - <<'PY'
from pathlib import Path
text = Path('COMPARISON.md').read_text()
for banned in ['TODO', 'TBD', 'placeholder', 'Platzhalter', 'XXX']:
    assert banned.lower() not in text.lower(), f'Found draft marker: {banned}'
assert '## Technische Hintergründe' in text, 'Technical background section missing'
assert '### Warum MySQL B-Trees?' in text, 'B-Tree explanation missing'
assert '### HNSW-Parameter (Qdrant)' in text, 'HNSW explanation missing'
PY</automated>
  </verify>
  <done>`COMPARISON.md` is cleanly formatted, free of draft markers, and ready to hand in as the final Markdown deliverable.</done>
</task>

</tasks>

<verification>
Re-read `COMPARISON.md` after edits and confirm that a professor can answer these questions without additional context:
1. Welche der drei Methoden gewinnt bei welcher Query — und warum?
2. Welche Evidenz stammt aus realen Ergebnissen des Projekts?
3. Was ist der technische Unterschied zwischen B-Tree, Vektor-Suche und Graph+RAG im konkreten System?
</verification>

<success_criteria>
- `COMPARISON.md` erfüllt sichtbar DOC-01 aus ROADMAP/REQUIREMENTS.
- Drei Suchanfragen mit allen drei Methoden bleiben vollständig vorhanden.
- Jede Methode hat pro Query echte Resultate oder klar benannte Grenzen statt leerer Behauptungen.
- Empfehlung und kritische Reflexion sind explizit, nicht nur implizit verteilt.
- Die Markdown-Datei ist sprachlich und formal abgabereif.
</success_criteria>

<output>
After completion, create `.planning/quick/1-pruefe-die-vergleichsanalyse-und-kritisc/1-SUMMARY.md`
</output>
