---
phase: quick-3-kannst-du-mir-jetzt-erklaeren-was-alles-
plan: 3
subsystem: documentation
tags: [demo, presentation, mysql, qdrant, neo4j, rag, documentation]
requires:
  - phase: 05-polish-dokumentation
    provides: COMPARISON.md and final project evidence for the three search layers
provides:
  - a 15-minute live-demo guide with exact routes, proof points, talking tracks, and honest fallbacks
affects: [demo, grading, documentation]
tech-stack:
  added: []
  patterns: [repo-grounded demo scripting, evidence-first presentation mapping, honest fallback wording]
key-files:
  created: [.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md, .planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-SUMMARY.md]
  modified: [.planning/STATE.md]
key-decisions:
  - "Use `with session.begin()` as the single deep-dive design decision because it is directly visible in rollback behavior and documented project history."
  - "Treat OpenAI-backed prose generation as optional in the demo and use the implemented fallback string as the honest backup path."
patterns-established:
  - "Every presentation claim is tied to a route, file, command, or observable runtime behavior from this repository."
  - "Fallback wording distinguishes core demo guarantees from optional environment-dependent features."
requirements-completed: [TXN-04, TXN-05, ROUTE-01, ROUTE-02, ROUTE-03, VECT-07, VECT-08, GRAPH-07, DOC-01]
duration: 11min
completed: 2026-05-10
---

# Phase Quick 3 Plan 3: Live-Demo-Leitfaden Summary

**Repo-grounded 15-minute demo script with exact click paths, architecture talk track, and honest fallbacks for MySQL, Qdrant, Neo4j, and optional LLM output**

## Performance

- **Duration:** 11 min
- **Started:** 2026-05-10T11:49:38Z
- **Completed:** 2026-05-10T12:00:38Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Wrote a strict readiness checklist covering startup, ports, core routes, expected outcomes, and core-vs-fallback demo paths.
- Added a presenter-ready 15-minute walkthrough tied to the actual project architecture and one concrete design decision.
- Mapped each grading criterion to live proof, repo artifacts, and backup wording that remains honest under demo pressure.

## task Commits

Each task was committed atomically:

1. **task 1: write a repo-grounded readiness checklist for what must work live** - `8c4ebcb` (docs)
2. **task 2: write the 15-minute demo flow with architecture, one design decision, and lessons learned** - `02dc110` (docs)
3. **task 3: add a grading matrix that maps every presentation criterion to proof and fallback wording** - `a45b036` (docs)

**Plan metadata:** recorded in the final completion commit after summary/state updates.

## Files Created/Modified
- `.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-DEMO-GUIDE.md` - practical live-demo guide with timing, routes, talk track, and fallback wording
- `.planning/quick/3-kannst-du-mir-jetzt-erklaeren-was-alles-/3-SUMMARY.md` - execution summary for this quick task
- `.planning/STATE.md` - quick-task log and latest session context updated

## Decisions Made
- Used `with session.begin()` as the single design-decision deep dive because it connects directly to the visible rollback demos and existing repository evidence.
- Framed Neo4j + RAG as a context layer and kept OpenAI output explicitly optional so the live demo does not overclaim what depends on environment secrets.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `AGENTS.md` and project skill directories referenced in the prompt did not exist; execution followed the verified plan context instead.

## User Setup Required

None - no external service configuration was changed. The guide documents optional OpenAI setup only as a live-demo fallback consideration.

## Next Phase Readiness

- The repository now contains a practical presenter cheat sheet for a 15-minute grading-oriented demo.
- No roadmap updates were applied because this is a quick task outside the planned phase flow.

## Self-Check
PASSED

---
*Phase: quick-3-kannst-du-mir-jetzt-erklaeren-was-alles-*
*Completed: 2026-05-10*
