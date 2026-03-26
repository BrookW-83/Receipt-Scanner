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
        'id', 'user_id', 'merchant_name', 'total', 'currency', 'status',
        'total_savings', 'total_missed_promos', 'matched_items_count', 'created_at'
    )
    list_filter = ('status', 'currency', 'created_at')
    search_fields = ('id', 'merchant_name')
    readonly_fields = ('total_savings', 'total_missed_promos', 'matched_items_count')
    inlines = [ReceiptItemInline]


@admin.register(PriceWatch)
class PriceWatchAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'user_id', 'product_name', 'watched_price', 'lowest_seen_price',
        'is_active', 'expires_at', 'notified_at', 'created_at'
    )
    list_filter = ('is_active', 'created_at', 'expires_at')
    search_fields = ('product_name', 'product_id')
    raw_id_fields = ('receipt_item',)


@admin.register(UserDevice)
class UserDeviceAdmin(admin.ModelAdmin):
    list_display = ('id', 'user_id', 'device_type', 'device_name', 'is_active', 'last_used', 'created_at')
    list_filter = ('device_type', 'is_active', 'created_at')
    search_fields = ('device_name',)


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'user_id', 'notification_type', 'title', 'is_sent', 'sent_at', 'read_at', 'created_at'
    )
    list_filter = ('notification_type', 'is_sent', 'created_at')
    search_fields = ('title', 'body')


@admin.register(NotificationPreference)
class NotificationPreferenceAdmin(admin.ModelAdmin):
    list_display = (
        'user_id', 'price_drop_enabled', 'missed_promo_enabled',
        'max_daily_notifications', 'quiet_start', 'quiet_end'
    )
