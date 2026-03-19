import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/receipt_item_entity.dart';

class ExtractedItemsReview extends StatefulWidget {
  final String merchantName;
  final DateTime? purchaseDate;
  final num? subtotal;
  final num? tax;
  final num? total;
  final String currency;
  final List<ReceiptItemEntity> items;
  final bool isUpdating;
  final String? receiptImageUrl;
  final void Function(String itemId, {String? description, num? quantity, num? unitPrice, num? totalPrice}) onItemUpdated;
  final VoidCallback onConfirm;

  const ExtractedItemsReview({
    super.key,
    required this.merchantName,
    this.purchaseDate,
    this.subtotal,
    this.tax,
    this.total,
    required this.currency,
    required this.items,
    required this.isUpdating,
    this.receiptImageUrl,
    required this.onItemUpdated,
    required this.onConfirm,
  });

  @override
  State<ExtractedItemsReview> createState() => _ExtractedItemsReviewState();
}

class _ExtractedItemsReviewState extends State<ExtractedItemsReview> {
  bool _isEditMode = false;
  final List<_EditableItem> _editableItems = [];
  late TextEditingController _dateController;

  /// Primary green - rgba(72, 199, 116, 1)
  static const Color primaryGreen = Color(0xFF48C774);
  /// Secondary green - rgba(171, 222, 188, 1)
  static const Color secondaryGreen = Color(0xFFABDEBC);

  @override
  void initState() {
    super.initState();
    _initializeEditableItems();
    final dateFormat = DateFormat('dd/MM/yyyy');
    _dateController = TextEditingController(
      text: widget.purchaseDate != null ? dateFormat.format(widget.purchaseDate!) : '',
    );
  }

  void _initializeEditableItems() {
    _editableItems.clear();
    for (final item in widget.items) {
      _editableItems.add(_EditableItem(
        id: item.id,
        descriptionController: TextEditingController(text: item.description),
        priceController: TextEditingController(
          text: (item.totalPrice ?? item.unitPrice)?.toStringAsFixed(2) ?? '',
        ),
      ));
    }
  }

  @override
  void didUpdateWidget(ExtractedItemsReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _initializeEditableItems();
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    for (final item in _editableItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addNewItem() {
    setState(() {
      _editableItems.add(_EditableItem(
        id: 'new_${DateTime.now().millisecondsSinceEpoch}',
        descriptionController: TextEditingController(),
        priceController: TextEditingController(),
        isNew: true,
      ));
    });
  }

  void _saveChanges() {
    // Save each modified item
    for (int i = 0; i < _editableItems.length; i++) {
      final editableItem = _editableItems[i];
      if (i < widget.items.length) {
        final originalItem = widget.items[i];
        final newDescription = editableItem.descriptionController.text.trim();
        final newPrice = num.tryParse(editableItem.priceController.text);

        if (newDescription != originalItem.description ||
            newPrice != (originalItem.totalPrice ?? originalItem.unitPrice)) {
          widget.onItemUpdated(
            originalItem.id,
            description: newDescription != originalItem.description ? newDescription : null,
            totalPrice: newPrice,
          );
        }
      }
    }
    setState(() => _isEditMode = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Scan receipt',
          style: TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: primaryGreen),
            onPressed: () {},
          ),
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.flash_on, color: primaryGreen),
              onPressed: () {},
            ),
        ],
      ),
      body: Column(
        children: [
          // Receipt image preview
          _buildReceiptPreview(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Store info
                    _buildStoreInfo(),
                    const SizedBox(height: 24),

                    // Date row
                    _buildDateRow(),
                    const SizedBox(height: 24),

                    // Items section
                    _buildItemsSection(),

                    if (!_isEditMode) ...[
                      const Divider(height: 32),
                      // Total row
                      _buildTotalRow(),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Bottom buttons
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildReceiptPreview() {
    if (_isEditMode) {
      // Collapsed preview in edit mode
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    // Full preview in view mode
    return Container(
      height: 280,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
        image: widget.receiptImageUrl != null
            ? DecorationImage(
                image: NetworkImage(widget.receiptImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: widget.receiptImageUrl == null
          ? Stack(
              children: [
                // Placeholder receipt look
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Receipt Preview',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildStoreInfo() {
    return Center(
      child: Column(
        children: [
          // Store logo placeholder
          Container(
            width: 80,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                'STORE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.merchantName.isNotEmpty ? widget.merchantName : 'Unknown Store',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    if (_isEditMode) {
      return Row(
        children: [
          const Text(
            'Date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.purchaseDate != null
                  ? dateFormat.format(widget.purchaseDate!)
                  : 'Unknown',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          widget.purchaseDate != null
              ? dateFormat.format(widget.purchaseDate!)
              : 'Unknown',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Items',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),

        if (_isEditMode)
          ..._buildEditableItems()
        else
          ..._buildViewItems(),

        if (_isEditMode) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _addNewItem,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryGreen,
                side: const BorderSide(color: primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Add'),
            ),
          ),
        ],
      ],
    );
  }

  /// Default currency symbol for Mauritius Rupee
  static const String _currencySymbol = 'Rs';

  List<Widget> _buildViewItems() {
    return widget.items.map((item) {
      final price = item.totalPrice ?? item.unitPrice ?? 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.description,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '$_currencySymbol ${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildEditableItems() {
    return _editableItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description field
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item ${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: item.descriptionController,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 15),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Price field
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currencySymbol,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: item.priceController,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildTotalRow() {
    final total = widget.total ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$_currencySymbol ${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: _isEditMode
            ? // Done button in edit mode
            ElevatedButton(
                onPressed: widget.isUpdating ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: widget.isUpdating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              )
            : // Edit and Analyze buttons in view mode
            Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit button
                  OutlinedButton(
                    onPressed: () => setState(() => _isEditMode = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryGreen,
                      side: const BorderSide(color: primaryGreen),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Analyze button
                  ElevatedButton(
                    onPressed: widget.isUpdating ? null : widget.onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                    child: widget.isUpdating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Analyze',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EditableItem {
  final String id;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final bool isNew;

  _EditableItem({
    required this.id,
    required this.descriptionController,
    required this.priceController,
    this.isNew = false,
  });

  void dispose() {
    descriptionController.dispose();
    priceController.dispose();
  }
}
