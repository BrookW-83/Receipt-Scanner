from celery import shared_task
from .models import ReceiptScan, ReceiptItem
from .services.parser_service import parse_receipt_image


@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=10, max_retries=2)
def process_receipt_scan_task(self, scan_id: str) -> str:
    scan = ReceiptScan.objects.get(id=scan_id)
    if scan.status == ReceiptScan.Status.COMPLETED:
        return f'scan {scan_id} already completed'

    scan.status = ReceiptScan.Status.PROCESSING
    scan.error_message = ''
    scan.save(update_fields=['status', 'error_message', 'updated_at'])

    try:
        data = parse_receipt_image(scan.receipt_image)
        scan.merchant_name = data.get('merchant_name', '')
        scan.currency = data.get('currency', 'USD')
        scan.total = data.get('total')
        scan.extracted_payload = data.get('extracted_payload', {})
        scan.status = ReceiptScan.Status.COMPLETED
        scan.save()

        ReceiptItem.objects.filter(scan=scan).delete()
        for index, item in enumerate(data.get('items', []), start=1):
            ReceiptItem.objects.create(
                scan=scan,
                line_number=item.get('line_number', index),
                description=item.get('description', ''),
                quantity=item.get('quantity', 1),
                unit_price=item.get('unit_price'),
                total_price=item.get('total_price'),
            )
    except Exception as exc:
        scan.status = ReceiptScan.Status.FAILED
        scan.error_message = str(exc)
        scan.save(update_fields=['status', 'error_message', 'updated_at'])
        raise

    return f'scan {scan_id} processed'
