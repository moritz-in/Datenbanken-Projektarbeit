"""Search route - Unified search interface"""
import logging
from flask import Blueprint, flash, render_template, request, redirect, url_for

from services import ServiceFactory
from utils import _get_int

log = logging.getLogger(__name__)
bp = Blueprint("search", __name__)


@bp.route("/search", methods=["GET", "POST"])
def search():
    """Unified search: vector, RAG, graph, PDF, SQL"""
    search_type = request.args.get("type") or request.form.get("type") or "vector"
    query = (
        request.form.get("query", "").strip()
        if request.method == "POST"
        else request.args.get("query", "")
    )
    topk = _get_int(request.form.get("topk"), 5)
    results = []
    answer = None

    if request.method == "POST" and query:
        try:
            search_svc = ServiceFactory.get_search_service()
            prod_svc = ServiceFactory.get_product_service()

            if search_type == "vector":
                results = search_svc.vector_search(query, topk=topk)
                if not results:
                    flash("Qdrant-Index leer — bitte zuerst Index aufbauen unter /index", "warning")

            elif search_type == "sql":
                results = prod_svc.execute_sql_query(query)

            elif search_type in ("rag", "graph", "pdf", "pdf_mgmt"):
                # Phase 4 methods — catch NotImplementedError, return empty results (no 501)
                try:
                    if search_type == "rag":
                        result = search_svc.rag_search("C", query, topk=topk)
                        results = result.get("hits", [])
                        answer = result.get("answer")
                    elif search_type == "graph":
                        result = search_svc.rag_search(
                            "C", query, topk=topk, use_graph_enrichment=True
                        )
                        results = result.get("hits", [])
                        answer = result.get("answer")
                    elif search_type == "pdf":
                        result = search_svc.pdf_rag_search(query, topk=topk)
                        results = (result or {}).get("hits", [])
                        answer = (result or {}).get("answer")
                    elif search_type == "pdf_mgmt":
                        results = search_svc.search_product_pdfs(query, topk=topk)
                except NotImplementedError:
                    results = []
                    answer = None

        except ValueError as e:
            flash(str(e), "danger")
        except Exception as e:
            log.exception("Search error: %s", e)
            flash(f"Suchfehler: {e}", "danger")

    return render_template(
        "search_unified.html",
        search_type=search_type,
        query=query,
        results=results,
        answer=answer,
    )
