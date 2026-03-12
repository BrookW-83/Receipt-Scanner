import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/initialize_fcm_usecase.dart';
import '../../domain/usecases/get_notifications_usecase.dart';

// ============================================================================
// EVENTS
// ============================================================================

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class InitializeFCMRequested extends NotificationEvent {}

class LoadNotificationsRequested extends NotificationEvent {}

class MarkNotificationReadRequested extends NotificationEvent {
  final String notificationId;

  const MarkNotificationReadRequested(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class MarkAllNotificationsReadRequested extends NotificationEvent {}

// ============================================================================
// STATES
// ============================================================================

sealed class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class FCMInitialized extends NotificationState {}

class NotificationsLoaded extends NotificationState {
  final List<NotificationEntity> notifications;

  const NotificationsLoaded(this.notifications);

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  List<Object?> get props => [notifications];
}

class NotificationFailure extends NotificationState {
  final String message;

  const NotificationFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// ============================================================================
// BLOC
// ============================================================================

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final InitializeFCMUseCase initializeFCMUseCase;
  final GetNotificationsUseCase getNotificationsUseCase;
  final NotificationRepository repository;

  NotificationBloc({
    required this.initializeFCMUseCase,
    required this.getNotificationsUseCase,
    required this.repository,
  }) : super(NotificationInitial()) {
    on<InitializeFCMRequested>(_onInitializeFCM);
    on<LoadNotificationsRequested>(_onLoadNotifications);
    on<MarkNotificationReadRequested>(_onMarkRead);
    on<MarkAllNotificationsReadRequested>(_onMarkAllRead);
  }

  Future<void> _onInitializeFCM(
    InitializeFCMRequested event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await initializeFCMUseCase();
      emit(FCMInitialized());
    } catch (e) {
      // FCM initialization failure shouldn't block the app
      emit(FCMInitialized());
    }
  }

  Future<void> _onLoadNotifications(
    LoadNotificationsRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      final notifications = await getNotificationsUseCase();
      emit(NotificationsLoaded(notifications));
    } catch (e) {
      emit(NotificationFailure(e.toString()));
    }
  }

  Future<void> _onMarkRead(
    MarkNotificationReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await repository.markAsRead(event.notificationId);
      // Reload notifications to get updated list
      add(LoadNotificationsRequested());
    } catch (e) {
      emit(NotificationFailure(e.toString()));
    }
  }

  Future<void> _onMarkAllRead(
    MarkAllNotificationsReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await repository.markAllAsRead();
      // Reload notifications to get updated list
      add(LoadNotificationsRequested());
    } catch (e) {
      emit(NotificationFailure(e.toString()));
    }
  }
}
