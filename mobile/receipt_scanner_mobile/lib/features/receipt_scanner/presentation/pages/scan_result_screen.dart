import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../bloc/receipt_scanner_bloc.dart';
import '../../domain/entities/receipt_scan_entity.dart';
import '../widgets/receipt_item_card.dart';
import '../widgets/savings_summary_card.dart';
import '../widgets/processing_indicator.dart';

class ScanResultScreen extends StatefulWidget {
  final String scanId;

  const ScanResultScreen({super.key, required this.scanId});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  @override
  void initState() {
    super.initState();
    // Start polling for status updates
    context.read<ReceiptScannerBloc>().add(PollReceiptStatusRequested(widget.scanId));
  }

  @override
  void dispose() {
    // Stop polling when leaving the screen
    context.read<ReceiptScannerBloc>().add(StopPollingRequested());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReceiptScannerBloc, ReceiptScannerState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Receipt Details'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                context.read<ReceiptScannerBloc>().add(StopPollingRequested());
                context.go('/');
              },
            ),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ReceiptScannerState state) {
    if (state is ReceiptProcessing) {
      return ProcessingIndicator(
        status: state.status,
        scanId: state.scanId,
      );
    }

    if (state is ReceiptDetailsLoaded) {
      return _buildReceiptDetails(context, state.scan);
    }

    if (state is ReceiptScannerFailure) {
      return _buildErrorState(context, state.message);
    }

    if (state is ReceiptScannerLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildReceiptDetails(BuildContext context, ReceiptScanEntity scan) {
    final dateFormat = DateFormat.yMMMd();
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ReceiptScannerBloc>().add(
              FetchReceiptDetailsRequested(widget.scanId),
            );
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.store,
                        size: 28,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scan.merchantName.isNotEmpty ? scan.merchantName : 'Unknown Store',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (scan.purchaseDate != null)
                            Text(
                              dateFormat.format(scan.purchaseDate!),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Savings summary
            if (scan.hasSavings || scan.hasMissedPromos)
              SavingsSummaryCard(scan: scan),

            const SizedBox(height: 16),

            // Items header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${scan.matchedItemsCount}/${scan.items.length} matched',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Items list
            ...scan.items.map((item) => ReceiptItemCard(item: item)),

            const SizedBox(height: 16),

            // Receipt totals
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (scan.subtotal != null)
                      _buildTotalRow('Subtotal', currencyFormat.format(scan.subtotal)),
                    if (scan.tax != null)
                      _buildTotalRow('Tax', currencyFormat.format(scan.tax)),
                    const Divider(),
                    _buildTotalRow(
                      'Total',
                      currencyFormat.format(scan.total ?? 0),
                      isBold: true,
                    ),
                    if (scan.hasSavings) ...[
                      const SizedBox(height: 8),
                      _buildTotalRow(
                        'You Saved',
                        currencyFormat.format(scan.totalSavings),
                        color: Colors.green,
                        isBold: true,
                      ),
                    ],
                    if (scan.hasMissedPromos) ...[
                      const SizedBox(height: 4),
                      _buildTotalRow(
                        'Missed Savings',
                        currencyFormat.format(scan.totalMissedPromos),
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Processing Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go Home'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => context.go('/scan'),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
