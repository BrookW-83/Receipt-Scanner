import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'injections/dependency_injection_container.dart';
import 'features/receipt_scanner/presentation/bloc/receipt_scanner_bloc.dart';

bool _firebaseInitialized = false;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (skip gracefully if config files are missing)
  try {
    await Firebase.initializeApp();
    _firebaseInitialized = true;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _requestNotificationPermissions();
  } catch (e) {
    debugPrint('Firebase not configured, skipping: $e');
  }

  // Initialize dependency injection (no auth for now)
  await initDepInj(tokenProvider: () async => null);

  runApp(const ReceiptScannerApp());
}

Future<void> _requestNotificationPermissions() async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
}

class ReceiptScannerApp extends StatefulWidget {
  const ReceiptScannerApp({super.key});

  @override
  State<ReceiptScannerApp> createState() => _ReceiptScannerAppState();
}

class _ReceiptScannerAppState extends State<ReceiptScannerApp> {
  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
  }

  void _setupFirebaseMessaging() {
    if (!_firebaseInitialized) return;

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showInAppNotification(message);
      }
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // Check if app was opened from a notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }

  void _showInAppNotification(RemoteMessage message) {
    final snackBar = SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.notification?.title ?? 'Notification',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (message.notification?.body != null)
            Text(message.notification!.body!),
        ],
      ),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'View',
        onPressed: () => _handleNotificationTap(message),
      ),
    );

    ScaffoldMessenger.of(appRouter.routerDelegate.navigatorKey.currentContext!)
        .showSnackBar(snackBar);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    if (type == 'scan_complete' && data['scan_id'] != null) {
      appRouter.go('/scan/${data['scan_id']}');
    } else if (type == 'price_drop' && data['scan_id'] != null) {
      appRouter.go('/scan/${data['scan_id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<ReceiptScannerBloc>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Receipt Scanner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF48C774),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
