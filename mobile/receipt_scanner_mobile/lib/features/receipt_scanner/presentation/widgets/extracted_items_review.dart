import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/receipt_item_entity.dart';

class ExtractedItemsReview extends StatefulWidget {
  final ScrollController? scrollController;
  final String merchantName;
  final DateTime? purchaseDate;
  final num? subtotal;
  final num? tax;
  final num? total;
  final String currency;
  final List<ReceiptItemEntity> items;
  final bool isUpdating;
  final void Function(String itemId, {String? description, num? quantity, num? unitPrice, num? totalPrice}) onItemUpdated;
  final VoidCallback onAnalyse;

  const ExtractedItemsReview({
    super.key,
    this.scrollController,
    required this.merchantName,
    this.purchaseDate,
    this.subtotal,
    this.tax,
    this.total,
    required this.currency,
    required this.items,
    required this.isUpdating,
    required this.onItemUpdated,
    required this.onAnalyse,
  });

  @override
  State<ExtractedItemsReview> createState() => _ExtractedItemsReviewState();
}

class _ExtractedItemsReviewState extends State<ExtractedItemsReview> {
  bool _isEditMode = false;
  final List<_EditableItem> _editableItems = [];
  late TextEditingController _dateController;

  static const Color primaryGreen = Color(0xFF48C774);

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
    return Column(
      children: [
        // Drag handle
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  _buildTotalRow(),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Bottom buttons
        _buildBottomButtons(),
      ],
    );
  }

  Widget _buildStoreInfo() {
    return Center(
      child: Column(
        children: [
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Text(
          widget.purchaseDate != null
              ? dateFormat.format(widget.purchaseDate!)
              : 'Unknown',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item ${index + 1}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currencySymbol,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: item.priceController,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          '$_currencySymbol ${total.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: _isEditMode
            ? ElevatedButton(
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: widget.isUpdating ? null : widget.onAnalyse,
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
                            'Analyse',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
