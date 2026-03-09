class ReceiptScannerEnvironment {
  static const String apiBaseUrl = String.fromEnvironment(
    'RECEIPT_SCANNER_API_BASE_URL',
    defaultValue: 'http://localhost:8010/api/',
  );
}
