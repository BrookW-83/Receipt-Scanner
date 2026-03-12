# Receipt Scanner Services
from .gemini_extraction import extract_receipt_data, ExtractedReceiptData, GeminiAPIError
from .product_matcher import match_products_trigram, get_best_match, normalize_product_name
from .savings_calculator import calculate_item_savings, calculate_receipt_savings
from .promo_checker import check_promo_on_date, check_receipt_promos
from .notification_service import (
    send_push_notification,
    create_price_drop_notification,
    create_missed_promo_notification,
    send_pending_notifications,
)

__all__ = [
    # Gemini extraction
    'extract_receipt_data',
    'ExtractedReceiptData',
    'GeminiAPIError',
    # Product matching
    'match_products_trigram',
    'get_best_match',
    'normalize_product_name',
    # Savings
    'calculate_item_savings',
    'calculate_receipt_savings',
    # Promo checking
    'check_promo_on_date',
    'check_receipt_promos',
    # Notifications
    'send_push_notification',
    'create_price_drop_notification',
    'create_missed_promo_notification',
    'send_pending_notifications',
]
