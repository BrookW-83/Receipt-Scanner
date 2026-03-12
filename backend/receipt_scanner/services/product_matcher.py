"""
Product Matching Service

Uses PostgreSQL pg_trgm extension for fuzzy trigram matching
to match receipt item descriptions against the Product database.
"""

import logging
import re
from functools import lru_cache
from typing import List, Dict, Any, Optional

from core.db_router import get_grocery_saving_connection

logger = logging.getLogger(__name__)


# =============================================================================
# TABLE NAMES (validated constants to prevent SQL injection)
# =============================================================================

# These are validated table names - never interpolate user input into SQL
PRODUCT_TABLE = 'products_product'


# =============================================================================
# CONFIGURATION
# =============================================================================

# Confidence thresholds for trigram similarity
HIGH_CONFIDENCE_THRESHOLD = 0.8
MEDIUM_CONFIDENCE_THRESHOLD = 0.5
MIN_MATCH_THRESHOLD = 0.3

# Weighting for combined similarity score
PRODUCTNAME_WEIGHT = 0.6  # Concise product name gets highest weight
NAME_WEIGHT = 0.3         # Full name with size
BRAND_WEIGHT = 0.1        # Brand name


# =============================================================================
# NORMALIZATION
# =============================================================================

# Common receipt abbreviations to expand
ABBREVIATION_MAP = {
    r'\bpkg\b': 'package',
    r'\bpcs\b': 'pieces',
    r'\bqty\b': 'quantity',
    r'\bwt\b': 'weight',
    r'\borg\b': 'organic',
    r'\breg\b': 'regular',
    r'\bsm\b': 'small',
    r'\bmd\b': 'medium',
    r'\blg\b': 'large',
    r'\bxl\b': 'extra large',
    r'\bwhl\b': 'whole',
    r'\bgrn\b': 'green',
    r'\bred\b': 'red',
    r'\bwht\b': 'white',
    r'\bbrn\b': 'brown',
    r'\bchkn\b': 'chicken',
    r'\bbf\b': 'beef',
    r'\bprk\b': 'pork',
    r'\bveg\b': 'vegetable',
    r'\bfrt\b': 'fruit',
    r'\bmlk\b': 'milk',
    r'\bbrd\b': 'bread',
}


def normalize_product_name(name: str) -> str:
    """
    Normalize product name for better matching.

    - Convert to lowercase
    - Expand common abbreviations
    - Remove extra whitespace
    - Remove special characters (except alphanumeric and spaces)
    """
    if not name:
        return ""

    normalized = name.lower().strip()

    # Expand abbreviations
    for pattern, replacement in ABBREVIATION_MAP.items():
        normalized = re.sub(pattern, replacement, normalized, flags=re.IGNORECASE)

    # Remove special characters but keep alphanumeric, spaces, and basic punctuation
    normalized = re.sub(r'[^\w\s\-\.]', '', normalized)

    # Normalize whitespace
    normalized = re.sub(r'\s+', ' ', normalized).strip()

    return normalized


# =============================================================================
# CONFIDENCE SCORING
# =============================================================================

def get_confidence_level(score: float) -> str:
    """Map similarity score to confidence level."""
    if score >= HIGH_CONFIDENCE_THRESHOLD:
        return 'high'
    elif score >= MEDIUM_CONFIDENCE_THRESHOLD:
        return 'medium'
    elif score >= MIN_MATCH_THRESHOLD:
        return 'low'
    return 'no_match'


# =============================================================================
# MATCHING FUNCTIONS
# =============================================================================

@lru_cache(maxsize=1)
def check_pg_trgm_available() -> bool:
    """
    Check if pg_trgm extension is available.

    Result is cached for the lifetime of the process since
    extension availability doesn't change at runtime.
    """
    try:
        connection = get_grocery_saving_connection()
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT EXISTS(
                    SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm'
                );
            """)
            result = cursor.fetchone()[0]
            logger.info(f"pg_trgm extension available: {result}")
            return result
    except Exception as e:
        logger.warning(f"Error checking pg_trgm availability: {e}")
        return False


def match_products_trigram(
    item_descriptions: List[str],
    limit_per_item: int = 5
) -> Dict[str, List[Dict[str, Any]]]:
    """
    Match receipt item descriptions against Product database using trigram similarity.

    Uses PostgreSQL pg_trgm extension for fuzzy matching with weighted scoring:
    - 60% weight on productname (concise name)
    - 30% weight on name (full name with size)
    - 10% weight on brand

    Args:
        item_descriptions: List of receipt item descriptions to match
        limit_per_item: Max candidates to return per item

    Returns:
        Dict mapping description to list of candidate matches:
        {
            "MILK 2%": [
                {"product_id": "uuid", "name": "Milk 2%", "score": 0.85, "confidence": "high"},
                ...
            ]
        }
    """
    if not item_descriptions:
        return {}

    # Check if pg_trgm is available (cached)
    if not check_pg_trgm_available():
        logger.warning("pg_trgm extension not available, falling back to LIKE matching")
        return _match_products_fallback(item_descriptions, limit_per_item)

    results = {}
    connection = get_grocery_saving_connection()

    with connection.cursor() as cursor:
        for description in item_descriptions:
            normalized = normalize_product_name(description)

            if not normalized:
                results[description] = []
                continue

            # Query using trigram similarity with weighted scoring
            # Note: PRODUCT_TABLE is a validated constant, not user input
            cursor.execute(
                f"""
                SELECT
                    id::text,
                    name,
                    productname,
                    brand,
                    (
                        COALESCE(similarity(LOWER(productname), %s), 0) * {PRODUCTNAME_WEIGHT} +
                        COALESCE(similarity(LOWER(name), %s), 0) * {NAME_WEIGHT} +
                        COALESCE(similarity(LOWER(COALESCE(brand, '')), %s), 0) * {BRAND_WEIGHT}
                    ) as combined_score
                FROM {PRODUCT_TABLE}
                WHERE
                    similarity(LOWER(productname), %s) > %s
                    OR similarity(LOWER(name), %s) > %s
                ORDER BY combined_score DESC
                LIMIT %s
                """,
                [
                    normalized, normalized, normalized,
                    normalized, MIN_MATCH_THRESHOLD,
                    normalized, MIN_MATCH_THRESHOLD,
                    limit_per_item
                ]
            )

            matches = []
            for row in cursor.fetchall():
                product_id, name, productname, brand, score = row
                if score and score >= MIN_MATCH_THRESHOLD:
                    matches.append({
                        'product_id': str(product_id),
                        'name': name,
                        'productname': productname,
                        'brand': brand or '',
                        'score': float(score),
                        'confidence': get_confidence_level(float(score))
                    })

            results[description] = matches

    return results


def _match_products_fallback(
    descriptions: List[str],
    limit_per_item: int = 5
) -> Dict[str, List[Dict[str, Any]]]:
    """
    Fallback matching using ILIKE when pg_trgm is unavailable.

    Uses keyword-based matching with lower confidence scores.
    """
    results = {}
    connection = get_grocery_saving_connection()

    with connection.cursor() as cursor:
        for description in descriptions:
            normalized = normalize_product_name(description)
            words = normalized.split()[:3]  # Use first 3 significant words

            if not words:
                results[description] = []
                continue

            # Build ILIKE conditions for each word
            conditions = []
            params = []
            for word in words:
                if len(word) >= 3:  # Only use words with 3+ chars
                    conditions.append(
                        "(LOWER(name) LIKE %s OR LOWER(productname) LIKE %s)"
                    )
                    params.extend([f'%{word}%', f'%{word}%'])

            if not conditions:
                results[description] = []
                continue

            # Note: PRODUCT_TABLE is a validated constant, not user input
            query = f"""
                SELECT id::text, name, productname, brand
                FROM {PRODUCT_TABLE}
                WHERE {' AND '.join(conditions)}
                LIMIT %s
            """
            params.append(limit_per_item)

            cursor.execute(query, params)

            matches = []
            for row in cursor.fetchall():
                product_id, name, productname, brand = row
                # Assign a fixed lower confidence for LIKE matches
                matches.append({
                    'product_id': str(product_id),
                    'name': name,
                    'productname': productname,
                    'brand': brand or '',
                    'score': 0.5,  # Fixed score for LIKE matches
                    'confidence': 'low'
                })

            results[description] = matches

    return results


def get_best_match(matches: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """
    Get the best match from a list of candidates.

    Returns the highest scoring match above the minimum threshold,
    or None if no suitable match found.
    """
    if not matches:
        return None

    # Return highest scoring match
    best = max(matches, key=lambda x: x.get('score', 0))

    if best.get('score', 0) >= MIN_MATCH_THRESHOLD:
        return best

    return None


def match_single_product(description: str) -> Optional[Dict[str, Any]]:
    """
    Convenience function to match a single product description.

    Returns the best match or None.
    """
    results = match_products_trigram([description], limit_per_item=3)
    matches = results.get(description, [])
    return get_best_match(matches)
