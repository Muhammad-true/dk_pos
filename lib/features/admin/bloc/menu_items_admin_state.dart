import 'package:equatable/equatable.dart';

import 'package:dk_pos/features/admin/data/admin_menu_item_row.dart';

enum MenuItemsAdminStatus { initial, loading, loaded, failure }

class MenuItemsAdminState extends Equatable {
  const MenuItemsAdminState({
    this.status = MenuItemsAdminStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final MenuItemsAdminStatus status;
  final List<AdminMenuItemRow> items;
  final String? errorMessage;

  bool get isLoading =>
      status == MenuItemsAdminStatus.loading && items.isEmpty;

  MenuItemsAdminState copyWith({
    MenuItemsAdminStatus? status,
    List<AdminMenuItemRow>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MenuItemsAdminState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
