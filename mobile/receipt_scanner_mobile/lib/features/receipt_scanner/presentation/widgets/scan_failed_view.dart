import 'package:flutter/material.dart';

class ScanFailedView extends StatelessWidget {
  final String? receiptImageUrl;
  final String? errorMessage;
  final VoidCallback onTryAgain;
  final VoidCallback? onGoBack;

  /// Primary green - rgba(72, 199, 116, 1)
  static const Color primaryGreen = Color(0xFF48C774);

  const ScanFailedView({
    super.key,
    this.receiptImageUrl,
    this.errorMessage,
    required this.onTryAgain,
    this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: onGoBack ?? () => Navigator.of(context).pop(),
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
        ],
      ),
      body: Column(
        children: [
          // Receipt image preview
          _buildReceiptPreview(),

          // Error content
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Warning icon - document with exclamation
                  _buildWarningIcon(),
                  const SizedBox(height: 24),

                  // Error message
                  const Text(
                    'Receipt Not Recognized',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),

                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Try Again button
          _buildTryAgainButton(),
        ],
      ),
    );
  }

  Widget _buildReceiptPreview() {
    return Container(
      height: 280,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
        image: receiptImageUrl != null
            ? DecorationImage(
                image: NetworkImage(receiptImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: receiptImageUrl == null
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

  Widget _buildWarningIcon() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Document icon
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          // Exclamation triangle overlay
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 28,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTryAgainButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: onTryAgain,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Try Again',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
