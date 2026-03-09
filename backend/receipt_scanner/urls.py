from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ReceiptScanViewSet, health_check

router = DefaultRouter()
router.register('scans', ReceiptScanViewSet, basename='receipt-scan')

urlpatterns = [
    path('health/', health_check, name='receipt-scanner-health'),
    path('', include(router.urls)),
]
