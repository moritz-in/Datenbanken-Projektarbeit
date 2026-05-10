---
phase: quick-3-kannst-du-mir-jetzt-erklaeren-was-alles-
plan: 3
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md
autonomous: true
requirements:
  - TXN-04
  - TXN-05
  - ROUTE-01
  - ROUTE-02
  - ROUTE-03
  - VECT-07
  - VECT-08
  - GRAPH-07
  - DOC-01
must_haves:
  truths:
    - "The presenter has a repo-grounded checklist of what must work live before the demo starts."
    - "The presenter has a 15-minute talk track covering running app, architecture overview, one concrete design decision, and lessons learned."
    - "Each grading point is tied to specific routes, files, commands, and fallback wording from the actual project."
  artifacts:
    - path: ".planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md"
      provides: "Live-demo guide with checklist, timing, talking points, and repo-backed evidence"
      min_lines: 120
      contains: "## 15-Minuten-Live-Demo"
  key_links:
    - from: ".planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md#was-live-funktionieren-muss"
      to: "docker-compose.yml and routes/*.py"
      via: "ports, startup command, and concrete route walkthrough"
      pattern: "docker compose up --build|http://localhost:8081|/products|/validate|/index|/search|/rag"
    - from: ".planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md#designentscheidung"
      to: ".planning/STATE.md and docs/INDEX_ANALYSIS.md"
      via: "one chosen implementation decision explained with rationale and evidence"
      pattern: "with session.begin\(\)|MERGE|ensure_collection\(\)|B-Tree"
    - from: ".planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md#bewertungsmatrix-fur-die-live-demo"
      to: "README.md, COMPARISON.md, docs/INDEX_ANALYSIS.md"
      via: "grading criteria mapped to proof artifacts"
      pattern: "README.md|COMPARISON.md|docs/INDEX_ANALYSIS.md"
---

<objective>
Erstelle einen konkreten Live-Demo-Leitfaden, der dem Nutzer erklärt, was im Projekt tatsächlich funktionieren muss, wie er es in wenigen Minuten testet und wie er die 15-minütige Vorstellung so strukturiert, dass die geforderten Bewertungspunkte sichtbar erfüllt sind.

Purpose: Der Code ist bereits fertig; jetzt braucht der Nutzer kein weiteres Feature, sondern eine verlässliche, repo-basierte Demo- und Prüfstrategie für die Präsentation.
Output: `.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md` mit Live-Checkliste, Testschritten, Demo-Ablauf, Architektur-Sprechzettel, Designentscheidung und Lessons-Learned-Teil.
</objective>

<execution_context>
@$HOME/.config/opencode/get-shit-done/workflows/execute-plan.md
@$HOME/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@README.md
@COMPARISON.md
@docs/INDEX_ANALYSIS.md
@docker-compose.yml
@routes/dashboard.py
@routes/products.py
@routes/validate.py
@routes/audit.py
@routes/index.py
@routes/search.py
@routes/rag.py

No `AGENTS.md` found in project root.
No project skill directories found in `.OpenCode/skills/` or `.agents/skills/`.

Relevant repo facts already verified:
- Startup command from `README.md`: `docker compose up --build`
- Demo app URL: `http://localhost:8081`
- Other visible services: MySQL `3316`, Adminer `8990`, Qdrant `6343`, Neo4j Web UI `7484`, Neo4j Bolt `7697`
- Core routes present in code: `/`, `/products`, `/validate`, `/validate/procedure`, `/audit`, `/index`, `/search`, `/rag`
- `README.md` says MySQL remains the source of truth; Qdrant and Neo4j are extensions, not replacements
- `COMPARISON.md` already contains three concrete comparison queries and can be cited in the presentation
- `docs/INDEX_ANALYSIS.md` already contains B-Tree / EXPLAIN evidence for the architecture and design explanation
- `STATE.md` contains concrete implementation decisions and pitfalls that can be reused for the “Designentscheidung” and “Lessons Learned” sections
</context>

<tasks>

<task type="auto">
  <name>task 1: write a repo-grounded readiness checklist for what must work live</name>
  <files>.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md</files>
  <action>Create the guide file and start with a strict “must work” section for the live demo. Derive it from `ROADMAP.md`, `REQUIREMENTS.md`, `README.md`, `docker-compose.yml`, and the existing route files — not from generic presentation advice. Include: startup command, URLs/ports, which pages to open, what visible outcome proves each area works, and which items are core vs. optional fallback. Explicitly cover the running app, MySQL CRUD/transaction behavior, validation/procedure/index evidence, semantic search, and graph/RAG demo path. Keep the guidance honest: if OpenAI is not configured, document the valid fallback already present in the repo (`[LLM nicht konfiguriert ...]`) instead of pretending live prose generation is guaranteed.</action>
  <verify>
    <automated>python3 - &lt;&lt;'PY'
from pathlib import Path
path = Path('.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md')
text = path.read_text()
required = [
    '## Was live funktionieren muss',
    'docker compose up --build',
    'http://localhost:8081',
    '/products',
    '/validate',
    '/validate/procedure',
    '/index',
    '/search',
    '/rag',
    'MySQL',
    'Qdrant',
    'Neo4j',
]
missing = [item for item in required if item not in text]
assert not missing, f'Missing live-demo checklist facts: {missing}'
PY</automated>
  </verify>
  <done>The guide names the exact commands, URLs, routes, and expected visible outcomes needed to prove the app is demo-ready.</done>
</task>

<task type="auto">
  <name>task 2: write the 15-minute demo flow with architecture, one design decision, and lessons learned</name>
  <files>.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md</files>
  <action>Add a time-boxed walkthrough that a single presenter can follow without improvising: opening statement, live product/demo sequence, architecture overview, one concrete design decision, and final lessons learned. Use the actual project architecture from the repo: Flask routes → services → repositories, with MySQL as source of truth plus Qdrant and Neo4j as search/context layers. Choose exactly one design decision to explain in depth and tie it to real project evidence; preferred options are `with session.begin()` for transaction safety, `ensure_collection()` before Qdrant upserts, or `MERGE` instead of `CREATE` for Neo4j sync. Add 2-4 project-specific lessons learned sourced from `STATE.md` pitfalls/decisions, not generic agile reflections.</action>
  <verify>
    <automated>python3 - &lt;&lt;'PY'
from pathlib import Path
text = Path('.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md').read_text()
required = [
    '## 15-Minuten-Live-Demo',
    'Minute 0-2',
    'Minute 2-5',
    'Minute 5-8',
    'Minute 8-11',
    'Minute 11-13',
    'Minute 13-15',
    '## Architekturüberblick',
    'Routes → Services → Repositories',
    '## Designentscheidung',
    '## Lessons Learned',
]
missing = [item for item in required if item not in text]
assert not missing, f'Missing demo-flow sections: {missing}'
assert any(choice in text for choice in ['with session.begin()', 'ensure_collection()', 'MERGE']), 'No concrete design decision documented'
PY</automated>
  </verify>
  <done>The guide contains a realistic 15-minute script plus project-specific explanation content for architecture, one design choice, and lessons learned.</done>
</task>

<task type="auto">
  <name>task 3: add a grading matrix that maps every presentation criterion to proof and fallback wording</name>
  <files>.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md</files>
  <action>Finish the guide with a compact grading matrix aimed at the actual presentation criteria from the user prompt: `Lauffähige App`, `Architekturüberblick`, `Eine Designentscheidung erläutern`, and `Lessons Learned`. For each criterion, include four things: what to show live, what sentence(s) to say, which repo artifact proves it (`README.md`, `COMPARISON.md`, `docs/INDEX_ANALYSIS.md`, relevant route/page), and what fallback to use if the live click path is slow or partially unavailable. Keep this as a presenter cheat sheet, not as general prose. Do not modify app code or root docs unless you discover a factual contradiction; this quick task should stay documentation-focused inside the quick-task directory.</action>
  <verify>
    <automated>python3 - &lt;&lt;'PY'
from pathlib import Path
text = Path('.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md').read_text()
required = [
    '## Bewertungsmatrix für die Live-Demo',
    'Lauffähige App',
    'Architekturüberblick',
    'Designentscheidung',
    'Lessons Learned',
    'README.md',
    'COMPARISON.md',
    'docs/INDEX_ANALYSIS.md',
]
missing = [item for item in required if item not in text]
assert not missing, f'Missing grading-matrix content: {missing}'
assert 'Fallback' in text or 'Fallbacks' in text, 'Guide must include fallback wording'
PY</automated>
  </verify>
  <done>The guide directly maps each demo criterion to concrete live proof, talking points, and backup wording.</done>
</task>

</tasks>

<verification>
After writing the guide, confirm all three of these are true:
1. A presenter can start the stack and click through the demo without guessing routes or commands.
2. Each required presentation point is backed by an actual file, route, or observable behavior from this repo.
3. The document is useful under live-demo pressure: short, specific, and honest about optional vs. guaranteed parts.</verification>

<success_criteria>
- `.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md` exists and stays focused on demo guidance, not code changes.
- The guide explains exactly what must work, how to test it quickly, and how to present it in ~15 minutes.
- Architecture, one design decision, and lessons learned are tied to real repo evidence rather than generic theory.
- The guide contains explicit fallback wording for optional or environment-dependent parts such as OpenAI-backed answer generation.
</success_criteria>

<output>
After completion, create `.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-SUMMARY.md`
</output>
