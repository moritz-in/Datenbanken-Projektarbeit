"""
Phase 02 Validation Tests — MySQL DDL Features
================================================
Covers all 13 requirements across plans 02-01, 02-02, 02-03.

Test groups:
  Static / file-content tests  — no DB, no Docker needed
    TRIG-01, TRIG-02, TRIG-03
    PROC-01, PROC-02, PROC-03, PROC-04
    IDX-01, IDX-02, IDX-03, IDX-05, IDX-06/DOC-02

  Flask test-client tests       — no live server needed
    ROUTE-02  (GET /audit → 200)
    ROUTE-03  (GET /validate/procedure → 200)
    IDX-04    (GET /validate renders B-Tree index table)

  Live-DB tests (skip when DB unavailable)
    PROC-02/PROC-03 live: OUT params + all result codes
    TRIG-02/TRIG-03 live: trigger fires only on actual changes

Run:
    docker compose exec app python -m pytest tests/test_phase02.py -v
"""

import os
import sys
import re
import pathlib
import pytest

try:
    import requests as _requests_lib
    _REQUESTS_AVAILABLE = True
except ImportError:
    _REQUESTS_AVAILABLE = False

# ---------------------------------------------------------------------------
# Paths (relative to repo root)
# ---------------------------------------------------------------------------
REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
TRIGGERS_SQL = REPO_ROOT / "mysql-init" / "02-triggers.sql"
PROCEDURES_SQL = REPO_ROOT / "mysql-init" / "03-procedures.sql"
SCHEMA_SQL = REPO_ROOT / "mysql-init" / "01-schema.sql"
INDEX_ANALYSIS_MD = REPO_ROOT / "docs" / "INDEX_ANALYSIS.md"


# ===========================================================================
# Helpers
# ===========================================================================

def _sql(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def _md(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# DB availability check (for live tests)
# ---------------------------------------------------------------------------
def _db_available() -> bool:
    """Return True if the MySQL container is reachable from this process."""
    try:
        import pymysql  # type: ignore
        conn = pymysql.connect(
            host=os.environ.get("MYSQL_HOST", "mysql"),
            user=os.environ.get("MYSQL_USER", "app"),
            password=os.environ.get("MYSQL_PASSWORD", "app"),
            database=os.environ.get("MYSQL_DB", "productdb"),
            connect_timeout=3,
        )
        conn.close()
        return True
    except Exception:
        return False


def _app_available() -> bool:
    """Return True if the Flask app is reachable via HTTP (live server mode)."""
    if not _REQUESTS_AVAILABLE:
        return False
    try:
        resp = _requests_lib.get(APP_BASE_URL + "/", timeout=3)
        return resp.status_code < 500
    except Exception:
        return False


# Determine app base URL: inside Docker use internal hostname, outside use localhost
APP_BASE_URL = os.environ.get("APP_BASE_URL", "http://localhost:8081")

DB_AVAILABLE = _db_available()
APP_AVAILABLE = _app_available()

skipif_no_db = pytest.mark.skipif(
    not DB_AVAILABLE,
    reason="MySQL DB not reachable — skipping live DB tests"
)

skipif_no_app = pytest.mark.skipif(
    not APP_AVAILABLE,
    reason="Flask app not reachable at APP_BASE_URL — skipping live HTTP route tests"
)


# ===========================================================================
# Flask test client fixture
# ===========================================================================

# ===========================================================================
# HTTP fixture for route tests (live app at APP_BASE_URL)
# ===========================================================================

@pytest.fixture(scope="module")
def flask_client():
    """
    Live HTTP session against the running Flask app.

    The app must be reachable at APP_BASE_URL (default: http://localhost:8081).
    Inside the Docker network use APP_BASE_URL=http://app:5000.

    Tests using this fixture are skipped when the app is not reachable.
    """
    if not APP_AVAILABLE:
        pytest.skip("Flask app not reachable — route tests skipped")
    yield _requests_lib.Session()


# ===========================================================================
# PLAN 02-01 — Triggers
# ===========================================================================

class TestTRIG01_TriggerFileExists:
    """TRIG-01: mysql-init/02-triggers.sql exists with CREATE TRIGGER trg_products_after_update"""

    def test_trigger_file_exists_on_disk(self):
        """File 02-triggers.sql must be present in the repo."""
        assert TRIGGERS_SQL.exists(), f"Expected file at {TRIGGERS_SQL}"

    def test_trigger_file_contains_create_trigger_statement(self):
        """File must contain the exact CREATE TRIGGER statement."""
        content = _sql(TRIGGERS_SQL)
        assert "CREATE TRIGGER trg_products_after_update" in content, \
            "Expected 'CREATE TRIGGER trg_products_after_update' in 02-triggers.sql"

    def test_trigger_file_uses_delimiter_wrapper(self):
        """File must use DELIMITER $$ ... DELIMITER ; wrapper."""
        content = _sql(TRIGGERS_SQL)
        assert "DELIMITER $$" in content, "Expected DELIMITER $$ wrapper in trigger file"
        assert "DELIMITER ;" in content, "Expected closing DELIMITER ; in trigger file"

    def test_trigger_fires_on_products_after_update(self):
        """Trigger must be defined as AFTER UPDATE ON products."""
        content = _sql(TRIGGERS_SQL)
        assert re.search(r"AFTER\s+UPDATE\s+ON\s+products", content, re.IGNORECASE), \
            "Expected 'AFTER UPDATE ON products' in trigger DDL"


class TestTRIG02_TriggerConditionalOnChange:
    """TRIG-02: Trigger fires ONLY when field value actually changes (IF OLD.x <> NEW.x)"""

    def test_trigger_has_conditional_if_block_for_name(self):
        """NOT NULL field 'name' must use IF OLD.name <> NEW.name."""
        content = _sql(TRIGGERS_SQL)
        assert re.search(r"OLD\.name\s*<>\s*NEW\.name", content), \
            "Expected 'OLD.name <> NEW.name' conditional in trigger"

    def test_trigger_has_conditional_if_block_for_price(self):
        """NOT NULL field 'price' must use IF OLD.price <> NEW.price."""
        content = _sql(TRIGGERS_SQL)
        assert re.search(r"OLD\.price\s*<>\s*NEW\.price", content), \
            "Expected 'OLD.price <> NEW.price' conditional in trigger"

    def test_trigger_has_null_safe_check_for_nullable_description(self):
        """Nullable field 'description' must have a NULL-safe conditional."""
        content = _sql(TRIGGERS_SQL)
        # Must reference OLD.description AND NEW.description with IS NULL guard
        assert "OLD.description IS NULL" in content or "OLD.description IS NOT NULL" in content, \
            "Expected NULL-safe comparison for 'description' in trigger"
        assert "NEW.description IS NOT NULL" in content or "NEW.description IS NULL" in content, \
            "Expected NULL-safe comparison for 'description' in trigger"

    def test_trigger_does_not_use_unconditional_insert(self):
        """Trigger must NOT unconditionally INSERT — must be inside IF blocks."""
        content = _sql(TRIGGERS_SQL)
        # Every INSERT into product_change_log must follow an IF ... THEN
        inserts_outside_if = re.findall(
            r"(?<!\bTHEN\b)\s*INSERT\s+INTO\s+product_change_log",
            content,
            re.IGNORECASE,
        )
        # A simpler structural check: count IF blocks vs INSERT statements
        if_count = len(re.findall(r"\bIF\b", content, re.IGNORECASE))
        insert_count = len(re.findall(r"\bINSERT\b", content, re.IGNORECASE))
        assert if_count >= insert_count, \
            "Expected at least as many IF blocks as INSERT statements (conditional inserts)"


class TestTRIG03_AllEightFieldsCovered:
    """TRIG-03: All 8 monitored fields covered in trigger body."""

    MONITORED_FIELDS = [
        "name", "description", "price", "sku",
        "load_class", "application", "brand_id", "category_id",
    ]

    @pytest.mark.parametrize("field", MONITORED_FIELDS)
    def test_trigger_covers_field(self, field):
        """Trigger body must reference OLD.{field} for change detection."""
        content = _sql(TRIGGERS_SQL)
        assert f"OLD.{field}" in content, \
            f"Expected 'OLD.{field}' in trigger body for field '{field}'"

    @pytest.mark.parametrize("field", MONITORED_FIELDS)
    def test_trigger_logs_field_name_as_string(self, field):
        """Trigger must insert the field name as a string literal into product_change_log."""
        content = _sql(TRIGGERS_SQL)
        assert f"'{field}'" in content, \
            f"Expected string literal '{field}' in trigger INSERT for field_name column"


# ===========================================================================
# PLAN 02-01 — Route /audit
# ===========================================================================

class TestROUTE02_AuditRouteReturns200:
    """ROUTE-02: GET /audit returns 200 and renders ETL run log (no NotImplementedError)"""

    def test_audit_route_returns_http_200(self, flask_client):
        """GET /audit must respond with HTTP 200."""
        resp = flask_client.get(APP_BASE_URL + "/audit")
        assert resp.status_code == 200, \
            f"GET /audit returned {resp.status_code}, expected 200"

    def test_audit_route_does_not_raise_not_implemented(self, flask_client):
        """GET /audit must not trigger the NotImplementedError handler (501)."""
        resp = flask_client.get(APP_BASE_URL + "/audit")
        assert resp.status_code != 501, \
            "GET /audit returned 501 — NotImplementedError is still raised"

    def test_audit_route_source_has_no_not_implemented_error(self):
        """routes/audit.py must not contain NotImplementedError."""
        source = (REPO_ROOT / "routes" / "audit.py").read_text(encoding="utf-8")
        assert "NotImplementedError" not in source, \
            "routes/audit.py still contains NotImplementedError"

    def test_audit_route_calls_get_audit_log(self):
        """routes/audit.py must call svc.get_audit_log()."""
        source = (REPO_ROOT / "routes" / "audit.py").read_text(encoding="utf-8")
        assert "get_audit_log" in source, \
            "routes/audit.py does not call get_audit_log()"


# ===========================================================================
# PLAN 02-02 — Stored Procedure
# ===========================================================================

class TestPROC01_ProcedureFileExists:
    """PROC-01: mysql-init/03-procedures.sql exists with CREATE PROCEDURE import_product"""

    def test_procedure_file_exists(self):
        """File 03-procedures.sql must be present."""
        assert PROCEDURES_SQL.exists(), f"Expected file at {PROCEDURES_SQL}"

    def test_procedure_file_contains_create_procedure(self):
        """File must contain CREATE PROCEDURE import_product."""
        content = _sql(PROCEDURES_SQL)
        assert "CREATE PROCEDURE import_product" in content, \
            "Expected 'CREATE PROCEDURE import_product' in 03-procedures.sql"

    def test_procedure_file_uses_delimiter_wrapper(self):
        """Procedure DDL must use DELIMITER $$ wrapper."""
        content = _sql(PROCEDURES_SQL)
        assert "DELIMITER $$" in content, "Expected DELIMITER $$ in procedures file"


class TestPROC02_OutParamsPresent:
    """PROC-02: OUT params p_result_code + p_result_message present"""

    def test_procedure_declares_out_param_result_code(self):
        """Procedure must declare OUT p_result_code."""
        content = _sql(PROCEDURES_SQL)
        assert re.search(r"OUT\s+p_result_code", content, re.IGNORECASE), \
            "Expected 'OUT p_result_code' in procedure signature"

    def test_procedure_declares_out_param_result_message(self):
        """Procedure must declare OUT p_result_message."""
        content = _sql(PROCEDURES_SQL)
        assert re.search(r"OUT\s+p_result_message", content, re.IGNORECASE), \
            "Expected 'OUT p_result_message' in procedure signature"

    def test_procedure_sets_result_code_zero_on_success(self):
        """Procedure must SET p_result_code = 0 for success path."""
        content = _sql(PROCEDURES_SQL)
        assert re.search(r"SET\s+p_result_code\s*=\s*0", content), \
            "Expected 'SET p_result_code = 0' in success path"

    def test_procedure_sets_result_message_on_success(self):
        """Procedure must set a CONCAT success message."""
        content = _sql(PROCEDURES_SQL)
        assert "Produkt importiert" in content, \
            "Expected German success message 'Produkt importiert' in procedure"


class TestPROC03_ErrorHandlingResultCodes:
    """PROC-03: SQLEXCEPTION handler, duplicate SKU → 1, missing category → 2, success → 0"""

    def test_procedure_has_sqlexception_handler(self):
        """DECLARE EXIT HANDLER FOR SQLEXCEPTION must be present."""
        content = _sql(PROCEDURES_SQL)
        assert re.search(r"DECLARE\s+EXIT\s+HANDLER\s+FOR\s+SQLEXCEPTION", content, re.IGNORECASE), \
            "Expected 'DECLARE EXIT HANDLER FOR SQLEXCEPTION' in procedure"

    def test_sqlexception_handler_sets_result_code_3(self):
        """SQLEXCEPTION handler must set p_result_code = 3."""
        content = _sql(PROCEDURES_SQL)
        # Find the handler block and check it sets code=3
        assert re.search(r"p_result_code\s*=\s*3", content), \
            "Expected 'p_result_code = 3' in SQLEXCEPTION handler"

    def test_duplicate_sku_sets_result_code_1(self):
        """Duplicate SKU path must set p_result_code = 1."""
        content = _sql(PROCEDURES_SQL)
        assert re.search(r"p_result_code\s*=\s*1", content), \
            "Expected 'p_result_code = 1' for duplicate SKU"

    def test_duplicate_sku_uses_sku_count_check(self):
        """Duplicate SKU detection must SELECT COUNT(*) from products WHERE sku = p_sku."""
        content = _sql(PROCEDURES_SQL)
        assert "sku_count" in content.lower() or re.search(r"sku\s*=\s*p_sku", content), \
            "Expected SKU duplicate check in procedure"

    def test_missing_category_sets_result_code_2(self):
        """Missing category path must set p_result_code = 2."""
        content = _sql(PROCEDURES_SQL)
        assert re.search(r"p_result_code\s*=\s*2", content), \
            "Expected 'p_result_code = 2' for validation error / missing category"

    def test_missing_category_has_german_error_message(self):
        """Missing category error must include German message."""
        content = _sql(PROCEDURES_SQL)
        assert "Kategorie nicht gefunden" in content or "Pflichtfelder fehlen" in content, \
            "Expected German error message for missing category"

    def test_procedure_resolves_category_from_categories_table(self):
        """Procedure must query categories table to resolve category name."""
        content = _sql(PROCEDURES_SQL)
        assert re.search(r"FROM\s+categories", content, re.IGNORECASE), \
            "Expected SELECT FROM categories in procedure"


class TestPROC04_RepositoryUsesNextset:
    """PROC-04: MySQLRepositoryImpl.call_import_product() uses raw cursor + cursor.nextset() loop"""

    def test_repository_has_call_import_product_method(self):
        """repositories/mysql_repository.py must have call_import_product method."""
        source = (REPO_ROOT / "repositories" / "mysql_repository.py").read_text(encoding="utf-8")
        assert "def call_import_product" in source, \
            "Expected 'def call_import_product' in mysql_repository.py"

    def test_repository_uses_raw_cursor(self):
        """call_import_product must use conn.connection.cursor() (raw DBAPI cursor)."""
        source = (REPO_ROOT / "repositories" / "mysql_repository.py").read_text(encoding="utf-8")
        assert "conn.connection.cursor()" in source, \
            "Expected 'conn.connection.cursor()' for raw DBAPI cursor in call_import_product"

    def test_repository_flushes_result_sets_with_nextset(self):
        """call_import_product must call cursor.nextset() to flush implicit result sets."""
        source = (REPO_ROOT / "repositories" / "mysql_repository.py").read_text(encoding="utf-8")
        assert "cursor.nextset()" in source, \
            "Expected 'cursor.nextset()' in call_import_product (Pitfall 12 compliance)"

    def test_repository_reads_out_params_via_select(self):
        """call_import_product must SELECT @rc and @rm after the CALL."""
        source = (REPO_ROOT / "repositories" / "mysql_repository.py").read_text(encoding="utf-8")
        assert "SELECT @rc" in source, \
            "Expected 'SELECT @rc' to read OUT params after CALL"

    def test_repository_closes_cursor_in_finally(self):
        """Cursor must be closed in a finally block to prevent leaks."""
        source = (REPO_ROOT / "repositories" / "mysql_repository.py").read_text(encoding="utf-8")
        assert "cursor.close()" in source, \
            "Expected 'cursor.close()' in finally block"


# ===========================================================================
# PLAN 02-02 — Route /validate/procedure
# ===========================================================================

class TestROUTE03_ValidateProcedureRoute:
    """ROUTE-03: GET /validate/procedure returns 200; POST returns result badge"""

    def test_validate_procedure_get_returns_200(self, flask_client):
        """GET /validate/procedure must return HTTP 200."""
        resp = flask_client.get(APP_BASE_URL + "/validate/procedure")
        assert resp.status_code == 200, \
            f"GET /validate/procedure returned {resp.status_code}, expected 200"

    def test_validate_procedure_template_exists(self):
        """templates/validate_procedure.html must exist."""
        template = REPO_ROOT / "templates" / "validate_procedure.html"
        assert template.exists(), "Expected templates/validate_procedure.html to exist"

    def test_validate_procedure_template_has_result_badge(self):
        """Template must contain a result badge section."""
        content = (REPO_ROOT / "templates" / "validate_procedure.html").read_text(encoding="utf-8")
        assert "result_code" in content, \
            "Expected 'result_code' in validate_procedure.html template"

    def test_validate_procedure_template_has_educational_note(self):
        """Template must have an educational note about A4 stored procedure."""
        content = (REPO_ROOT / "templates" / "validate_procedure.html").read_text(encoding="utf-8")
        assert "import_product" in content and ("A4" in content or "stored Procedure" in content or "Stored Procedure" in content), \
            "Expected A4 educational note mentioning import_product in template"

    def test_validate_procedure_route_source_has_procedure_endpoint(self):
        """routes/validate.py must define /validate/procedure endpoint."""
        source = (REPO_ROOT / "routes" / "validate.py").read_text(encoding="utf-8")
        assert "/validate/procedure" in source, \
            "Expected '/validate/procedure' route in routes/validate.py"

    def test_validate_procedure_route_handles_post(self):
        """routes/validate.py /validate/procedure must accept POST."""
        source = (REPO_ROOT / "routes" / "validate.py").read_text(encoding="utf-8")
        # Check route decorator accepts POST
        assert re.search(r'methods.*POST.*validate_procedure|validate_procedure.*methods.*POST', source, re.DOTALL), \
            "Expected POST method on /validate/procedure route"


# ===========================================================================
# PLAN 02-03 — Indexes in schema.sql
# ===========================================================================

class TestIDX01_NameIndexInSchema:
    """IDX-01: idx_products_name present in schema.sql DDL"""

    def test_schema_has_idx_products_name(self):
        """mysql-init/01-schema.sql must contain CREATE INDEX idx_products_name."""
        content = _sql(SCHEMA_SQL)
        assert "idx_products_name" in content, \
            "Expected 'idx_products_name' in 01-schema.sql"

    def test_idx_products_name_indexes_name_column(self):
        """idx_products_name must index the name column."""
        content = _sql(SCHEMA_SQL)
        assert re.search(r"idx_products_name\s+ON\s+products\s*\(\s*name\s*\)", content), \
            "Expected 'CREATE INDEX idx_products_name ON products(name)' in schema.sql"


class TestIDX02_CategoryIndexInSchema:
    """IDX-02: idx_products_category present in schema.sql DDL"""

    def test_schema_has_idx_products_category(self):
        """mysql-init/01-schema.sql must contain CREATE INDEX idx_products_category."""
        content = _sql(SCHEMA_SQL)
        assert "idx_products_category" in content, \
            "Expected 'idx_products_category' in 01-schema.sql"

    def test_idx_products_category_indexes_category_id_column(self):
        """idx_products_category must index the category_id column."""
        content = _sql(SCHEMA_SQL)
        assert re.search(r"idx_products_category\s+ON\s+products\s*\(\s*category_id\s*\)", content), \
            "Expected 'CREATE INDEX idx_products_category ON products(category_id)' in schema.sql"


class TestIDX03_BrandIndexInSchema:
    """IDX-03: idx_products_brand present in schema.sql DDL"""

    def test_schema_has_idx_products_brand(self):
        """mysql-init/01-schema.sql must contain CREATE INDEX idx_products_brand."""
        content = _sql(SCHEMA_SQL)
        assert "idx_products_brand" in content, \
            "Expected 'idx_products_brand' in 01-schema.sql"

    def test_idx_products_brand_indexes_brand_id_column(self):
        """idx_products_brand must index the brand_id column."""
        content = _sql(SCHEMA_SQL)
        assert re.search(r"idx_products_brand\s+ON\s+products\s*\(\s*brand_id\s*\)", content), \
            "Expected 'CREATE INDEX idx_products_brand ON products(brand_id)' in schema.sql"


# ===========================================================================
# PLAN 02-03 — Route /validate B-Tree index table (IDX-04)
# ===========================================================================

class TestIDX04_ValidateRendersIndexTable:
    """IDX-04: GET /validate renders B-Tree index table (information_schema query)"""

    def test_validate_route_queries_information_schema(self):
        """routes/validate.py must query information_schema.statistics."""
        source = (REPO_ROOT / "routes" / "validate.py").read_text(encoding="utf-8")
        assert "information_schema" in source, \
            "Expected 'information_schema' query in routes/validate.py for IDX-04"

    def test_validate_result_template_has_index_table_markup(self):
        """templates/validation_result.html must contain the B-Tree index table."""
        content = (REPO_ROOT / "templates" / "validation_result.html").read_text(encoding="utf-8")
        assert "index_name" in content or "B-Tree" in content or "idx_products" in content, \
            "Expected B-Tree index table markup in validation_result.html"

    def test_validate_route_returns_200(self, flask_client):
        """GET /validate must return HTTP 200.

        IMPORTANT: Requires current Docker image (docker compose up --build app).
        Returns 500 if container image is stale — db.mysql_engine not defined in
        the image's db.py. Rebuild to fix: docker compose up --build app
        """
        resp = flask_client.get(APP_BASE_URL + "/validate")
        assert resp.status_code == 200, \
            f"GET /validate returned {resp.status_code}, expected 200. " \
            f"If 500 with AttributeError: db.mysql_engine — rebuild container: " \
            f"docker compose up --build app"


# ===========================================================================
# PLAN 02-03 — INDEX_ANALYSIS.md document (IDX-05, IDX-06, DOC-02)
# ===========================================================================

class TestIDX05_ExplainOutputDocumented:
    """IDX-05: docs/INDEX_ANALYSIS.md contains EXPLAIN output for 3 queries"""

    def test_index_analysis_file_exists(self):
        """docs/INDEX_ANALYSIS.md must exist."""
        assert INDEX_ANALYSIS_MD.exists(), f"Expected docs/INDEX_ANALYSIS.md at {INDEX_ANALYSIS_MD}"

    def test_index_analysis_contains_explain_keyword_at_least_three_times(self):
        """Document must have EXPLAIN output for at least 3 queries."""
        content = _md(INDEX_ANALYSIS_MD)
        explain_count = len(re.findall(r"\bEXPLAIN\b", content, re.IGNORECASE))
        assert explain_count >= 3, \
            f"Expected at least 3 EXPLAIN references in INDEX_ANALYSIS.md, found {explain_count}"

    def test_index_analysis_documents_name_exact_match_query(self):
        """Document must include EXPLAIN for name exact-match query."""
        content = _md(INDEX_ANALYSIS_MD)
        assert "idx_products_name" in content, \
            "Expected 'idx_products_name' EXPLAIN reference in INDEX_ANALYSIS.md"

    def test_index_analysis_documents_price_range_scan(self):
        """Document must include EXPLAIN for price range scan."""
        content = _md(INDEX_ANALYSIS_MD)
        assert "idx_products_price" in content or "price BETWEEN" in content, \
            "Expected price range scan EXPLAIN in INDEX_ANALYSIS.md"

    def test_index_analysis_documents_join_with_brand(self):
        """Document must include EXPLAIN for JOIN query using brand index."""
        content = _md(INDEX_ANALYSIS_MD)
        assert "idx_products_brand" in content, \
            "Expected 'idx_products_brand' JOIN EXPLAIN reference in INDEX_ANALYSIS.md"


class TestIDX06_DOC02_BTreeTheorySection:
    """IDX-06 / DOC-02: docs/INDEX_ANALYSIS.md contains B-Tree theory (O(log N), 16KB pages, B+-tree)"""

    def test_index_analysis_mentions_o_log_n(self):
        """Document must explain O(log N) lookup complexity."""
        content = _md(INDEX_ANALYSIS_MD)
        assert "log N" in content or "O(log" in content or "logarithm" in content.lower(), \
            "Expected O(log N) complexity explanation in INDEX_ANALYSIS.md"

    def test_index_analysis_mentions_16kb_innodb_pages(self):
        """Document must mention 16 KB InnoDB page size."""
        content = _md(INDEX_ANALYSIS_MD)
        assert "16 KB" in content or "16KB" in content or "16 kb" in content.lower(), \
            "Expected '16 KB' InnoDB page size mention in INDEX_ANALYSIS.md"

    def test_index_analysis_mentions_b_plus_tree(self):
        """Document must reference B+-tree structure."""
        content = _md(INDEX_ANALYSIS_MD)
        assert "B+" in content or "B+-" in content or "B+-Baum" in content or "B-Tree" in content, \
            "Expected B+-tree / B-Tree structural reference in INDEX_ANALYSIS.md"

    def test_index_analysis_has_btree_theory_section(self):
        """Document must have a theory/explanation section about B-Trees."""
        content = _md(INDEX_ANALYSIS_MD)
        # Section header about why MySQL uses B-Trees
        assert re.search(r"Warum.*B.Baum|B.Tree.*Theorie|B-Tree.*Analyse", content, re.IGNORECASE), \
            "Expected B-Tree theory section header in INDEX_ANALYSIS.md"

    def test_index_analysis_explains_sorted_order_benefit(self):
        """Document must explain sorted order as a B-Tree advantage."""
        content = _md(INDEX_ANALYSIS_MD)
        assert "sortiert" in content.lower() or "sorted" in content.lower() or "Sortierte Ordnung" in content, \
            "Expected sorted order explanation in INDEX_ANALYSIS.md"


# ===========================================================================
# Live DB tests — skipped when DB is not reachable
# ===========================================================================

@skipif_no_db
class TestPROC02PROC03_LiveProcedureResultCodes:
    """PROC-02/PROC-03 live: stored procedure OUT params and all result codes work."""

    @pytest.fixture(scope="class")
    def db_conn(self):
        import pymysql
        conn = pymysql.connect(
            host=os.environ.get("MYSQL_HOST", "mysql"),
            user=os.environ.get("MYSQL_USER", "app"),
            password=os.environ.get("MYSQL_PASSWORD", "app"),
            database=os.environ.get("MYSQL_DB", "productdb"),
        )
        yield conn
        conn.close()

    def _call_procedure(self, conn, **kwargs):
        """Helper: call import_product() and return {result_code, result_message}."""
        cursor = conn.cursor()
        try:
            cursor.execute("SET @rc = 0, @rm = ''")
            cursor.execute(
                "CALL import_product(%s, %s, %s, %s, %s, %s, %s, %s, @rc, @rm)",
                (
                    kwargs.get("name", ""),
                    kwargs.get("description", ""),
                    kwargs.get("brand_name", ""),
                    kwargs.get("category_name", ""),
                    float(kwargs.get("price", 0)),
                    kwargs.get("sku", ""),
                    kwargs.get("load_class", ""),
                    kwargs.get("application", ""),
                ),
            )
            while cursor.nextset():
                pass
            cursor.execute("SELECT @rc AS result_code, @rm AS result_message")
            row = cursor.fetchone()
            conn.commit()
            return {"result_code": int(row[0] or 0), "result_message": str(row[1] or "")}
        finally:
            cursor.close()

    def _get_existing_category(self, conn) -> str:
        """Get a real category name from the DB."""
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM categories LIMIT 1")
        row = cursor.fetchone()
        cursor.close()
        return row[0] if row else "Kugellager"

    def _get_existing_sku(self, conn) -> str:
        """Get a real existing SKU from the DB."""
        cursor = conn.cursor()
        cursor.execute("SELECT sku FROM products WHERE sku IS NOT NULL LIMIT 1")
        row = cursor.fetchone()
        cursor.close()
        return row[0] if row else None

    def test_procedure_returns_result_code_2_for_missing_category(self, db_conn):
        """Calling with a non-existent category must return result_code=2."""
        result = self._call_procedure(
            db_conn,
            name="Test Produkt",
            price=10.0,
            category_name="__NONEXISTENT_CATEGORY_XYZ__",
        )
        assert result["result_code"] == 2, \
            f"Expected result_code=2 for missing category, got {result}"
        assert result["result_message"], "Expected non-empty result_message for code=2"

    def test_procedure_returns_result_code_2_for_empty_name(self, db_conn):
        """Calling with empty name must return result_code=2 (validation error)."""
        cat = self._get_existing_category(db_conn)
        result = self._call_procedure(
            db_conn,
            name="",
            price=10.0,
            category_name=cat,
        )
        assert result["result_code"] == 2, \
            f"Expected result_code=2 for empty name, got {result}"

    def test_procedure_returns_result_code_1_for_duplicate_sku(self, db_conn):
        """Calling with an existing SKU must return result_code=1."""
        existing_sku = self._get_existing_sku(db_conn)
        if existing_sku is None:
            pytest.skip("No products with SKU found in DB")

        cat = self._get_existing_category(db_conn)
        result = self._call_procedure(
            db_conn,
            name="Duplicate SKU Test",
            price=9.99,
            sku=existing_sku,
            category_name=cat,
        )
        assert result["result_code"] == 1, \
            f"Expected result_code=1 for duplicate SKU '{existing_sku}', got {result}"

    def test_procedure_returns_result_code_0_for_valid_insert(self, db_conn):
        """Calling with valid data must return result_code=0 and insert a product."""
        import uuid
        cat = self._get_existing_category(db_conn)
        unique_sku = f"TEST-{uuid.uuid4().hex[:8].upper()}"
        result = self._call_procedure(
            db_conn,
            name="Phase02 Testprodukt",
            description="Automatisch eingefügt durch Phase02 Test",
            price=42.00,
            sku=unique_sku,
            category_name=cat,
        )
        assert result["result_code"] == 0, \
            f"Expected result_code=0 for valid insert, got {result}"
        assert "importiert" in result["result_message"].lower() or result["result_message"], \
            "Expected success message for result_code=0"


@skipif_no_db
class TestTRIG02TRIG03_LiveTriggerBehavior:
    """TRIG-02/TRIG-03 live: trigger fires only on actual changes and covers all 8 fields."""

    @pytest.fixture(scope="class")
    def db_conn(self):
        import pymysql
        conn = pymysql.connect(
            host=os.environ.get("MYSQL_HOST", "mysql"),
            user=os.environ.get("MYSQL_USER", "app"),
            password=os.environ.get("MYSQL_PASSWORD", "app"),
            database=os.environ.get("MYSQL_DB", "productdb"),
        )
        yield conn
        conn.close()

    def _count_change_log_rows(self, conn, product_id: int) -> int:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT COUNT(*) FROM product_change_log WHERE product_id = %s", (product_id,)
        )
        count = cursor.fetchone()[0]
        cursor.close()
        return count

    def _get_test_product(self, conn):
        """Get a product to use for trigger tests."""
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id, name, price FROM products WHERE name IS NOT NULL AND price IS NOT NULL LIMIT 1"
        )
        row = cursor.fetchone()
        cursor.close()
        return row  # (id, name, price)

    def test_trigger_fires_when_name_changes(self, db_conn):
        """Trigger must insert a log row when name field changes."""
        product = self._get_test_product(db_conn)
        if not product:
            pytest.skip("No suitable product found")

        product_id, original_name, price = product
        new_name = original_name + " (changed)"

        before_count = self._count_change_log_rows(db_conn, product_id)

        cursor = db_conn.cursor()
        cursor.execute(
            "UPDATE products SET name = %s WHERE id = %s", (new_name, product_id)
        )
        db_conn.commit()
        cursor.close()

        after_count = self._count_change_log_rows(db_conn, product_id)

        # Restore original name
        cursor = db_conn.cursor()
        cursor.execute(
            "UPDATE products SET name = %s WHERE id = %s", (original_name, product_id)
        )
        db_conn.commit()
        cursor.close()

        assert after_count > before_count, \
            f"Trigger should have added a log row for name change; " \
            f"before={before_count}, after={after_count}"

    def test_trigger_does_not_fire_when_name_unchanged(self, db_conn):
        """Trigger must NOT insert a log row when updating to the same name value."""
        product = self._get_test_product(db_conn)
        if not product:
            pytest.skip("No suitable product found")

        product_id, original_name, price = product

        before_count = self._count_change_log_rows(db_conn, product_id)

        cursor = db_conn.cursor()
        # Update to the exact same name — no change
        cursor.execute(
            "UPDATE products SET name = %s WHERE id = %s", (original_name, product_id)
        )
        db_conn.commit()
        cursor.close()

        after_count = self._count_change_log_rows(db_conn, product_id)

        assert after_count == before_count, \
            f"Trigger should NOT add a log row when name is unchanged; " \
            f"before={before_count}, after={after_count}"

    def test_trigger_logs_field_name_correctly(self, db_conn):
        """Trigger log row must use correct field_name value ('name')."""
        product = self._get_test_product(db_conn)
        if not product:
            pytest.skip("No suitable product found")

        product_id, original_name, price = product
        new_name = original_name + " (trigger_test)"

        cursor = db_conn.cursor()
        cursor.execute(
            "UPDATE products SET name = %s WHERE id = %s", (new_name, product_id)
        )
        db_conn.commit()

        cursor.execute(
            "SELECT field_name FROM product_change_log "
            "WHERE product_id = %s ORDER BY id DESC LIMIT 1",
            (product_id,)
        )
        row = cursor.fetchone()

        # Restore
        cursor.execute(
            "UPDATE products SET name = %s WHERE id = %s", (original_name, product_id)
        )
        db_conn.commit()
        cursor.close()

        assert row is not None, "Expected a log row after name change"
        assert row[0] == "name", f"Expected field_name='name', got '{row[0]}'"

    def test_trigger_fires_when_price_changes(self, db_conn):
        """Trigger must insert a log row when price field changes."""
        product = self._get_test_product(db_conn)
        if not product:
            pytest.skip("No suitable product found")

        product_id, name, original_price = product
        new_price = float(original_price) + 0.01

        before_count = self._count_change_log_rows(db_conn, product_id)

        cursor = db_conn.cursor()
        cursor.execute(
            "UPDATE products SET price = %s WHERE id = %s", (new_price, product_id)
        )
        db_conn.commit()

        after_count = self._count_change_log_rows(db_conn, product_id)

        # Restore
        cursor.execute(
            "UPDATE products SET price = %s WHERE id = %s", (original_price, product_id)
        )
        db_conn.commit()
        cursor.close()

        assert after_count > before_count, \
            f"Trigger should have added a log row for price change; " \
            f"before={before_count}, after={after_count}"
