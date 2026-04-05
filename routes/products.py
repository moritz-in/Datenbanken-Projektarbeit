"""Products route - List products with pagination"""
import logging
from flask import Blueprint, render_template, request

from services import ServiceFactory
from utils import _get_int

log = logging.getLogger(__name__)
bp = Blueprint("products", __name__)


@bp.get("/products")
def products():
    """List products with brand, category, and tags"""
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
