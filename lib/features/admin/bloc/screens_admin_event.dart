import 'package:equatable/equatable.dart';

sealed class ScreensAdminEvent extends Equatable {
  const ScreensAdminEvent();

  @override
  List<Object?> get props => [];
}

class ScreensLoadRequested extends ScreensAdminEvent {
  const ScreensLoadRequested();
}

class ScreensErrorDismissed extends ScreensAdminEvent {
  const ScreensErrorDismissed();
}
