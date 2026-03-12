from django.contrib import admin
from .models import (
    ReceiptScan,
    ReceiptItem,
    PriceWatch,
    UserDevice,
    Notification,
    NotificationPreference,
)


class ReceiptItemInline(admin.TabularInline):
    model = ReceiptItem
    extra = 0
    readonly_fields = (
        'matched_product_id', 'matched_product_name', 'match_confidence',
        'confidence_score', 'database_price', 'saving_per_unit', 'total_saving',
        'was_on_promo', 'promo_price', 'missed_savings',
    )


@admin.register(ReceiptScan)
class ReceiptScanAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'user', 'merchant_name', 'total', 'currency', 'status',
        'total_savings', 'total_missed_promos', 'matched_items_count', 'created_at'
    )
    list_filter = ('status', 'currency', 'created_at')
    search_fields = ('id', 'merchant_name', 'user__username', 'user__email')
    readonly_fields = ('total_savings', 'total_missed_promos', 'matched_items_count')
    inlines = [ReceiptItemInline]


@admin.register(PriceWatch)
class PriceWatchAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'user', 'product_name', 'watched_price', 'lowest_seen_price',
        'is_active', 'expires_at', 'notified_at', 'created_at'
    )
    list_filter = ('is_active', 'created_at', 'expires_at')
    search_fields = ('product_name', 'product_id', 'user__username', 'user__email')
    raw_id_fields = ('user', 'receipt_item')


@admin.register(UserDevice)
class UserDeviceAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'device_type', 'device_name', 'is_active', 'last_used', 'created_at')
    list_filter = ('device_type', 'is_active', 'created_at')
    search_fields = ('user__username', 'user__email', 'device_name')
    raw_id_fields = ('user',)


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'user', 'notification_type', 'title', 'is_sent', 'sent_at', 'read_at', 'created_at'
    )
    list_filter = ('notification_type', 'is_sent', 'created_at')
    search_fields = ('user__username', 'user__email', 'title', 'body')
    raw_id_fields = ('user',)


@admin.register(NotificationPreference)
class NotificationPreferenceAdmin(admin.ModelAdmin):
    list_display = (
        'user', 'price_drop_enabled', 'missed_promo_enabled',
        'max_daily_notifications', 'quiet_start', 'quiet_end'
    )
    search_fields = ('user__username', 'user__email')
    raw_id_fields = ('user',)
