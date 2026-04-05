"""Dashboard route - Main overview page"""
import logging
from flask import Blueprint, render_template

from services import ServiceFactory

log = logging.getLogger(__name__)
bp = Blueprint("dashboard", __name__)


@bp.get("/")
def dashboard():
    """Main dashboard with MySQL and Qdrant statistics"""
    svc = ServiceFactory.get_product_service()
    data = svc.get_dashboard_data()
    return render_template("dashboard.html", data=data)
