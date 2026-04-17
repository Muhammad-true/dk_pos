import 'package:flutter/widgets.dart';

import 'package:dk_pos/app/app_locale_scope.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

/// Локаль UI из [AppLocaleScope] (включая `tg`), в отличие от
/// [Localizations.localeOf], который следует за [MaterialApp.locale].
extension ContextAppL10n on BuildContext {
  Locale get appUiLocale => AppLocaleScope.localeOf(this);

  AppLocalizations get appL10n => lookupAppLocalizations(appUiLocale);
}
