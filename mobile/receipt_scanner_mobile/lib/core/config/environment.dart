class ReceiptScannerEnvironment {
  static const String apiBaseUrl = String.fromEnvironment(
    'RECEIPT_SCANNER_API_BASE_URL',
    defaultValue: 'https://dev-receipt-scanner.piksou.com/api/',
  );
}
