import 'package:image_picker/image_picker.dart';
import '../repositories/receipt_scanner_repository.dart';

enum ImageSourceType { camera, gallery }

class CaptureImageUseCase {
  final ReceiptScannerRepository repository;

  CaptureImageUseCase(this.repository);

  Future<XFile?> call(ImageSourceType source) {
    switch (source) {
      case ImageSourceType.camera:
        return repository.captureFromCamera();
      case ImageSourceType.gallery:
        return repository.pickFromGallery();
    }
  }
}
