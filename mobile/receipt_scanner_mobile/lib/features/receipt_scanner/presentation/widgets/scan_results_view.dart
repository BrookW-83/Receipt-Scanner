import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../domain/entities/receipt_scan_entity.dart';
import '../../domain/entities/receipt_item_entity.dart';

class ScanResultsView extends StatefulWidget {
  final ReceiptScanEntity scan;
  final String? receiptImageUrl;
  final VoidCallback onDone;
  final VoidCallback? onViewReceipt;
  final VoidCallback? onDownload;

  const ScanResultsView({
    super.key,
    required this.scan,
    this.receiptImageUrl,
    required this.onDone,
    this.onViewReceipt,
    this.onDownload,
  });

  @override
  State<ScanResultsView> createState() => _ScanResultsViewState();
}

class _ScanResultsViewState extends State<ScanResultsView> {
  bool _notifyAllItems = true;
  final Set<String> _notifyItems = {};

  /// Primary green - rgba(72, 199, 116, 1)
  static const Color primaryGreen = Color(0xFF48C774);
  /// Secondary green - rgba(171, 222, 188, 1)
  static const Color secondaryGreen = Color(0xFFABDEBC);
  /// Default currency symbol for Mauritius Rupee
  static const String _currencySymbol = 'Rs';

  @override
  void initState() {
    super.initState();
    // Initialize all matched items as notified
    for (final item in widget.scan.items) {
      if (item.isMatched) {
        _notifyItems.add(item.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      body: Column(
        children: [
          // Green header section
          Container(
            decoration: BoxDecoration(
              color: secondaryGreen.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // App bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.onDone,
                          color: primaryGreen,
                        ),
                        const Spacer(),
                        Text(
                          'PikSou',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                  ),

                  // Date and Store row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                widget.scan.purchaseDate != null
                                    ? dateFormat.format(widget.scan.purchaseDate!)
                                    : 'Unknown',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Store
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(Icons.store, color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.scan.merchantName.isNotEmpty
                                    ? widget.scan.merchantName
                                    : 'Unknown Store',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Receipt preview card
                  _buildReceiptPreviewCard(context),
                  const SizedBox(height: 16),

                  // Savings card
                  _buildSavingsCard(context, primaryGreen),
                  const SizedBox(height: 16),

                  // Items section
                  _buildItemsSection(context, primaryGreen),
                  const SizedBox(height: 100),
                  
                ],
              ),
            ),
          ),
        ],
      ),

      // Done button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: widget.onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptPreviewCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Receipt thumbnail
          Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: widget.receiptImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.receiptImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.receipt_long,
                        color: Colors.grey.shade400,
                        size: 32,
                      ),
                    ),
                  )
                : Icon(
                    Icons.receipt_long,
                    color: Colors.grey.shade400,
                    size: 32,
                  ),
          ),
          const Spacer(),

          // View Receipt button
          _buildActionButton(
            icon: Icons.visibility_outlined,
            label: 'View Receipt',
            onTap: widget.onViewReceipt,
          ),
          const SizedBox(width: 24),

          // Download button
          _buildActionButton(
            icon: Icons.download_outlined,
            label: 'Download',
            onTap: widget.onDownload,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryGreen, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: primaryGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(BuildContext context, Color primaryGreen) {
    final currencyFormat = NumberFormat.currency(symbol: _currencySymbol);
    final totalPaid = widget.scan.total ?? 0;
    final potentialSavings = widget.scan.totalMissedPromos ?? 0;
    final withPikSou = (totalPaid as num) - (potentialSavings as num);

    // Calculate percentage for the ring
    final savingsPercentage = totalPaid > 0 ? (potentialSavings / totalPaid) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Title
          Text(
            'You Could Have Saved',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: primaryGreen,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),

          // Savings amount and ring
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currencySymbol,
                    style: TextStyle(
                      fontSize: 24,
                      color: primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    potentialSavings.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Ring chart
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _SavingsRingPainter(
                    progress: savingsPercentage.clamp(0.0, 1.0),
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Comparison
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You Paid',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'With PikSou',
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(totalPaid),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(withPikSou),
                    style: TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context, Color primaryGreen) {
    final matchedItems = widget.scan.items.where((item) => item.isMatched).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Notify toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notify me next time these items are on discount',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Switch(
                value: _notifyAllItems,
                onChanged: (value) {
                  setState(() {
                    _notifyAllItems = value;
                    if (value) {
                      for (final item in matchedItems) {
                        _notifyItems.add(item.id);
                      }
                    } else {
                      _notifyItems.clear();
                    }
                  });
                },
                activeColor: primaryGreen,
              ),
            ],
          ),
          const Divider(height: 24),

          // Items list
          ...matchedItems.map((item) => _buildItemCard(item, primaryGreen)),

          // Non-matched items (if any)
          if (widget.scan.items.any((item) => !item.isMatched)) ...[
            const SizedBox(height: 16),
            Text(
              'Unmatched Items',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.scan.items
                .where((item) => !item.isMatched)
                .map((item) => _buildUnmatchedItemCard(item)),
          ],
        ],
      ),
    );
  }

  Widget _buildItemCard(ReceiptItemEntity item, Color primaryGreen) {
    final currencyFormat = NumberFormat.currency(symbol: _currencySymbol);
    final hasDiscount = item.hasMissedPromo || item.hasSavings;
    final originalPrice = item.unitPrice ?? item.totalPrice ?? 0;
    final discountPrice = item.promoPrice ?? item.databasePrice ?? originalPrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image placeholder
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shopping_basket,
              color: Colors.grey.shade400,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original description
                Text(
                  item.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),

                // Matched product name
                if (item.matchedProductName != null && item.matchedProductName!.isNotEmpty)
                  Text(
                    item.matchedProductName!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 4),

                // Store badge (placeholder - would need store data)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront, size: 12, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Best Deal',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Prices
                Row(
                  children: [
                    if (hasDiscount) ...[
                      Text(
                        currencyFormat.format(originalPrice),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      currencyFormat.format(hasDiscount ? discountPrice : originalPrice),
                      style: TextStyle(
                        fontSize: 15,
                        color: hasDiscount ? primaryGreen : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Notification toggle
          Switch(
            value: _notifyItems.contains(item.id),
            onChanged: (value) {
              setState(() {
                if (value) {
                  _notifyItems.add(item.id);
                } else {
                  _notifyItems.remove(item.id);
                }
                _notifyAllItems = _notifyItems.length ==
                    widget.scan.items.where((i) => i.isMatched).length;
              });
            },
            activeColor: primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildUnmatchedItemCard(ReceiptItemEntity item) {
    final currencyFormat = NumberFormat.currency(symbol: _currencySymbol);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            currencyFormat.format(item.totalPrice ?? item.unitPrice ?? 0),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the savings ring
class _SavingsRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SavingsRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SavingsRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
