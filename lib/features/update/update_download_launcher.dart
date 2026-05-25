import 'package:url_launcher/url_launcher.dart';

/// Открывает URL установщика (https) в браузере / системном обработчике.
/// Возвращает `true`, если [launchUrl] вернул успех.
Future<bool> openUpdateDownloadUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || !uri.hasScheme) return false;
  final s = uri.scheme.toLowerCase();
  if (s != 'https' && s != 'http') return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
