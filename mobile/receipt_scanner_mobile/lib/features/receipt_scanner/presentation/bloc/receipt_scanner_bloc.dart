import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/receipt_scan_entity.dart';
import '../../domain/usecases/upload_receipt_usecase.dart';

sealed class ReceiptScannerEvent extends Equatable {
  const ReceiptScannerEvent();

  @override
  List<Object?> get props => [];
}

class UploadReceiptRequested extends ReceiptScannerEvent {
  final List<int> imageBytes;
  final String filename;

  const UploadReceiptRequested({required this.imageBytes, required this.filename});

  @override
  List<Object?> get props => [imageBytes, filename];
}

sealed class ReceiptScannerState extends Equatable {
  const ReceiptScannerState();

  @override
  List<Object?> get props => [];
}

class ReceiptScannerInitial extends ReceiptScannerState {}
class ReceiptScannerLoading extends ReceiptScannerState {}

class ReceiptScannerSuccess extends ReceiptScannerState {
  final ReceiptScanEntity scan;

  const ReceiptScannerSuccess(this.scan);

  @override
  List<Object?> get props => [scan];
}

class ReceiptScannerFailure extends ReceiptScannerState {
  final String message;

  const ReceiptScannerFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class ReceiptScannerBloc extends Bloc<ReceiptScannerEvent, ReceiptScannerState> {
  final UploadReceiptUseCase uploadReceiptUseCase;

  ReceiptScannerBloc({required this.uploadReceiptUseCase}) : super(ReceiptScannerInitial()) {
    on<UploadReceiptRequested>(_onUpload);
  }

  Future<void> _onUpload(
    UploadReceiptRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    emit(ReceiptScannerLoading());
    try {
      final scan = await uploadReceiptUseCase(
        imageBytes: event.imageBytes,
        filename: event.filename,
      );
      emit(ReceiptScannerSuccess(scan));
    } catch (e) {
      emit(ReceiptScannerFailure(e.toString()));
    }
  }
}
