"""RAG route - Retrieval-Augmented Generation with graph enrichment"""
import logging
from flask import Blueprint, flash, redirect, render_template, request, url_for

from services import ServiceFactory
from utils import _get_int

log = logging.getLogger(__name__)
bp = Blueprint("rag", __name__)


@bp.route("/rag", methods=["GET", "POST"])
def rag():
    """RAG search: vector retrieval + Neo4j graph enrichment + LLM answer"""
    query = ""
    topk = 5
    answer = None
    results = []

    if request.method == "POST":
        query = (request.form.get("query") or "").strip()
        topk = _get_int(request.form.get("topk"), default=5)
        topk = max(1, min(topk, 20))  # clamp 1–20

        if not query:
            flash("Bitte einen Suchbegriff eingeben.", "warning")
            return render_template("rag.html", query=query, topk=topk, answer=answer, results=results)

        try:
            svc = ServiceFactory.get_search_service()
            rag_result = svc.rag_search(strategy="C", query=query, topk=topk)
            answer = rag_result.get("answer")
            hits = rag_result.get("hits") or []
            # Map hits to template-expected shape: name field (template uses r.name or r.title)
            results = [
                {
                    'name': h.get('title', ''),
                    'title': h.get('title', ''),
                    'brand': h.get('brand', ''),
                    'category': h.get('category', ''),
                    'tags': h.get('tags') or [],
                    'price': h.get('price', 0),
                    'score': round(h.get('score', 0), 4),
                    'graph_source': h.get('graph_source'),
                    'doc_preview': h.get('doc_preview', ''),
                }
                for h in hits
            ]
            if not results:
                flash("Keine Ergebnisse — bitte zuerst den Index aufbauen unter /index.", "warning")
        except Exception as e:
            log.exception("RAG search failed for query=%r", query)
            flash(f"RAG-Fehler: {e}", "danger")

    return render_template("rag.html", query=query, topk=topk, answer=answer, results=results)


@bp.route("/graph-rag", methods=["GET", "POST"])
def graph_rag():
    """Redirect legacy /graph-rag to /rag"""
    return redirect(url_for("rag.rag"))
