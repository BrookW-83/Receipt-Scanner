import 'package:get_it/get_it.dart';
import 'receipt_scanner_injection.dart';
import 'notification_injection.dart';

final sl = GetIt.instance;

Future<void> initDepInj({
  required Future<String?> Function() tokenProvider,
}) async {
  await initReceiptScannerModule(sl, tokenProvider: tokenProvider);
  await initNotificationModule(sl);
}
