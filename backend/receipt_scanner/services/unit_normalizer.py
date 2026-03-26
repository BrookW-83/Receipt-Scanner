"""
Unit Normalizer Service

Extracts unit sizes from product descriptions and normalizes prices
for accurate comparison between different package sizes.

Examples:
- "MILK 2L" @ $5.99 → $2.995/L
- "MILK 1L" @ $3.50 → $3.50/L
- "CHEESE 500G" @ $6.99 → $13.98/kg
"""

import re
import logging
from decimal import Decimal
from typing import Optional, Tuple, Dict, Any

logger = logging.getLogger(__name__)


# =============================================================================
# UNIT PATTERNS
# =============================================================================

# Volume units (normalized to liters)
VOLUME_PATTERNS = [
    (r'(\d+(?:\.\d+)?)\s*(?:litre|liter|liters|litres|ltr|lt|l)\b', 'L', Decimal('1')),
    (r'(\d+(?:\.\d+)?)\s*(?:ml|millilitre|milliliter|millilitres|milliliters)\b', 'mL', Decimal('0.001')),
    (r'(\d+(?:\.\d+)?)\s*(?:gal|gallon|gallons)\b', 'gal', Decimal('3.78541')),  # to liters
]

# Weight units (normalized to kg)
WEIGHT_PATTERNS = [
    (r'(\d+(?:\.\d+)?)\s*(?:kg|kilogram|kilograms|kilo|kilos)\b', 'kg', Decimal('1')),
    (r'(\d+(?:\.\d+)?)\s*(?:g|gram|grams|gr)\b', 'g', Decimal('0.001')),
    (r'(\d+(?:\.\d+)?)\s*(?:lb|lbs|pound|pounds)\b', 'lb', Decimal('0.453592')),  # to kg
    (r'(\d+(?:\.\d+)?)\s*(?:oz|ounce|ounces)\b', 'oz', Decimal('0.0283495')),  # to kg
]

# Count units (normalized to each)
COUNT_PATTERNS = [
    (r'(\d+)\s*(?:pk|pack|packs|ct|count)\b', 'pack', Decimal('1')),
    (r'(\d+)\s*(?:pc|pcs|piece|pieces)\b', 'piece', Decimal('1')),
    (r'x\s*(\d+)\b', 'x', Decimal('1')),  # "6 x 330ml" format
]


# =============================================================================
# UNIT EXTRACTION
# =============================================================================

def extract_unit_info(description: str) -> Optional[Dict[str, Any]]:
    """
    Extract unit information from product description.

    Returns:
        Dict with:
        - value: The numeric value (e.g., 2 for "2L")
        - unit: The unit type (e.g., "L")
        - category: "volume", "weight", or "count"
        - normalized_value: Value converted to base unit (L, kg, or each)

        None if no unit found.
    """
    if not description:
        return None

    desc_lower = description.lower()

    # Try volume patterns
    for pattern, unit, multiplier in VOLUME_PATTERNS:
        match = re.search(pattern, desc_lower, re.IGNORECASE)
        if match:
            value = Decimal(match.group(1))
            return {
                'value': value,
                'unit': unit,
                'category': 'volume',
                'normalized_value': value * multiplier,
                'base_unit': 'L'
            }

    # Try weight patterns
    for pattern, unit, multiplier in WEIGHT_PATTERNS:
        match = re.search(pattern, desc_lower, re.IGNORECASE)
        if match:
            value = Decimal(match.group(1))
            return {
                'value': value,
                'unit': unit,
                'category': 'weight',
                'normalized_value': value * multiplier,
                'base_unit': 'kg'
            }

    # Try count patterns
    for pattern, unit, multiplier in COUNT_PATTERNS:
        match = re.search(pattern, desc_lower, re.IGNORECASE)
        if match:
            value = Decimal(match.group(1))
            return {
                'value': value,
                'unit': unit,
                'category': 'count',
                'normalized_value': value * multiplier,
                'base_unit': 'each'
            }

    return None


# =============================================================================
# PRICE NORMALIZATION
# =============================================================================

def normalize_price_per_unit(
    price: Optional[Decimal],
    description: str
) -> Tuple[Optional[Decimal], Optional[str]]:
    """
    Normalize price to per-unit basis (per L, per kg, or per each).

    Args:
        price: Total price for the item
        description: Product description containing unit info

    Returns:
        Tuple of (normalized_price_per_base_unit, base_unit)
        Returns (None, None) if unable to normalize
    """
    if price is None:
        return None, None

    unit_info = extract_unit_info(description)

    if unit_info is None or unit_info['normalized_value'] == 0:
        # No unit info found - return original price as "per item"
        return price, 'item'

    # Calculate price per base unit
    normalized_price = price / unit_info['normalized_value']

    return normalized_price.quantize(Decimal('0.0001')), unit_info['base_unit']


def calculate_comparable_savings(
    receipt_price: Optional[Decimal],
    receipt_description: str,
    database_price: Optional[Decimal],
    database_description: str,
    quantity: Decimal = Decimal('1')
) -> Dict[str, Any]:
    """
    Calculate savings with unit-aware price comparison.

    Normalizes both prices to the same unit before comparing.

    Returns:
        Dict with:
        - comparable: bool - whether prices are comparable
        - receipt_normalized_price: price per base unit from receipt
        - database_normalized_price: price per base unit from database
        - saving_per_base_unit: savings per base unit
        - total_saving: total savings for quantity purchased
        - base_unit: the unit used for comparison
        - reason: explanation if not comparable
    """
    result = {
        'comparable': False,
        'receipt_normalized_price': None,
        'database_normalized_price': None,
        'saving_per_base_unit': Decimal('0'),
        'total_saving': Decimal('0'),
        'base_unit': None,
        'reason': None
    }

    if receipt_price is None or database_price is None:
        result['reason'] = 'Missing price data'
        return result

    # Normalize both prices
    receipt_norm, receipt_unit = normalize_price_per_unit(receipt_price, receipt_description)
    database_norm, database_unit = normalize_price_per_unit(database_price, database_description)

    if receipt_norm is None or database_norm is None:
        result['reason'] = 'Unable to normalize prices'
        return result

    # Check if units are compatible
    if receipt_unit != database_unit:
        # Units don't match - can't compare directly
        # Fall back to per-item comparison if both are "item"
        if receipt_unit == 'item' and database_unit == 'item':
            pass  # Continue with comparison
        else:
            result['reason'] = f'Incompatible units: {receipt_unit} vs {database_unit}'
            # Still try to compare, but flag it
            logger.debug(f"Unit mismatch: receipt={receipt_unit}, database={database_unit}")

    result['receipt_normalized_price'] = receipt_norm
    result['database_normalized_price'] = database_norm
    result['base_unit'] = receipt_unit
    result['comparable'] = True

    # Calculate savings only if receipt price is higher
    if receipt_norm > database_norm:
        # Get the quantity in base units from receipt
        receipt_unit_info = extract_unit_info(receipt_description)
        base_quantity = receipt_unit_info['normalized_value'] if receipt_unit_info else Decimal('1')

        # Savings per base unit
        saving_per_base = receipt_norm - database_norm

        # Total savings = (savings per base unit) * (base units purchased) * quantity
        total_saving = saving_per_base * base_quantity * quantity

        result['saving_per_base_unit'] = saving_per_base.quantize(Decimal('0.01'))
        result['total_saving'] = total_saving.quantize(Decimal('0.01'))

    return result


# =============================================================================
# HELPERS FOR SAVINGS CALCULATOR
# =============================================================================

def get_unit_aware_savings(
    receipt_unit_price: Optional[Decimal],
    receipt_description: str,
    database_price: Optional[Decimal],
    database_description: str,
    quantity: Decimal = Decimal('1')
) -> Dict[str, Decimal]:
    """
    Wrapper for savings_calculator that handles unit differences.

    Returns dict with 'saving_per_unit' and 'total_saving' keys,
    same as the original calculate_item_savings function.
    """
    zero = Decimal('0.00')

    result = calculate_comparable_savings(
        receipt_price=receipt_unit_price,
        receipt_description=receipt_description,
        database_price=database_price,
        database_description=database_description,
        quantity=quantity
    )

    if not result['comparable']:
        logger.debug(f"Not comparable: {result['reason']}")
        return {
            'saving_per_unit': zero,
            'total_saving': zero,
            'comparison_note': result['reason']
        }

    return {
        'saving_per_unit': result['saving_per_base_unit'],
        'total_saving': result['total_saving'],
        'comparison_note': f"Compared at {result['base_unit']} level"
    }
