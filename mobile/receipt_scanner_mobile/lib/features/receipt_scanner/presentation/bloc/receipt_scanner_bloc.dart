import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/receipt_scan_entity.dart';
import '../../domain/entities/receipt_item_entity.dart';
import '../../domain/usecases/upload_receipt_usecase.dart';
import '../../domain/usecases/get_receipt_details_usecase.dart';
import '../../domain/usecases/capture_image_usecase.dart';
import '../../domain/usecases/get_recent_scans_usecase.dart';
import '../../domain/repositories/receipt_scanner_repository.dart';
import '../../data/models/extracted_items_response.dart';

// ============================================================================
// EVENTS
// ============================================================================

sealed class ReceiptScannerEvent extends Equatable {
  const ReceiptScannerEvent();

  @override
  List<Object?> get props => [];
}

class CaptureImageRequested extends ReceiptScannerEvent {
  final ImageSourceType source;

  const CaptureImageRequested(this.source);

  @override
  List<Object?> get props => [source];
}

class UploadReceiptRequested extends ReceiptScannerEvent {
  final List<int> imageBytes;
  final String filename;

  const UploadReceiptRequested({required this.imageBytes, required this.filename});

  @override
  List<Object?> get props => [imageBytes, filename];
}

class FetchReceiptDetailsRequested extends ReceiptScannerEvent {
  final String scanId;

  const FetchReceiptDetailsRequested(this.scanId);

  @override
  List<Object?> get props => [scanId];
}

class PollReceiptStatusRequested extends ReceiptScannerEvent {
  final String scanId;

  const PollReceiptStatusRequested(this.scanId);

  @override
  List<Object?> get props => [scanId];
}

class _PollTickRequested extends ReceiptScannerEvent {
  final String scanId;
  final int attempt;
  final int consecutiveErrors;

  const _PollTickRequested({
    required this.scanId,
    required this.attempt,
    required this.consecutiveErrors,
  });

  @override
  List<Object?> get props => [scanId, attempt, consecutiveErrors];
}

class StopPollingRequested extends ReceiptScannerEvent {}

class LoadRecentScansRequested extends ReceiptScannerEvent {}

class ResetStateRequested extends ReceiptScannerEvent {}

// Extracted items review events
class FetchExtractedItemsRequested extends ReceiptScannerEvent {
  final String scanId;

  const FetchExtractedItemsRequested(this.scanId);

  @override
  List<Object?> get props => [scanId];
}

class UpdateExtractedItemRequested extends ReceiptScannerEvent {
  final String scanId;
  final String itemId;
  final String? description;
  final num? quantity;
  final num? unitPrice;
  final num? totalPrice;

  const UpdateExtractedItemRequested({
    required this.scanId,
    required this.itemId,
    this.description,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });

  @override
  List<Object?> get props => [scanId, itemId, description, quantity, unitPrice, totalPrice];
}

class ConfirmExtractedItemsRequested extends ReceiptScannerEvent {
  final String scanId;

  const ConfirmExtractedItemsRequested(this.scanId);

  @override
  List<Object?> get props => [scanId];
}

// ============================================================================
// STATES
// ============================================================================

sealed class ReceiptScannerState extends Equatable {
  const ReceiptScannerState();

  @override
  List<Object?> get props => [];
}

class ReceiptScannerInitial extends ReceiptScannerState {}

class ReceiptScannerLoading extends ReceiptScannerState {
  final String? message;

  const ReceiptScannerLoading([this.message]);

  @override
  List<Object?> get props => [message];
}

class ImageCaptured extends ReceiptScannerState {
  final XFile image;

  const ImageCaptured(this.image);

  @override
  List<Object?> get props => [image.path];
}

class ReceiptUploaded extends ReceiptScannerState {
  final ReceiptScanEntity scan;

  const ReceiptUploaded(this.scan);

  @override
  List<Object?> get props => [scan];
}

class ReceiptProcessing extends ReceiptScannerState {
  final String scanId;
  final String status;

  const ReceiptProcessing({required this.scanId, required this.status});

  @override
  List<Object?> get props => [scanId, status];
}

class ReceiptDetailsLoaded extends ReceiptScannerState {
  final ReceiptScanEntity scan;

  const ReceiptDetailsLoaded(this.scan);

  @override
  List<Object?> get props => [scan];
}

class RecentScansLoaded extends ReceiptScannerState {
  final List<ReceiptScanEntity> scans;

  const RecentScansLoaded(this.scans);

  @override
  List<Object?> get props => [scans];
}

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

// Extracted items review states
class ExtractedItemsLoaded extends ReceiptScannerState {
  final String scanId;
  final String merchantName;
  final DateTime? purchaseDate;
  final num? subtotal;
  final num? tax;
  final num? total;
  final String currency;
  final List<ReceiptItemEntity> items;

  const ExtractedItemsLoaded({
    required this.scanId,
    required this.merchantName,
    this.purchaseDate,
    this.subtotal,
    this.tax,
    this.total,
    required this.currency,
    required this.items,
  });

  @override
  List<Object?> get props => [scanId, merchantName, purchaseDate, subtotal, tax, total, currency, items];

  ExtractedItemsLoaded copyWith({
    String? scanId,
    String? merchantName,
    DateTime? purchaseDate,
    num? subtotal,
    num? tax,
    num? total,
    String? currency,
    List<ReceiptItemEntity>? items,
  }) {
    return ExtractedItemsLoaded(
      scanId: scanId ?? this.scanId,
      merchantName: merchantName ?? this.merchantName,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      items: items ?? this.items,
    );
  }
}

class ExtractedItemsUpdating extends ReceiptScannerState {
  final ExtractedItemsLoaded previousState;

  const ExtractedItemsUpdating(this.previousState);

  @override
  List<Object?> get props => [previousState];
}

class ExtractedItemsConfirming extends ReceiptScannerState {
  final String scanId;

  const ExtractedItemsConfirming(this.scanId);

  @override
  List<Object?> get props => [scanId];
}

// ============================================================================
// BLOC
// ============================================================================

class ReceiptScannerBloc extends Bloc<ReceiptScannerEvent, ReceiptScannerState> {
  final UploadReceiptUseCase uploadReceiptUseCase;
  final GetReceiptDetailsUseCase getReceiptDetailsUseCase;
  final CaptureImageUseCase captureImageUseCase;
  final GetRecentScansUseCase getRecentScansUseCase;
  final ReceiptScannerRepository repository;

  Timer? _pollingTimer;
  static const _pollingInterval = Duration(seconds: 2);
  static const _maxPollingAttempts = 60; // 2 minutes max
  static const _maxConsecutiveErrors = 5;

  ReceiptScannerBloc({
    required this.uploadReceiptUseCase,
    required this.getReceiptDetailsUseCase,
    required this.captureImageUseCase,
    required this.getRecentScansUseCase,
    required this.repository,
  }) : super(ReceiptScannerInitial()) {
    on<CaptureImageRequested>(_onCaptureImage);
    on<UploadReceiptRequested>(_onUpload);
    on<FetchReceiptDetailsRequested>(_onFetchDetails);
    on<PollReceiptStatusRequested>(_onPollStatus);
    on<_PollTickRequested>(_onPollTick);
    on<StopPollingRequested>(_onStopPolling);
    on<LoadRecentScansRequested>(_onLoadRecentScans);
    on<ResetStateRequested>(_onResetState);
    on<FetchExtractedItemsRequested>(_onFetchExtractedItems);
    on<UpdateExtractedItemRequested>(_onUpdateExtractedItem);
    on<ConfirmExtractedItemsRequested>(_onConfirmExtractedItems);
  }

  Future<void> _onCaptureImage(
    CaptureImageRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    emit(const ReceiptScannerLoading('Opening camera...'));
    try {
      final image = await captureImageUseCase(event.source);
      if (image != null) {
        emit(ImageCaptured(image));
      } else {
        emit(ReceiptScannerInitial());
      }
    } catch (e) {
      emit(ReceiptScannerFailure('Failed to capture image: $e'));
    }
  }

  Future<void> _onUpload(
    UploadReceiptRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    emit(const ReceiptScannerLoading('Uploading receipt...'));
    try {
      final scan = await uploadReceiptUseCase(
        imageBytes: event.imageBytes,
        filename: event.filename,
      );
      emit(ReceiptUploaded(scan));
    } catch (e) {
      emit(ReceiptScannerFailure(e.toString()));
    }
  }

  Future<void> _onFetchDetails(
    FetchReceiptDetailsRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    emit(const ReceiptScannerLoading('Loading receipt...'));
    try {
      final scan = await getReceiptDetailsUseCase(event.scanId);
      emit(ReceiptDetailsLoaded(scan));
    } catch (e) {
      emit(ReceiptScannerFailure('Failed to load receipt: $e'));
    }
  }

  Future<void> _onPollStatus(
    PollReceiptStatusRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    _pollingTimer?.cancel();
    emit(ReceiptProcessing(scanId: event.scanId, status: 'pending'));
    // Fire first poll immediately, then schedule subsequent ticks with delay
    add(_PollTickRequested(scanId: event.scanId, attempt: 0, consecutiveErrors: 0));
  }

  Future<void> _onPollTick(
    _PollTickRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    if (event.attempt >= _maxPollingAttempts) {
      _pollingTimer?.cancel();
      emit(const ReceiptScannerFailure('Processing timed out. Please try again.'));
      return;
    }

    try {
      final scan = await getReceiptDetailsUseCase(event.scanId);

      if (scan.isCompleted) {
        _pollingTimer?.cancel();
        emit(ReceiptDetailsLoaded(scan));
      } else if (scan.isFailed) {
        _pollingTimer?.cancel();
        emit(const ReceiptScannerFailure('Receipt processing failed. Please try again.'));
      } else if (scan.isAwaitingReview) {
        // Stop polling and fetch extracted items for review
        _pollingTimer?.cancel();
        add(FetchExtractedItemsRequested(event.scanId));
      } else {
        emit(ReceiptProcessing(scanId: event.scanId, status: scan.status));
        _schedulePollTick(event.scanId, event.attempt + 1, 0, _pollingInterval);
      }
    } catch (e) {
      final errors = event.consecutiveErrors + 1;

      if (errors >= _maxConsecutiveErrors) {
        _pollingTimer?.cancel();
        emit(ReceiptScannerFailure('Network error: Unable to check status. Error: $e'));
        return;
      }

      // Exponential backoff on errors
      final backoffDuration = Duration(
        milliseconds: _pollingInterval.inMilliseconds * (errors + 1),
      );
      _schedulePollTick(event.scanId, event.attempt + 1, errors, backoffDuration);
    }
  }

  void _schedulePollTick(String scanId, int attempt, int consecutiveErrors, Duration delay) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer(delay, () {
      add(_PollTickRequested(
        scanId: scanId,
        attempt: attempt,
        consecutiveErrors: consecutiveErrors,
      ));
    });
  }

  void _onStopPolling(
    StopPollingRequested event,
    Emitter<ReceiptScannerState> emit,
  ) {
    _pollingTimer?.cancel();
  }

  Future<void> _onLoadRecentScans(
    LoadRecentScansRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    emit(const ReceiptScannerLoading('Loading recent scans...'));
    try {
      final scans = await getRecentScansUseCase();
      emit(RecentScansLoaded(scans));
    } catch (e) {
      emit(ReceiptScannerFailure('Failed to load recent scans: $e'));
    }
  }

  void _onResetState(
    ResetStateRequested event,
    Emitter<ReceiptScannerState> emit,
  ) {
    _pollingTimer?.cancel();
    emit(ReceiptScannerInitial());
  }

  Future<void> _onFetchExtractedItems(
    FetchExtractedItemsRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    emit(const ReceiptScannerLoading('Loading extracted items...'));
    try {
      final response = await repository.getExtractedItems(event.scanId);
      emit(ExtractedItemsLoaded(
        scanId: response.scanId,
        merchantName: response.merchantName,
        purchaseDate: response.purchaseDate,
        subtotal: response.subtotal,
        tax: response.tax,
        total: response.total,
        currency: response.currency,
        items: response.items,
      ));
    } catch (e) {
      emit(ReceiptScannerFailure('Failed to load extracted items: $e'));
    }
  }

  Future<void> _onUpdateExtractedItem(
    UpdateExtractedItemRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ExtractedItemsLoaded) return;

    emit(ExtractedItemsUpdating(currentState));

    try {
      // Build the update payload
      final Map<String, dynamic> itemUpdate = {'id': event.itemId};
      if (event.description != null) itemUpdate['description'] = event.description;
      if (event.quantity != null) itemUpdate['quantity'] = event.quantity;
      if (event.unitPrice != null) itemUpdate['unit_price'] = event.unitPrice;
      if (event.totalPrice != null) itemUpdate['total_price'] = event.totalPrice;

      await repository.updateExtractedItems(event.scanId, [itemUpdate]);

      // Refresh the extracted items
      final response = await repository.getExtractedItems(event.scanId);
      emit(ExtractedItemsLoaded(
        scanId: response.scanId,
        merchantName: response.merchantName,
        purchaseDate: response.purchaseDate,
        subtotal: response.subtotal,
        tax: response.tax,
        total: response.total,
        currency: response.currency,
        items: response.items,
      ));
    } catch (e) {
      // Restore previous state on error
      emit(currentState);
      emit(ReceiptScannerFailure('Failed to update item: $e'));
    }
  }

  Future<void> _onConfirmExtractedItems(
    ConfirmExtractedItemsRequested event,
    Emitter<ReceiptScannerState> emit,
  ) async {
    emit(ExtractedItemsConfirming(event.scanId));

    try {
      await repository.confirmExtractedItems(event.scanId);
      // Resume polling for matching/completion
      add(PollReceiptStatusRequested(event.scanId));
    } catch (e) {
      emit(ReceiptScannerFailure('Failed to confirm items: $e'));
    }
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }
}
