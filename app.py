"""
Flask Application Factory

Clean 3-tier architecture with Controller-Service-Repository pattern.
All routes are organized in separate blueprint files.
"""
import logging
import os
from datetime import date
from time import perf_counter
from uuid import uuid4

from flask import Flask, g, request, render_template

import db
from config import Config
from routes import (
    dashboard_bp,
    products_bp,
    index_bp,
    audit_bp,
    search_bp,
    rag_bp,
    validate_bp,
    pdf_bp,
)
from utils import _get_int

log = logging.getLogger(__name__)


class DailyFileHandler(logging.Handler):
    """Write logs to logs/YYYY-MM-DD.log and rotate automatically each day."""

    def __init__(self, log_dir: str, level: int = logging.NOTSET, encoding: str = "utf-8"):
        super().__init__(level=level)
        self.log_dir = log_dir
        self.encoding = encoding
        self._current_date = None
        self._file_handler = None
        os.makedirs(self.log_dir, exist_ok=True)
        self._rotate_if_needed()

    def _rotate_if_needed(self) -> None:
        today = date.today()
        if today == self._current_date:
            return

        if self._file_handler is not None:
            self._file_handler.close()

        self._current_date = today
        path = os.path.join(self.log_dir, f"{today.isoformat()}.log")
        self._file_handler = logging.FileHandler(path, encoding=self.encoding)
        self._file_handler.setLevel(self.level)
        if self.formatter is not None:
            self._file_handler.setFormatter(self.formatter)

    def setFormatter(self, fmt):
        super().setFormatter(fmt)
        if self._file_handler is not None:
            self._file_handler.setFormatter(fmt)

    def emit(self, record):
        self._rotate_if_needed()
        if self._file_handler is not None:
            self._file_handler.emit(record)

    def close(self):
        try:
            if self._file_handler is not None:
                self._file_handler.close()
        finally:
            super().close()


def _configure_logging(base_dir: str) -> str:
    log_dir = os.path.join(base_dir, "logs")
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)

    has_daily_handler = any(getattr(h, "_is_daily_app_handler", False) for h in root_logger.handlers)
    if not has_daily_handler:
        formatter = logging.Formatter("%(asctime)s | %(levelname)s | %(name)s | %(message)s")
        daily_handler = DailyFileHandler(log_dir=log_dir, level=logging.INFO)
        daily_handler.setFormatter(formatter)
        daily_handler._is_daily_app_handler = True
        root_logger.addHandler(daily_handler)

    return log_dir


def _register_request_logging(app: Flask) -> None:
    action_log = logging.getLogger("app.actions")

    @app.before_request
    def _log_request_start():
        g.request_id = uuid4().hex[:8]
        g.request_started_at = perf_counter()
        client_ip = (request.headers.get("X-Forwarded-For") or request.remote_addr or "-").split(",")[0].strip()
        action_log.info(
            "request_start id=%s method=%s path=%s endpoint=%s ip=%s",
            g.request_id,
            request.method,
            request.path,
            request.endpoint,
            client_ip,
        )

    @app.after_request
    def _log_request_end(response):
        started_at = getattr(g, "request_started_at", perf_counter())
        request_id = getattr(g, "request_id", "-")
        duration_ms = int((perf_counter() - started_at) * 1000)
        action_log.info(
            "request_end id=%s method=%s path=%s status=%s duration_ms=%s",
            request_id,
            request.method,
            request.path,
            response.status_code,
            duration_ms,
        )
        return response

    @app.teardown_request
    def _log_request_error(error):
        if error is not None:
            request_id = getattr(g, "request_id", "-")
            action_log.exception(
                "request_error id=%s method=%s path=%s", request_id, request.method, request.path
            )


def create_app():
    """
    Flask application factory.

    Creates and configures the Flask application with all blueprints.
    Uses environment variables for configuration (see .env.example file).
    """
    base_dir = os.path.abspath(os.path.dirname(__file__))
    app = Flask(
        __name__,
        static_folder=os.path.join(base_dir, "static"),
        template_folder=os.path.join(base_dir, "templates"),
    )

    # Load configuration
    app.config.from_object(Config)
    log_dir = _configure_logging(base_dir)
    _register_request_logging(app)
    log.info("Application logging initialized in %s", log_dir)

    if not app.config.get("SECRET_KEY"):
        log.warning(
            "SECRET_KEY ist nicht gesetzt; flash()/Sessions funktionieren ggf. nicht korrekt."
        )

    # Initialize MySQL database connection
    mysql_url = app.config.get("MYSQL_URL")
    if mysql_url:
        try:
            from sqlalchemy import create_engine
            engine = create_engine(mysql_url, pool_pre_ping=True, future=True)
            db.mysql_engine = engine
            from sqlalchemy.orm import sessionmaker
            db.mysql_session_factory = sessionmaker(
                bind=engine, autoflush=False, autocommit=False, future=True
            )
            log.info("✓ MySQL database initialized")
        except Exception:
            log.exception(
                "MySQL-Session konnte nicht initialisiert werden (MYSQL_URL/Netz/Container prüfen)."
            )
    else:
        log.warning("MYSQL_URL fehlt; DB-Initialisierung wird im Skeleton-Branch uebersprungen.")

    @app.errorhandler(NotImplementedError)
    def _not_implemented(error):
        return render_template("student_hint.html"), 501

    # Register all blueprints
    app.register_blueprint(dashboard_bp)
    app.register_blueprint(products_bp)
    app.register_blueprint(index_bp)
    app.register_blueprint(audit_bp)
    app.register_blueprint(search_bp)
    app.register_blueprint(rag_bp)
    app.register_blueprint(validate_bp)
    app.register_blueprint(pdf_bp)

    log.info("✓ All blueprints registered")

    return app


if __name__ == "__main__":
    """
    Development server entry point.

    For production, use a WSGI server like Gunicorn:
        gunicorn app:create_app()
    """
    app = create_app()

    port = _get_int(os.environ.get("PORT"), 5000, min_value=1, max_value=65535)
    debug = bool(app.config.get("DEBUG", False))

    log.info(f"Starting development server on port {port} (debug={debug})")
    app.run(host="0.0.0.0", port=port, debug=debug)
