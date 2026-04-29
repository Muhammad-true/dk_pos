import 'package:equatable/equatable.dart';

sealed class UsersAdminEvent extends Equatable {
  const UsersAdminEvent();

  @override
  List<Object?> get props => [];
}

final class UsersLoadRequested extends UsersAdminEvent {
  const UsersLoadRequested();
}

final class UserCreateSubmitted extends UsersAdminEvent {
  const UserCreateSubmitted({
    required this.username,
    required this.password,
    required this.role,
    this.isActive,
    this.kitchenStationId,
    this.kitchenButtonId,
  });

  final String username;
  final String password;
  final String role;
  final int? isActive;
  final int? kitchenStationId;
  final int? kitchenButtonId;

  @override
  List<Object?> get props => [username, password, role, isActive, kitchenStationId, kitchenButtonId];
}

final class UserUpdateSubmitted extends UsersAdminEvent {
  const UserUpdateSubmitted({
    required this.id,
    required this.username,
    required this.role,
    this.isActive,
    this.kitchenStationId,
    this.kitchenButtonId,
    this.password,
  });

  final int id;
  final String username;
  final String role;
  final int? isActive;
  final int? kitchenStationId;
  final int? kitchenButtonId;
  final String? password;

  @override
  List<Object?> get props => [id, username, role, isActive, kitchenStationId, kitchenButtonId, password];
}

final class UserDeleteSubmitted extends UsersAdminEvent {
  const UserDeleteSubmitted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

final class UsersErrorDismissed extends UsersAdminEvent {
  const UsersErrorDismissed();
}
