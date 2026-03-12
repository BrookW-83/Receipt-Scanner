"""
Promo Checker Service

Checks if products were on promotion at the time of purchase
and calculates missed savings.
"""

import logging
from decimal import Decimal
from datetime import date, datetime
from typing import Dict, Any, Optional, List

from core.db_router import get_grocery_saving_connection

logger = logging.getLogger(__name__)


# =============================================================================
# TABLE NAMES (validated constants to prevent SQL injection)
# =============================================================================

DEAL_TABLE = 'products_deal'
STORE_TABLE = 'stores_store'


# =============================================================================
# CONSTANTS
# =============================================================================

# Valid deal statuses for promo checking
VALID_DEAL_STATUSES = ('MANUALLY_ADDED', 'AUTO_VERIFIED', 'HUMAN_VERIFIED')


# =============================================================================
# PROMO LOOKUP
# =============================================================================

def check_promo_on_date(
    product_id: str,
    purchase_date: date
) -> Optional[Dict[str, Any]]:
    """
    Check if a product was on promotion on a specific date.

    Looks for active deals where:
    - start_date <= purchase_date <= end_date
    - Deal has a valid status

    Returns:
        Dict with deal info if promo existed:
        {
            'deal_id': str,
            'promo_price': Decimal,
            'original_price': Decimal or None,
            'discount_percentage': float or None,
            'store_name': str
        }
        Returns None if no promo was active.
    """
    if not product_id or not purchase_date:
        return None

    # Convert date to datetime for comparison
    if isinstance(purchase_date, datetime):
        check_date = purchase_date.date()
    else:
        check_date = purchase_date

    connection = get_grocery_saving_connection()

    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT
                d.id::text,
                d.discounted_price,
                d.original_price,
                CASE
                    WHEN d.original_price > 0 THEN
                        ROUND(((d.original_price - d.discounted_price) / d.original_price) * 100, 2)
                    ELSE NULL
                END as discount_pct,
                s.name as store_name
            FROM {DEAL_TABLE} d
            JOIN {STORE_TABLE} s ON d.store_id = s.id
            WHERE d.product_id = %s
              AND d.start_date::date <= %s
              AND d.end_date::date >= %s
              AND d.status IN %s
            ORDER BY d.discounted_price ASC
            LIMIT 1
            """,
            [product_id, check_date, check_date, VALID_DEAL_STATUSES]
        )

        result = cursor.fetchone()
        if result:
            deal_id, discounted_price, original_price, discount_pct, store_name = result
            return {
                'deal_id': str(deal_id),
                'promo_price': Decimal(str(discounted_price)).quantize(Decimal('0.01')),
                'original_price': Decimal(str(original_price)).quantize(Decimal('0.01')) if original_price else None,
                'discount_percentage': float(discount_pct) if discount_pct else None,
                'store_name': store_name
            }

    return None


def check_promos_batch(
    product_ids: List[str],
    purchase_date: date
) -> Dict[str, Optional[Dict[str, Any]]]:
    """
    Check promos for multiple products on a specific date in a single query.

    More efficient than calling check_promo_on_date for each product.

    Returns:
        Dict mapping product_id to promo info (or None if no promo)
    """
    if not product_ids or not purchase_date:
        return {}

    # Filter out empty/None values
    valid_ids = [pid for pid in product_ids if pid]
    if not valid_ids:
        return {}

    # Convert date
    if isinstance(purchase_date, datetime):
        check_date = purchase_date.date()
    else:
        check_date = purchase_date

    connection = get_grocery_saving_connection()

    with connection.cursor() as cursor:
        placeholders = ','.join(['%s'] * len(valid_ids))

        # Get best (lowest) promo price for each product
        cursor.execute(
            f"""
            SELECT DISTINCT ON (d.product_id)
                d.product_id::text,
                d.id::text as deal_id,
                d.discounted_price,
                d.original_price,
                CASE
                    WHEN d.original_price > 0 THEN
                        ROUND(((d.original_price - d.discounted_price) / d.original_price) * 100, 2)
                    ELSE NULL
                END as discount_pct,
                s.name as store_name
            FROM {DEAL_TABLE} d
            JOIN {STORE_TABLE} s ON d.store_id = s.id
            WHERE d.product_id::text IN ({placeholders})
              AND d.start_date::date <= %s
              AND d.end_date::date >= %s
              AND d.status IN %s
            ORDER BY d.product_id, d.discounted_price ASC
            """,
            valid_ids + [check_date, check_date, VALID_DEAL_STATUSES]
        )

        result = {}
        for row in cursor.fetchall():
            (product_id, deal_id, discounted_price,
             original_price, discount_pct, store_name) = row
            result[str(product_id)] = {
                'deal_id': str(deal_id),
                'promo_price': Decimal(str(discounted_price)).quantize(Decimal('0.01')),
                'original_price': Decimal(str(original_price)).quantize(Decimal('0.01')) if original_price else None,
                'discount_percentage': float(discount_pct) if discount_pct else None,
                'store_name': store_name
            }

        # Fill in None for products not found
        for pid in valid_ids:
            if pid not in result:
                result[pid] = None

        return result


# =============================================================================
# MISSED SAVINGS CALCULATION
# =============================================================================

def calculate_missed_savings(
    receipt_price: Optional[Decimal],
    promo_price: Optional[Decimal],
    quantity: Optional[Decimal]
) -> Decimal:
    """
    Calculate how much user could have saved with promo price.

    If user paid more than the promo price, returns the difference * quantity.
    If user got a price equal to or better than promo, returns 0.

    Args:
        receipt_price: Price user actually paid per unit
        promo_price: Promotional price that was available
        quantity: Number of units purchased

    Returns:
        Missed savings amount (always >= 0)
    """
    zero = Decimal('0.00')

    if receipt_price is None or promo_price is None or quantity is None:
        return zero

    # Ensure Decimal types
    receipt = Decimal(str(receipt_price))
    promo = Decimal(str(promo_price))
    qty = Decimal(str(quantity))

    # User already got equal or better price
    if receipt <= promo:
        return zero

    missed = (receipt - promo) * qty
    return missed.quantize(Decimal('0.01'))


# =============================================================================
# RECEIPT PROMO CHECKING
# =============================================================================

def check_receipt_promos(
    items: List[Dict[str, Any]],
    purchase_date: Optional[date] = None
) -> Dict[str, Any]:
    """
    Check all matched items for missed promotions.

    For each item with a matched_product_id:
    1. Check if product was on promo on purchase date
    2. Calculate missed savings if user paid more than promo price

    Args:
        items: List of receipt items with:
            - matched_product_id: Product UUID string
            - unit_price: Price paid per unit
            - quantity: Number of units
        purchase_date: Date of purchase (defaults to today if None)

    Returns:
        Dict with:
            - total_missed_savings: Sum of all missed savings
            - items_with_missed_promos: Count of items with missed promos
            - items: List with promo data added to each item
    """
    if not items:
        return {
            'total_missed_savings': Decimal('0.00'),
            'items_with_missed_promos': 0,
            'items': []
        }

    # Default to today if no date provided
    if purchase_date is None:
        purchase_date = date.today()

    # Get all product IDs for batch lookup
    product_ids = [
        item.get('matched_product_id')
        for item in items
        if item.get('matched_product_id')
    ]

    # Batch fetch promos
    promos = check_promos_batch(product_ids, purchase_date)

    total_missed = Decimal('0.00')
    items_with_missed_promos = 0
    items_processed = []

    for item in items:
        product_id = item.get('matched_product_id')
        unit_price = item.get('unit_price')
        quantity = item.get('quantity', Decimal('1'))

        # Ensure Decimal types
        if unit_price is not None:
            unit_price = Decimal(str(unit_price))
        if quantity is not None:
            quantity = Decimal(str(quantity))

        # Check if product was on promo
        promo = promos.get(product_id) if product_id else None

        if promo and unit_price:
            missed = calculate_missed_savings(
                unit_price,
                promo['promo_price'],
                quantity
            )

            items_processed.append({
                **item,
                'was_on_promo': True,
                'promo_price': promo['promo_price'],
                'missed_savings': missed,
                'promo_deal_id': promo['deal_id'],
                'promo_store': promo['store_name'],
                'promo_discount_pct': promo['discount_percentage']
            })

            if missed > 0:
                items_with_missed_promos += 1
                total_missed += missed
        else:
            items_processed.append({
                **item,
                'was_on_promo': False,
                'promo_price': None,
                'missed_savings': Decimal('0.00'),
                'promo_deal_id': None,
                'promo_store': None,
                'promo_discount_pct': None
            })

    return {
        'total_missed_savings': total_missed.quantize(Decimal('0.01')),
        'items_with_missed_promos': items_with_missed_promos,
        'items': items_processed
    }
