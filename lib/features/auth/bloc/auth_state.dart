import 'package:equatable/equatable.dart';

import 'package:dk_pos/shared/shared.dart';

enum AuthStatus { initial, authenticating, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.loginError,
  });

  final AuthStatus status;
  final UserModel? user;
  final String? loginError;

  bool get isReady =>
      status == AuthStatus.authenticated ||
      status == AuthStatus.unauthenticated;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? loginError,
    bool clearLoginError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      loginError: clearLoginError ? null : (loginError ?? this.loginError),
    );
  }

  @override
  List<Object?> get props => [status, user, loginError];
}
