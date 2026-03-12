"""
URL Configuration for Receipt Scanner API

Endpoints:
- /health/ - Health check
- /scans/ - Receipt scans CRUD
- /price-watches/ - Price watch list/deactivate
- /devices/ - FCM device management
- /notifications/ - Notification list/read
- /notification-preferences/ - User preferences
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    health_check,
    ReceiptScanViewSet,
    PriceWatchViewSet,
    UserDeviceViewSet,
    NotificationViewSet,
    NotificationPreferenceView,
)

router = DefaultRouter()
router.register('scans', ReceiptScanViewSet, basename='receipt-scan')
router.register('price-watches', PriceWatchViewSet, basename='price-watch')
router.register('devices', UserDeviceViewSet, basename='user-device')
router.register('notifications', NotificationViewSet, basename='notification')

urlpatterns = [
    path('health/', health_check, name='receipt-scanner-health'),
    path(
        'notification-preferences/',
        NotificationPreferenceView.as_view(),
        name='notification-preferences'
    ),
    path('', include(router.urls)),
]
