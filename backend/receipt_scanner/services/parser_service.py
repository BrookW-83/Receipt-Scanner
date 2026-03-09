from typing import Any


def parse_receipt_image(_image: Any) -> dict:
    """Placeholder parser. Replace with OCR/AI provider later."""
    return {
        'merchant_name': '',
        'currency': 'USD',
        'total': None,
        'items': [],
        'extracted_payload': {'note': 'parser not implemented'},
    }
