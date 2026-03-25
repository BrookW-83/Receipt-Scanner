import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/receipt_scanner_bloc.dart';
import '../../domain/usecases/capture_image_usecase.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  String? _capturedImagePath;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReceiptScannerBloc, ReceiptScannerState>(
      listener: (context, state) {
        if (state is ImageCaptured) {
          _capturedImagePath = state.image.path;
        } else if (state is ReceiptUploaded) {
          // Navigate to result screen, pass local image path
          context.go('/scan/${state.scan.id}', extra: _capturedImagePath);
        } else if (state is ReceiptScannerFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Scan Receipt'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                context.read<ReceiptScannerBloc>().add(ResetStateRequested());
                context.pop();
              },
            ),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ReceiptScannerState state) {
    if (state is ReceiptScannerLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(state.message ?? 'Processing...'),
          ],
        ),
      );
    }

    if (state is ImageCaptured) {
      return _buildImagePreview(context, state);
    }

    return _buildImageSourcePicker(context);
  }

  Widget _buildImageSourcePicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: const Color(0xFF48C774).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Capture or Select Receipt',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo of your receipt or select one from your gallery',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: _buildSourceButton(
                  context,
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    context.read<ReceiptScannerBloc>().add(
                          const CaptureImageRequested(ImageSourceType.camera),
                        );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSourceButton(
                  context,
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    context.read<ReceiptScannerBloc>().add(
                          const CaptureImageRequested(ImageSourceType.gallery),
                        );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: const Color(0xFF48C774),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF48C774),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context, ImageCaptured state) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(state.image.path),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<ReceiptScannerBloc>().add(ResetStateRequested());
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final bytes = await state.image.readAsBytes();
                    if (context.mounted) {
                      context.read<ReceiptScannerBloc>().add(
                            UploadReceiptRequested(
                              imageBytes: bytes,
                              filename: state.image.name,
                            ),
                          );
                    }
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload & Analyze'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
