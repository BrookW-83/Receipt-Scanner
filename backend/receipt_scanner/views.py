from rest_framework import viewsets, permissions, status
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny

from .models import ReceiptScan
from .serializers import ReceiptScanSerializer, ReceiptScanCreateSerializer
from .tasks import process_receipt_scan_task


@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(_request):
    return Response({'status': 'ok'})


class ReceiptScanViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ReceiptScan.objects.filter(user=self.request.user).prefetch_related('items')

    def get_serializer_class(self):
        if self.action == 'create':
            return ReceiptScanCreateSerializer
        return ReceiptScanSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        scan = ReceiptScan.objects.create(
            user=request.user,
            receipt_image=serializer.validated_data['receipt_image'],
            status=ReceiptScan.Status.PENDING,
        )
        process_receipt_scan_task.delay(str(scan.id))

        output = ReceiptScanSerializer(scan, context={'request': request})
        return Response(output.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def reprocess(self, request, pk=None):
        scan = self.get_object()
        scan.status = ReceiptScan.Status.PENDING
        scan.error_message = ''
        scan.save(update_fields=['status', 'error_message', 'updated_at'])
        process_receipt_scan_task.delay(str(scan.id))
        return Response({'detail': 'reprocess queued'}, status=status.HTTP_202_ACCEPTED)
