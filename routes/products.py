"""Products route — CRUD for products with transaction-safe operations"""
import logging
from flask import Blueprint, render_template, request, redirect, url_for, flash, abort

from sqlalchemy.exc import IntegrityError

from services import ServiceFactory
from utils import _get_int

log = logging.getLogger(__name__)
bp = Blueprint("products", __name__)


@bp.get("/products")
def products():
    """List products with brand, category, and tags (paginated)"""
    page = _get_int(request.args.get("page"), 1, min_value=1)
    page_size = _get_int(request.args.get("page_size"), 20, min_value=5, max_value=100)
    svc = ServiceFactory.get_product_service()
    result = svc.list_products_joined(page=page, page_size=page_size)
    total = result.get("total", 0)
    total_pages = max(1, (total + page_size - 1) // page_size)
    return render_template(
        "products.html",
        result=result,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )


@bp.get("/products/new")
def new_product():
    """Render empty create form"""
    svc = ServiceFactory.get_product_service()
    return render_template(
        "product_form.html",
        mode="create",
        brands=svc.get_brands(),
        categories=svc.get_categories(),
        form_data={},
    )


@bp.post("/products/new")
def create_product():
    """Handle product create form submission"""
    svc = ServiceFactory.get_product_service()
    name = request.form.get("name", "").strip()
    sku = request.form.get("sku", "").strip() or None
    price_raw = request.form.get("price", "")
    brand_id = request.form.get("brand_id")
    category_id = request.form.get("category_id")
    tags_str = request.form.get("tags_str", "")

    form_data = {
        "name": name,
        "sku": sku or "",
        "price": price_raw,
        "brand_id": brand_id,
        "category_id": category_id,
        "tags_str": tags_str,
    }

    # Basic validation
    if not name or not brand_id or not category_id or not price_raw:
        flash("Name, Marke, Kategorie und Preis sind Pflichtfelder.", "danger")
        return render_template(
            "product_form.html",
            mode="create",
            brands=svc.get_brands(),
            categories=svc.get_categories(),
            form_data=form_data,
        )

    try:
        price = float(price_raw)
    except ValueError:
        flash("Ungültiger Preis.", "danger")
        return render_template(
            "product_form.html",
            mode="create",
            brands=svc.get_brands(),
            categories=svc.get_categories(),
            form_data=form_data,
        )

    try:
        svc.create_product_with_relations(
            name=name,
            sku=sku,
            price=price,
            brand_id=int(brand_id),
            category_id=int(category_id),
            tags_str=tags_str,
        )
        flash("Produkt erfolgreich angelegt.", "success")
        return redirect(url_for("products.products"))
    except IntegrityError:
        # Rollback already done by SQLAlchemy — TXN-04 visible here
        flash("Datenbankfehler: Produkt konnte nicht angelegt werden (z.B. doppelte SKU).", "danger")
        return render_template(
            "product_form.html",
            mode="create",
            brands=svc.get_brands(),
            categories=svc.get_categories(),
            form_data=form_data,
        )


@bp.get("/products/<int:product_id>/edit")
def edit_product(product_id: int):
    """Render pre-filled edit form"""
    svc = ServiceFactory.get_product_service()
    product = svc.get_product_by_id(product_id)
    if product is None:
        abort(404)
    return render_template(
        "product_form.html",
        mode="edit",
        brands=svc.get_brands(),
        categories=svc.get_categories(),
        form_data=product,
        product_id=product_id,
    )


@bp.post("/products/<int:product_id>/edit")
def update_product(product_id: int):
    """Handle product update form submission"""
    svc = ServiceFactory.get_product_service()
    name = request.form.get("name", "").strip()
    price_raw = request.form.get("price", "")
    brand_id = request.form.get("brand_id")
    category_id = request.form.get("category_id")
    tags_str = request.form.get("tags_str", "")

    # Build form_data for re-render on error (SKU from existing product — read only)
    existing = svc.get_product_by_id(product_id)
    form_data = {
        "name": name,
        "sku": existing["sku"] if existing else "",
        "price": price_raw,
        "brand_id": brand_id,
        "category_id": category_id,
        "tags_str": tags_str,
    }

    if not name or not brand_id or not category_id or not price_raw:
        flash("Name, Marke, Kategorie und Preis sind Pflichtfelder.", "danger")
        return render_template(
            "product_form.html",
            mode="edit",
            brands=svc.get_brands(),
            categories=svc.get_categories(),
            form_data=form_data,
            product_id=product_id,
        )

    try:
        price = float(price_raw)
    except ValueError:
        flash("Ungültiger Preis.", "danger")
        return render_template(
            "product_form.html",
            mode="edit",
            brands=svc.get_brands(),
            categories=svc.get_categories(),
            form_data=form_data,
            product_id=product_id,
        )

    try:
        svc.update_product(
            product_id=product_id,
            name=name,
            price=price,
            brand_id=int(brand_id),
            category_id=int(category_id),
            tags_str=tags_str,
        )
        flash("Produkt erfolgreich aktualisiert.", "success")
        return redirect(url_for("products.products"))
    except IntegrityError:
        flash("Datenbankfehler: Produkt konnte nicht aktualisiert werden.", "danger")
        return render_template(
            "product_form.html",
            mode="edit",
            brands=svc.get_brands(),
            categories=svc.get_categories(),
            form_data=form_data,
            product_id=product_id,
        )


@bp.post("/products/<int:product_id>/delete")
def delete_product(product_id: int):
    """Handle product delete (single-click, no confirmation dialog)"""
    svc = ServiceFactory.get_product_service()
    try:
        svc.delete_product(product_id)
        flash("Produkt erfolgreich gelöscht.", "success")
    except IntegrityError:
        # TXN-05: referential integrity violation — product not deleted, rollback done by SQLAlchemy
        flash("Datenbankfehler: Produkt konnte nicht gelöscht werden (referenzielle Integrität).", "danger")
    return redirect(url_for("products.products"))
