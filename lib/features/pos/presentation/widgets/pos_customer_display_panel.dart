import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_sync_state.dart';
import 'package:dk_pos/features/pos/presentation/widgets/customer_display_idle_renderer.dart';
import 'package:dk_pos/features/pos/presentation/widgets/customer_display_menu_view.dart';
import 'package:dk_pos/features/pos/presentation/widgets/customer_display_payment_view.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

class PosCustomerDisplayPanel extends StatelessWidget {
  const PosCustomerDisplayPanel({
    super.key,
    required this.cart,
    this.idleContentConfig,
    this.viewMode = CustomerDisplayViewMode.idle,
    this.menu,
    this.cartAddPulse,
    this.syncFilePath,
  });

  final CustomerDisplayCartData cart;
  final CustomerDisplayContentConfig? idleContentConfig;
  final CustomerDisplayViewMode viewMode;
  final CustomerDisplayMenuSnapshot? menu;
  final CustomerDisplayCartAddPulse? cartAddPulse;
  final String? syncFilePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final config =
        idleContentConfig ?? CustomerDisplayContentConfig.fallback();

    Widget body;
    Key bodyKey;
    switch (viewMode) {
      case CustomerDisplayViewMode.menu:
        bodyKey = const ValueKey('menu');
        body = CustomerDisplayMenuView(
          menu: menu ?? const CustomerDisplayMenuSnapshot(),
          cart: cart,
          cartAddPulse: cartAddPulse,
          syncFilePath: syncFilePath,
          idleContentConfig: config,
        );
      case CustomerDisplayViewMode.payment:
        bodyKey = const ValueKey('payment');
        body = CustomerDisplayPaymentView(
          cart: cart,
          promoConfig: config,
        );
      case CustomerDisplayViewMode.idle:
        bodyKey = ValueKey(cart.isEmpty ? 'idle' : 'receipt_legacy');
        body = cart.isEmpty
            ? _CustomerIdleView(
                config: config,
              )
            : _CustomerReceiptView(
                cart: cart,
                promoConfig: config,
              );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: customerDisplayBackgroundGradient(theme),
        ),
      ),
      // Мгновенное переключение режимов: crossfade оставлял idle поверх меню.
      child: KeyedSubtree(
        key: bodyKey,
        child: body,
      ),
    );
  }
}

class CustomerDisplayCartData {
  const CustomerDisplayCartData({
    this.lines = const [],
    this.itemCount = 0,
    this.total = 0,
    this.payableTotal = 0,
    this.discountTotal = 0,
    this.hasDiscount = false,
    this.orderTypeSelected = false,
    this.activeOrderTypeIndex = -1,
  });

  final List<CustomerDisplayLineData> lines;
  final int itemCount;
  final double total;
  final double payableTotal;
  final double discountTotal;
  final bool hasDiscount;
  final bool orderTypeSelected;
  final int activeOrderTypeIndex;

  bool get isEmpty => lines.isEmpty;

  double get displayTotal => hasDiscount ? payableTotal : total;

  String get listSyncKey => lines
      .map((line) => '${line.lineKey}:${line.quantity}:${line.lineTotal}')
      .join('|');

  Map<String, dynamic> toJson() => {
        'lines': lines.map((line) => line.toJson()).toList(),
        'itemCount': itemCount,
        'total': total,
        'payableTotal': payableTotal,
        'discountTotal': discountTotal,
        'hasDiscount': hasDiscount,
        'orderTypeSelected': orderTypeSelected,
        'activeOrderTypeIndex': activeOrderTypeIndex,
      };

  factory CustomerDisplayCartData.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final lines = <CustomerDisplayLineData>[];
    if (rawLines is List) {
      for (final entry in rawLines) {
        if (entry is Map) {
          lines.add(
            CustomerDisplayLineData.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          );
        }
      }
    }
    final total = (json['total'] as num?)?.toDouble() ?? 0;
    final payable = (json['payableTotal'] as num?)?.toDouble() ?? total;
    final discount = (json['discountTotal'] as num?)?.toDouble() ?? 0;
    final hasDiscount = json['hasDiscount'] == true || discount > 0.009;
    final orderTypeIndex = (json['activeOrderTypeIndex'] as num?)?.toInt() ??
        (json['orderTypeSelected'] == true ? 0 : -1);
    return CustomerDisplayCartData(
      lines: lines,
      itemCount: (json['itemCount'] as num?)?.toInt() ??
          lines.fold<int>(0, (sum, line) => sum + line.quantity),
      total: total,
      payableTotal: payable,
      discountTotal: discount,
      hasDiscount: hasDiscount,
      orderTypeSelected:
          orderTypeIndex >= 0 || json['orderTypeSelected'] == true,
      activeOrderTypeIndex: orderTypeIndex,
    );
  }
}

class CustomerDisplayLineData {
  const CustomerDisplayLineData({
    required this.lineKey,
    required this.name,
    required this.quantity,
    required this.lineTotal,
  });

  final String lineKey;
  final String name;
  final int quantity;
  final double lineTotal;

  Map<String, dynamic> toJson() => {
        'lineKey': lineKey,
        'name': name,
        'quantity': quantity,
        'lineTotal': lineTotal,
      };

  factory CustomerDisplayLineData.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final quantity = (json['quantity'] as num?)?.toInt() ?? 0;
    final lineTotal = (json['lineTotal'] as num?)?.toDouble() ?? 0;
    final rawKey = json['lineKey']?.toString().trim();
    return CustomerDisplayLineData(
      lineKey: rawKey != null && rawKey.isNotEmpty
          ? rawKey
          : '$name|$quantity|$lineTotal',
      name: name,
      quantity: quantity,
      lineTotal: lineTotal,
    );
  }
}

class _CustomerIdleView extends StatelessWidget {
  const _CustomerIdleView({super.key, required this.config});

  final CustomerDisplayContentConfig config;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        _AmbientSteamBackdrop(isDark: isDark),
        Padding(
          padding: const EdgeInsets.all(28),
          child: CustomerDisplayIdleRenderer(config: config),
        ),
      ],
    );
  }
}

class _AnimatedLogoHalo extends StatefulWidget {
  const _AnimatedLogoHalo();

  @override
  State<_AnimatedLogoHalo> createState() => _AnimatedLogoHaloState();
}

class _AnimatedLogoHaloState extends State<_AnimatedLogoHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = Curves.easeInOut.transform(_controller.value);
        final size = 250.0 + pulse * 24.0;
        final glow = 58.0 + pulse * 20.0;
        return Transform.scale(
          scale: 1 + pulse * 0.035,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14 + pulse * 0.04),
                  Colors.white.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18 + pulse * 0.06),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x88E4002B),
                  blurRadius: glow,
                  spreadRadius: 10 + pulse * 6,
                ),
                BoxShadow(
                  color: const Color(0x55FFD166),
                  blurRadius: glow * 0.8,
                  spreadRadius: 4 + pulse * 4,
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.24),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: ClipOval(
                child: Image.asset(
                  'assets/img/icon_logo.PNG',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CustomerReceiptView extends StatelessWidget {
  const _CustomerReceiptView({
    super.key,
    required this.cart,
    required this.promoConfig,
  });

  final CustomerDisplayCartData cart;
  final CustomerDisplayContentConfig promoConfig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        _AmbientSteamBackdrop(isDark: isDark),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: customerDisplayGlassFill(theme),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: customerDisplayGlassBorder(theme)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ваш заказ',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${cart.itemCount} позиций',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        formatSomoni(cart.total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: customerDisplayCardSurface(theme),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: customerDisplayCardBorder(theme)),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(18),
                                itemCount: cart.lines.length,
                                separatorBuilder: (_, _) =>
                                    Divider(height: 18, color: scheme.outlineVariant),
                                itemBuilder: (context, index) {
                                  final line = cart.lines[index];
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: scheme.primary.withValues(
                                            alpha: 0.10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${line.quantity}x',
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                color: scheme.primary,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            line.name,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  color: scheme.onSurface,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        formatSomoni(line.lineTotal),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: scheme.primary,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                14,
                                18,
                                18,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: scheme.outlineVariant),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Итого к оплате',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    formatSomoni(cart.total),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: customerDisplayGlassFill(theme),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: customerDisplayGlassBorder(theme),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CustomerDisplayPromoCarousel(
                          config: promoConfig,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmbientSteamBackdrop extends StatefulWidget {
  const _AmbientSteamBackdrop({this.isDark = true});

  final bool isDark;

  @override
  State<_AmbientSteamBackdrop> createState() => _AmbientSteamBackdropState();
}

class _AmbientSteamBackdropState extends State<_AmbientSteamBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final isDark = widget.isDark;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (!isDark)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        math.sin(t * math.pi * 2) * 0.06,
                        0.12 + math.sin(t * math.pi * 2) * 0.05,
                      ),
                      radius: 1.05,
                      colors: [
                        const Color(0x22E4002B),
                        const Color(0x18FFD166),
                        const Color(0x00000000),
                      ],
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        math.sin(t * math.pi * 2) * 0.06,
                        0.12 + math.sin(t * math.pi * 2) * 0.05,
                      ),
                      radius: 1.05,
                      colors: const [
                        Color(0x22FFFFFF),
                        Color(0x44FFD166),
                        Color(0x33FFD166),
                        Color(0x33E4002B),
                        Color(0x00000000),
                      ],
                    ),
                  ),
                ),
              ),
            ...List.generate(14, (index) {
              final drift = (t + index * 0.071) % 1;
              final dx =
                  -0.92 +
                  (index % 7) * 0.31 +
                  math.sin(drift * math.pi * 2) * 0.05;
              final dy = -0.82 + (((index * 37) % 100) / 100) * 1.64;
              final size = 4.0 + (index % 3) * 3.0;
              final alpha = isDark
                  ? 0.10 + math.sin(drift * math.pi) * 0.08
                  : 0.04 + math.sin(drift * math.pi) * 0.03;
              return Align(
                alignment: Alignment(dx, dy),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: alpha),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: alpha),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
            if (isDark)
              ...List.generate(7, (index) {
                final shift = (t + index * 0.13) % 1;
                final smokeY = 0.96 - shift * 1.08;
                final smokeX =
                    -0.42 +
                    math.sin((shift * 1.8 + index) * math.pi * 2) * 0.58;
                final size =
                    82.0 + index * 18.0 + math.sin(shift * math.pi) * 18;
                return Align(
                  alignment: Alignment(smokeX, smokeY),
                  child: Transform.scale(
                    scale: 0.75 + math.sin(shift * math.pi) * 0.35,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: (0.08 - shift * 0.05).clamp(0.01, 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(
                              alpha: (0.12 - shift * 0.07).clamp(0.01, 0.12),
                            ),
                            blurRadius: 34,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
