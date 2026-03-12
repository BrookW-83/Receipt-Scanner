"""
Celery Tasks for Receipt Scanner

Main pipeline:
1. Extract receipt data via Gemini Vision
2. Match items to products via trigram similarity
3. Calculate savings vs current deals
4. Check for missed promos on purchase date
5. Create PriceWatch entries (30-day expiry)
6. Queue notifications for missed promos
"""

import logging
from datetime import timedelta
from decimal import Decimal

from celery import shared_task
from django.db import transaction, DatabaseError
from django.utils import timezone

from .models import ReceiptScan, ReceiptItem, PriceWatch
from .services.gemini_extraction import extract_receipt_data, GeminiAPIError
from .services.product_matcher import match_products_trigram, get_best_match, normalize_product_name
from .services.savings_calculator import calculate_receipt_savings
from .services.promo_checker import check_receipt_promos
from .services.notification_service import (
    create_missed_promo_notification,
    create_price_drop_notification,
    send_all_pending_notifications,
)

logger = logging.getLogger(__name__)


# =============================================================================
# MAIN RECEIPT PROCESSING TASK
# =============================================================================

@shared_task(
    bind=True,
    autoretry_for=(GeminiAPIError, DatabaseError),
    retry_backoff=300,  # 5 minutes base delay
    retry_backoff_max=172800,  # 2 days max
    retry_jitter=True,
    max_retries=2,
    rate_limit='10/m'  # 10 requests per minute (Gemini rate limit)
)
def process_receipt_scan_task(self, scan_id: str) -> str:
    """
    Main task to process a receipt scan.

    Pipeline:
    1. Extract data from image using Gemini Vision
    2. Match items to products using trigram similarity
    3. Calculate savings against current deals
    4. Check for missed promotions on purchase date
    5. Create PriceWatch entries for matched items
    6. Queue notifications for missed promos
    """
    logger.info(f"Processing receipt scan: {scan_id}")

    # Get scan
    try:
        scan = ReceiptScan.objects.get(id=scan_id)
    except ReceiptScan.DoesNotExist:
        logger.error(f"Scan {scan_id} not found")
        return f"Scan {scan_id} not found"

    # Skip if already completed
    if scan.status == ReceiptScan.Status.COMPLETED:
        return f"Scan {scan_id} already completed"

    # Update to processing
    scan.status = ReceiptScan.Status.PROCESSING
    scan.error_message = ''
    scan.save(update_fields=['status', 'error_message', 'updated_at'])

    try:
        # =====================================================================
        # STEP 1: EXTRACT DATA FROM IMAGE
        # =====================================================================
        image_path = scan.receipt_image.path
        extracted = extract_receipt_data(image_path)

        # Store raw extraction
        scan.extracted_payload = extracted.model_dump()
        scan.merchant_name = extracted.merchant_name
        scan.total = Decimal(str(extracted.total)) if extracted.total else None
        scan.subtotal = Decimal(str(extracted.subtotal)) if extracted.subtotal else None
        scan.tax = Decimal(str(extracted.tax)) if extracted.tax else None
        scan.currency = extracted.currency

        # Parse purchase date
        if extracted.purchase_date:
            from datetime import datetime
            try:
                scan.purchase_date = datetime.strptime(
                    extracted.purchase_date, '%Y-%m-%d'
                ).date()
            except ValueError:
                logger.warning(f"Invalid date format: {extracted.purchase_date}")

        scan.status = ReceiptScan.Status.MATCHING
        scan.save()

        logger.info(f"Scan {scan_id}: Extracted {len(extracted.items)} items")

        # =====================================================================
        # STEP 2-6: PROCESS ITEMS IN A TRANSACTION
        # =====================================================================
        with transaction.atomic():
            # Delete existing items and create new ones
            ReceiptItem.objects.filter(scan=scan).delete()

            # Get descriptions for batch matching
            descriptions = [item.description for item in extracted.items]
            matches = match_products_trigram(descriptions)

            items_data = []
            for item in extracted.items:
                best_match = get_best_match(matches.get(item.description, []))

                receipt_item = ReceiptItem.objects.create(
                    scan=scan,
                    line_number=item.line_number,
                    description=item.description,
                    normalized_description=normalize_product_name(item.description),
                    quantity=Decimal(str(item.quantity)),
                    unit_price=Decimal(str(item.unit_price)) if item.unit_price else None,
                    total_price=Decimal(str(item.total_price)) if item.total_price else None,
                    matched_product_id=best_match['product_id'] if best_match else None,
                    matched_product_name=best_match['name'] if best_match else '',
                    confidence_score=Decimal(str(best_match['score'])) if best_match else None,
                    match_confidence=best_match['confidence'] if best_match else 'no_match'
                )

                items_data.append({
                    'id': str(receipt_item.id),
                    'matched_product_id': receipt_item.matched_product_id,
                    'unit_price': receipt_item.unit_price,
                    'quantity': receipt_item.quantity
                })

            logger.info(f"Scan {scan_id}: Matched {sum(1 for i in items_data if i['matched_product_id'])} items")

            # Calculate savings
            savings_result = calculate_receipt_savings(items_data)

            # Check for missed promos
            promo_result = check_receipt_promos(items_data, scan.purchase_date)

            # Update items with savings & promo info
            total_savings = Decimal('0')
            total_missed = Decimal('0')
            matched_count = 0

            # Merge savings and promo data
            savings_by_id = {item['id']: item for item in savings_result['items']}
            promo_by_id = {item['id']: item for item in promo_result['items']}

            for item_data in items_data:
                item_id = item_data['id']
                item = ReceiptItem.objects.get(id=item_id)

                # Savings data
                savings_data = savings_by_id.get(item_id, {})
                item.database_price = savings_data.get('database_price')
                item.saving_per_unit = savings_data.get('saving_per_unit', Decimal('0'))
                item.total_saving = savings_data.get('total_saving', Decimal('0'))

                # Promo data
                promo_data = promo_by_id.get(item_id, {})
                item.was_on_promo = promo_data.get('was_on_promo', False)
                item.promo_price = promo_data.get('promo_price')
                item.missed_savings = promo_data.get('missed_savings', Decimal('0'))
                item.promo_deal_id = promo_data.get('promo_deal_id')

                item.save()

                # Aggregate totals
                if item.matched_product_id:
                    matched_count += 1
                if item.total_saving and item.total_saving > 0:
                    total_savings += item.total_saving
                if item.missed_savings and item.missed_savings > 0:
                    total_missed += item.missed_savings

            # Update scan summary
            scan.total_savings = total_savings
            scan.total_missed_promos = total_missed
            scan.matched_items_count = matched_count
            scan.status = ReceiptScan.Status.COMPLETED
            scan.save()

        logger.info(
            f"Scan {scan_id} completed: "
            f"{matched_count} matches, "
            f"${total_savings} savings, "
            f"${total_missed} missed"
        )

        # =====================================================================
        # STEP 7: CREATE PRICE WATCHES FOR MATCHED ITEMS
        # =====================================================================
        watches_created = 0
        for item in ReceiptItem.objects.filter(scan=scan, matched_product_id__isnull=False):
            if item.unit_price:
                # Use select_for_update to prevent race conditions
                with transaction.atomic():
                    # Check if watch already exists
                    existing = PriceWatch.objects.select_for_update().filter(
                        user=scan.user,
                        product_id=item.matched_product_id,
                        receipt_item=item,
                    ).first()

                    if not existing:
                        PriceWatch.objects.create(
                            user=scan.user,
                            product_id=item.matched_product_id,
                            receipt_item=item,
                            product_name=item.matched_product_name,
                            watched_price=item.unit_price,
                            expires_at=timezone.now() + timedelta(days=30)
                        )
                        watches_created += 1

        logger.info(f"Scan {scan_id}: Created {watches_created} price watches")

        # =====================================================================
        # STEP 8: QUEUE MISSED PROMO NOTIFICATIONS (only if user exists)
        # =====================================================================
        if total_missed > 0 and scan.user_id:
            # Find the item with highest missed savings for notification
            top_missed = ReceiptItem.objects.filter(
                scan=scan,
                missed_savings__gt=0
            ).order_by('-missed_savings').first()

            if top_missed:
                # Get store name from promo data
                promo_data = promo_by_id.get(str(top_missed.id), {})
                store_name = promo_data.get('promo_store', 'a local store')

                create_missed_promo_notification(
                    user_id=str(scan.user_id),
                    product_name=top_missed.matched_product_name,
                    paid_price=top_missed.unit_price,
                    promo_price=top_missed.promo_price,
                    store_name=store_name,
                    scan_id=str(scan.id)
                )

        return f"Scan {scan_id} completed successfully"

    except GeminiAPIError:
        # Re-raise for Celery retry
        scan.status = ReceiptScan.Status.PENDING  # Reset for retry
        scan.save(update_fields=['status'])
        raise

    except Exception as e:
        logger.exception(f"Scan {scan_id} failed: {e}")
        scan.status = ReceiptScan.Status.FAILED
        scan.error_message = str(e)
        scan.save(update_fields=['status', 'error_message', 'updated_at'])
        raise


# =============================================================================
# PERIODIC TASKS
# =============================================================================

@shared_task
def check_price_drops_task() -> str:
    """
    Periodic task to check for price drops on watched items.

    Should run daily (configured in Celery Beat).
    """
    from .services.savings_calculator import get_product_current_price

    logger.info("Starting price drop check")

    # Get active price watches that haven't been notified (only for users with accounts)
    watches = PriceWatch.objects.filter(
        is_active=True,
        expires_at__gt=timezone.now(),
        notified_at__isnull=True,
        user__isnull=False,  # Only notify users with accounts
    ).select_related('user')

    notifications_created = 0

    for watch in watches:
        current_price = get_product_current_price(watch.product_id)

        if current_price and current_price < watch.watched_price:
            # Price dropped!
            create_price_drop_notification(
                user_id=str(watch.user_id),
                product_name=watch.product_name,
                old_price=watch.watched_price,
                new_price=current_price,
                product_id=watch.product_id
            )

            # Update watch
            watch.lowest_seen_price = current_price
            watch.notified_at = timezone.now()
            watch.save()

            notifications_created += 1

    logger.info(f"Price drop check complete: {notifications_created} notifications created")
    return f"Created {notifications_created} price drop notifications"


@shared_task
def send_pending_notifications_task() -> str:
    """
    Periodic task to send pending notifications.

    Respects daily limits per user.
    Should run every 30 minutes (configured in Celery Beat).
    """
    result = send_all_pending_notifications()

    logger.info(
        f"Sent {result['total_sent']} notifications "
        f"to {result['users_processed']} users"
    )

    return f"Sent {result['total_sent']} notifications"


@shared_task
def cleanup_expired_price_watches_task() -> str:
    """
    Periodic task to clean up expired price watches.

    Should run daily (configured in Celery Beat).
    """
    expired = PriceWatch.objects.filter(
        expires_at__lt=timezone.now(),
        is_active=True
    )

    count = expired.count()
    expired.update(is_active=False)

    logger.info(f"Deactivated {count} expired price watches")
    return f"Deactivated {count} expired price watches"


@shared_task
def requeue_failed_scans_task() -> str:
    """
    Periodic task to requeue failed scans for retry.

    Useful for recovering from temporary failures.
    Should run hourly (optional).
    """
    failed_scans = ReceiptScan.objects.filter(
        status=ReceiptScan.Status.FAILED,
        updated_at__gte=timezone.now() - timedelta(hours=24)  # Only recent failures
    )

    requeued = 0
    for scan in failed_scans:
        scan.status = ReceiptScan.Status.PENDING
        scan.error_message = ''
        scan.save(update_fields=['status', 'error_message', 'updated_at'])

        process_receipt_scan_task.delay(str(scan.id))
        requeued += 1

    logger.info(f"Requeued {requeued} failed scans")
    return f"Requeued {requeued} failed scans"
