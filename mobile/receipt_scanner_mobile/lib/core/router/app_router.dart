import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/receipt_scanner/presentation/pages/home_screen.dart';
import '../../features/receipt_scanner/presentation/pages/scan_receipt_screen.dart';
import '../../features/receipt_scanner/presentation/pages/scan_result_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/scan',
      name: 'scan',
      builder: (context, state) => const ScanReceiptScreen(),
    ),
    GoRoute(
      path: '/scan/:id',
      name: 'scan-result',
      builder: (context, state) {
        final scanId = state.pathParameters['id']!;
        final imagePath = state.extra as String?;
        return ScanResultScreen(scanId: scanId, localImagePath: imagePath);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(state.uri.toString()),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);
