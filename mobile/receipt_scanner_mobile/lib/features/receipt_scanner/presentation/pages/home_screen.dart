import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../bloc/receipt_scanner_bloc.dart';
import '../../domain/entities/receipt_scan_entity.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, RouteAware {
  static const Color primaryGreen = Color(0xFF48C774);
  static const String _currencySymbol = 'Rs';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadScans();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _loadScans();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when navigating back to this screen
    final currentState = context.read<ReceiptScannerBloc>().state;
    if (currentState is! RecentScansLoaded && currentState is! ReceiptScannerLoading) {
      _loadScans();
    }
  }

  void _loadScans() {
    context.read<ReceiptScannerBloc>().add(LoadRecentScansRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Receipt Scanner',
          style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryGreen),
            onPressed: () {
              context.read<ReceiptScannerBloc>().add(LoadRecentScansRequested());
            },
          ),
        ],
      ),
      body: BlocBuilder<ReceiptScannerBloc, ReceiptScannerState>(
        builder: (context, state) {
          return RefreshIndicator(
            color: primaryGreen,
            onRefresh: () async {
              context.read<ReceiptScannerBloc>().add(LoadRecentScansRequested());
            },
            child: CustomScrollView(
              slivers: [
                // Hero section
                SliverToBoxAdapter(
                  child: _buildHeroSection(context),
                ),

                // Recent scans header
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Recent Scans',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Recent scans list
                if (state is ReceiptScannerLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: primaryGreen)),
                  )
                else if (state is RecentScansLoaded)
                  state.scans.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildScanTile(context, state.scans[index]),
                            childCount: state.scans.length,
                          ),
                        )
                else if (state is ReceiptScannerFailure)
                  SliverFillRemaining(
                    child: _buildErrorState(context, state.message),
                  )
                else
                  SliverFillRemaining(child: _buildEmptyState()),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/scan'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan Receipt'),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.receipt_long, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Track Your Savings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan your receipts to see how much you saved and find missed deals.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/scan'),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTile(BuildContext context, ReceiptScanEntity scan) {
    final dateFormat = DateFormat.yMMMd();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => context.push('/scan/${scan.id}'),
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(scan.status).withValues(alpha: 0.15),
          child: Icon(
            _getStatusIcon(scan.status),
            color: _getStatusColor(scan.status),
          ),
        ),
        title: Text(
          scan.merchantName.isNotEmpty ? scan.merchantName : 'Unknown Store',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scan.createdAt != null)
              Text(dateFormat.format(scan.createdAt!)),
            if (scan.hasSavings)
              Text(
                'Saved $_currencySymbol ${scan.totalSavings!.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (scan.total != null)
              Text(
                '$_currencySymbol ${scan.total!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            _buildStatusChip(scan.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(status),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return primaryGreen;
      case 'processing':
      case 'pending':
      case 'awaiting_review':
      case 'matching':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'processing':
      case 'pending':
      case 'matching':
        return Icons.hourglass_top;
      case 'awaiting_review':
        return Icons.rate_review;
      case 'failed':
        return Icons.error;
      default:
        return Icons.receipt;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No receipts yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to scan your first receipt',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load scans',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<ReceiptScannerBloc>().add(LoadRecentScansRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
