import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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

  static const Color primaryGreen = Color(0xFF48C774);
  static const Color secondaryGreen = Color(0xFFABDEBC);
  static const Color bgColor = Color(0xFFF0F7F3);
  static const String _currencySymbol = 'Rs';

  @override
  void initState() {
    super.initState();
    for (final item in widget.scan.items) {
      if (item.isMatched) {
        _notifyItems.add(item.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button and PikSou logo
            _buildTopBar(context),

            // Scrollable cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    // Card 1: Date & Merchant
                    _buildDateMerchantCard(),
                    const SizedBox(height: 12),

                    // Card 2: Receipt preview & actions
                    _buildReceiptActionsCard(),
                    const SizedBox(height: 12),

                    // Card 3: Savings & Items
                    _buildSavingsAndItemsCard(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Done button
      bottomNavigationBar: _buildDoneButton(),
    );
  }

  // ===========================================================================
  // Top bar
  // ===========================================================================

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: primaryGreen),
            onPressed: widget.onDone,
          ),
          const Spacer(),
          Text(
            'PikSou',
            style: GoogleFonts.dancingScript(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: primaryGreen,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ===========================================================================
  // Card 1: Date & Merchant
  // ===========================================================================

  Widget _buildDateMerchantCard() {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Date
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                widget.scan.purchaseDate != null
                    ? dateFormat.format(widget.scan.purchaseDate!)
                    : 'Unknown date',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Merchant name
          Flexible(
            child: Text(
              widget.scan.merchantName.isNotEmpty
                  ? widget.scan.merchantName
                  : 'Unknown Store',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Card 2: Receipt preview & actions
  // ===========================================================================

  Widget _buildReceiptActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Small receipt thumbnail
          Container(
            width: 48,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _buildReceiptThumbnail(),
          ),
          const Spacer(),

          // View button
          _buildActionButton(
            icon: Icons.visibility_outlined,
            label: 'View',
            onTap: widget.onViewReceipt,
          ),
          const SizedBox(width: 32),

          // Download button
          _buildActionButton(
            icon: Icons.download_outlined,
            label: 'Download',
            onTap: widget.onDownload,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildReceiptThumbnail() {
    final imageUrl = widget.scan.receiptImageUrl ?? widget.receiptImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _receiptPlaceholder(),
        ),
      );
    }
    return _receiptPlaceholder();
  }

  Widget _receiptPlaceholder() {
    return Center(
      child: Icon(Icons.receipt_long, color: Colors.grey.shade400, size: 24),
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
              color: primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: primaryGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Card 3: Savings & Items
  // ===========================================================================

  Widget _buildSavingsAndItemsCard() {
    final totalPaid = (widget.scan.total ?? 0).toDouble();
    final savings = (widget.scan.totalSavings ?? 0).toDouble().abs();
    final withPikSou = (totalPaid - savings).clamp(0.0, totalPaid);
    final savingsPercent = totalPaid > 0 ? savings / totalPaid : 0.0;
    final currencyFormat = NumberFormat.currency(symbol: '$_currencySymbol ');

    final matchedItems = widget.scan.items.where((item) => item.isMatched).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Center(
            child: Text(
              'You Could Have Saved',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Pie chart + amounts
          Row(
            children: [
              // Pie chart
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _SavingsPieChartPainter(
                    savingsPercent: savingsPercent.clamp(0.0, 1.0),
                    totalColor: secondaryGreen,
                    savingsColor: primaryGreen,
                  ),
                  child: Center(
                    child: Text(
                      '${(savingsPercent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Amounts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Savings amount
                    Text(
                      currencyFormat.format(savings),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'potential savings',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pie chart legend
          Row(
            children: [
              _legendDot(secondaryGreen),
              const SizedBox(width: 6),
              Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 20),
              _legendDot(primaryGreen),
              const SizedBox(width: 6),
              Text('Saved', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 20),

          // You paid / With PikSou
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You Paid',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    Text(
                      currencyFormat.format(totalPaid),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'With PikSou',
                      style: GoogleFonts.dancingScript(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryGreen,
                      ),
                    ),
                    Text(
                      currencyFormat.format(withPikSou),
                      style: const TextStyle(
                        fontSize: 17,
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Items header
          const Text(
            'Items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Notify toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notify me when these items are on discount',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
                activeThumbColor: Colors.white,
                activeTrackColor: primaryGreen,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Matched items
          ...matchedItems.map((item) => _buildItemCard(item)),

          // Unmatched items
          if (widget.scan.items.any((item) => !item.isMatched)) ...[
            const SizedBox(height: 12),
            Text(
              'Other Items',
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

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildItemCard(ReceiptItemEntity item) {
    final currencyFormat = NumberFormat.currency(symbol: '$_currencySymbol ');
    final hasDiscount = item.hasMissedPromo || item.hasSavings;
    final originalPrice = item.unitPrice ?? item.totalPrice ?? 0;
    final discountPrice = item.promoPrice ?? item.databasePrice ?? originalPrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shopping_basket, color: Colors.grey.shade400, size: 24),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (item.matchedProductName != null && item.matchedProductName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.matchedProductName!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 4),
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
                        color: hasDiscount ? primaryGreen : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toggle
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
            activeThumbColor: Colors.white,
            activeTrackColor: primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildUnmatchedItemCard(ReceiptItemEntity item) {
    final currencyFormat = NumberFormat.currency(symbol: '$_currencySymbol ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          Text(
            currencyFormat.format(item.totalPrice ?? item.unitPrice ?? 0),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Done button
  // ===========================================================================

  Widget _buildDoneButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
    );
  }
}

// =============================================================================
// Pie chart painter
// =============================================================================

class _SavingsPieChartPainter extends CustomPainter {
  final double savingsPercent;
  final Color totalColor;
  final Color savingsColor;

  _SavingsPieChartPainter({
    required this.savingsPercent,
    required this.totalColor,
    required this.savingsColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Total (light green) - full circle background
    final totalPaint = Paint()
      ..color = totalColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, totalPaint);

    // Savings (primary green) - arc from top
    if (savingsPercent > 0) {
      final savingsPaint = Paint()
        ..color = savingsColor
        ..style = PaintingStyle.fill;
      final sweepAngle = 2 * math.pi * savingsPercent;
      canvas.drawArc(rect, -math.pi / 2, sweepAngle, true, savingsPaint);
    }

    // White center hole for donut effect
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, holePaint);
  }

  @override
  bool shouldRepaint(covariant _SavingsPieChartPainter oldDelegate) {
    return oldDelegate.savingsPercent != savingsPercent;
  }
}
