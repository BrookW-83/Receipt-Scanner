"""
Views for Receipt Scanner API

Endpoints:
- ReceiptScan CRUD + reprocess
- PriceWatch list/deactivate
- UserDevice register/unregister
- Notification list/mark read
- NotificationPreference get/update

Authentication is optional for testing. When authenticated, user data is
associated with requests. When not authenticated, user fields are left null.
"""

from rest_framework import viewsets, generics, status
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.throttling import AnonRateThrottle
from django.utils import timezone

from .models import (
    ReceiptScan,
    PriceWatch,
    UserDevice,
    Notification,
    NotificationPreference,
)
from .serializers import (
    ReceiptScanSerializer,
    ReceiptScanCreateSerializer,
    ReceiptScanListSerializer,
    PriceWatchSerializer,
    UserDeviceSerializer,
    UserDeviceCreateSerializer,
    NotificationSerializer,
    NotificationPreferenceSerializer,
)
from .tasks import process_receipt_scan_task


# =============================================================================
# HELPERS
# =============================================================================

def get_user_or_none(request):
    """Get authenticated user or None for anonymous requests."""
    if request.user and request.user.is_authenticated:
        return request.user
    return None


# =============================================================================
# THROTTLING
# =============================================================================

class ReceiptUploadThrottle(AnonRateThrottle):
    """Rate limit receipt uploads to 3 per hour."""
    rate = '3/hour'
    scope = 'receipt_upload'


# =============================================================================
# HEALTH CHECK
# =============================================================================

@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(_request):
    """Simple health check endpoint."""
    return Response({'status': 'ok'})


# =============================================================================
# RECEIPT SCAN VIEWS
# =============================================================================

class ReceiptScanViewSet(viewsets.ModelViewSet):
    """
    Receipt scan CRUD with processing.

    Endpoints:
    - GET /scans/ - List scans (user's scans if authenticated, all if not)
    - POST /scans/ - Upload new receipt (rate limited: 3/hour)
    - GET /scans/{id}/ - Get scan details
    - DELETE /scans/{id}/ - Delete scan
    - POST /scans/{id}/reprocess/ - Requeue for processing
    """
    permission_classes = [AllowAny]

    def get_throttles(self):
        """Apply rate limiting only to create action."""
        if self.action == 'create':
            return [ReceiptUploadThrottle()]
        return []

    def get_queryset(self):
        user = get_user_or_none(self.request)
        qs = ReceiptScan.objects.prefetch_related('items').order_by('-created_at')
        if user:
            return qs.filter(user=user)
        return qs

    def get_serializer_class(self):
        if self.action == 'create':
            return ReceiptScanCreateSerializer
        if self.action == 'list':
            return ReceiptScanListSerializer
        return ReceiptScanSerializer

    def create(self, request, *args, **kwargs):
        """Upload a new receipt and queue for processing."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        scan = ReceiptScan.objects.create(
            user=get_user_or_none(request),
            receipt_image=serializer.validated_data['receipt_image'],
            status=ReceiptScan.Status.PENDING,
        )

        # Queue async processing
        process_receipt_scan_task.delay(str(scan.id))

        output = ReceiptScanSerializer(scan, context={'request': request})
        return Response(output.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def reprocess(self, request, pk=None):
        """Requeue a scan for processing."""
        scan = self.get_object()
        scan.status = ReceiptScan.Status.PENDING
        scan.error_message = ''
        scan.save(update_fields=['status', 'error_message', 'updated_at'])

        process_receipt_scan_task.delay(str(scan.id))

        return Response(
            {'detail': 'reprocess queued'},
            status=status.HTTP_202_ACCEPTED
        )


# =============================================================================
# PRICE WATCH VIEWS
# =============================================================================

class PriceWatchViewSet(viewsets.ReadOnlyModelViewSet):
    """
    View price watches.

    Endpoints:
    - GET /price-watches/ - List active watches
    - GET /price-watches/{id}/ - Get watch details
    - POST /price-watches/{id}/deactivate/ - Stop watching
    """
    permission_classes = [AllowAny]
    serializer_class = PriceWatchSerializer

    def get_queryset(self):
        user = get_user_or_none(self.request)
        qs = PriceWatch.objects.filter(
            is_active=True,
            expires_at__gt=timezone.now()
        ).order_by('-created_at')
        if user:
            return qs.filter(user=user)
        return qs

    @action(detail=True, methods=['post'])
    def deactivate(self, request, pk=None):
        """Manually deactivate a price watch."""
        watch = self.get_object()
        watch.is_active = False
        watch.save(update_fields=['is_active'])
        return Response({'detail': 'price watch deactivated'})


# =============================================================================
# USER DEVICE VIEWS
# =============================================================================

class UserDeviceViewSet(viewsets.ModelViewSet):
    """
    Manage device FCM tokens.

    Endpoints:
    - GET /devices/ - List devices
    - POST /devices/ - Register device token
    - DELETE /devices/{id}/ - Remove device
    - POST /devices/unregister/ - Unregister by token
    """
    permission_classes = [AllowAny]

    def get_queryset(self):
        user = get_user_or_none(self.request)
        if user:
            return UserDevice.objects.filter(user=user)
        return UserDevice.objects.all()

    def get_serializer_class(self):
        if self.action == 'create':
            return UserDeviceCreateSerializer
        return UserDeviceSerializer

    def create(self, request, *args, **kwargs):
        """Register or update device token."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = get_user_or_none(request)

        # Upsert by token - if token exists, update user association
        device, created = UserDevice.objects.update_or_create(
            fcm_token=serializer.validated_data['fcm_token'],
            defaults={
                'user': user,
                'device_type': serializer.validated_data.get(
                    'device_type', UserDevice.DeviceType.ANDROID
                ),
                'device_name': serializer.validated_data.get('device_name', ''),
                'is_active': True,
            }
        )

        output = UserDeviceSerializer(device)
        return Response(
            output.data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )

    @action(detail=False, methods=['post'])
    def unregister(self, request):
        """Unregister a device by token."""
        token = request.data.get('fcm_token')
        if not token:
            return Response(
                {'detail': 'fcm_token required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Filter by user if authenticated
        qs = UserDevice.objects.filter(fcm_token=token)
        user = get_user_or_none(request)
        if user:
            qs = qs.filter(user=user)

        updated = qs.update(is_active=False)

        if updated:
            return Response({'detail': 'device unregistered'})
        return Response(
            {'detail': 'device not found'},
            status=status.HTTP_404_NOT_FOUND
        )


# =============================================================================
# NOTIFICATION VIEWS
# =============================================================================

class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    """
    View notifications.

    Endpoints:
    - GET /notifications/ - List sent notifications
    - GET /notifications/{id}/ - Get notification details
    - PATCH /notifications/{id}/read/ - Mark as read
    - POST /notifications/mark-all-read/ - Mark all as read
    """
    permission_classes = [AllowAny]
    serializer_class = NotificationSerializer

    def get_queryset(self):
        user = get_user_or_none(self.request)
        qs = Notification.objects.filter(is_sent=True).order_by('-sent_at')
        if user:
            return qs.filter(user=user)
        return qs

    @action(detail=True, methods=['patch'])
    def read(self, request, pk=None):
        """Mark a notification as read."""
        notification = self.get_object()
        if not notification.read_at:
            notification.read_at = timezone.now()
            notification.save(update_fields=['read_at'])
        return Response({'detail': 'marked as read'})

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        """Mark all notifications as read."""
        user = get_user_or_none(request)
        qs = Notification.objects.filter(is_sent=True, read_at__isnull=True)
        if user:
            qs = qs.filter(user=user)

        updated = qs.update(read_at=timezone.now())
        return Response({'detail': f'marked {updated} as read'})


# =============================================================================
# NOTIFICATION PREFERENCE VIEWS
# =============================================================================

class NotificationPreferenceView(generics.RetrieveUpdateAPIView):
    """
    View and update notification preferences.

    Endpoints:
    - GET /notification-preferences/ - Get preferences
    - PATCH /notification-preferences/ - Update preferences
    """
    permission_classes = [AllowAny]
    serializer_class = NotificationPreferenceSerializer

    def get_object(self):
        """Get or create preferences for current user."""
        user = get_user_or_none(self.request)
        if user:
            obj, _ = NotificationPreference.objects.get_or_create(user=user)
            return obj
        # For anonymous users, return default preferences
        return NotificationPreference()
