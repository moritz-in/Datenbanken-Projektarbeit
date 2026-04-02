# Coding Conventions

**Analysis Date:** 2026-04-02

## Naming Patterns

**Files:**
- Modules use `snake_case.py` (e.g., `product_service.py`, `mysql_repository.py`, `audit_repository.py`)
- One class per file as the primary export; file named after the primary class (lowercased + underscores)
- `__init__.py` files serve as factory/barrel exports for each layer (`repositories/__init__.py`, `services/__init__.py`)

**Classes:**
- `PascalCase` for all classes (e.g., `ProductService`, `MySQLRepositoryImpl`, `QdrantRepository`)
- Abstract base classes named after the concept without suffix: `MySQLRepository`, `QdrantRepository`
- Concrete implementations suffixed with `Impl`: `MySQLRepositoryImpl`, `QdrantRepositoryImpl`, `Neo4jRepositoryImpl`
- No-op/null-object variants prefixed with `NoOp`: `NoOpNeo4jRepository`
- Factory classes suffixed with `Factory`: `RepositoryFactory`, `ServiceFactory`

**Functions & Methods:**
- `snake_case` for all methods and functions (e.g., `get_products_with_joins`, `build_index`, `embed_texts`)
- Private/internal helpers prefixed with single underscore: `_get_session`, `_get_embedding_model`, `_configure_logging`, `_rotate_if_needed`
- Private utility functions at module level also use `_` prefix: `_get_int`, `_get_optional_int`, `_require_env`
- Flask Blueprint route handler functions use plain `snake_case` names matching the route: `def products()`, `def audit()`, `def graph_rag()`

**Variables:**
- `snake_case` for all variables
- Module-level loggers always named `log`: `log = logging.getLogger(__name__)`
- Blueprint instances always named `bp`: `bp = Blueprint("products", __name__)`
- Collection name constants use `UPPER_SNAKE_CASE`: `COLLECTION_PDF = "pdf_skripte"`, `COLLECTION_PDF_PRODUCTS = "pdf_produkte"`

**Type Annotations:**
- All method signatures use type annotations (Python 3.12 style)
- Modern union syntax preferred: `list[dict]`, `Optional[str]`, `tuple[list, Optional[str]]`
- Return types always annotated on public methods
- `Optional` from `typing` used for nullable params; not `X | None` style

## Code Style

**Formatting:**
- No `pyproject.toml`, `.flake8`, or `.prettierrc` detected — no enforced formatter configured
- Indentation: 4 spaces (standard Python)
- Line length appears to follow ~100-120 char limit (not strict PEP8 79-char)
- Mixed-language comments exist (German in `config.py`, `app.py`, `validation.py`; English in docstrings)

**Linting:**
- No linting config (`.flake8`, `ruff.toml`, `pyproject.toml`) present
- No `# type: ignore` or `# noqa` suppressions detected in reviewed files

## Import Organization

**Order (observed pattern):**
1. Standard library (`abc`, `os`, `re`, `logging`, `typing`, `datetime`)
2. Third-party libraries (`flask`, `sqlalchemy`, `qdrant_client`, `sentence_transformers`, `openai`, `neo4j`)
3. Internal imports (`db`, `config`, `repositories`, `services`, `utils`)

**Path Aliases:**
- No path aliases; all internal imports use bare module names relative to project root (e.g., `import db`, `from repositories import ...`)

**Barrel Exports:**
- Each layer (`repositories/`, `services/`) has an `__init__.py` that imports and re-exports all public symbols
- Routes use `from services import ServiceFactory` and `from utils import _get_int` — always import from the layer, not the file

## Error Handling

**Primary Patterns:**
- Unimplemented methods raise `NotImplementedError` with a descriptive `"TODO: implement ..."` message — this is an intentional scaffold pattern for student implementation
- Business logic methods document their exceptions via `Raises:` in docstrings (e.g., `ValueError` for invalid SQL, `Exception` for DB errors)
- In `app.py`: Flask `@app.errorhandler(NotImplementedError)` renders a `student_hint.html` template with HTTP 501 — catching `NotImplementedError` at the framework level is deliberate
- In `validation.py`: broad `except SQLAlchemyError` followed by `except Exception` catch blocks — exceptions are logged as `ERROR` items inside the `ValidationReport` (never re-raised)
- In `app.py` `create_app()`: DB initialization wrapped in `try/except Exception` with `log.exception()` — failures are non-fatal

**Exception Strategy:**
- Repositories raise directly (no wrapping)
- Services document `ValueError` for invalid input
- Routes rely on Flask's 501 handler for `NotImplementedError`
- Never use bare `except:` (always `except Exception` or specific types)

## Logging

**Framework:** Python `logging` module (stdlib)

**Setup Pattern:**
- Each module gets its own logger at module level: `log = logging.getLogger(__name__)`
- Application-wide logging configured in `app.py` via `_configure_logging()` using a custom `DailyFileHandler` that rotates daily to `logs/YYYY-MM-DD.log`
- Log format: `"%(asctime)s | %(levelname)s | %(name)s | %(message)s"`
- Root logger level: `INFO`

**Request Logging:**
- Every HTTP request logged via `before_request`/`after_request` hooks in `app.py`
- Uses structured key=value format: `"request_start id=%s method=%s path=%s endpoint=%s ip=%s"`
- Request IDs generated as 8-char hex UUIDs: `uuid4().hex[:8]`

**Usage Patterns:**
- `log.info(...)` for normal operations and startup messages
- `log.warning(...)` for missing config (non-fatal)
- `log.exception(...)` for caught exceptions (includes stack trace automatically)
- Use `%s` format strings (not f-strings) in log calls to defer formatting

## Comments

**When to Comment:**
- Module-level docstrings on all service and repository files explaining the layer's purpose
- Class-level docstrings on all classes
- Method-level docstrings on all public methods using Google-style Args/Returns/Raises sections

**Docstring Format (Google-style):**
```python
def get_products_with_joins(self, page: int, page_size: int) -> dict:
    """
    Get paginated products with brand, category, and tags joined.

    Args:
        page: Page number (1-based)
        page_size: Number of items per page

    Returns:
        dict with 'items' (list of products) and 'total' (total count)
    """
```

**Inline Comments:**
- Used sparingly, in German for student-facing notes (e.g., `# wird in app.py initialisiert`)
- Section separators in large files use `# =====` blocks (e.g., `# High-level operations` in `qdrant_repository.py`)

## Function Design

**Size:** Route handlers intentionally minimal (scaffold only); service/repository methods are well-scoped to a single responsibility

**Parameters:**
- Dependency injection via `__init__` constructor for repos/services
- `Optional` params have defaults: `page: int = 1`, `page_size: int = 20`
- Keyword-only enforcement on helpers: `_get_int(value, default, *, min_value=None, max_value=None)` — note the `*` separator

**Return Values:**
- Repositories return `dict` with consistent keys (`'items'`, `'total'`) for paginated results
- Services return `dict` for structured results, `list[dict]` for flat result sets
- Validation results returned as typed dataclass objects: `ValidationReport`, `ValidationItem`

## Module Design

**Exports:**
- Every layer `__init__.py` defines `__all__` explicitly listing all exportable symbols
- Abstract base classes exported alongside `Impl` classes to enable type-hinting in consumers

**Factory Pattern:**
- `RepositoryFactory` and `ServiceFactory` manage singleton instances in a class-level `_instances = {}` dict
- `reset()` method on each factory for test isolation
- Shared expensive resources (embedding models, LLM clients) managed in `ServiceFactory._shared_resources = {}`

**Dataclasses:**
- `@dataclass` used for pure data containers in `validation.py`: `ValidationItem`, `ValidationReport`
- `field(default_factory=dict)` for mutable defaults

---

*Convention analysis: 2026-04-02*
