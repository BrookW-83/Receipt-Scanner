import 'package:flutter/material.dart';

class ProcessingIndicator extends StatefulWidget {
  final String status;
  final String scanId;

  const ProcessingIndicator({
    super.key,
    required this.status,
    required this.scanId,
  });

  @override
  State<ProcessingIndicator> createState() => _ProcessingIndicatorState();
}

class _ProcessingIndicatorState extends State<ProcessingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated receipt icon
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(),
                      size: 64,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Status text
            Text(
              _getStatusTitle(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _getStatusMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Progress indicator
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Processing steps
            _buildProcessingSteps(),
          ],
        ),
      ),
    );
  }

  int _statusLevel() {
    switch (widget.status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'processing':
        return 1;
      case 'matching':
        return 2;
      case 'calculating':
        return 3;
      default:
        return 0;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_top;
      case 'processing':
        return Icons.auto_awesome;
      case 'matching':
        return Icons.compare_arrows;
      case 'calculating':
        return Icons.calculate;
      default:
        return Icons.receipt_long;
    }
  }

  String _getStatusTitle() {
    switch (widget.status.toLowerCase()) {
      case 'pending':
        return 'In Queue';
      case 'processing':
        return 'Analyzing Receipt';
      case 'matching':
        return 'Matching Products';
      case 'calculating':
        return 'Calculating Savings';
      default:
        return 'Processing';
    }
  }

  String _getStatusMessage() {
    switch (widget.status.toLowerCase()) {
      case 'pending':
        return 'Your receipt is waiting to be processed.\nThis usually takes a few seconds.';
      case 'processing':
        return 'AI is reading your receipt...\nThis may take 10-15 seconds.';
      case 'matching':
        return 'Matching items to products in our database...';
      case 'calculating':
        return 'Calculating your potential savings...';
      default:
        return 'Please wait while we process your receipt.';
    }
  }

  Widget _buildProcessingSteps() {
    final level = _statusLevel();
    final steps = [
      ('Upload', Icons.cloud_upload, true),
      ('Extract', Icons.document_scanner, level >= 1),
      ('Match', Icons.compare_arrows, level >= 2),
      ('Calculate', Icons.calculate, level >= 3),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isActive = step.$3;
        final isLast = index == steps.length - 1;

        return Row(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.$2,
                    size: 16,
                    color: isActive ? Colors.white : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.$1,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade500,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (!isLast)
              Container(
                width: 24,
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
              ),
          ],
        );
      }).toList(),
    );
  }
}
