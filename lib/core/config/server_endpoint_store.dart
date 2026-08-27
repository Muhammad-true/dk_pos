import 'package:dk_pos/core/network/network_fingerprint.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerEndpointStore {
  static const _key = 'server_api_origin';
  static const _fingerprintKey = 'server_api_network_fp';

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<String?> readStoredFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fingerprintKey)?.trim();
  }

  /// true — сеть та же или отпечаток неизвестен (не блокируем).
  static Future<bool> isNetworkBindingValid() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_fingerprintKey)?.trim();
    if (stored == null || stored.isEmpty) return true;
    final current = await readLocalNetworkFingerprint();
    if (current == null || current.isEmpty) return true;
    return stored == current;
  }

  static Future<void> save(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    await prefs.setString(_key, trimmed);
    final fp = await readLocalNetworkFingerprint();
    if (fp != null && fp.isNotEmpty) {
      await prefs.setString(_fingerprintKey, fp);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_fingerprintKey);
  }
}
