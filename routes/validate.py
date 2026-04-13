"""Validate route - MySQL schema validation + stored procedure test"""
import logging
import db
import validation
from flask import Blueprint, render_template, flash, redirect, url_for, request
from services import ServiceFactory

log = logging.getLogger(__name__)
bp = Blueprint("validate", __name__)


@bp.route("/validate", methods=["GET", "POST"])
def validate():
    """Run validate_mysql() against the live MySQL engine and render results."""
    if db.mysql_engine is None:
        flash("MySQL engine nicht initialisiert — MYSQL_URL fehlt?", "danger")
        return redirect(url_for("dashboard.dashboard"))
    report = validation.validate_mysql(db.mysql_engine)

    # Fetch B-Tree index status for display (IDX-04 demonstration)
    indexes = []
    try:
        svc = ServiceFactory.get_product_service()
        indexes = svc.execute_sql_query(
            "SELECT index_name, column_name, non_unique, index_type "
            "FROM information_schema.statistics "
            "WHERE table_schema = 'projectdb' AND table_name = 'products' "
            "ORDER BY index_name, seq_in_index"
        )
    except Exception:
        pass  # Non-blocking — schema validation still works if index query fails

    return render_template("validation_result.html", report=report, indexes=indexes)


@bp.route("/validate/procedure", methods=["GET", "POST"])
def validate_procedure():
    """Test import_product() stored procedure with form inputs.

    Demonstrates A4: stored procedure with validation, error handling,
    and OUT parameters. The form lets the grader deliberately trigger each
    result code (0=success, 1=duplicate, 2=validation error, 3=db error).
    """
    result = None
    form_data = {}
    if request.method == "POST":
        form_data = {
            "name": request.form.get("name", "").strip(),
            "description": request.form.get("description", ""),
            "brand_name": request.form.get("brand_name", ""),
            "category_name": request.form.get("category_name", ""),
            "price": request.form.get("price", "0"),
            "sku": request.form.get("sku", ""),
            "load_class": request.form.get("load_class", ""),
            "application": request.form.get("application", ""),
        }
        try:
            svc = ServiceFactory.get_product_service()
            result = svc.import_product(
                name=form_data["name"],
                description=form_data["description"],
                brand_name=form_data["brand_name"],
                category_name=form_data["category_name"],
                price=float(form_data["price"] or 0),
                sku=form_data["sku"],
                load_class=form_data["load_class"],
                application=form_data["application"],
            )
        except Exception as e:
            result = {"result_code": 3, "result_message": str(e)}
    return render_template("validate_procedure.html", result=result, form_data=form_data)
