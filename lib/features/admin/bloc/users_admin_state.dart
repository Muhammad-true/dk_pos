import 'package:equatable/equatable.dart';

import 'package:dk_pos/features/admin/data/admin_user_row.dart';

enum UsersAdminStatus { initial, loading, loaded, failure }

class UsersAdminState extends Equatable {
  const UsersAdminState({
    this.status = UsersAdminStatus.initial,
    this.users = const [],
    this.errorMessage,
  });

  final UsersAdminStatus status;
  final List<AdminUserRow> users;
  final String? errorMessage;

  bool get isLoading => status == UsersAdminStatus.loading;

  UsersAdminState copyWith({
    UsersAdminStatus? status,
    List<AdminUserRow>? users,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UsersAdminState(
      status: status ?? this.status,
      users: users ?? this.users,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, users, errorMessage];
}
