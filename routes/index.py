"""Index route - Build and manage Qdrant vector index"""
import logging
from flask import Blueprint, flash, redirect, render_template, request, url_for

from services import ServiceFactory
from utils import _get_int, _get_optional_int

log = logging.getLogger(__name__)
bp = Blueprint("index", __name__)


@bp.route("/index", methods=["GET", "POST"])
def index():
    """Index management page - build, truncate, view status"""
    index_svc = ServiceFactory.get_index_service()

    if request.method == "POST":
        strategy = request.form.get("strategy", "C")
        limit = _get_optional_int(request.form.get("limit"))
        batch_size = _get_int(request.form.get("batch_size"), 64)
        try:
            result = index_svc.build_index(strategy=strategy, limit=limit, batch_size=batch_size)
            flash(
                f"{result['count']} Produkte in {result['elapsed']:.1f}s indexiert (Strategie C)",
                "success",
            )
        except Exception as e:
            log.exception("build_index failed: %s", e)
            flash(f"Index-Build fehlgeschlagen: {e}", "danger")
        return redirect(url_for("index.index"))

    # GET
    try:
        status = index_svc.get_index_status()
    except Exception as e:
        log.warning("get_index_status failed: %s", e)
        status = {
            'count_indexed': 0,
            'last_indexed_at': None,
            'embedding_model': None,
            'collection_info': {
                'name': 'products',
                'vector_size': 0,
                'distance': 'COSINE',
                'points_count': 0,
                'hnsw_m': 16,
                'hnsw_ef_construct': 128,
            },
        }
    return render_template("index.html", status=status)


@bp.post("/truncate-index")
def truncate_index():
    """Truncate (delete and recreate) the Qdrant index"""
    try:
        index_svc = ServiceFactory.get_index_service()
        index_svc.truncate_index()
        flash("Index geleert", "success")
    except Exception as e:
        log.exception("truncate_index failed: %s", e)
        flash(f"Index-Leerung fehlgeschlagen: {e}", "danger")
    return redirect(url_for("index.index"))
