"""PDF route - PDF upload and management"""
import logging
from flask import Blueprint, flash, jsonify, redirect, render_template, request, url_for

from services import ServiceFactory

log = logging.getLogger(__name__)
bp = Blueprint("pdf", __name__)


@bp.route("/pdf-upload", methods=["GET"])
def pdf_upload():
    """PDF upload page — counts are loaded via JS fetch to /api/pdf-stats"""
    try:
        ServiceFactory.get_pdf_service()  # warm up (no-op if already initialized)
    except Exception as e:
        log.warning("pdf_upload: service init warning: %s", e)
    return render_template("pdf_upload.html")


@bp.post("/upload-teaching-pdf")
def upload_teaching_pdf():
    """Upload a teaching PDF to Qdrant"""
    pdf_file = request.files.get('pdf_file')
    if not pdf_file or pdf_file.filename == '':
        flash("Keine Datei ausgewählt", "warning")
        return redirect(url_for('pdf.pdf_upload'))
    if not pdf_file.filename.lower().endswith('.pdf'):
        flash("Nur PDF-Dateien erlaubt", "danger")
        return redirect(url_for('pdf.pdf_upload'))
    try:
        pdf_svc = ServiceFactory.get_pdf_service()
        msg = pdf_svc.upload_pdf_to_qdrant(pdf_file, collection_name='pdf_skripte')
        flash(msg, "success")
    except Exception as e:
        log.exception("upload_teaching_pdf failed: %s", e)
        flash(f"Upload fehlgeschlagen: {e}", "danger")
    return redirect(url_for('pdf.pdf_upload'))


@bp.post("/upload-product-pdf")
def upload_product_pdf():
    """Upload a product PDF to Qdrant"""
    pdf_file = request.files.get('pdf_file')
    if not pdf_file or pdf_file.filename == '':
        flash("Keine Datei ausgewählt", "warning")
        return redirect(url_for('pdf.pdf_upload'))
    if not pdf_file.filename.lower().endswith('.pdf'):
        flash("Nur PDF-Dateien erlaubt", "danger")
        return redirect(url_for('pdf.pdf_upload'))
    try:
        pdf_svc = ServiceFactory.get_pdf_service()
        msg = pdf_svc.upload_product_pdf(pdf_file)
        flash(msg, "success")
    except Exception as e:
        log.exception("upload_product_pdf failed: %s", e)
        flash(f"Upload fehlgeschlagen: {e}", "danger")
    return redirect(url_for('pdf.pdf_upload'))


@bp.route("/api/pdf-stats")
def get_pdf_stats():
    """API endpoint: Get PDF statistics for admin page"""
    try:
        pdf_svc = ServiceFactory.get_pdf_service()
        counts = pdf_svc.get_pdf_counts()
        return jsonify({
            'pdf_skripte': counts.get('pdf_skripte', 0),
            'pdf_produkte': counts.get('pdf_produkte', 0),
        })
    except Exception as e:
        log.warning("get_pdf_stats error: %s", e)
        return jsonify({'pdf_skripte': 0, 'pdf_produkte': 0})
