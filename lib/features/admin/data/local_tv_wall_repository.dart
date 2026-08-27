import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

/// Типы контента стены (выбираем одно).
const kTvWallContentTypes = <String>[
  'pizza_carousel',
  'pizza_bounce',
  'pizza_slam',
  'pizza_spin',
  'product_spotlight',
  'price_burst',
  'stripe_wipe',
  'brand_pulse',
  'video',
  'photo_pan',
];

const kTvWallDesignIds = <String>[
  'kfc_red',
  'kfc_black',
  'mustard',
  'fire',
  'clean_white',
];

String tvWallContentTypeTitle(String id) {
  switch (id) {
    case 'pizza_carousel':
      return 'Карусель по стене';
    case 'pizza_bounce':
      return 'Отскок по стене';
    case 'pizza_slam':
      return 'Удар сверху';
    case 'pizza_spin':
      return 'Вращение по стене';
    case 'product_spotlight':
      return 'Прожектор';
    case 'price_burst':
      return 'Взрыв цены';
    case 'stripe_wipe':
      return 'Полосы / wipe';
    case 'brand_pulse':
      return 'Бренд-пульс';
    case 'video':
      return 'Широкое видео';
    case 'photo_pan':
      return 'Панорама фото';
    default:
      return id;
  }
}

String tvWallContentTypeDesc(String id) {
  switch (id) {
    case 'pizza_carousel':
      return '3 ТВ = один экран: товары цепочкой ТВ1→ТВN';
    case 'pizza_bounce':
      return 'Цепочка по стене с подпрыгиванием';
    case 'pizza_slam':
      return 'Падает сверху с «ударом»';
    case 'pizza_spin':
      return 'Цепочка: крутятся и едут ТВ1→ТВN';
    case 'product_spotlight':
      return 'Крупный кадр по центру';
    case 'price_burst':
      return 'Сначала фото, потом огромная цена';
    case 'stripe_wipe':
      return 'Диагональные полосы + товар';
    case 'brand_pulse':
      return 'Только бренд, без товара';
    case 'video':
      return 'Один широкий MP4';
    case 'photo_pan':
      return 'Одно широкое фото';
    default:
      return '';
  }
}

String tvWallDesignTitle(String id) {
  switch (id) {
    case 'kfc_red':
      return 'KFC Red';
    case 'kfc_black':
      return 'KFC Black';
    case 'mustard':
      return 'Mustard Gold';
    case 'fire':
      return 'Fire';
    case 'clean_white':
      return 'Clean White';
    default:
      return id;
  }
}

class LocalTvWallScreenSlot {
  const LocalTvWallScreenSlot({
    required this.screenId,
    required this.panelIndex,
  });

  final int screenId;
  final int panelIndex;

  Map<String, dynamic> toJson() => {
        'screenId': screenId,
        'panelIndex': panelIndex,
      };

  factory LocalTvWallScreenSlot.fromJson(Map raw) {
    return LocalTvWallScreenSlot(
      screenId: int.tryParse((raw['screenId'] ?? raw['screen_id'] ?? '0').toString()) ?? 0,
      panelIndex:
          int.tryParse((raw['panelIndex'] ?? raw['panel_index'] ?? '0').toString()) ?? 0,
    );
  }
}

class LocalTvWallItem {
  const LocalTvWallItem({
    required this.id,
    required this.name,
    required this.priceText,
    required this.imagePath,
    this.volumeVariants = const [],
  });

  final String id;
  final String name;
  final String priceText;
  final String imagePath;
  final List<Map<String, String>> volumeVariants;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'priceText': priceText,
        'imagePath': imagePath,
        if (volumeVariants.isNotEmpty) 'volumeVariants': volumeVariants,
      };

  factory LocalTvWallItem.fromJson(Map raw) {
    var imagePath = (raw['imagePath'] ?? raw['image_path'] ?? raw['image'] ?? '')
        .toString()
        .trim();
    if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);
    final variants = <Map<String, String>>[];
    final rawVv = raw['volumeVariants'] ?? raw['volume_variants'];
    if (rawVv is List) {
      for (final e in rawVv) {
        if (e is! Map) continue;
        final label = (e['label'] ?? e['volume'] ?? '').toString().trim();
        final pt = (e['priceText'] ?? e['price_text'] ?? '').toString().trim();
        if (label.isNotEmpty && pt.isNotEmpty) {
          variants.add({'label': label, 'priceText': pt});
        }
      }
    }
    return LocalTvWallItem(
      id: (raw['id'] ?? '').toString(),
      name: (raw['name'] ?? raw['title'] ?? 'Пицца').toString(),
      priceText: (raw['priceText'] ?? raw['price_text'] ?? raw['price'] ?? '').toString(),
      imagePath: imagePath,
      volumeVariants: variants,
    );
  }
}

class LocalTvWallConfig {
  const LocalTvWallConfig({
    required this.enabled,
    required this.groupId,
    required this.panelCount,
    required this.screens,
    required this.contentType,
    required this.designId,
    required this.videoPath,
    required this.photoPath,
    required this.items,
    required this.itemHoldMs,
    required this.nameFontScale,
    required this.priceFontScale,
    this.photoScale = 1.25,
    this.railWords = const [],
    this.wordEvery = 2,
    required this.intervalMinutes,
    required this.showDurationMs,
  });

  final bool enabled;
  final String groupId;
  final int panelCount;
  final List<LocalTvWallScreenSlot> screens;
  final String contentType;
  final String designId;
  final String videoPath;
  final String photoPath;
  final List<LocalTvWallItem> items;
  final int itemHoldMs;
  final double nameFontScale;
  final double priceFontScale;
  final double photoScale;
  final List<String> railWords;
  final int wordEvery;
  final int intervalMinutes;
  final int showDurationMs;

  static const defaults = LocalTvWallConfig(
    enabled: false,
    groupId: 'wall',
    panelCount: 3,
    screens: [],
    contentType: 'pizza_carousel',
    designId: 'kfc_red',
    videoPath: '',
    photoPath: '',
    items: [],
    itemHoldMs: 7500,
    nameFontScale: 1,
    priceFontScale: 1,
    photoScale: 1.25,
    railWords: [],
    wordEvery: 2,
    intervalMinutes: 15,
    showDurationMs: 45000,
  );

  bool get hasContent {
    switch (contentType) {
      case 'video':
        return videoPath.trim().isNotEmpty;
      case 'photo_pan':
        return photoPath.trim().isNotEmpty || videoPath.trim().isNotEmpty;
      case 'brand_pulse':
        return true;
      default:
        return items.isNotEmpty;
    }
  }

  factory LocalTvWallConfig.fromJson(Map? raw) {
    if (raw == null) return defaults;
    final screensRaw = raw['screens'];
    final screens = <LocalTvWallScreenSlot>[];
    if (screensRaw is List) {
      for (final e in screensRaw) {
        if (e is! Map) continue;
        final slot = LocalTvWallScreenSlot.fromJson(Map<String, dynamic>.from(e));
        if (slot.screenId > 0) screens.add(slot);
      }
    }
    screens.sort((a, b) => a.panelIndex.compareTo(b.panelIndex));
    var videoPath = (raw['videoPath'] ?? raw['video_path'] ?? '').toString().trim();
    if (videoPath.startsWith('/')) videoPath = videoPath.substring(1);
    var photoPath = (raw['photoPath'] ?? raw['photo_path'] ?? '').toString().trim();
    if (photoPath.startsWith('/')) photoPath = photoPath.substring(1);
    final itemsRaw = raw['items'];
    final items = <LocalTvWallItem>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is! Map) continue;
        items.add(LocalTvWallItem.fromJson(Map<String, dynamic>.from(e)));
        if (items.length >= 20) break;
      }
    }
    var contentType = (raw['contentType'] ?? raw['content_type'] ?? 'pizza_carousel')
        .toString()
        .trim()
        .toLowerCase();
    if (!kTvWallContentTypes.contains(contentType)) {
      contentType = 'pizza_carousel';
    }
    var designId =
        (raw['designId'] ?? raw['design_id'] ?? 'kfc_red').toString().trim().toLowerCase();
    if (!kTvWallDesignIds.contains(designId)) designId = 'kfc_red';
    return LocalTvWallConfig(
      enabled: raw['enabled'] == true || raw['enabled'] == 1 || raw['enabled'] == '1',
      groupId: ((raw['groupId'] ?? raw['group'] ?? 'wall').toString().trim().isEmpty)
          ? 'wall'
          : (raw['groupId'] ?? raw['group'] ?? 'wall').toString().trim(),
      panelCount: _clamp(raw['panelCount'] ?? raw['panel_count'], 3, 2, 5),
      screens: screens,
      contentType: contentType,
      designId: designId,
      videoPath: videoPath,
      photoPath: photoPath,
      items: items,
      itemHoldMs: _clamp(raw['itemHoldMs'] ?? raw['item_hold_ms'], 7500, 6000, 20000),
      nameFontScale: _clampDouble(raw['nameFontScale'] ?? raw['name_font_scale'], 1, 0.6, 2),
      priceFontScale: _clampDouble(raw['priceFontScale'] ?? raw['price_font_scale'], 1, 0.6, 2),
      photoScale: _clampDouble(raw['photoScale'] ?? raw['photo_scale'], 1.25, 0.8, 4),
      railWords: _parseLocalRailWords(raw['railWords'] ?? raw['rail_words']),
      wordEvery: _clamp(raw['wordEvery'] ?? raw['word_every'], 2, 1, 6),
      intervalMinutes: _clamp(raw['intervalMinutes'] ?? raw['interval_minutes'], 15, 0, 180),
      showDurationMs: _clamp(raw['showDurationMs'] ?? raw['show_duration_ms'], 45000, 5000, 180000),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'groupId': groupId,
        'panelCount': panelCount,
        'screens': screens.map((e) => e.toJson()).toList(),
        'contentType': contentType,
        'designId': designId,
        'videoPath': videoPath,
        'photoPath': photoPath,
        'items': items.map((e) => e.toJson()).toList(),
        'itemHoldMs': itemHoldMs,
        'nameFontScale': nameFontScale,
        'priceFontScale': priceFontScale,
        'photoScale': photoScale,
        'railWords': railWords,
        'wordEvery': wordEvery,
        'intervalMinutes': intervalMinutes,
        'showDurationMs': showDurationMs,
      };

  LocalTvWallConfig copyWith({
    bool? enabled,
    String? groupId,
    int? panelCount,
    List<LocalTvWallScreenSlot>? screens,
    String? contentType,
    String? designId,
    String? videoPath,
    String? photoPath,
    List<LocalTvWallItem>? items,
    int? itemHoldMs,
    double? nameFontScale,
    double? priceFontScale,
    double? photoScale,
    List<String>? railWords,
    int? wordEvery,
    int? intervalMinutes,
    int? showDurationMs,
  }) {
    return LocalTvWallConfig(
      enabled: enabled ?? this.enabled,
      groupId: groupId ?? this.groupId,
      panelCount: panelCount ?? this.panelCount,
      screens: screens ?? this.screens,
      contentType: contentType ?? this.contentType,
      designId: designId ?? this.designId,
      videoPath: videoPath ?? this.videoPath,
      photoPath: photoPath ?? this.photoPath,
      items: items ?? this.items,
      itemHoldMs: itemHoldMs ?? this.itemHoldMs,
      nameFontScale: nameFontScale ?? this.nameFontScale,
      priceFontScale: priceFontScale ?? this.priceFontScale,
      photoScale: photoScale ?? this.photoScale,
      railWords: railWords ?? this.railWords,
      wordEvery: wordEvery ?? this.wordEvery,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      showDurationMs: showDurationMs ?? this.showDurationMs,
    );
  }

  static int _clamp(Object? raw, int fallback, int min, int max) {
    final n = int.tryParse(raw?.toString() ?? '');
    if (n == null) return fallback;
    return n.clamp(min, max);
  }

  static double _clampDouble(Object? raw, double fallback, double min, double max) {
    final n = double.tryParse(raw?.toString() ?? '');
    if (n == null) return fallback;
    return n.clamp(min, max);
  }

  static List<String> _parseLocalRailWords(Object? raw) {
    final out = <String>[];
    if (raw is List) {
      for (final e in raw) {
        final t = e.toString().trim();
        if (t.isEmpty) continue;
        out.add(t);
        if (out.length >= 12) break;
      }
    } else if (raw is String) {
      for (final line in raw.split(RegExp(r'[\r\n|;]+'))) {
        final t = line.trim();
        if (t.isEmpty) continue;
        out.add(t);
        if (out.length >= 12) break;
      }
    }
    return out;
  }
}

class LocalTvWallRepository {
  LocalTvWallRepository(this._http);

  final HttpClient _http;

  /// Одна стена на точку — branchId не передаём.
  Future<LocalTvWallConfig> fetch() async {
    final res = await _http.get('api/local/tv-wall');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ стены ТВ');
    }
    final config = body['config'];
    if (config is! Map) return LocalTvWallConfig.defaults;
    return LocalTvWallConfig.fromJson(Map<String, dynamic>.from(config));
  }

  Future<LocalTvWallConfig> save(LocalTvWallConfig config) async {
    final res = await _http.patch(
      'api/local/tv-wall',
      body: {'config': config.toJson()},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ стены ТВ');
    }
    final saved = body['config'];
    if (saved is! Map) return config;
    return LocalTvWallConfig.fromJson(Map<String, dynamic>.from(saved));
  }

  Future<String> playNow({int? showDurationMs}) async {
    final res = await _http.post(
      'api/local/tv-wall/play-now',
      body: {
        if (showDurationMs != null) 'showDurationMs': showDurationMs,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
    return 'Шоу запущено';
  }
}
