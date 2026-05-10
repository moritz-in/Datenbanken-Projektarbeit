---
phase: quick-2-pruefe-und-behebe-gemeldete-abgabeproble
plan: 2
type: execute
wave: 1
depends_on: []
files_modified:
  - schema.sql
  - mysql-init/01-schema.sql
  - import.sql
  - verify_database.sql
  - README.md
  - ER-Diagramm.md
autonomous: true
requirements:
  - FOUND-01
  - FOUND-02
  - FOUND-03
  - FOUND-04
  - TRIG-03
  - PROC-03
  - IDX-04
  - DOC-02
must_haves:
  truths:
    - "A grader can execute the standalone SQL artifacts without singular/plural table mismatches or half-imported product data."
    - "README setup instructions match the actual repository files, commands, and exposed service ports."
    - "The ER diagram describes the same relational structure that `schema.sql` creates, instead of an outdated starter-schema variant."
  artifacts:
    - path: "schema.sql"
      provides: "Standalone DDL for the submitted MySQL schema"
      min_lines: 250
      contains: "CREATE TABLE product_tags"
    - path: "mysql-init/01-schema.sql"
      provides: "Docker init DDL kept in sync with the submitted schema"
      min_lines: 250
      contains: "CREATE TABLE product_change_log"
    - path: "import.sql"
      provides: "Complete CSV import workflow for all required seed data"
      min_lines: 80
      contains: "products_500_new.csv"
    - path: "verify_database.sql"
      provides: "Post-import verification against the pluralized runtime schema"
      min_lines: 200
      contains: "FROM products"
    - path: "README.md"
      provides: "Submission-facing setup and artifact guidance"
      min_lines: 100
      contains: "ER-Diagramm.md"
    - path: "ER-Diagramm.md"
      provides: "Schema-aligned ER documentation for the delivered database model"
      min_lines: 120
      contains: "product_tags"
  key_links:
    - from: "README.md"
      to: "schema.sql, import.sql, verify_database.sql"
      via: "literal setup commands and file references"
      pattern: "schema\.sql|import\.sql|verify_database\.sql"
    - from: "verify_database.sql"
      to: "schema.sql"
      via: "table names and integrity checks against created tables"
      pattern: "FROM products|FROM brands|FROM categories|FROM tags|FROM product_tags"
    - from: "ER-Diagramm.md"
      to: "schema.sql"
      via: "matching entity/table names and relationships"
      pattern: "products|brands|categories|tags|product_tags"
---

<objective>
Prüfe die abgaberelevanten SQL- und Doku-Artefakte auf Widersprüche und behebe die gemeldeten Formfehler so, dass Schema, Import, Verifikation, README und ER-Diagramm als konsistentes Paket abgegeben werden können.

Purpose: Die Abgabe scheitert schnell an inkonsistenten Dateinamen, alten Tabellennamen, falschen Importpfaden oder toten README-Verweisen — diese Schnellkorrektur macht die Artefakte formell vollständig und nachvollziehbar.
Output: Konsistente SQL-Artefakte (`schema.sql`, `mysql-init/01-schema.sql`, `import.sql`, `verify_database.sql`) plus abgestimmte Doku in `README.md` und `ER-Diagramm.md`.
</objective>

<execution_context>
@$HOME/.config/opencode/get-shit-done/workflows/execute-plan.md
@$HOME/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@README.md
@schema.sql
@import.sql
@verify_database.sql
@mysql-init/01-schema.sql
@mysql-init/02-triggers.sql
@mysql-init/03-procedures.sql
@ER-Diagramm.md
@docs/INDEX_ANALYSIS.md

No `AGENTS.md` found in project root.
No project skill directories found in `.OpenCode/skills/` or `.agents/skills/`.

Known inconsistencies already visible from the provided files:
- `verify_database.sql` still queries singular tables (`brand`, `product`, `product_tag`) although the live schema uses plural names.
- `import.sql` documents `--local-infile` but currently uses `LOAD DATA INFILE`, imports only `products_extended.csv`, and leaves `products_500_new.csv` commented out.
- `README.md` still contains starter-text, links to missing `DATABASE_IMPORT.md`, and lists Neo4j on the wrong port.
- `ER-Diagramm.md` documents an outdated four-file/singular-table model that does not match `schema.sql`.
- `schema.sql` and `mysql-init/01-schema.sql` must stay synchronized for standalone import and Docker init behavior.
</context>

<tasks>

<task type="auto">
  <name>task 1: reconcile schema and verification SQL around the pluralized runtime model</name>
  <files>schema.sql, mysql-init/01-schema.sql, verify_database.sql</files>
  <action>Audit the standalone schema, Docker init schema, and verification script as one unit. Keep `schema.sql` and `mysql-init/01-schema.sql` semantically identical for all submission-relevant DDL, then rewrite `verify_database.sql` so it validates the real pluralized tables (`brands`, `categories`, `tags`, `products`, `product_tags`) and the current supporting artifacts instead of the obsolete starter schema. Preserve the existing trigger/procedure compatibility from `mysql-init/02-triggers.sql` and `mysql-init/03-procedures.sql`; do not rename tables or constraints away from the runtime model already used by the app.</action>
  <verify>
    <automated>python3 - &lt;&lt;'PY'
from pathlib import Path
schema = Path('schema.sql').read_text()
init_schema = Path('mysql-init/01-schema.sql').read_text()
verify = Path('verify_database.sql').read_text()
assert schema == init_schema, 'schema.sql and mysql-init/01-schema.sql must stay identical'
for needle in ['FROM products', 'FROM brands', 'FROM categories', 'FROM tags', 'FROM product_tags']:
    assert needle in verify, f'missing plural verification target: {needle}'
for banned in ['FROM product\n', 'FROM brand\n', 'FROM category\n', 'FROM tag\n', 'FROM product_tag\n']:
    assert banned not in verify, f'obsolete singular table reference remains: {banned!r}'
PY</automated>
  </verify>
  <done>`verify_database.sql` checks the real schema, and both schema entry points remain synchronized for submission and Docker init use.</done>
</task>

<task type="auto">
  <name>task 2: make the import workflow complete and executable from the repository</name>
  <files>import.sql, README.md</files>
  <action>Fix `import.sql` so the documented import path actually works for the intended submission workflow: use the correct LOCAL INFILE mode, import the full seed dataset (including both product CSV batches and the junction data), and make the transaction comments match the real executed statements. Then update `README.md` so the setup section explains the exact prerequisites, database-selection/creation expectation, correct command flags, actual file locations in this repository, existing supporting documents only, and the real exposed service ports from `docker-compose.yml`. Remove or replace stale starter-scaffold wording instead of layering new instructions on top of it.</action>
  <verify>
    <automated>python3 - &lt;&lt;'PY'
from pathlib import Path
imp = Path('import.sql').read_text()
readme = Path('README.md').read_text()
for needle in ['LOAD DATA LOCAL INFILE', 'brands.csv', 'categories.csv', 'tags.csv', 'products_extended.csv', 'products_500_new.csv', 'product_tags.csv']:
    assert needle in imp, f'import.sql missing required import entry: {needle}'
assert 'DATABASE_IMPORT.md' not in readme, 'README must not reference missing DATABASE_IMPORT.md'
assert 'http://localhost:7484' in readme, 'README must list the actual Neo4j HTTP port'
for needle in ['schema.sql', 'import.sql', 'verify_database.sql', '--local-infile=1']:
    assert needle in readme, f'README missing setup reference: {needle}'
PY</automated>
  </verify>
  <done>The import script can load the full dataset as documented, and README setup instructions align with the current repository instead of the old scaffold.</done>
</task>

<task type="auto">
  <name>task 3: align the ER diagram with the submitted relational artifacts</name>
  <files>ER-Diagramm.md, README.md</files>
  <action>Rewrite `ER-Diagramm.md` so it reflects the delivered relational model rather than the old singular-table teaching example. Update Mermaid entities, relationship descriptions, file/data references, and integrity notes to match the current schema and import files. Include the explicit `product_tags` junction table and either document the operational tables (`product_change_log`, `etl_run_log`) directly or clearly scope them as auxiliary tables outside the core product ER view; avoid ambiguous half-documentation. Keep `README.md` references aligned with the final ER artifact wording.</action>
  <verify>
    <automated>python3 - &lt;&lt;'PY'
from pathlib import Path
er = Path('ER-Diagramm.md').read_text()
for needle in ['products', 'brands', 'categories', 'tags', 'product_tags']:
    assert needle in er, f'ER-Diagramm missing schema artifact: {needle}'
for banned in ['brand.csv', 'category.csv', 'tag.csv', 'product.csv', '4 CSV-Dateien']:
    assert banned not in er, f'ER-Diagramm still contains outdated artifact reference: {banned}'
assert 'ER-Diagramm.md' in Path('README.md').read_text(), 'README must still point to the ER diagram'
PY</automated>
  </verify>
  <done>The ER documentation matches the shipped schema/import artifacts and no longer describes the obsolete starter model.</done>
</task>

</tasks>

<verification>
Run the three automated checks, then do a final consistency read across `README.md`, `schema.sql`, `import.sql`, `verify_database.sql`, and `ER-Diagramm.md` to confirm that the same table names, CSV files, commands, and ports appear everywhere.
</verification>

<success_criteria>
- `verify_database.sql` no longer uses singular starter-table names.
- `import.sql` imports all required CSV files for the full 1000-product dataset using the same workflow the README documents.
- `README.md` references only files that exist and lists the real service ports/commands.
- `ER-Diagramm.md` matches the delivered schema instead of the obsolete simplified model.
- `schema.sql` and `mysql-init/01-schema.sql` stay synchronized after the fixes.
</success_criteria>

<output>
After completion, create `.planning/quick/2-pruefe-und-behebe-gemeldete-abgabeproble/2-SUMMARY.md`
</output>
