import 'package:shared_preferences/shared_preferences.dart';

class ServerEndpointStore {
  static const _key = 'server_api_origin';

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<void> save(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.trim());
  }
}
