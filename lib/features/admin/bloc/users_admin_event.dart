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
    this.kitchenStationId,
  });

  final String username;
  final String password;
  final String role;
  final int? kitchenStationId;

  @override
  List<Object?> get props => [username, password, role, kitchenStationId];
}

final class UserUpdateSubmitted extends UsersAdminEvent {
  const UserUpdateSubmitted({
    required this.id,
    required this.username,
    required this.role,
    this.kitchenStationId,
    this.password,
  });

  final int id;
  final String username;
  final String role;
  final int? kitchenStationId;
  final String? password;

  @override
  List<Object?> get props => [id, username, role, kitchenStationId, password];
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
