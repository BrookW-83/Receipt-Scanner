import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/receipt_scanner_bloc.dart';
import '../../domain/entities/receipt_scan_entity.dart';
import '../widgets/processing_indicator.dart';
import '../widgets/extracted_items_review.dart';
import '../widgets/scan_results_view.dart';
import '../widgets/scan_failed_view.dart';

class ScanResultScreen extends StatefulWidget {
  final String scanId;

  const ScanResultScreen({super.key, required this.scanId});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  // Animation: when completed, cycle through remaining steps before showing results
  bool _animatingCompletion = false;
  String _animatedStatus = 'pending';
  ReceiptScanEntity? _completedScan;
  late final ReceiptScannerBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ReceiptScannerBloc>();
    // Start polling for status updates
    _bloc.add(PollReceiptStatusRequested(widget.scanId));
  }

  @override
  void dispose() {
    // Stop polling when leaving the screen (safe — uses cached reference)
    _bloc.add(StopPollingRequested());
    super.dispose();
  }

  void _startCompletionAnimation(ReceiptScanEntity scan) async {
    if (_animatingCompletion) return;
    _animatingCompletion = true;
    _completedScan = scan;

    setState(() => _animatedStatus = 'matching');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _animatedStatus = 'calculating');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _animatingCompletion = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReceiptScannerBloc, ReceiptScannerState>(
      listener: (context, state) {
        if (state is ReceiptDetailsLoaded && !_animatingCompletion && _completedScan == null) {
          _startCompletionAnimation(state.scan);
        }
      },
      builder: (context, state) {
        // Show results view without AppBar (it has its own header)
        if (state is ReceiptDetailsLoaded && !_animatingCompletion) {
          return _buildReceiptDetails(context, state.scan);
        }

        // Show extracted items review (has its own Scaffold)
        if (state is ExtractedItemsLoaded) {
          return ExtractedItemsReview(
            merchantName: state.merchantName,
            purchaseDate: state.purchaseDate,
            subtotal: state.subtotal,
            tax: state.tax,
            total: state.total,
            currency: state.currency,
            items: state.items,
            isUpdating: false,
            onItemUpdated: (itemId, {description, quantity, unitPrice, totalPrice}) {
              context.read<ReceiptScannerBloc>().add(
                    UpdateExtractedItemRequested(
                      scanId: state.scanId,
                      itemId: itemId,
                      description: description,
                      quantity: quantity,
                      unitPrice: unitPrice,
                      totalPrice: totalPrice,
                    ),
                  );
            },
            onConfirm: () {
              context.read<ReceiptScannerBloc>().add(
                    ConfirmExtractedItemsRequested(state.scanId),
                  );
            },
          );
        }

        // Show extracted items with updating indicator (has its own Scaffold)
        if (state is ExtractedItemsUpdating) {
          return ExtractedItemsReview(
            merchantName: state.previousState.merchantName,
            purchaseDate: state.previousState.purchaseDate,
            subtotal: state.previousState.subtotal,
            tax: state.previousState.tax,
            total: state.previousState.total,
            currency: state.previousState.currency,
            items: state.previousState.items,
            isUpdating: true,
            onItemUpdated: (_, {description, quantity, unitPrice, totalPrice}) {},
            onConfirm: () {},
          );
        }

        // Show scan failed view
        if (state is ReceiptScannerFailure) {
          return ScanFailedView(
            errorMessage: state.message,
            onTryAgain: () {
              _bloc.add(StopPollingRequested());
              context.go('/scan');
            },
            onGoBack: () {
              _bloc.add(StopPollingRequested());
              context.go('/');
            },
          );
        }

        // For other states, show with AppBar
        return Scaffold(
          appBar: AppBar(
            title: const Text('Receipt Details'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _bloc.add(StopPollingRequested());
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

    // Show animation steps before revealing results
    if (_animatingCompletion) {
      return ProcessingIndicator(
        status: _animatedStatus,
        scanId: widget.scanId,
      );
    }

    // Show confirming state
    if (state is ExtractedItemsConfirming) {
      return ProcessingIndicator(
        status: 'confirming',
        scanId: state.scanId,
      );
    }

    // ReceiptDetailsLoaded and ReceiptScannerFailure are handled in build() method directly

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
    // Get receipt image URL if available
    String? receiptImageUrl;
    // The receipt_image field from the API would be here
    // For now we'll leave it null

    return ScanResultsView(
      scan: scan,
      receiptImageUrl: receiptImageUrl,
      onDone: () {
        _bloc.add(StopPollingRequested());
        context.go('/');
      },
      onViewReceipt: () {
        // TODO: Implement view receipt full screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('View receipt coming soon')),
        );
      },
      onDownload: () {
        // TODO: Implement download receipt
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download coming soon')),
        );
      },
    );
  }

}
