"""
Savings Calculator Service

Calculates potential savings for receipt items by comparing receipt prices
against current deal prices in the database.

Shows users how much they COULD save if they used deals on this platform.

Now includes unit-aware comparison for accurate savings calculation
when comparing different package sizes (e.g., 2L vs 1L milk).
"""

import logging
from decimal import Decimal
from typing import Dict, Any, Optional, List
from django.utils import timezone

from core.db_router import get_grocery_saving_connection
from .unit_normalizer import get_unit_aware_savings, extract_unit_info

logger = logging.getLogger(__name__)


# =============================================================================
# TABLE NAMES (validated constants to prevent SQL injection)
# =============================================================================

DEAL_TABLE = 'products_deal'


# =============================================================================
# CONSTANTS
# =============================================================================

# Valid deal statuses for price comparison
VALID_DEAL_STATUSES = ('MANUALLY_ADDED', 'AUTO_VERIFIED', 'HUMAN_VERIFIED', 'active')


# =============================================================================
# PRICE LOOKUP
# =============================================================================

def get_product_current_price(product_id: str) -> Optional[Decimal]:
    """
    Get the current best (lowest) price for a product from active deals.

    Looks up active deals where:
    - Deal is currently active (start_date <= now <= end_date)
    - Deal has a valid status

    Returns:
        The lowest discounted_price from active deals, or None if no active deals.
    """
    if not product_id:
        return None

    now = timezone.now()
    connection = get_grocery_saving_connection()

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT MIN(discounted_price)
            FROM {DEAL_TABLE}
            WHERE product_id = %s
              AND start_date <= %s
              AND end_date >= %s
              AND status IN %s
            """,
            [product_id, now, now, VALID_DEAL_STATUSES]
        )

        result = cursor.fetchone()
        if result and result[0] is not None:
            return Decimal(str(result[0])).quantize(Decimal('0.01'))

    return None


def get_product_prices_batch(product_ids: List[str]) -> Dict[str, Optional[Decimal]]:
    """
    Get current best prices for multiple products in a single query.

    More efficient than calling get_product_current_price for each product.

    Returns:
        Dict mapping product_id to lowest price (or None if no active deal)
    """
    if not product_ids:
        return {}

    # Filter out empty/None values
    valid_ids = [pid for pid in product_ids if pid]
    if not valid_ids:
        return {}

    now = timezone.now()
    connection = get_grocery_saving_connection()

    with connection.cursor() as cursor:
        placeholders = ','.join(['%s'] * len(valid_ids))
        cursor.execute(
            f"""
            SELECT product_id::text, MIN(discounted_price)
            FROM {DEAL_TABLE}
            WHERE product_id::text IN ({placeholders})
              AND start_date <= %s
              AND end_date >= %s
              AND status IN %s
            GROUP BY product_id
            """,
            valid_ids + [now, now, VALID_DEAL_STATUSES]
        )

        result = {}
        for row in cursor.fetchall():
            product_id, min_price = row
            if min_price:
                result[str(product_id)] = Decimal(str(min_price)).quantize(Decimal('0.01'))
            else:
                result[str(product_id)] = None

        # Fill in None for products not found
        for pid in valid_ids:
            if pid not in result:
                result[pid] = None

        return result


def get_product_info_batch(product_ids: List[str]) -> Dict[str, Dict[str, Any]]:
    """
    Get product information (name, price) for multiple products.

    Returns:
        Dict mapping product_id to dict with 'name' and 'price' keys.
    """
    if not product_ids:
        return {}

    valid_ids = [pid for pid in product_ids if pid]
    if not valid_ids:
        return {}

    now = timezone.now()
    connection = get_grocery_saving_connection()

    with connection.cursor() as cursor:
        placeholders = ','.join(['%s'] * len(valid_ids))
        # Join products and deals to get both name and best price
        cursor.execute(
            f"""
            SELECT
                p.id::text,
                p.name,
                MIN(d.discounted_price) as best_price
            FROM products_product p
            LEFT JOIN {DEAL_TABLE} d ON d.product_id = p.id
                AND d.start_date <= %s
                AND d.end_date >= %s
                AND d.status IN %s
            WHERE p.id::text IN ({placeholders})
            GROUP BY p.id, p.name
            """,
            [now, now, VALID_DEAL_STATUSES] + valid_ids
        )

        result = {}
        for row in cursor.fetchall():
            product_id, name, price = row
            result[str(product_id)] = {
                'name': name or '',
                'price': Decimal(str(price)).quantize(Decimal('0.01')) if price else None
            }

        # Fill in empty for products not found
        for pid in valid_ids:
            if pid not in result:
                result[pid] = {'name': '', 'price': None}

        return result


# =============================================================================
# SAVINGS CALCULATION
# =============================================================================

def calculate_item_savings(
    receipt_unit_price: Optional[Decimal],
    database_price: Optional[Decimal],
    quantity: Optional[Decimal]
) -> Dict[str, Decimal]:
    """
    Calculate potential savings for a single item.

    Shows how much the user COULD have saved if they used deals on this platform.
    Only calculates savings when user paid MORE than the database deal price.

    Formula: (receipt_unit_price - database_price) * quantity
             (only if receipt_price > database_price)

    Returns:
        Dict with 'saving_per_unit' and 'total_saving' (always >= 0)
    """
    zero = Decimal('0.00')

    # Handle missing values
    if receipt_unit_price is None or database_price is None or quantity is None:
        return {
            'saving_per_unit': zero,
            'total_saving': zero
        }

    # Ensure Decimal types
    receipt_price = Decimal(str(receipt_unit_price))
    db_price = Decimal(str(database_price))
    qty = Decimal(str(quantity))

    # Only show savings if user paid MORE than the deal price
    # (i.e., they could have saved money by using this platform)
    if receipt_price <= db_price:
        return {
            'saving_per_unit': zero,
            'total_saving': zero
        }

    # Calculate how much user could have saved
    saving_per_unit = receipt_price - db_price
    total_saving = saving_per_unit * qty

    return {
        'saving_per_unit': saving_per_unit.quantize(Decimal('0.01')),
        'total_saving': total_saving.quantize(Decimal('0.01'))
    }


def calculate_receipt_savings(
    items: List[Dict[str, Any]]
) -> Dict[str, Any]:
    """
    Calculate total potential savings for all matched items in a receipt.

    Shows users how much they COULD have saved if they used deals on this platform.

    For each item with a matched_product_id:
    1. Look up current best deal price AND product name
    2. Compare prices using unit-aware comparison (handles 2L vs 1L etc.)
    3. If user paid MORE than deal price per unit, calculate potential savings

    Args:
        items: List of receipt items with:
            - matched_product_id: Product UUID string
            - description: Receipt item description (e.g., "MILK 2% 2L")
            - unit_price: Price paid per unit
            - quantity: Number of units

    Returns:
        Dict with:
            - total_savings: Sum of potential savings (user could have saved)
            - items_with_savings: Count of items where user could have saved
            - items: List with savings data added to each item
    """
    if not items:
        return {
            'total_savings': Decimal('0.00'),
            'items_with_savings': 0,
            'items': []
        }

    # Get all product IDs for batch lookup
    product_ids = [
        item.get('matched_product_id')
        for item in items
        if item.get('matched_product_id')
    ]

    # Batch fetch product info (name + price) for unit-aware comparison
    product_info = get_product_info_batch(product_ids)

    total_savings = Decimal('0.00')
    items_with_savings = 0
    items_processed = []

    for item in items:
        product_id = item.get('matched_product_id')
        unit_price = item.get('unit_price')
        quantity = item.get('quantity', Decimal('1'))
        receipt_description = item.get('description', '')

        # Ensure Decimal types
        if unit_price is not None:
            unit_price = Decimal(str(unit_price))
        if quantity is not None:
            quantity = Decimal(str(quantity))

        # Get product info (name + price) from database
        db_info = product_info.get(product_id, {}) if product_id else {}
        database_price = db_info.get('price')
        database_description = db_info.get('name', '')

        # Calculate potential savings using unit-aware comparison
        if database_price and unit_price:
            # Use unit-aware savings calculation
            savings = get_unit_aware_savings(
                receipt_unit_price=unit_price,
                receipt_description=receipt_description,
                database_price=database_price,
                database_description=database_description,
                quantity=quantity
            )

            # Track items where user could have saved
            if savings['total_saving'] > 0:
                items_with_savings += 1
                total_savings += savings['total_saving']

            items_processed.append({
                **item,
                'database_price': database_price,
                'saving_per_unit': savings['saving_per_unit'],
                'total_saving': savings['total_saving']
            })
        else:
            items_processed.append({
                **item,
                'database_price': database_price,
                'saving_per_unit': Decimal('0.00'),
                'total_saving': Decimal('0.00')
            })

    return {
        'total_savings': total_savings.quantize(Decimal('0.01')),
        'items_with_savings': items_with_savings,
        'items': items_processed
    }
