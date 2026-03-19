"""
Serializers for Receipt Scanner API

Includes serializers for:
- ReceiptScan and ReceiptItem (enhanced with savings fields)
- PriceWatch
- UserDevice (FCM tokens)
- Notification
- NotificationPreference
"""

from rest_framework import serializers
from .models import (
    ReceiptScan,
    ReceiptItem,
    PriceWatch,
    UserDevice,
    Notification,
    NotificationPreference,
)


# =============================================================================
# RECEIPT ITEM SERIALIZERS
# =============================================================================

class ReceiptItemSerializer(serializers.ModelSerializer):
    """Full receipt item with matching and savings data."""

    class Meta:
        model = ReceiptItem
        fields = (
            'id',
            'line_number',
            'description',
            'normalized_description',
            'quantity',
            'unit_price',
            'total_price',
            # Matching
            'matched_product_id',
            'matched_product_name',
            'match_confidence',
            'confidence_score',
            # Savings
            'database_price',
            'saving_per_unit',
            'total_saving',
            # Promo
            'was_on_promo',
            'promo_price',
            'missed_savings',
            'promo_deal_id',
        )
        read_only_fields = fields


class ExtractedItemSerializer(serializers.ModelSerializer):
    """Extracted item for user review (before matching)."""

    class Meta:
        model = ReceiptItem
        fields = (
            'id',
            'line_number',
            'description',
            'quantity',
            'unit_price',
            'total_price',
        )
        read_only_fields = fields


class ExtractedItemUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating extracted items."""

    class Meta:
        model = ReceiptItem
        fields = ('id', 'description', 'quantity', 'unit_price', 'total_price')
        read_only_fields = ('id',)


class ExtractedItemsBulkUpdateSerializer(serializers.Serializer):
    """Serializer for bulk updating extracted items."""

    items = ExtractedItemUpdateSerializer(many=True)


# =============================================================================
# RECEIPT SCAN SERIALIZERS
# =============================================================================

class MatchedItemSerializer(serializers.ModelSerializer):
    """Serializer for matched items only — shows savings per item."""

    class Meta:
        model = ReceiptItem
        fields = (
            'id',
            'description',
            'quantity',
            'unit_price',
            'total_price',
            'matched_product_id',
            'matched_product_name',
            'match_confidence',
            'confidence_score',
            'database_price',
            'saving_per_unit',
            'total_saving',
            'was_on_promo',
            'promo_price',
            'missed_savings',
        )
        read_only_fields = fields


class ReceiptScanSerializer(serializers.ModelSerializer):
    """Full receipt scan with items and savings summary."""

    items = ReceiptItemSerializer(many=True, read_only=True)
    matched_items = serializers.SerializerMethodField()

    class Meta:
        model = ReceiptScan
        fields = (
            'id',
            'receipt_image',
            'merchant_name',
            'purchase_date',
            'subtotal',
            'tax',
            'total',
            'currency',
            'status',
            'error_message',
            # Savings summary
            'total_savings',
            'total_missed_promos',
            'matched_items_count',
            # Items
            'matched_items',
            'items',
            # Timestamps
            'created_at',
            'updated_at',
        )
        read_only_fields = (
            'status',
            'error_message',
            'created_at',
            'updated_at',
            'total_savings',
            'total_missed_promos',
            'matched_items_count',
        )

    def get_matched_items(self, obj):
        matched = obj.items.exclude(match_confidence='no_match')
        return MatchedItemSerializer(matched, many=True).data


class ReceiptScanCreateSerializer(serializers.ModelSerializer):
    """Minimal serializer for creating a new receipt scan."""

    class Meta:
        model = ReceiptScan
        fields = ('id', 'receipt_image')
        read_only_fields = ('id',)


class ReceiptScanListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for listing scans (no items)."""

    class Meta:
        model = ReceiptScan
        fields = (
            'id',
            'receipt_image',
            'merchant_name',
            'purchase_date',
            'total',
            'currency',
            'status',
            'total_savings',
            'total_missed_promos',
            'matched_items_count',
            'created_at',
        )


# =============================================================================
# PRICE WATCH SERIALIZERS
# =============================================================================

class PriceWatchSerializer(serializers.ModelSerializer):
    """Price watch for tracking price drops."""

    class Meta:
        model = PriceWatch
        fields = (
            'id',
            'product_id',
            'product_name',
            'watched_price',
            'lowest_seen_price',
            'is_active',
            'notified_at',
            'created_at',
            'expires_at',
        )
        read_only_fields = fields


# =============================================================================
# USER DEVICE SERIALIZERS
# =============================================================================

class UserDeviceSerializer(serializers.ModelSerializer):
    """Full device info for listing."""

    class Meta:
        model = UserDevice
        fields = (
            'id',
            'fcm_token',
            'device_type',
            'device_name',
            'is_active',
            'last_used',
            'created_at',
        )
        read_only_fields = ('id', 'last_used', 'created_at')


class UserDeviceCreateSerializer(serializers.ModelSerializer):
    """Serializer for registering a new device."""

    class Meta:
        model = UserDevice
        fields = ('fcm_token', 'device_type', 'device_name')


class UserDeviceUnregisterSerializer(serializers.Serializer):
    """Serializer for unregistering a device."""

    fcm_token = serializers.CharField(required=True)


# =============================================================================
# NOTIFICATION SERIALIZERS
# =============================================================================

class NotificationSerializer(serializers.ModelSerializer):
    """Full notification details."""

    class Meta:
        model = Notification
        fields = (
            'id',
            'notification_type',
            'title',
            'body',
            'data',
            'is_sent',
            'sent_at',
            'read_at',
            'created_at',
        )
        read_only_fields = fields


class NotificationMarkReadSerializer(serializers.Serializer):
    """Empty serializer for marking notification as read."""
    pass


# =============================================================================
# NOTIFICATION PREFERENCE SERIALIZERS
# =============================================================================

class NotificationPreferenceSerializer(serializers.ModelSerializer):
    """User notification preferences."""

    class Meta:
        model = NotificationPreference
        fields = (
            'price_drop_enabled',
            'missed_promo_enabled',
            'scan_complete_enabled',
            'weekly_summary_enabled',
            'max_daily_notifications',
            'quiet_start',
            'quiet_end',
        )
