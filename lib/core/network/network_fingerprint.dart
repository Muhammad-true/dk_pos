import 'dart:io';

/// Отпечаток Wi‑Fi/LAN: первые 3 октета IPv4 устройства (подсеть /24).
/// При смене сети просим ввести IP сервера заново.
Future<String?> readLocalNetworkFingerprint() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('127.')) continue;
          final parts = ip.split('.');
          if (parts.length == 4) {
            return '${parts[0]}.${parts[1]}.${parts[2]}';
          }
        }
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}
