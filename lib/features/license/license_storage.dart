import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Стабильный **device_id** для тел запросов (`POST /api/local/license/sync` и т.д.).
///
/// Снимок лицензии и срок — **только на локальном сервере** (`GET /api/local/license/status`), не в SharedPreferences.
///
/// Исключение: если в POS задан прямой `GLOBAL_LICENSE_API_BASE_URL` без локальной записи лицензии на сервере —
/// ключ можно держать в prefs (редкий обходной режим), см. [readGlobalBypassLicenseKey] / [writeGlobalBypassLicenseKey].
class LicenseStorage {
  static const _kDeviceId = 'pos_global_device_id';
  static const _kGlobalBypassKey = 'pos_global_license_key';
  static const _kLegacyCache = 'pos_global_license_cache_json';

  Future<String> ensureDeviceId() async {
    final p = await SharedPreferences.getInstance();
    final existing = p.getString(_kDeviceId);
    if (existing != null && existing.trim().length >= 16) {
      return existing.trim();
    }
    const uuid = Uuid();
    final id = uuid.v4();
    await p.setString(_kDeviceId, id);
    return id;
  }

  /// Удалить устаревшие ключи лицензии / кеш из старых версий приложения (не трогает device_id).
  Future<void> wipeLegacyLicensePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kGlobalBypassKey);
    await p.remove(_kLegacyCache);
  }

  Future<String?> readGlobalBypassLicenseKey() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kGlobalBypassKey);
    return v?.trim();
  }

  Future<void> writeGlobalBypassLicenseKey(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGlobalBypassKey, key.trim());
  }
}
