import os
from dotenv import load_dotenv

load_dotenv()


def _require_env(name: str) -> str:
    value = os.getenv(name)
    if value is None or not value.strip():
        raise RuntimeError(f"Fehlende Pflicht-Umgebungsvariable: {name}")
    return value


def _int_env(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None or not str(raw).strip():
        return default
    try:
        return int(raw)
    except ValueError:
        raise RuntimeError(f"Umgebungsvariable {name} muss eine Ganzzahl sein (war: {raw!r}).")


class Config:
    # Sessions/flash()
    SECRET_KEY = os.getenv("FLASK_SECRET_KEY", "dev-secret")

    # Pflichtwerte (in Containern i.d.R. immer gesetzt)
    MYSQL_URL = os.getenv("MYSQL_URL")
    QDRANT_URL = os.getenv("QDRANT_URL")

    # Optional
    QDRANT_COLLECTION = os.getenv("QDRANT_COLLECTION", "products")
    EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
    EMBEDDING_DIM = _int_env("EMBEDDING_DIM", 384)
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
    LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4.1-mini")

    # Neo4j
    NEO4J_URI = os.getenv("NEO4J_URI", "bolt://neo4j:7687")
    NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
    NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD")

    @classmethod
    def validate(cls) -> None:
        _require_env("MYSQL_URL")
        _require_env("QDRANT_URL")