from django.contrib import admin
from .models import ReceiptScan, ReceiptItem


class ReceiptItemInline(admin.TabularInline):
    model = ReceiptItem
    extra = 0


@admin.register(ReceiptScan)
class ReceiptScanAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'merchant_name', 'total', 'currency', 'status', 'created_at')
    list_filter = ('status', 'currency', 'created_at')
    search_fields = ('id', 'merchant_name', 'user__username', 'user__email')
    inlines = [ReceiptItemInline]
