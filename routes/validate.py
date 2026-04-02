"""Validate route - MySQL schema validation"""
import logging
import db
import validation
from flask import Blueprint, render_template, flash, redirect, url_for

log = logging.getLogger(__name__)
bp = Blueprint("validate", __name__)


@bp.post("/validate")
def validate():
    """Run validate_mysql() against the live MySQL engine and render results."""
    if db.mysql_engine is None:
        flash("MySQL engine nicht initialisiert — MYSQL_URL fehlt?", "danger")
        return redirect(url_for("dashboard.dashboard"))
    report = validation.validate_mysql(db.mysql_engine)
    return render_template("validation_result.html", report=report)
