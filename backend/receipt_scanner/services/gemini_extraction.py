"""
Gemini Vision Receipt Extraction Service

Uses Google's Gemini Vision AI to extract structured data from receipt images.
Pattern based on grocery_saving's extractions/services/gemini_extraction.py
"""

import json
import logging
import mimetypes
import os
from pathlib import Path
from typing import Dict, Any, List, Optional, Union

from google import genai
from google.genai import types
from pydantic import BaseModel, Field, ValidationError
import requests

logger = logging.getLogger(__name__)


# =============================================================================
# EXCEPTIONS
# =============================================================================

class GeminiAPIError(Exception):
    """
    Custom exception for Gemini API failures that should trigger retrying.
    Distinguishes from validation/logic errors.
    """
    def __init__(self, message: str, original_error: Optional[Exception] = None):
        super().__init__(message)
        self.original_error = original_error


# =============================================================================
# CONFIGURATION
# =============================================================================

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

MODEL_NAME = "gemini-2.5-flash-lite"

GENERATION_CONFIG = {
    "temperature": 0.1,  # Low for consistent extraction
    "top_p": 1,
    "top_k": 1,
    "max_output_tokens": 4096,
    "response_mime_type": "application/json",
}


# =============================================================================
# PYDANTIC MODELS
# =============================================================================

class ExtractedItem(BaseModel):
    """Single item extracted from receipt."""
    line_number: int = Field(..., description="Sequential position on receipt")
    description: str = Field(..., description="Product name/description as printed")
    quantity: float = Field(default=1.0, description="Number of units")
    unit_price: Optional[float] = Field(None, description="Price per unit")
    total_price: Optional[float] = Field(None, description="Line total")
    is_unclear: bool = Field(default=False, description="True if text is blurry/ambiguous")
    unclear_reason: Optional[str] = Field(None, description="Explanation if unclear")


class ExtractedReceiptData(BaseModel):
    """Validated receipt extraction result."""
    merchant_name: str = Field(default="", description="Store/merchant name")
    merchant_address: Optional[str] = Field(None, description="Store address if visible")
    purchase_date: Optional[str] = Field(None, description="Date in YYYY-MM-DD format")
    items: List[ExtractedItem] = Field(default_factory=list, description="Line items")
    subtotal: Optional[float] = Field(None, description="Subtotal before tax")
    tax: Optional[float] = Field(None, description="Tax amount")
    total: Optional[float] = Field(None, description="Total amount")
    currency: str = Field(default="CAD", description="Currency code")
    verification_status: str = Field(
        default="AI_VERIFIED",
        description="AI_VERIFIED or NEEDS_HUMAN_VERIFICATION"
    )
    verification_notes: Optional[str] = Field(
        None,
        description="Explanation if verification failed"
    )


# =============================================================================
# PROMPT
# =============================================================================

RECEIPT_EXTRACTION_PROMPT = """
You are an expert receipt data extraction AI for a Canadian grocery savings app.

Your task is to extract structured data from the receipt image provided.

### EXTRACTION REQUIREMENTS:

1. **Merchant Information**
   - Extract the store/merchant name
   - Extract the store address if visible

2. **Purchase Date**
   - Extract the date in YYYY-MM-DD format
   - If only partial date visible, make reasonable inference

3. **Line Items** - Extract ALL items with:
   - line_number: Sequential position (1, 2, 3...)
   - description: Product name/description exactly as printed
   - quantity: Number of units (default 1 if not specified)
   - unit_price: Price per unit (may need to calculate from total_price / quantity)
   - total_price: Line total for this item
   - is_unclear: Set to true if text is blurry, partially visible, or ambiguous
   - unclear_reason: Brief explanation if is_unclear is true

4. **Totals**
   - subtotal: Sum before tax
   - tax: Tax amount (may be multiple tax lines, sum them)
   - total: Final total

5. **Currency**
   - Default to "CAD" for Canadian receipts
   - Use "USD" if US dollars indicated

### VERIFICATION:
- If merchant name, items, or total are unreadable/unclear, set verification_status to "NEEDS_HUMAN_VERIFICATION"
- Provide verification_notes explaining any issues

### OUTPUT FORMAT:
Return ONLY a valid JSON object. No markdown formatting or additional text.

Example:
{
    "merchant_name": "Metro",
    "merchant_address": "123 Main St, Montreal, QC",
    "purchase_date": "2024-03-10",
    "items": [
        {
            "line_number": 1,
            "description": "MILK 2% 2L",
            "quantity": 1,
            "unit_price": 4.99,
            "total_price": 4.99,
            "is_unclear": false,
            "unclear_reason": null
        },
        {
            "line_number": 2,
            "description": "BREAD WHITE",
            "quantity": 2,
            "unit_price": 2.50,
            "total_price": 5.00,
            "is_unclear": false,
            "unclear_reason": null
        }
    ],
    "subtotal": 9.99,
    "tax": 0.50,
    "total": 10.49,
    "currency": "CAD",
    "verification_status": "AI_VERIFIED",
    "verification_notes": null
}
"""


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def _clean_gemini_json_response(raw_text: str) -> Dict[str, Any]:
    """
    Clean and parse Gemini JSON response.
    Handles markdown-wrapped responses like ```json ... ```
    """
    try:
        # Remove markdown code blocks if present
        if "```json" in raw_text:
            json_part = raw_text.split("```json", 1)[1].split("```", 1)[0]
        elif "```" in raw_text:
            json_part = raw_text.split("```", 1)[1].split("```", 1)[0]
        else:
            json_part = raw_text

        return json.loads(json_part.strip())
    except (json.JSONDecodeError, IndexError) as e:
        logger.warning(f"Failed to parse JSON response. Error: {e}")
        logger.debug(f"Raw text: {raw_text}")
        raise ValueError(f"Gemini response was not valid JSON: {raw_text[:500]}")


def _load_image_as_part(image_path: Union[str, Path]) -> types.Part:
    """
    Load image from file path or URL into Gemini Part format.

    Supports:
    - Local file paths
    - HTTP/HTTPS URLs
    """
    image_path = str(image_path)

    try:
        if image_path.startswith("http://") or image_path.startswith("https://"):
            # Load from URL
            response = requests.get(image_path, timeout=30)
            response.raise_for_status()
            image_bytes = response.content
            mime_type = response.headers.get("Content-Type", "application/octet-stream")
        else:
            # Load from local file
            path = Path(image_path)
            if not path.exists():
                raise FileNotFoundError(f"Image file not found: {image_path}")

            image_bytes = path.read_bytes()
            mime_type, _ = mimetypes.guess_type(image_path)
            if not mime_type:
                mime_type = "application/octet-stream"

        return types.Part.from_bytes(data=image_bytes, mime_type=mime_type)

    except requests.RequestException as e:
        logger.warning(f"Failed to load image from URL: {image_path}. Error: {e}")
        raise
    except Exception as e:
        logger.warning(f"Failed to load image at path: {image_path}. Error: {e}")
        raise


# =============================================================================
# MAIN EXTRACTION FUNCTION
# =============================================================================

def extract_receipt_data(image_path: str) -> ExtractedReceiptData:
    """
    Extract structured data from a receipt image using Gemini Vision.

    Args:
        image_path: Local file path or URL to receipt image

    Returns:
        ExtractedReceiptData: Validated extraction result

    Raises:
        GeminiAPIError: If API call fails (should trigger retry)
        ValidationError: If response doesn't match schema
        FileNotFoundError: If image cannot be loaded
    """
    # Check API key
    api_key = GEMINI_API_KEY
    if not api_key:
        raise EnvironmentError("GEMINI_API_KEY environment variable is not set.")

    logger.info(f"Starting Gemini receipt extraction for: {image_path}")

    # Initialize client
    client = genai.Client(api_key=api_key)

    # Build prompt with image
    prompt_parts = [RECEIPT_EXTRACTION_PROMPT]

    try:
        image_part = _load_image_as_part(image_path)
        prompt_parts.extend(["Receipt Image:", image_part])
    except FileNotFoundError:
        raise
    except Exception as e:
        raise FileNotFoundError(f"Could not load receipt image: {image_path}. Error: {e}")

    # Call Gemini API
    try:
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt_parts,
            config=types.GenerateContentConfig(**GENERATION_CONFIG),
        )
    except Exception as e:
        logger.warning(f"Gemini API call failed: {e}")
        raise GeminiAPIError(f"Gemini API call failed: {str(e)}", original_error=e)

    # Parse response
    try:
        raw_data = _clean_gemini_json_response(response.text)
    except ValueError as e:
        logger.warning(f"Failed to parse Gemini response: {e}")
        raise GeminiAPIError(f"Invalid JSON response from Gemini: {e}", original_error=e)

    # Validate with Pydantic
    try:
        validated_data = ExtractedReceiptData(**raw_data)
        logger.info(
            f"Receipt extraction successful: "
            f"{len(validated_data.items)} items, "
            f"total: {validated_data.total}, "
            f"status: {validated_data.verification_status}"
        )
        return validated_data

    except ValidationError as e:
        logger.warning(f"Pydantic validation failed: {e}")
        logger.debug(f"Raw data: {raw_data}")
        raise
