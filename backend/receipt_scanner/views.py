"""
Views for Receipt Scanner API

Endpoints:
- ReceiptScan CRUD + reprocess + extracted items review
- PriceWatch list/deactivate
- UserDevice register/unregister
- Notification list/mark read
- NotificationPreference get/update

Authentication is optional for testing. When authenticated, user data is
associated with requests. When not authenticated, user fields are left null.
"""

from decimal import Decimal

from rest_framework import viewsets, generics, status
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.throttling import AnonRateThrottle
from django.utils import timezone

from .models import (
    ReceiptScan,
    ReceiptItem,
    PriceWatch,
    UserDevice,
    Notification,
    NotificationPreference,
)
from .serializers import (
    ReceiptScanSerializer,
    ReceiptScanCreateSerializer,
    ReceiptScanListSerializer,
    ExtractedItemSerializer,
    PriceWatchSerializer,
    UserDeviceSerializer,
    UserDeviceCreateSerializer,
    NotificationSerializer,
    NotificationPreferenceSerializer,
)
from .tasks import extract_receipt_task, process_receipt_items_task, process_receipt_scan_task
from .services.product_matcher import normalize_product_name


# =============================================================================
# HELPERS
# =============================================================================

def get_user_id_or_none(request):
    """Get authenticated user's ID or None for anonymous requests."""
    if request.user and request.user.is_authenticated:
        return request.user.id
    return None


# =============================================================================
# THROTTLING
# =============================================================================

class ReceiptUploadThrottle(AnonRateThrottle):
    """Rate limit receipt uploads to 3 per hour."""
    rate = '1000/hour'
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
        user_id = get_user_id_or_none(self.request)
        qs = ReceiptScan.objects.prefetch_related('items').order_by('-created_at')
        if user_id:
            return qs.filter(user_id=user_id)
        return qs

    def get_serializer_class(self):
        if self.action == 'create':
            return ReceiptScanCreateSerializer
        if self.action == 'list':
            return ReceiptScanListSerializer
        return ReceiptScanSerializer

    def create(self, request, *args, **kwargs):
        """Upload a new receipt and queue for extraction."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        scan = ReceiptScan.objects.create(
            user_id=get_user_id_or_none(request),
            receipt_image=serializer.validated_data['receipt_image'],
            status=ReceiptScan.Status.PENDING,
        )

        # Queue async extraction (pauses at AWAITING_REVIEW for user review)
        extract_receipt_task.delay(str(scan.id))

        output = ReceiptScanSerializer(scan, context={'request': request})
        return Response(output.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def reprocess(self, request, pk=None):
        """Requeue a scan for full processing (extract + match)."""
        scan = self.get_object()
        scan.status = ReceiptScan.Status.PENDING
        scan.error_message = ''
        scan.save(update_fields=['status', 'error_message', 'updated_at'])

        # Use legacy task that does full pipeline
        process_receipt_scan_task.delay(str(scan.id))

        return Response(
            {'detail': 'reprocess queued'},
            status=status.HTTP_202_ACCEPTED
        )

    @action(detail=True, methods=['get', 'patch'], url_path='extracted-items')
    def extracted_items(self, request, pk=None):
        """
        GET: Get extracted items for user review.
        PATCH: Edit extracted items before processing.

        Only available when scan status is AWAITING_REVIEW.
        """
        scan = self.get_object()

        if scan.status != ReceiptScan.Status.AWAITING_REVIEW:
            return Response(
                {'detail': f'Scan must be in awaiting_review status, current status: {scan.status}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if request.method == 'GET':
            return self._get_extracted_items(scan)
        elif request.method == 'PATCH':
            return self._update_extracted_items(request, scan)

    def _get_extracted_items(self, scan):
        """Helper: Return extracted items for review."""
        items = scan.items.all().order_by('line_number')
        return Response({
            'scan_id': str(scan.id),
            'merchant_name': scan.merchant_name,
            'purchase_date': scan.purchase_date,
            'subtotal': scan.subtotal,
            'tax': scan.tax,
            'total': scan.total,
            'currency': scan.currency,
            'items': ExtractedItemSerializer(items, many=True).data
        })

    def _update_extracted_items(self, request, scan):
        """
        Helper: Update extracted items.
        Accepts: {"items": [{"id": "uuid", "description": "...", ...}, ...]}
        """
        items_data = request.data.get('items', [])
        if not items_data:
            return Response(
                {'detail': 'No items provided'},
                status=status.HTTP_400_BAD_REQUEST
            )

        updated_items = []
        errors = []

        for item_data in items_data:
            item_id = item_data.get('id')
            if not item_id:
                errors.append({'error': 'Item id is required'})
                continue

            try:
                item = ReceiptItem.objects.get(id=item_id, scan=scan)
            except ReceiptItem.DoesNotExist:
                errors.append({'id': item_id, 'error': 'Item not found'})
                continue

            # Update editable fields
            if 'description' in item_data:
                item.description = item_data['description']
                item.normalized_description = normalize_product_name(item_data['description'])
            if 'quantity' in item_data:
                item.quantity = Decimal(str(item_data['quantity']))
            if 'unit_price' in item_data:
                item.unit_price = Decimal(str(item_data['unit_price'])) if item_data['unit_price'] is not None else None
            if 'total_price' in item_data:
                item.total_price = Decimal(str(item_data['total_price'])) if item_data['total_price'] is not None else None

            item.save()
            updated_items.append(str(item.id))

        response_data = {
            'detail': f'Updated {len(updated_items)} items',
            'updated_item_ids': updated_items
        }
        if errors:
            response_data['errors'] = errors

        return Response(response_data)

    @action(detail=True, methods=['post'])
    def confirm(self, request, pk=None):
        """
        Confirm extracted items and trigger product matching.

        Only available when scan status is AWAITING_REVIEW.
        """
        scan = self.get_object()

        # Only allow confirming in AWAITING_REVIEW status
        if scan.status != ReceiptScan.Status.AWAITING_REVIEW:
            return Response(
                {'detail': f'Scan must be in awaiting_review status, current status: {scan.status}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Queue processing task (matching, savings, promos)
        process_receipt_items_task.delay(str(scan.id))

        return Response(
            {'detail': 'Processing started', 'scan_id': str(scan.id)},
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
        user_id = get_user_id_or_none(self.request)
        qs = PriceWatch.objects.filter(
            is_active=True,
            expires_at__gt=timezone.now()
        ).order_by('-created_at')
        if user_id:
            return qs.filter(user_id=user_id)
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
        user_id = get_user_id_or_none(self.request)
        if user_id:
            return UserDevice.objects.filter(user_id=user_id)
        return UserDevice.objects.all()

    def get_serializer_class(self):
        if self.action == 'create':
            return UserDeviceCreateSerializer
        return UserDeviceSerializer

    def create(self, request, *args, **kwargs):
        """Register or update device token."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user_id = get_user_id_or_none(request)

        # Upsert by token - if token exists, update user association
        device, created = UserDevice.objects.update_or_create(
            fcm_token=serializer.validated_data['fcm_token'],
            defaults={
                'user_id': user_id,
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
        user_id = get_user_id_or_none(request)
        if user_id:
            qs = qs.filter(user_id=user_id)

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
        user_id = get_user_id_or_none(self.request)
        qs = Notification.objects.filter(is_sent=True).order_by('-sent_at')
        if user_id:
            return qs.filter(user_id=user_id)
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
        user_id = get_user_id_or_none(request)
        qs = Notification.objects.filter(is_sent=True, read_at__isnull=True)
        if user_id:
            qs = qs.filter(user_id=user_id)

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
        user_id = get_user_id_or_none(self.request)
        if user_id:
            obj, _ = NotificationPreference.objects.get_or_create(user_id=user_id)
            return obj
        # For anonymous users, return default preferences
        return NotificationPreference()
