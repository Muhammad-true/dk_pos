import 'package:dk_pos/l10n/app_localizations.dart';

import 'package:dk_pos/shared/models/user_model.dart';

extension UserRoleL10n on UserModel {
  String roleLabel(AppLocalizations l10n) {
    switch (role) {
      case 'admin':
        return l10n.roleAdmin;
      case 'warehouse':
        return l10n.roleWarehouse;
      case 'cashier':
        return l10n.roleCashier;
      case 'expeditor':
        return l10n.roleExpeditor;
      case 'waiter':
        return _waiterLabelByLocale(l10n);
      default:
        return role;
    }
  }

  String _waiterLabelByLocale(AppLocalizations l10n) {
    final code = l10n.localeName.toLowerCase();
    if (code.startsWith('en')) return 'Waiter';
    if (code.startsWith('tg')) return 'Офисиант';
    return 'Официант';
  }
}
