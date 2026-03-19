import uuid
from django.conf import settings
from django.db import models


# =============================================================================
# REPLICA MODELS (Read from grocery_saving database - managed=False)
# These will be replaced with direct imports when databases are merged
# =============================================================================

class Category(models.Model):
    """Replica of grocery_saving Category model for product matching."""
    id = models.UUIDField(primary_key=True)
    name = models.CharField(max_length=100)
    name_fr = models.CharField(max_length=100, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = 'products_category'

    def __str__(self):
        return self.name


class Store(models.Model):
    """Replica of grocery_saving Store model."""
    id = models.UUIDField(primary_key=True)
    name = models.CharField(max_length=200)

    class Meta:
        managed = False
        db_table = 'stores_store'

    def __str__(self):
        return self.name


class Product(models.Model):
    """Replica of grocery_saving Product model for matching."""
    id = models.UUIDField(primary_key=True)
    name = models.CharField(max_length=200)
    productname = models.CharField(max_length=50)
    brand = models.CharField(max_length=100, blank=True, null=True)
    category_id = models.UUIDField(null=True)

    class Meta:
        managed = False
        db_table = 'products_product'

    def __str__(self):
        return self.name


class Deal(models.Model):
    """Replica of grocery_saving Deal model for promo checking."""
    id = models.UUIDField(primary_key=True)
    product_id = models.UUIDField()
    store_id = models.UUIDField()
    original_price = models.DecimalField(max_digits=10, decimal_places=2, null=True)
    discounted_price = models.DecimalField(max_digits=10, decimal_places=2)
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()
    status = models.CharField(max_length=20)

    class Meta:
        managed = False
        db_table = 'products_deal'

    def __str__(self):
        return f"Deal {self.id} - {self.discounted_price}"


# =============================================================================
# RECEIPT SCANNER MODELS
# =============================================================================

class ReceiptScan(models.Model):
    """Receipt scan with AI extraction and savings analysis."""

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        PROCESSING = 'processing', 'Processing'
        AWAITING_REVIEW = 'awaiting_review', 'Awaiting Review'
        MATCHING = 'matching', 'Matching Products'
        COMPLETED = 'completed', 'Completed'
        FAILED = 'failed', 'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='receipt_scans',
        null=True,
        blank=True,
    )
    receipt_image = models.ImageField(upload_to='receipt_scanner/raw/')

    # Extracted fields
    merchant_name = models.CharField(max_length=255, blank=True)
    purchase_date = models.DateField(null=True, blank=True)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    tax = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    total = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    currency = models.CharField(max_length=8, default='CAD')

    # Processing fields
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    extracted_payload = models.JSONField(default=dict, blank=True)
    error_message = models.TextField(blank=True)

    # Savings summary
    total_savings = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    total_missed_promos = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    matched_items_count = models.PositiveIntegerField(default=0)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['status']),
        ]

    def __str__(self):
        return f"Receipt {self.id} - {self.merchant_name or 'Unknown'} ({self.status})"


class ReceiptItem(models.Model):
    """Individual item from a scanned receipt with product matching and savings."""

    class MatchConfidence(models.TextChoices):
        HIGH = 'high', 'High (>0.8)'
        MEDIUM = 'medium', 'Medium (0.5-0.8)'
        LOW = 'low', 'Low (<0.5)'
        NO_MATCH = 'no_match', 'No Match'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    scan = models.ForeignKey(ReceiptScan, on_delete=models.CASCADE, related_name='items')
    line_number = models.PositiveIntegerField(default=1)

    # Extracted from receipt
    description = models.CharField(max_length=255)
    normalized_description = models.CharField(max_length=255, blank=True)
    quantity = models.DecimalField(max_digits=8, decimal_places=2, default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    total_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    # Product matching (uses string IDs for portability)
    matched_product_id = models.CharField(max_length=36, null=True, blank=True, db_index=True)
    matched_product_name = models.CharField(max_length=255, blank=True)
    match_confidence = models.CharField(
        max_length=20,
        choices=MatchConfidence.choices,
        default=MatchConfidence.NO_MATCH
    )
    confidence_score = models.DecimalField(max_digits=5, decimal_places=4, null=True, blank=True)

    # Savings calculation
    database_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    saving_per_unit = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    total_saving = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    # Promo check
    was_on_promo = models.BooleanField(default=False)
    promo_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    missed_savings = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    promo_deal_id = models.CharField(max_length=36, null=True, blank=True)

    class Meta:
        ordering = ['line_number']
        indexes = [
            models.Index(fields=['matched_product_id']),
            models.Index(fields=['scan', 'was_on_promo']),
        ]

    def __str__(self):
        return f"{self.description} x{self.quantity}"


# =============================================================================
# PRICE WATCH MODELS
# =============================================================================

class PriceWatch(models.Model):
    """Track matched items for 30-day price drop monitoring."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='price_watches',
        null=True,
        blank=True,
    )
    receipt_item = models.ForeignKey(
        ReceiptItem,
        on_delete=models.CASCADE,
        related_name='price_watches'
    )

    # Product reference (string for portability)
    product_id = models.CharField(max_length=36, db_index=True)
    product_name = models.CharField(max_length=255)

    # Pricing
    watched_price = models.DecimalField(max_digits=10, decimal_places=2)
    lowest_seen_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    # Status
    is_active = models.BooleanField(default=True)
    notified_at = models.DateTimeField(null=True, blank=True)

    # Lifecycle
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['product_id', 'is_active']),
            models.Index(fields=['expires_at']),
        ]
        unique_together = ['user', 'product_id', 'receipt_item']

    def __str__(self):
        return f"Watch: {self.product_name} @ ${self.watched_price}"


# =============================================================================
# NOTIFICATION MODELS
# =============================================================================

class UserDevice(models.Model):
    """Store FCM tokens for push notifications."""

    class DeviceType(models.TextChoices):
        IOS = 'ios', 'iOS'
        ANDROID = 'android', 'Android'
        WEB = 'web', 'Web'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='devices',
        null=True,
        blank=True,
    )
    fcm_token = models.TextField(unique=True)
    device_type = models.CharField(max_length=10, choices=DeviceType.choices)
    device_name = models.CharField(max_length=100, blank=True)
    is_active = models.BooleanField(default=True)
    last_used = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-last_used']
        indexes = [
            models.Index(fields=['user', 'is_active']),
        ]

    def __str__(self):
        return f"{self.device_type}: {self.device_name or self.fcm_token[:20]}..."


class Notification(models.Model):
    """Track all notifications sent to users."""

    class NotificationType(models.TextChoices):
        PRICE_DROP = 'price_drop', 'Price Drop Alert'
        MISSED_PROMO = 'missed_promo', 'Missed Promo Alert'
        SCAN_COMPLETE = 'scan_complete', 'Scan Complete'
        WEEKLY_SUMMARY = 'weekly_summary', 'Weekly Summary'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
        null=True,
        blank=True,
    )
    notification_type = models.CharField(max_length=20, choices=NotificationType.choices)
    title = models.CharField(max_length=255)
    body = models.TextField()
    data = models.JSONField(default=dict, blank=True)

    # Delivery status
    is_sent = models.BooleanField(default=False)
    sent_at = models.DateTimeField(null=True, blank=True)
    fcm_message_id = models.CharField(max_length=255, blank=True)

    # Read status
    read_at = models.DateTimeField(null=True, blank=True)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    scheduled_for = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['user', 'is_sent', 'scheduled_for']),
            models.Index(fields=['notification_type']),
        ]

    def __str__(self):
        return f"{self.notification_type}: {self.title}"


class NotificationPreference(models.Model):
    """User notification settings."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notification_preferences',
        null=True,
        blank=True,
    )

    # Feature toggles
    price_drop_enabled = models.BooleanField(default=True)
    missed_promo_enabled = models.BooleanField(default=True)
    scan_complete_enabled = models.BooleanField(default=True)
    weekly_summary_enabled = models.BooleanField(default=False)

    # Rate limiting
    max_daily_notifications = models.PositiveIntegerField(default=1)

    # Quiet hours
    quiet_start = models.TimeField(null=True, blank=True)
    quiet_end = models.TimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name_plural = 'Notification preferences'

    def __str__(self):
        return f"Preferences for {self.user}"
