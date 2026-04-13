"""Audit route - View ETL run log"""
import logging
from flask import Blueprint, render_template, request

from services import ServiceFactory
from utils import _get_int

log = logging.getLogger(__name__)
bp = Blueprint("audit", __name__)


@bp.get("/audit")
def audit():
    """View ETL run log with pagination."""
    svc = ServiceFactory.get_product_service()
    page = _get_int(request.args, "page", 1)
    page_size = _get_int(request.args, "page_size", 10)
    result = svc.get_audit_log(page=page, page_size=page_size)
    return render_template("audit.html", result=result, page=page, page_size=page_size)
