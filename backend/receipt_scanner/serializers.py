from rest_framework import serializers
from .models import ReceiptScan, ReceiptItem


class ReceiptItemSerializer(serializers.ModelSerializer):
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


class ReceiptScanSerializer(serializers.ModelSerializer):
    items = ReceiptItemSerializer(many=True, read_only=True)

    class Meta:
        model = ReceiptScan
        fields = (
            'id',
            'receipt_image',
            'merchant_name',
            'total',
            'currency',
            'status',
            'extracted_payload',
            'error_message',
            'items',
            'created_at',
            'updated_at',
        )
        read_only_fields = ('status', 'extracted_payload', 'error_message', 'created_at', 'updated_at')


class ReceiptScanCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReceiptScan
        fields = ('id', 'receipt_image')
        read_only_fields = ('id',)
