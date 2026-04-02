# Technology Stack

**Project:** Datenbanken-Projektarbeit (Flask RAG Application)
**Researched:** 2026-04-02
**Confidence:** HIGH — all patterns verified against official documentation

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Flask | 3.0.3 | Web framework | Pinned in requirements.txt; lightweight, well-suited for API layers |
| SQLAlchemy | 2.0.32 | ORM + raw SQL abstraction for MySQL | Full 2.0 mode (`future=True`); session factory already wired in `db.py` |
| PyMySQL | 1.1.1 | MySQL driver (pure Python) | No C extensions needed; works with SQLAlchemy via `pymysql` dialect |
| qdrant-client | >=1.7.0 | Vector search (Qdrant) | Official Python client; `collection_exists`, `upsert`, `search` API stable since 1.7 |
| neo4j | >=5.0 | Graph database driver | `driver.execute_query()` (simple path) and managed transactions available |

### Database Layer

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| MySQL | 8.4 | Relational store + stored procedures | Primary structured data store; stored procs called via `CALL` |
| Qdrant | 1.16.2 | Vector similarity search | Embeddings store for RAG retrieval pipeline |
| Neo4j | 5.x | Knowledge graph | Entity relationships, graph traversal for RAG enrichment |

---

## SQLAlchemy 2.0 — Correct Patterns

> **Source:** https://docs.sqlalchemy.org/en/20/orm/session_transaction.html (HIGH confidence)

### Session Acquisition

`db.mysql_session_factory` is a `sessionmaker` configured with `future=True` (full 2.0 mode).
Each repository method must acquire its own session:

```python
session = self._session_factory()   # creates a new Session
```

### Preferred Transaction Pattern (context manager)

```python
from sqlalchemy import text

session = self._session_factory()
with session.begin():
    result = session.execute(text("SELECT * FROM table WHERE id = :id"), {"id": value})
    rows = result.mappings().all()   # list of dict-like RowMapping objects
# auto-commits on success, auto-rolls back on exception
```

### Explicit try/except Pattern (when you need fine-grained control)

```python
from sqlalchemy import text

session = self._session_factory()
try:
    session.begin()
    result = session.execute(text("INSERT INTO ..."), {"col": val})
    session.commit()
except Exception:
    session.rollback()
    raise
finally:
    session.close()
```

### Stored Procedures via CALL

MySQL stored procedures must use the `CALL` keyword. Parameters passed as a dict:

```python
session.execute(
    text("CALL proc_name(:param1, :param2)"),
    {"param1": value1, "param2": value2}
)
```

For stored procedures that return result sets, fetch immediately inside the transaction:

```python
with session.begin():
    result = session.execute(text("CALL get_items(:user_id)"), {"user_id": uid})
    rows = result.mappings().all()
```

### Result Handling

```python
result = session.execute(text("SELECT id, name FROM table"))
rows = result.mappings().all()      # list of RowMapping (dict-like, access by column name)
row = result.mappings().first()     # first row or None
scalar = result.scalar()            # single value (first col, first row)
```

### DO NOT USE (deprecated / wrong mode)

| Anti-pattern | Why |
|---|---|
| `session.execute("SELECT ...")` (bare string) | Raises `TypeError` in 2.0 — must use `text()` |
| `session.query(Model).filter(...)` | SQLAlchemy 1.x ORM style — avoid in 2.0 |
| `session.autocommit = True` | Breaks transaction semantics; not supported in `future=True` mode |
| Reusing a session across requests | Sessions are not thread-safe; always create a new one per operation |

---

## Qdrant Python Client — Correct Patterns

> **Source:** https://qdrant.tech/documentation/quickstart/ + https://python-client.qdrant.tech/ (HIGH confidence)

### Initialization

```python
from qdrant_client import QdrantClient

client = QdrantClient(url="http://qdrant:6333")
```

### Imports

```python
from qdrant_client import QdrantClient
from qdrant_client.http.models import (
    VectorParams,
    Distance,
    HnswConfigDiff,
    PointStruct,
    SearchParams,
)
```

### Collection Management

```python
# Check existence
exists: bool = client.collection_exists(collection_name="my_collection")

# Create collection
client.create_collection(
    collection_name="my_collection",
    vectors_config=VectorParams(size=384, distance=Distance.COSINE),
    hnsw_config=HnswConfigDiff(m=16, ef_construct=128),
)

# Delete collection
client.delete_collection(collection_name="my_collection")

# Get collection info (returns CollectionInfo object)
info = client.get_collection(collection_name="my_collection")
```

### Upsert Points

```python
from qdrant_client.http.models import PointStruct

client.upsert(
    collection_name="my_collection",
    wait=True,   # wait for indexing to complete before returning
    points=[
        PointStruct(
            id=42,              # int or UUID string
            vector=[0.1, 0.2, ...],
            payload={"key": "value"},
        )
    ],
)
```

### Search (Vector Similarity)

```python
from qdrant_client.http.models import SearchParams

results = client.search(
    collection_name="my_collection",
    query_vector=[0.1, 0.2, ...],
    limit=10,
    with_payload=True,
    search_params=SearchParams(hnsw_ef=64),   # ef >= limit recommended
)
# results: list of ScoredPoint
# each: result.id, result.score, result.payload
```

### Count & Scroll

```python
# Count
count: int = client.count(collection_name="my_collection", exact=True).count

# Scroll (paginated retrieval without vector query)
points, next_offset = client.scroll(
    collection_name="my_collection",
    limit=100,
    with_payload=True,
    offset=None,   # pass next_offset to paginate
)
```

### DO NOT USE

| Anti-pattern | Why |
|---|---|
| `client.recreate_collection(...)` | Deprecated since qdrant-client 1.1.1 — use `delete_collection` + `create_collection` |
| Omitting `wait=True` on upsert in tests | Points may not be searchable immediately |
| Omitting `SearchParams` on search | Default HNSW ef may be too low for accuracy |

---

## Neo4j Python Driver — Correct Patterns

> **Source:** https://neo4j.com/docs/python-manual/current/query-simple/ + https://neo4j.com/docs/python-manual/current/transactions/ (HIGH confidence)

### Initialization

```python
from neo4j import GraphDatabase

driver = GraphDatabase.driver(uri, auth=(user, password))
driver.verify_connectivity()   # optional but recommended at startup
```

### Simple Queries (preferred path — auto-managed transactions with retry)

```python
records, summary, keys = driver.execute_query(
    "MATCH (n:Entity {id: $entity_id}) RETURN n",
    entity_id=entity_id,
    database_="neo4j",
)
# records: list of Record objects
for record in records:
    data = record.data()   # dict of {key: value}
```

### Managed Transactions (when you need read/write separation or custom logic)

```python
def _find_entity(tx, entity_id):
    result = tx.run("MATCH (n:Entity {id: $id}) RETURN n", id=entity_id)
    return [record.data() for record in result]

with driver.session(database="neo4j") as session:
    records = session.execute_read(_find_entity, entity_id)
    # use execute_write for mutations
```

### Explicit Transactions (when you need manual commit/rollback control)

```python
with driver.session(database="neo4j") as session:
    with session.begin_transaction() as tx:
        tx.run("CREATE (n:Entity {id: $id})", id=entity_id)
        tx.commit()   # or tx.rollback()
```

### Record to Dict

```python
record.data()          # full dict: {key: value}
record["key"]          # single field by key
record.values()        # list of values (ordered by RETURN clause)
```

### Closing the Driver

```python
driver.close()   # call once at app shutdown
```

### DO NOT USE

| Anti-pattern | Why |
|---|---|
| `session.run(cypher)` directly | Bypasses automatic retry logic — use `execute_query` or managed transactions |
| `from neo4j.v1 import ...` | Old v1 API — removed in neo4j>=5.0 |
| Opening a new `driver` per request | Expensive; driver manages a connection pool — reuse the singleton |
| `session.begin_transaction()` without context manager | Risk of unclosed transactions on error |

---

## NoOpNeo4jRepository — Safe Return Values

The `NoOpNeo4jRepository` is a null-object implementation. All methods must return safe empty values — never raise `NotImplementedError`:

| Return type expected | Safe value |
|---|---|
| list | `[]` |
| dict | `{}` |
| Optional / nullable | `None` |
| bool | `False` |
| int | `0` |

---

## Repository `__init__` Patterns

### MySQLRepositoryImpl

```python
def __init__(self, session_factory=None):
    import db
    self._session_factory = session_factory or db.mysql_session_factory
```

### QdrantRepositoryImpl

```python
def __init__(self, qdrant_url: str, default_collection: str):
    self.client = QdrantClient(url=qdrant_url)
    self.default_collection = default_collection
```

### Neo4jRepositoryImpl

```python
def __init__(self, uri: str, user: str, password: str):
    self.driver = GraphDatabase.driver(uri, auth=(user, password))
```

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| MySQL driver | PyMySQL | mysqlclient (C ext) | No C toolchain in Docker image; PyMySQL is pure Python |
| SQLAlchemy style | 2.0 `text()` + `session.begin()` | 1.x `session.query()` | App is `future=True`; 1.x patterns raise errors |
| Qdrant collection create | `create_collection` | `recreate_collection` | Deprecated; removed in newer client versions |
| Neo4j queries | `driver.execute_query()` | `session.run()` directly | `execute_query` has built-in retry and cleaner API |

---

## Sources

- SQLAlchemy 2.0 Session Transactions: https://docs.sqlalchemy.org/en/20/orm/session_transaction.html (HIGH)
- SQLAlchemy 2.0 Core Text Construct: https://docs.sqlalchemy.org/en/20/core/sqlelement.html#sqlalchemy.sql.expression.text (HIGH)
- Qdrant Python Quickstart: https://qdrant.tech/documentation/quickstart/ (HIGH)
- Qdrant Python Client API: https://python-client.qdrant.tech/ (HIGH)
- Neo4j Python Driver — Simple Queries: https://neo4j.com/docs/python-manual/current/query-simple/ (HIGH)
- Neo4j Python Driver — Transactions: https://neo4j.com/docs/python-manual/current/transactions/ (HIGH)
