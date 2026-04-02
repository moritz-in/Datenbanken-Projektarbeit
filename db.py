from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

def make_session(database_url: str):
    engine = create_engine(database_url, pool_pre_ping=True, future=True)
    return sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

# wird in app.py initialisiert
mysql_session_factory = None
