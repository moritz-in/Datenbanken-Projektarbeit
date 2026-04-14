---
status: diagnosed
phase: 04-neo4j-graph-rag-a7
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md, 04-03-SUMMARY.md]
started: 2026-04-14T00:00:00Z
updated: 2026-04-14T09:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Cold Start Smoke Test
expected: Kill any running server/service. Clear ephemeral state (temp DBs, caches, lock files). Start the application from scratch (e.g., docker compose up --build). Server boots without errors, Neo4j driver initialises cleanly, and a primary request (health check, homepage load, or basic API call) returns a live response.
result: pass

### 2. NoOp Fallback Without NEO4J_URI
expected: With NEO4J_URI absent (or unset in .env), the application starts without errors. Index builds and other operations complete successfully — RepositoryFactory.get_neo4j_repository() returns a NoOpNeo4jRepository that silently returns 0/empty without crashing.
result: pass

### 3. GET /rag Renders Empty Form
expected: Opening http://localhost:8081/rag returns a 200 response with a search form showing an empty query field, no results, and no answer — just a clean form ready for input.
result: pass

### 4. POST /rag With Valid Query Returns RAG Results
expected: Submitting a product search query via POST /rag returns a page showing: a German-language LLM answer (or the fallback message "[LLM nicht konfiguriert — OPENAI_API_KEY fehlt]" if no OpenAI key is configured), plus a list of product results with title, brand, category, tags, price, and relevance score. No 501 or unhandled errors.
result: pass

### 5. POST /rag With Empty Query Shows Warning
expected: Submitting POST /rag with a blank/empty query shows a flash warning message (no results, no error traceback). The page stays on the search form.
result: pass

### 6. /graph-rag Redirects to /rag
expected: Visiting GET /graph-rag redirects to /rag. The final page loaded is the RAG search page — backward compatibility preserved.
result: pass

### 7. Index Build Returns neo4j_count
expected: Triggering an index build returns a response that includes a neo4j_count field showing how many products were synced to Neo4j alongside the Qdrant count.
result: issue
reported: "grep -i neo4j returned no output; log file shows: build_index: Neo4j sync failed (non-fatal): 'NoneType' object has no attribute 'session'"
severity: major

### 8. Index Build Non-Fatal on Neo4j Failure
expected: If Neo4j is unreachable during an index build, the build still completes and Qdrant is populated. A warning appears in the logs but the ETL does not abort.
result: pass

### 9. Graph-Enriched Hits Show Neo4j Badge
expected: After an index build with Neo4j running and populated, RAG search results show a visual badge or indicator (e.g. "Neo4j" label / graph_source badge) on hits that were enriched with graph data — category, tags, and related products are filled in from the graph.
result: pass

### 10. Docker Stop — Clean Neo4j Teardown
expected: Running docker compose stop app produces no connection timeout errors in the app logs. The teardown_appcontext hook fires and closes the Neo4j driver cleanly.
result: pass

## Summary

total: 10
passed: 9
issues: 1
pending: 0
skipped: 0

## Gaps

- truth: "Index build syncs products to Neo4j — neo4j_count > 0 in result"
  status: failed
  reason: "User reported: grep -i neo4j returned no output; log file shows: build_index: Neo4j sync failed (non-fatal): 'NoneType' object has no attribute 'session'"
  severity: major
  test: 7
  root_cause: "teardown_appcontext fires after every HTTP request (not just shutdown), calling close() which sets _driver=None. RepositoryFactory never recreates the broken singleton. Every subsequent sync_products call hits NoneType on self._driver.session()"
  artifacts:
    - path: "app.py"
      issue: "_close_neo4j registered with teardown_appcontext — fires per-request, destroys driver after every request"
    - path: "repositories/neo4j_repository.py"
      issue: "close() sets self._driver = None with no reconnect path — instance permanently broken after first call"
    - path: "repositories/__init__.py"
      issue: "Singleton cache never evicts or recreates the broken instance — dead instance returned forever"
  missing:
    - "Remove teardown_appcontext hook (or replace with atexit/shutdown signal) — Neo4j driver is a long-lived singleton, not per-request"
    - "Add lazy-reconnect guard in execute_cypher(): if self._driver is None, reconnect before proceeding"
  debug_session: ".planning/debug/neo4j-driver-null-after-teardown.md"
