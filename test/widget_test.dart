import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dk_pos/core/network/dio_factory.dart';
import 'package:dk_pos/data/network/dio_http_client.dart';
import 'package:dk_pos/data/storage/shared_preferences_key_value_store.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_event.dart';
import 'package:dk_pos/features/auth/data/auth_remote_data_source_impl.dart';
import 'package:dk_pos/features/auth/data/auth_repository.dart';
import 'package:dk_pos/app/app_locale_scope.dart';
import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/app/locale/locale_event.dart';
import 'package:dk_pos/features/auth/presentation/screens/login_screen.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Экран входа отображается', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final kv = SharedPreferencesKeyValueStore(prefs);
    final http = DioHttpClient(createDio());
    final remote = AuthRemoteDataSourceImpl(http);
    final authRepo = AuthRepository(kv: kv, remote: remote, http: http);
    final auth = AuthBloc(authRepo)..add(const AuthStarted());

    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: authRepo,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<LocaleBloc>(
              create: (_) => LocaleBloc(kv)..add(const LocaleStarted()),
            ),
          ],
          child: AppLocaleScope(
            locale: const Locale('ru'),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('ru'),
              home: const LoginScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Doner Kebab POS'), findsOneWidget);
  });
}
