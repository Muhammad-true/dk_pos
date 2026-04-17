import 'package:shared_preferences/shared_preferences.dart';

import 'package:dk_pos/core/storage/key_value_store.dart';

/// [KeyValueStore] на SharedPreferences.
class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferencesKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPreferencesKeyValueStore> create() async {
    final p = await SharedPreferences.getInstance();
    return SharedPreferencesKeyValueStore(p);
  }

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
