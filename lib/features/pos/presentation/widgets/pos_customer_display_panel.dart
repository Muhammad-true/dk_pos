import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/widgets/customer_display_idle_renderer.dart';

class PosCustomerDisplayPanel extends StatelessWidget {
  const PosCustomerDisplayPanel({
    super.key,
    required this.cart,
    this.idleContentConfig,
  });

  static const _bankQrPayload =
      'https://pay.example.bank/merchant/doner-kebab-pos';

  final CustomerDisplayCartData cart;
  final CustomerDisplayContentConfig? idleContentConfig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF120A0A),
            scheme.surface,
            const Color(0xFF090909),
          ],
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: cart.isEmpty
            ? _CustomerIdleView(
                key: const ValueKey('idle'),
                config: idleContentConfig ?? CustomerDisplayContentConfig.fallback(),
              )
            : _CustomerReceiptView(
                key: const ValueKey('receipt'),
                cart: cart,
                promoConfig: idleContentConfig ?? CustomerDisplayContentConfig.fallback(),
                bankQrPayload: _bankQrPayload,
              ),
      ),
    );
  }
}

class CustomerDisplayCartData {
  const CustomerDisplayCartData({
    this.lines = const [],
    this.itemCount = 0,
    this.total = 0,
  });

  final List<CustomerDisplayLineData> lines;
  final int itemCount;
  final double total;

  bool get isEmpty => lines.isEmpty;

  Map<String, dynamic> toJson() => {
    'lines': lines.map((line) => line.toJson()).toList(),
    'itemCount': itemCount,
    'total': total,
  };

  factory CustomerDisplayCartData.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final lines = <CustomerDisplayLineData>[];
    if (rawLines is List) {
      for (final entry in rawLines) {
        if (entry is Map<String, dynamic>) {
          lines.add(CustomerDisplayLineData.fromJson(entry));
        }
      }
    }
    return CustomerDisplayCartData(
      lines: lines,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CustomerDisplayLineData {
  const CustomerDisplayLineData({
    required this.name,
    required this.quantity,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final double lineTotal;

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'lineTotal': lineTotal,
  };

  factory CustomerDisplayLineData.fromJson(Map<String, dynamic> json) {
    return CustomerDisplayLineData(
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _CustomerIdleView extends StatelessWidget {
  const _CustomerIdleView({super.key, required this.config});

  final CustomerDisplayContentConfig config;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _AmbientSteamBackdrop(),
        Padding(
          padding: const EdgeInsets.all(28),
          child: CustomerDisplayIdleRenderer(
            config: config,
          ),
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
    required this.bankQrPayload,
  });

  final CustomerDisplayCartData cart;
  final CustomerDisplayContentConfig promoConfig;
  final String bankQrPayload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${cart.itemCount} позиций',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFFFD166),
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
                    color: const Color(0xFFE4002B),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    formatSomoni(cart.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(18),
                            itemCount: cart.lines.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 18),
                            itemBuilder: (context, index) {
                              final line = cart.lines[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
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
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        line.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: const Color(0xFF161616),
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    formatSomoni(line.lineTotal),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: const Color(0xFFE4002B),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFEAEAEA)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Итого к оплате',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF171717),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatSomoni(cart.total),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: const Color(0xFFE4002B),
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
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    clipBehavior: Clip.antiAlias,
                    child: CustomerDisplayPromoCarousel(
                      config: promoConfig,
                      paymentQrData: bankQrPayload,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientSteamBackdrop extends StatefulWidget {
  const _AmbientSteamBackdrop();

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
        return Stack(
          fit: StackFit.expand,
          children: [
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
              final alpha = 0.10 + math.sin(drift * math.pi) * 0.08;
              return Align(
                alignment: Alignment(dx, dy),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFD166).withValues(alpha: alpha),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x66FFD166).withValues(alpha: alpha),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            }),
            ...List.generate(7, (index) {
              final shift = (t + index * 0.13) % 1;
              final smokeY = 0.96 - shift * 1.08;
              final smokeX =
                  -0.42 + math.sin((shift * 1.8 + index) * math.pi * 2) * 0.58;
              final size = 82.0 + index * 18.0 + math.sin(shift * math.pi) * 18;
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
