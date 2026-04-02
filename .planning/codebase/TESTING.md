# Testing Patterns

**Analysis Date:** 2026-04-02

## Test Framework

**Runner (Python):**
- `pytest` >= 7.4.0
- `pytest-mock` >= 3.11.0 (for mocking)
- `pytest-cov` >= 4.1.0 (for coverage)
- No `pytest.ini` or `pyproject.toml` config detected — pytest uses defaults
- Tests run via Docker (`Dockerfile` `test` stage): `RUN pytest -q`

**SQL Test Runner:**
- Shell-based snapshot test runner: `tests/run_tests.sh`
- Uses `mysql` CLI client directly — no Python test framework involved for SQL

**Run Commands:**
```bash
# Python unit tests (via Docker)
docker build --target test -t local/app:test .

# Python unit tests (locally, from project root)
pytest -q

# SQL snapshot tests (requires running MySQL)
DB_HOST=127.0.0.1 DB_PORT=3306 DB_USER=root DB_PASS=rootpw DB_NAME=testdb ./tests/run_tests.sh

# SQL record mode (regenerate expected CSVs)
RECORD=1 ./tests/run_tests.sh

# Python tests with coverage
pytest --cov=. -q
```

## Test File Organization

**Python Tests:**
- No `test_*.py` files currently exist in the codebase — all Python test infrastructure is set up but no test files have been written yet
- `pytest` would auto-discover any `test_*.py` or `*_test.py` files placed in `tests/` or project root
- Intended location: `tests/` directory (based on `tests/run_tests.sh`, `tests/fixtures/`, `tests/expected/`)

**SQL Snapshot Tests:**
- SQL queries to test: `src/sql/*.sql` (one `.sql` file = one test case)
- Seed data: `tests/fixtures/seed.sql`
- Expected outputs: `tests/expected/<name>.csv` (tab-separated, one per `.sql` file)
- Actual outputs (generated): `tests/out/<name>.csv` (gitignored)
- Naming: `src/sql/foo.sql` → expected at `tests/expected/foo.csv`

**Structure:**
```
tests/
├── fixtures/
│   └── seed.sql              # MySQL seed data for all SQL tests
├── expected/
│   └── foo.csv               # Expected output for src/sql/foo.sql
├── out/                      # Generated (gitignored), actual query outputs
│   └── *.csv
└── run_tests.sh              # SQL test runner

src/sql/
└── foo.sql                   # Student-written SQL SELECT queries under test
```

## SQL Snapshot Test Pattern

**How it works:**
1. `tests/fixtures/seed.sql` seeds the database (DROP + CREATE + INSERT for a minimal dataset)
2. Each `src/sql/*.sql` file is executed against the seeded database
3. Output is captured as a tab-separated CSV (no headers, via `--batch --skip-column-names`)
4. Output is normalized: CRLF stripped, trailing whitespace stripped
5. Compared via `diff -u` against `tests/expected/<name>.csv`

**Seed Data:**
```sql
-- tests/fixtures/seed.sql
DROP TABLE IF EXISTS products;
CREATE TABLE products (
  id INT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  category VARCHAR(50) NOT NULL
);
INSERT INTO products (id, name, price, category) VALUES
  (1, 'Widget A', 10.00, 'tools'),
  (2, 'Widget B', 12.50, 'tools'),
  (3, 'Cable X',  5.90,  'cables'),
  ...
```

**Expected CSV Format (tab-separated, no header):**
```
1	Widget A	10.00
2	Widget B	12.50
```

**Safety Guard:**
- The runner rejects any `.sql` file containing DML/DDL keywords (INSERT, UPDATE, DELETE, CREATE, ALTER, DROP)
- Only pure SELECT queries are allowed in `src/sql/`

## SQL Test Record Mode

To update expected outputs after intentional query changes:
```bash
RECORD=1 ./tests/run_tests.sh
```
This overwrites `tests/expected/*.csv` with current query outputs. The bootstrap workflow (`.github/workflows/sql-bootstrap-expected.yml`) automates this via `workflow_dispatch` and creates a PR with updated expected files.

## CI Integration

**GitHub Actions Workflows:**

| Workflow | File | Trigger | What it tests |
|----------|------|---------|---------------|
| SQL CI | `.github/workflows/sql-ci.yml` | push, PR | SQL snapshot tests via `run_tests.sh` |
| SQL Bootstrap | `.github/workflows/sql-bootstrap-expected.yml` | manual dispatch | Regenerates expected CSVs, creates PR |
| CI (Docker) | `.github/workflows/ci.yml` | push to main, PR | Docker build + `pytest -q` |
| SQL Script | `.github/workflows/sql-test.yml` | push/PR to main | Runs lecture SQL file, validates table exists |

**SQL CI pipeline:**
```yaml
# .github/workflows/sql-ci.yml
- mysql:8 service container on port 3306
- runs: ./tests/run_tests.sh
- on failure: uploads tests/out/*.csv as artifact
```

**Python CI pipeline:**
```yaml
# .github/workflows/ci.yml
- Docker build targeting 'test' stage
- 'test' stage runs: RUN pytest -q
```

## Python Mocking

**Framework:** `pytest-mock` (provides `mocker` fixture)

**Intended Patterns (based on architecture):**
- Factory classes (`RepositoryFactory`, `ServiceFactory`) have `reset()` methods explicitly documented for test isolation
- Dependency injection via `__init__` constructors on all services and repositories — pass mock objects directly
- Example of intended injection pattern:

```python
# Inject mock repos directly via constructor
def test_product_service_list(mocker):
    mock_mysql = mocker.Mock(spec=MySQLRepository)
    mock_qdrant = mocker.Mock(spec=QdrantRepository)
    mock_mysql.get_products_with_joins.return_value = {"items": [], "total": 0}

    service = ProductService(mysql_repo=mock_mysql, qdrant_repo=mock_qdrant)
    result = service.list_products_joined(page=1, page_size=20)

    mock_mysql.get_products_with_joins.assert_called_once_with(1, 20)
```

**What to Mock:**
- All database calls (`MySQLRepository`, `QdrantRepository`, `Neo4jRepository`)
- External API calls (`OpenAI` client, `SentenceTransformer.encode`)
- Flask `current_app` when testing services outside request context

**What NOT to Mock:**
- `validation.py` `validate_mysql()` — should be tested against a real (seeded) MySQL instance
- Pure utility functions in `utils.py` — test directly without mocking

## Fixtures and Factories

**SQL Test Seed (for SQL tests):**
- Location: `tests/fixtures/seed.sql`
- Format: DDL + DML to create minimal test schema

**Python Test Fixtures (intended pattern):**
```python
# Place in tests/conftest.py
import pytest
from unittest.mock import MagicMock
from repositories import MySQLRepository, QdrantRepository

@pytest.fixture
def mock_mysql_repo():
    return MagicMock(spec=MySQLRepository)

@pytest.fixture
def mock_qdrant_repo():
    return MagicMock(spec=QdrantRepository)

@pytest.fixture
def product_service(mock_mysql_repo, mock_qdrant_repo):
    from services.product_service import ProductService
    return ProductService(mysql_repo=mock_mysql_repo, qdrant_repo=mock_qdrant_repo)
```

## Coverage

**Requirements:** Not enforced (no coverage thresholds in config)

**View Coverage:**
```bash
pytest --cov=. --cov-report=html -q
# Open htmlcov/index.html
```

## Test Types

**SQL Snapshot Tests:**
- Scope: Each `src/sql/*.sql` file is one end-to-end test against a seeded MySQL DB
- Tests the exact query output (column order, value format, row order)
- Infrastructure: shell + MySQL CLI
- Location: `tests/run_tests.sh` + `tests/fixtures/` + `tests/expected/`

**Python Unit Tests:**
- Scope: Individual service and repository method behavior
- Framework: `pytest` + `pytest-mock`
- Infrastructure: Docker (`test` stage in `Dockerfile`)
- Location: `tests/` directory (no test files exist yet — only scaffold)
- No pytest config file; all defaults apply

**Integration Tests:** Not present — no integration test infrastructure beyond Docker-based `pytest -q`

**E2E Tests:** Not used

## Adding New SQL Tests

1. Create `src/sql/<test_name>.sql` with a pure SELECT query
2. Run `RECORD=1 ./tests/run_tests.sh` to generate `tests/expected/<test_name>.csv`
3. Commit both files
4. CI will validate on every push/PR

## Adding New Python Tests

1. Create `tests/test_<module>.py`
2. Use `pytest` conventions (`test_` prefix for functions, `Test` prefix for classes)
3. Use `mocker` fixture (from `pytest-mock`) or `unittest.mock.MagicMock(spec=...)` for mocking
4. Reset factories in teardown if testing factory methods: call `RepositoryFactory.reset()` / `ServiceFactory.reset()`

---

*Testing analysis: 2026-04-02*
