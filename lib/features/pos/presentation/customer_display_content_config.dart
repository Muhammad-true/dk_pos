class CustomerDisplayContentConfig {
  const CustomerDisplayContentConfig({
    required this.left,
    required this.cards,
    this.rotationSeconds = 7,
    this.transitionDurationMs = 950,
  });

  final CustomerDisplayLeftConfig left;
  final List<CustomerDisplayPromoCardConfig> cards;
  final int rotationSeconds;
  final int transitionDurationMs;

  bool get hasCards => cards.isNotEmpty;

  factory CustomerDisplayContentConfig.fromJson(Map<String, dynamic> json) {
    final leftJson = json['left'];
    final cardsJson = json['cards'];
    return CustomerDisplayContentConfig(
      left: leftJson is Map<String, dynamic>
          ? CustomerDisplayLeftConfig.fromJson(leftJson)
          : const CustomerDisplayLeftConfig(),
      cards: cardsJson is List
          ? cardsJson
                .whereType<Map>()
                .map(
                  (entry) => CustomerDisplayPromoCardConfig.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList(growable: false)
          : const [],
      rotationSeconds: _readClampedInt(json['rotationSeconds'], 3, 60, 7),
      transitionDurationMs: _readClampedInt(
        json['transitionDurationMs'],
        200,
        3000,
        950,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'left': left.toJson(),
    'cards': cards.map((card) => card.toJson()).toList(growable: false),
    'rotationSeconds': rotationSeconds,
    'transitionDurationMs': transitionDurationMs,
  };

  CustomerDisplayContentConfig copyWith({
    CustomerDisplayLeftConfig? left,
    List<CustomerDisplayPromoCardConfig>? cards,
    int? rotationSeconds,
    int? transitionDurationMs,
  }) {
    return CustomerDisplayContentConfig(
      left: left ?? this.left,
      cards: cards ?? this.cards,
      rotationSeconds: rotationSeconds ?? this.rotationSeconds,
      transitionDurationMs: transitionDurationMs ?? this.transitionDurationMs,
    );
  }

  static CustomerDisplayContentConfig fallback() {
    return const CustomerDisplayContentConfig(
      left: CustomerDisplayLeftConfig(
        headline: 'Добро пожаловать',
        brandTitle: 'Doner Kebab',
        description:
            'Соберите заказ на кассе, и здесь сразу появится экран клиента с чеком.',
      ),
      cards: [
        CustomerDisplayPromoCardConfig(
          id: 'site',
          title: 'Станьте ближе к нам',
          body:
              'Сканируйте QR-код и переходите на наш сайт для регистрации и новостей.',
          qrMode: CustomerDisplayQrMode.generated,
          qrText: 'https://donerkebab.tj',
          footer: 'donerkebab.tj',
          animation: CustomerDisplayCardAnimation.slideUp,
        ),
        CustomerDisplayPromoCardConfig(
          id: 'bank',
          title: 'Оплата по QR-коду',
          body: 'Отсканируйте код и оплатите через банк.',
          logoPath: 'assets/img/bank/dc.png',
          qrMode: CustomerDisplayQrMode.image,
          qrImagePath: 'assets/img/bank/photo_5337234839905702752_y.jpg',
          animation: CustomerDisplayCardAnimation.slideUp,
        ),
      ],
      rotationSeconds: 7,
      transitionDurationMs: 950,
    );
  }

  static CustomerDisplayContentConfig? fromScreenConfig(Map<String, dynamic>? config) {
    if (config == null || config.isEmpty) return null;
    final nested = config['customerDisplay'];
    if (nested is Map<String, dynamic>) {
      return CustomerDisplayContentConfig.fromJson(nested);
    }
    if (nested is Map) {
      return CustomerDisplayContentConfig.fromJson(Map<String, dynamic>.from(nested));
    }
    return CustomerDisplayContentConfig.fromJson(config);
  }
}

class CustomerDisplayLeftConfig {
  const CustomerDisplayLeftConfig({
    this.headline = '',
    this.brandTitle = '',
    this.description = '',
    this.logoPath,
  });

  final String headline;
  final String brandTitle;
  final String description;
  final String? logoPath;

  factory CustomerDisplayLeftConfig.fromJson(Map<String, dynamic> json) {
    return CustomerDisplayLeftConfig(
      headline: json['headline']?.toString() ?? '',
      brandTitle: json['brandTitle']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      logoPath: _readNullableString(json['logoPath']),
    );
  }

  Map<String, dynamic> toJson() => {
    'headline': headline,
    'brandTitle': brandTitle,
    'description': description,
    'logoPath': logoPath,
  };

  CustomerDisplayLeftConfig copyWith({
    String? headline,
    String? brandTitle,
    String? description,
    String? logoPath,
    bool clearLogo = false,
  }) {
    return CustomerDisplayLeftConfig(
      headline: headline ?? this.headline,
      brandTitle: brandTitle ?? this.brandTitle,
      description: description ?? this.description,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
    );
  }
}

enum CustomerDisplayQrMode { generated, image }

enum CustomerDisplayCardAnimation { slideUp, slideLeft, fade, scale }

class CustomerDisplayPromoCardConfig {
  const CustomerDisplayPromoCardConfig({
    required this.id,
    required this.title,
    required this.body,
    this.logoPath,
    this.qrMode = CustomerDisplayQrMode.generated,
    this.qrText,
    this.qrImagePath,
    this.footer,
    this.phone,
    this.animation = CustomerDisplayCardAnimation.slideUp,
  });

  final String id;
  final String title;
  final String body;
  final String? logoPath;
  final CustomerDisplayQrMode qrMode;
  final String? qrText;
  final String? qrImagePath;
  final String? footer;
  final String? phone;
  final CustomerDisplayCardAnimation animation;

  factory CustomerDisplayPromoCardConfig.fromJson(Map<String, dynamic> json) {
    return CustomerDisplayPromoCardConfig(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      logoPath: _readNullableString(json['logoPath']),
      qrMode: _parseQrMode(json['qrMode']),
      qrText: _readNullableString(json['qrText']),
      qrImagePath: _readNullableString(json['qrImagePath']),
      footer: _readNullableString(json['footer']),
      phone: _readNullableString(json['phone']),
      animation: _parseCardAnimation(json['animation']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'logoPath': logoPath,
    'qrMode': qrMode.name,
    'qrText': qrText,
    'qrImagePath': qrImagePath,
    'footer': footer,
    'phone': phone,
    'animation': animation.name,
  };

  CustomerDisplayPromoCardConfig copyWith({
    String? id,
    String? title,
    String? body,
    String? logoPath,
    bool clearLogo = false,
    CustomerDisplayQrMode? qrMode,
    String? qrText,
    String? qrImagePath,
    String? footer,
    String? phone,
    CustomerDisplayCardAnimation? animation,
    bool clearQrImage = false,
  }) {
    return CustomerDisplayPromoCardConfig(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      qrMode: qrMode ?? this.qrMode,
      qrText: qrText ?? this.qrText,
      qrImagePath: clearQrImage ? null : (qrImagePath ?? this.qrImagePath),
      footer: footer ?? this.footer,
      phone: phone ?? this.phone,
      animation: animation ?? this.animation,
    );
  }
}

String? _readNullableString(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

int _readClampedInt(dynamic value, int min, int max, int fallback) {
  int? parsed;
  if (value is int) parsed = value;
  if (value is num) parsed = value.toInt();
  if (value is String) parsed = int.tryParse(value.trim());
  if (parsed == null) return fallback;
  if (parsed < min) return min;
  if (parsed > max) return max;
  return parsed;
}

CustomerDisplayQrMode _parseQrMode(dynamic value) {
  final raw = value?.toString().trim().toLowerCase();
  return raw == 'image'
      ? CustomerDisplayQrMode.image
      : CustomerDisplayQrMode.generated;
}

CustomerDisplayCardAnimation _parseCardAnimation(dynamic value) {
  final raw = value?.toString().trim().toLowerCase();
  switch (raw) {
    case 'slideleft':
    case 'slide_left':
      return CustomerDisplayCardAnimation.slideLeft;
    case 'fade':
      return CustomerDisplayCardAnimation.fade;
    case 'scale':
      return CustomerDisplayCardAnimation.scale;
    case 'slideup':
    case 'slide_up':
    default:
      return CustomerDisplayCardAnimation.slideUp;
  }
}
