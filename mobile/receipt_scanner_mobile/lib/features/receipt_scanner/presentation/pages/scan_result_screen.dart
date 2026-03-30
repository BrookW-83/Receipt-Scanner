import 'dart:io';
import 'package:flutter/foundation.dart';
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
  final String? localImagePath;

  const ScanResultScreen({super.key, required this.scanId, this.localImagePath});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  // Completion animation state
  bool _animatingCompletion = false;
  String _animatedStatus = 'pending';
  ReceiptScanEntity? _completedScan;
  late final ReceiptScannerBloc _bloc;

  // Track whether we've moved past the extraction+review phase
  bool _analysisStarted = false;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ReceiptScannerBloc>();
    _bloc.add(PollReceiptStatusRequested(widget.scanId));
  }

  @override
  void dispose() {
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

  /// Whether we should show the bottom sheet overlay (extraction + review phase).
  /// Only applies to fresh scans (localImagePath != null), not history views.
  bool _isSheetPhase(ReceiptScannerState state) {
    if (_analysisStarted) return false;
    if (widget.localImagePath == null) return false;
    return state is ReceiptScannerLoading ||
        state is ReceiptProcessing ||
        state is ExtractedItemsLoaded ||
        state is ExtractedItemsUpdating;
  }

  void _navigateBack() {
    _bloc.add(StopPollingRequested());
    _bloc.add(LoadRecentScansRequested());
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateBack();
        }
      },
      child: BlocConsumer<ReceiptScannerBloc, ReceiptScannerState>(
      listener: (context, state) {
        if (state is ExtractedItemsConfirming) {
          setState(() => _analysisStarted = true);
        }
        if (state is ReceiptDetailsLoaded && !_animatingCompletion && _completedScan == null) {
          _startCompletionAnimation(state.scan);
        }
      },
      builder: (context, state) {
        // === PHASE 3: Show completed results ===
        if (state is ReceiptDetailsLoaded && !_animatingCompletion) {
          return _buildReceiptDetails(context, state.scan);
        }

        // === PHASE 2: After "Analyse" — show 4-step progress ===
        if (_analysisStarted) {
          return _buildAnalysisPhase(context, state);
        }

        // === PHASE 1: Extraction + Review with bottom sheet over receipt image ===
        if (_isSheetPhase(state)) {
          return _buildSheetPhase(context, state);
        }

        // === Failure state ===
        if (state is ReceiptScannerFailure) {
          return ScanFailedView(
            errorMessage: state.message,
            onTryAgain: () {
              _bloc.add(StopPollingRequested());
              context.go('/scan');
            },
            onGoBack: _navigateBack,
          );
        }

        // Fallback loading
        return Scaffold(
          backgroundColor: Colors.white,
          body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF48C774)),
          ),
        );
      },
    ),
    );
  }

  // =========================================================================
  // PHASE 1: Bottom sheet over receipt image
  // =========================================================================

  Widget _buildSheetPhase(BuildContext context, ReceiptScannerState state) {
    final bool isExtracting = state is ReceiptScannerLoading ||
        state is ReceiptProcessing;
    final isUpdating = state is ExtractedItemsUpdating;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background: receipt image
          _buildReceiptImageBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                      shape: const CircleBorder(),
                    ),
                    onPressed: _navigateBack,
                  ),
                ),
              ),
            ),
          ),

          // Bottom sheet
          DraggableScrollableSheet(
            initialChildSize: isExtracting ? 0.25 : 0.80,
            minChildSize: 0.20,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.25, 0.80, 0.95],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: isExtracting
                    ? _buildExtractingSheet(scrollController)
                    : _buildExtractedItemsSheet(
                        context,
                        scrollController,
                        state is ExtractedItemsLoaded ? state : null,
                        isUpdating ? state as ExtractedItemsUpdating : null,
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptImageBackground({Widget? child}) {
    return SizedBox.expand(
      child: widget.localImagePath != null
          ? Image.file(
              File(widget.localImagePath!),
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.3),
              colorBlendMode: BlendMode.darken,
            )
          : Container(
              color: Colors.grey.shade900,
              child: child,
            ),
    );
  }

  Widget _buildExtractingSheet(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          // Receipt icon with pulse animation
          _ExtractingIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Extracting items...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI is reading your receipt',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildExtractedItemsSheet(
    BuildContext context,
    ScrollController scrollController,
    ExtractedItemsLoaded? loadedState,
    ExtractedItemsUpdating? updatingState,
  ) {
    final itemsState = loadedState ?? updatingState?.previousState;
    if (itemsState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ExtractedItemsReview(
      scrollController: scrollController,
      merchantName: itemsState.merchantName,
      purchaseDate: itemsState.purchaseDate,
      subtotal: itemsState.subtotal,
      tax: itemsState.tax,
      total: itemsState.total,
      currency: itemsState.currency,
      items: itemsState.items,
      isUpdating: updatingState != null,
      onItemUpdated: (itemId, {description, quantity, unitPrice, totalPrice}) {
        context.read<ReceiptScannerBloc>().add(
              UpdateExtractedItemRequested(
                scanId: itemsState.scanId,
                itemId: itemId,
                description: description,
                quantity: quantity,
                unitPrice: unitPrice,
                totalPrice: totalPrice,
              ),
            );
      },
      onAnalyse: () {
        context.read<ReceiptScannerBloc>().add(
              ConfirmExtractedItemsRequested(itemsState.scanId),
            );
      },
    );
  }

  // =========================================================================
  // PHASE 2: Analysis (4-step progress)
  // =========================================================================

  Widget _buildAnalysisPhase(BuildContext context, ReceiptScannerState state) {
    String status = 'confirming';

    if (state is ReceiptProcessing) {
      status = state.status;
    } else if (state is ExtractedItemsConfirming) {
      status = 'confirming';
    } else if (_animatingCompletion) {
      status = _animatedStatus;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysing Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
      ),
      body: ProcessingIndicator(
        status: status,
        scanId: widget.scanId,
      ),
    );
  }

  // =========================================================================
  // PHASE 3: Results
  // =========================================================================

  void _showReceiptImageViewer(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Receipt'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF48C774),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white54, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _downloadReceiptImage(BuildContext context, String imageUrl) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading receipt image...')),
    );
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);

      final dir = Directory.systemTemp;
      final fileName = 'receipt_${widget.scanId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt saved: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download receipt')),
      );
    }
  }

  Widget _buildReceiptDetails(BuildContext context, ReceiptScanEntity scan) {
    return ScanResultsView(
      scan: scan,
      receiptImageUrl: scan.receiptImageUrl,
      onDone: _navigateBack,
      onViewReceipt: () {
        final imageUrl = scan.receiptImageUrl;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _showReceiptImageViewer(context, imageUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt image not available')),
          );
        }
      },
      onDownload: () {
        final imageUrl = scan.receiptImageUrl;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _downloadReceiptImage(context, imageUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt image not available')),
          );
        }
      },
    );
  }
}

// =============================================================================
// Extracting indicator with pulse animation
// =============================================================================

class _ExtractingIndicator extends StatefulWidget {
  @override
  State<_ExtractingIndicator> createState() => _ExtractingIndicatorState();
}

class _ExtractingIndicatorState extends State<_ExtractingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFABDEBC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 40,
              color: Color(0xFF48C774),
            ),
          ),
        );
      },
    );
  }
}
