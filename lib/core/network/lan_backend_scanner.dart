import 'dart:io';

import 'package:dio/dio.dart';

/// Поиск backend Doner Kebab в локальной подсети (api/health на :3000).
class LanBackendScanner {
  LanBackendScanner._();

  static const int defaultPort = 3000;

  /// Возвращает origin вида `http://192.168.1.110:3000` или null.
  static Future<String?> findBackendOrigin({
    Iterable<String> tryFirst = const [],
    Duration probeTimeout = const Duration(seconds: 2),
    int batchSize = 20,
  }) async {
    final seen = <String>{};
    for (final raw in tryFirst) {
      final origin = _normalizeOrigin(raw);
      if (origin.isEmpty || !seen.add(origin)) continue;
      if (await _probeHealth(origin, probeTimeout)) return origin;
    }

    final hosts = await _candidateHosts(tryFirst: tryFirst);
    for (var i = 0; i < hosts.length; i += batchSize) {
      final batch = hosts.skip(i).take(batchSize).toList(growable: false);
      final results = await Future.wait(
        batch.map((host) async {
          final origin = 'http://$host:$defaultPort';
          if (await _probeHealth(origin, probeTimeout)) return origin;
          return null;
        }),
      );
      for (final origin in results) {
        if (origin != null && origin.isNotEmpty) return origin;
      }
    }
    return null;
  }

  static Future<bool> _probeHealth(String origin, Duration timeout) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: origin.endsWith('/') ? origin : '$origin/',
          connectTimeout: timeout,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );
      final res = await dio.get<dynamic>(
        'api/health',
        options: Options(validateStatus: (_) => true),
      );
      return (res.statusCode ?? 0) == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> _candidateHosts({
    required Iterable<String> tryFirst,
  }) async {
    final prefix = await _detectSubnetPrefix(tryFirst: tryFirst);
    if (prefix == null) return const [];

    final selfHosts = <String>{};
    try {
      for (final iface in await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      )) {
        for (final addr in iface.addresses) {
          selfHosts.add(addr.address);
        }
      }
    } catch (_) {
      // На части устройств список интерфейсов недоступен — сканируем подсеть целиком.
    }

    final ordered = <String>[];
    final seen = <String>{};

    void add(String host) {
      if (host.isEmpty || selfHosts.contains(host) || !seen.add(host)) return;
      ordered.add(host);
    }

    // Частые адреса сервера / роутера — в начало (без жёстко зашитого IP).
    for (final last in [100, 101, 102, 110, 125, 50, 10, 1]) {
      add('$prefix.$last');
    }
    for (var last = 1; last <= 254; last++) {
      add('$prefix.$last');
    }
    return ordered;
  }

  static Future<String?> _detectSubnetPrefix({
    required Iterable<String> tryFirst,
  }) async {
    try {
      for (final iface in await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      )) {
        for (final addr in iface.addresses) {
          final host = addr.address;
          final prefix = _prefixFromHost(host);
          if (prefix != null) return prefix;
        }
      }
    } catch (_) {}

    for (final raw in tryFirst) {
      final host = Uri.tryParse(_normalizeOrigin(raw))?.host;
      final prefix = host != null ? _prefixFromHost(host) : null;
      if (prefix != null) return prefix;
    }
    return _prefixFromHost('192.168.1.1');
  }

  static String? _prefixFromHost(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return null;
    if (!_isPrivateIpv4(parts)) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  static bool _isPrivateIpv4(List<String> parts) {
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;
    if (a == 10) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }

  static String _normalizeOrigin(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      final hasPort = RegExp(r':\d+$').hasMatch(value);
      value = hasPort ? 'http://$value' : 'http://$value:$defaultPort';
    }
    value = value.replaceAll(RegExp(r'/+$'), '');
    if (value.endsWith('/api')) {
      value = value.substring(0, value.length - 4);
    }
    return value;
  }
}
