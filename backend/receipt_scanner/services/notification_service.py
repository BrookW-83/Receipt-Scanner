"""
Notification Service

Handles push notifications via Firebase Cloud Messaging (FCM)
with rate limiting and user preference support.
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone

logger = logging.getLogger(__name__)

# Firebase Admin SDK - lazy initialization
_firebase_app = None
_firebase_initialized = False


# =============================================================================
# FIREBASE INITIALIZATION
# =============================================================================

def _get_firebase_app():
    """
    Lazy initialization of Firebase Admin SDK.

    Only initializes if FIREBASE_CREDENTIALS_PATH is configured.
    """
    global _firebase_app, _firebase_initialized

    if _firebase_initialized:
        return _firebase_app

    _firebase_initialized = True

    cred_path = getattr(settings, 'FIREBASE_CREDENTIALS_PATH', None)

    if not cred_path:
        logger.warning(
            "FIREBASE_CREDENTIALS_PATH not configured. "
            "Push notifications will be disabled."
        )
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(cred_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin SDK initialized successfully")
        return _firebase_app

    except Exception as e:
        logger.error(f"Failed to initialize Firebase: {e}")
        return None


# =============================================================================
# PUSH NOTIFICATION SENDING
# =============================================================================

def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None
) -> Optional[str]:
    """
    Send a push notification via FCM.

    Args:
        fcm_token: Device FCM token
        title: Notification title
        body: Notification body text
        data: Optional data payload for the app

    Returns:
        FCM message ID if successful, None otherwise
    """
    app = _get_firebase_app()
    if not app:
        logger.debug("Firebase not initialized, skipping push notification")
        return None

    try:
        from firebase_admin import messaging

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=fcm_token,
        )

        response = messaging.send(message)
        logger.info(f"FCM notification sent successfully: {response}")
        return response

    except Exception as e:
        # Check for specific error types
        error_str = str(e).lower()
        if 'unregistered' in error_str or 'not found' in error_str:
            logger.warning(f"FCM token unregistered: {fcm_token[:20]}...")
            # Mark device as inactive
            _deactivate_device(fcm_token)
        else:
            logger.error(f"FCM send failed: {e}")
        return None


def _deactivate_device(fcm_token: str):
    """Mark a device as inactive when its token becomes invalid."""
    try:
        from ..models import UserDevice
        UserDevice.objects.filter(fcm_token=fcm_token).update(is_active=False)
    except Exception as e:
        logger.warning(f"Failed to deactivate device: {e}")


# =============================================================================
# RATE LIMITING
# =============================================================================

def can_send_notification_today(user_id: str) -> bool:
    """
    Check if user has room for more notifications today.

    Respects max_daily_notifications preference (default: 1).
    """
    from ..models import Notification, NotificationPreference

    today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)

    # Get user preference
    try:
        pref = NotificationPreference.objects.get(user_id=user_id)
        max_daily = pref.max_daily_notifications
    except NotificationPreference.DoesNotExist:
        max_daily = 1  # Default to 1 per day

    # Count today's sent notifications
    sent_today = Notification.objects.filter(
        user_id=user_id,
        is_sent=True,
        sent_at__gte=today_start
    ).count()

    return sent_today < max_daily


def is_quiet_hours(user_id: str) -> bool:
    """
    Check if current time is within user's quiet hours.

    Quiet hours are when notifications should not be sent.
    """
    from ..models import NotificationPreference

    try:
        pref = NotificationPreference.objects.get(user_id=user_id)

        if not pref.quiet_start or not pref.quiet_end:
            return False

        now = timezone.localtime().time()

        # Handle overnight quiet hours (e.g., 22:00 - 08:00)
        if pref.quiet_start > pref.quiet_end:
            # Quiet hours span midnight
            return now >= pref.quiet_start or now <= pref.quiet_end
        else:
            # Normal range (e.g., 12:00 - 14:00)
            return pref.quiet_start <= now <= pref.quiet_end

    except NotificationPreference.DoesNotExist:
        return False


def is_notification_type_enabled(user_id: str, notification_type: str) -> bool:
    """Check if a specific notification type is enabled for the user."""
    from ..models import NotificationPreference

    try:
        pref = NotificationPreference.objects.get(user_id=user_id)

        type_to_field = {
            'price_drop': pref.price_drop_enabled,
            'missed_promo': pref.missed_promo_enabled,
            'scan_complete': pref.scan_complete_enabled,
            'weekly_summary': pref.weekly_summary_enabled,
        }

        return type_to_field.get(notification_type, True)

    except NotificationPreference.DoesNotExist:
        # Default to enabled
        return True


# =============================================================================
# NOTIFICATION CREATION
# =============================================================================

def create_price_drop_notification(
    user_id: str,
    product_name: str,
    old_price: Decimal,
    new_price: Decimal,
    product_id: str
) -> Optional[str]:
    """
    Create a price drop notification.

    Returns notification ID if created, None if user has disabled this type.
    """
    from ..models import Notification

    # Check if notification type is enabled
    if not is_notification_type_enabled(user_id, 'price_drop'):
        logger.debug(f"Price drop notifications disabled for user {user_id}")
        return None

    savings = old_price - new_price

    notification = Notification.objects.create(
        user_id=user_id,
        notification_type=Notification.NotificationType.PRICE_DROP,
        title=f"Price Drop: {product_name}",
        body=f"Now ${new_price:.2f} (was ${old_price:.2f}). Save ${savings:.2f}!",
        data={
            'type': 'price_drop',
            'product_id': product_id,
            'new_price': str(new_price),
            'old_price': str(old_price),
            'savings': str(savings)
        }
    )

    logger.info(f"Created price drop notification {notification.id} for user {user_id}")
    return str(notification.id)


def create_missed_promo_notification(
    user_id: str,
    product_name: str,
    paid_price: Decimal,
    promo_price: Decimal,
    store_name: str,
    scan_id: str
) -> Optional[str]:
    """
    Create a missed promo notification.

    Returns notification ID if created, None if user has disabled this type.
    """
    from ..models import Notification

    # Check if notification type is enabled
    if not is_notification_type_enabled(user_id, 'missed_promo'):
        logger.debug(f"Missed promo notifications disabled for user {user_id}")
        return None

    missed = paid_price - promo_price

    notification = Notification.objects.create(
        user_id=user_id,
        notification_type=Notification.NotificationType.MISSED_PROMO,
        title=f"Missed Deal: {product_name}",
        body=f"Was on sale at {store_name} for ${promo_price:.2f}. You could have saved ${missed:.2f}!",
        data={
            'type': 'missed_promo',
            'scan_id': scan_id,
            'store_name': store_name,
            'paid_price': str(paid_price),
            'promo_price': str(promo_price),
            'missed_savings': str(missed)
        }
    )

    logger.info(f"Created missed promo notification {notification.id} for user {user_id}")
    return str(notification.id)


def create_scan_complete_notification(
    user_id: str,
    scan_id: str,
    total_savings: Decimal,
    total_missed: Decimal,
    items_count: int
) -> Optional[str]:
    """
    Create a scan complete notification.

    Returns notification ID if created, None if user has disabled this type.
    """
    from ..models import Notification

    # Check if notification type is enabled
    if not is_notification_type_enabled(user_id, 'scan_complete'):
        logger.debug(f"Scan complete notifications disabled for user {user_id}")
        return None

    # Build body based on results
    if total_savings > 0:
        body = f"You saved ${total_savings:.2f} on {items_count} items!"
    elif total_missed > 0:
        body = f"You could have saved ${total_missed:.2f}. Check the deals!"
    else:
        body = f"Scanned {items_count} items. See your receipt breakdown."

    notification = Notification.objects.create(
        user_id=user_id,
        notification_type=Notification.NotificationType.SCAN_COMPLETE,
        title="Receipt Scan Complete",
        body=body,
        data={
            'type': 'scan_complete',
            'scan_id': scan_id,
            'total_savings': str(total_savings),
            'total_missed': str(total_missed),
            'items_count': str(items_count)
        }
    )

    logger.info(f"Created scan complete notification {notification.id} for user {user_id}")
    return str(notification.id)


# =============================================================================
# NOTIFICATION SENDING
# =============================================================================

def send_pending_notifications(user_id: str) -> int:
    """
    Send all pending notifications for a user, respecting daily limit.

    Returns number of notifications sent.
    """
    from ..models import Notification, UserDevice

    # Check daily limit
    if not can_send_notification_today(user_id):
        logger.info(f"User {user_id} has reached daily notification limit")
        return 0

    # Check quiet hours
    if is_quiet_hours(user_id):
        logger.info(f"User {user_id} is in quiet hours")
        return 0

    # Get active device tokens
    devices = list(UserDevice.objects.filter(
        user_id=user_id,
        is_active=True
    ).values_list('fcm_token', flat=True))

    if not devices:
        logger.debug(f"User {user_id} has no active devices")
        return 0

    # Get pending notifications (oldest first, limit to daily max)
    pending = Notification.objects.filter(
        user_id=user_id,
        is_sent=False
    ).order_by('created_at')[:1]  # Send max 1 per call

    sent_count = 0

    for notification in pending:
        # Send to all devices
        success = False
        message_id = None

        for token in devices:
            result = send_push_notification(
                fcm_token=token,
                title=notification.title,
                body=notification.body,
                data={k: str(v) for k, v in notification.data.items()}
            )
            if result:
                success = True
                message_id = result

        if success:
            notification.is_sent = True
            notification.sent_at = timezone.now()
            if message_id:
                notification.fcm_message_id = message_id
            notification.save()
            sent_count += 1

            logger.info(f"Sent notification {notification.id} to user {user_id}")

            # Check if we've hit daily limit
            if not can_send_notification_today(user_id):
                break

    return sent_count


def send_all_pending_notifications() -> Dict[str, int]:
    """
    Send pending notifications for all users.

    Returns dict with total sent count and user count.
    """
    from ..models import Notification

    # Get users with pending notifications
    users_with_pending = Notification.objects.filter(
        is_sent=False
    ).values_list('user_id', flat=True).distinct()

    total_sent = 0
    users_processed = 0

    for user_id in users_with_pending:
        sent = send_pending_notifications(str(user_id))
        total_sent += sent
        users_processed += 1

    logger.info(f"Sent {total_sent} notifications to {users_processed} users")

    return {
        'total_sent': total_sent,
        'users_processed': users_processed
    }
