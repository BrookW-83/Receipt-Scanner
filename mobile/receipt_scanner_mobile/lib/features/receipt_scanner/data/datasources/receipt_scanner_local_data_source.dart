import 'package:image_picker/image_picker.dart';

abstract class ReceiptScannerLocalDataSource {
  Future<XFile?> captureFromCamera();
  Future<XFile?> pickFromGallery();
}

class ReceiptScannerLocalDataSourceImpl implements ReceiptScannerLocalDataSource {
  final ImagePicker _imagePicker;

  ReceiptScannerLocalDataSourceImpl({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  @override
  Future<XFile?> captureFromCamera() async {
    return await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
  }

  @override
  Future<XFile?> pickFromGallery() async {
    return await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
  }
}
