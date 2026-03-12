import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/receipt_scan_entity.dart';
import '../../domain/usecases/upload_receipt_usecase.dart';
import '../../domain/usecases/get_receipt_details_usecase.dart';
import '../../domain/usecases/capture_image_usecase.dart';
import '../../domain/usecases/get_recent_scans_usecase.dart';

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

class StopPollingRequested extends ReceiptScannerEvent {}

class LoadRecentScansRequested extends ReceiptScannerEvent {}

class ResetStateRequested extends ReceiptScannerEvent {}

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

// ============================================================================
// BLOC
// ============================================================================

class ReceiptScannerBloc extends Bloc<ReceiptScannerEvent, ReceiptScannerState> {
  final UploadReceiptUseCase uploadReceiptUseCase;
  final GetReceiptDetailsUseCase getReceiptDetailsUseCase;
  final CaptureImageUseCase captureImageUseCase;
  final GetRecentScansUseCase getRecentScansUseCase;

  Timer? _pollingTimer;
  static const _pollingInterval = Duration(seconds: 2);
  static const _maxPollingAttempts = 60; // 2 minutes max

  ReceiptScannerBloc({
    required this.uploadReceiptUseCase,
    required this.getReceiptDetailsUseCase,
    required this.captureImageUseCase,
    required this.getRecentScansUseCase,
  }) : super(ReceiptScannerInitial()) {
    on<CaptureImageRequested>(_onCaptureImage);
    on<UploadReceiptRequested>(_onUpload);
    on<FetchReceiptDetailsRequested>(_onFetchDetails);
    on<PollReceiptStatusRequested>(_onPollStatus);
    on<StopPollingRequested>(_onStopPolling);
    on<LoadRecentScansRequested>(_onLoadRecentScans);
    on<ResetStateRequested>(_onResetState);
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
    var attempts = 0;
    var consecutiveErrors = 0;
    const maxConsecutiveErrors = 5;

    emit(ReceiptProcessing(scanId: event.scanId, status: 'pending'));

    Future<void> poll() async {
      if (attempts >= _maxPollingAttempts) {
        emit(const ReceiptScannerFailure('Processing timed out. Please try again.'));
        return;
      }

      try {
        final scan = await getReceiptDetailsUseCase(event.scanId);
        consecutiveErrors = 0; // Reset on success

        if (scan.isCompleted) {
          _pollingTimer?.cancel();
          emit(ReceiptDetailsLoaded(scan));
        } else if (scan.isFailed) {
          _pollingTimer?.cancel();
          emit(const ReceiptScannerFailure('Receipt processing failed. Please try again.'));
        } else {
          emit(ReceiptProcessing(scanId: event.scanId, status: scan.status));
          attempts++;
          _pollingTimer = Timer(_pollingInterval, poll);
        }
      } catch (e) {
        consecutiveErrors++;
        attempts++;

        // If too many consecutive errors, show error to user
        if (consecutiveErrors >= maxConsecutiveErrors) {
          _pollingTimer?.cancel();
          emit(ReceiptScannerFailure('Network error: Unable to check status. Error: $e'));
          return;
        }

        // Otherwise keep trying with exponential backoff
        final backoffDuration = Duration(
          milliseconds: _pollingInterval.inMilliseconds * (consecutiveErrors + 1),
        );
        _pollingTimer = Timer(backoffDuration, poll);
      }
    }

    await poll();
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

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }
}
