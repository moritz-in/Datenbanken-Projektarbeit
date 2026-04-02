---
phase: 00-foundation-blockers
plan: "04"
subsystem: validation-route
tags: [flask, sqlalchemy, mysql, validation, requirements]
dependency_graph:
  requires: [00-01, 00-02, 00-03]
  provides: [working-validate-route, mysql-engine-exposed]
  affects: [routes/validate.py, db.py, app.py]
tech_stack:
  added: []
  patterns: [module-level-engine-singleton, graceful-degradation-with-flash]
key_files:
  created: []
  modified:
    - db.py
    - app.py
    - routes/validate.py
    - .planning/REQUIREMENTS.md
decisions:
  - "Use simple mysql_engine = None module-level variable in db.py rather than returning tuple from make_session()"
  - "Inline create_engine() in create_app() rather than calling db.make_session() to avoid double-engine creation"
  - "Graceful None check in /validate route — redirect with flash error instead of crashing when engine not ready"
metrics:
  duration: "1 minute"
  completed: "2026-04-02"
  tasks_completed: 2
  files_modified: 4
---

# Phase 0 Plan 04: Close Validation Route & REQUIREMENTS.md Gap — Summary

**One-liner:** Wired `mysql_engine` singleton through `db.py`/`app.py` and replaced `/validate` stub with working `validate_mysql()` call + corrected stale REQUIREMENTS.md column specs.

---

## What Was Built

Two targeted gap-closure changes to satisfy the remaining Phase 0 verifier failures:

1. **`db.mysql_engine` exposure** — Added `mysql_engine = None` module-level variable to `db.py`. In `app.py`'s `create_app()`, replaced the indirect `db.make_session()` call with an explicit `create_engine()` that stores the engine in `db.mysql_engine` before building the `sessionmaker`. Both objects are set from the same engine instance — no duplicate connection pools.

2. **`/validate` route implementation** — Replaced the `raise NotImplementedError` stub in `routes/validate.py` with a handler that checks `db.mysql_engine`, handles the `None` case gracefully (flash error + redirect to dashboard), calls `validation.validate_mysql(db.mysql_engine)`, and renders `validation_result.html` with the returned `ValidationReport`.

3. **REQUIREMENTS.md corrections** — Updated FOUND-02 column spec from the stale design (`run_at, products_indexed, duration_seconds`) to the implemented schema (`strategy, started_at, finished_at, products_processed, products_written, status, error_msg`). Updated FOUND-03 from a wide denormalized spec to the EAV-style implemented schema (`field_name, old_value, new_value, changed_by`). Marked FOUND-01 through FOUND-08 as Complete in both checkboxes and traceability table.

---

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Expose mysql_engine in db.py and wire in app.py | f0fda31 | db.py, app.py |
| 2 | Implement /validate route + update REQUIREMENTS.md | 5e9fb73 | routes/validate.py, .planning/REQUIREMENTS.md |

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Success Criteria Verification

- [x] `routes/validate.py` calls `validate_mysql(db.mysql_engine)` and renders `validation_result.html`
- [x] `db.py` exposes `mysql_engine = None` at module level
- [x] `app.py` sets `db.mysql_engine = engine` during MySQL initialization
- [x] `REQUIREMENTS.md` FOUND-02 spec updated: `strategy, started_at, finished_at, products_processed, products_written, status, error_msg`
- [x] `REQUIREMENTS.md` FOUND-03 spec updated: `field_name, old_value, new_value, changed_by`
- [x] All Phase 0 FOUND-01–08 requirements marked Complete in traceability table

---

## Key Decisions Made

| Decision | Rationale |
|----------|-----------|
| Simple `mysql_engine = None` module variable | Cleanest approach — no need for tuple return from `make_session()` |
| Inline `create_engine()` in `create_app()` | Avoids double engine creation that `db.make_session()` would cause |
| Flash + redirect on None engine | Graceful degradation — user sees error, app doesn't crash with 500 |

## Self-Check: PASSED
