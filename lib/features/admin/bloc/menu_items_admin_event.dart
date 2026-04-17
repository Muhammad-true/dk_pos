import 'package:equatable/equatable.dart';

sealed class MenuItemsAdminEvent extends Equatable {
  const MenuItemsAdminEvent();

  @override
  List<Object?> get props => [];
}

final class MenuItemsLoadRequested extends MenuItemsAdminEvent {
  const MenuItemsLoadRequested();
}

final class MenuItemsErrorDismissed extends MenuItemsAdminEvent {
  const MenuItemsErrorDismissed();
}
