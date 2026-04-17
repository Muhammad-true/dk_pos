import 'package:equatable/equatable.dart';

import 'package:dk_pos/features/admin/data/admin_screen_row.dart';

enum ScreensAdminStatus { initial, loading, loaded, failure }

class ScreensAdminState extends Equatable {
  const ScreensAdminState({
    this.status = ScreensAdminStatus.initial,
    this.screens = const [],
    this.errorMessage,
  });

  final ScreensAdminStatus status;
  final List<AdminScreenRow> screens;
  final String? errorMessage;

  ScreensAdminState copyWith({
    ScreensAdminStatus? status,
    List<AdminScreenRow>? screens,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ScreensAdminState(
      status: status ?? this.status,
      screens: screens ?? this.screens,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, screens, errorMessage];
}
