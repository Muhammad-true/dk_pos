import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:dk_digitial_menu/widgets/robust_network_image.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';

/// Акцент экрана клиента: «Добро пожаловать», текст оплаты.
const Color kCustomerDisplayAccentRed = Color(0xFFE4002B);

List<Shadow> _customerDisplayRedGlow() => [
      Shadow(
        color: kCustomerDisplayAccentRed.withValues(alpha: 0.75),
        blurRadius: 18,
      ),
      Shadow(
        color: const Color(0xFFFF6B6B).withValues(alpha: 0.45),
        blurRadius: 36,
      ),
    ];

TextStyle _customerDisplayHeadlineStyle(ThemeData theme, TextStyle? base) {
  return (base ?? theme.textTheme.displaySmall!).copyWith(
    color: kCustomerDisplayAccentRed,
    fontWeight: FontWeight.w900,
    shadows: _customerDisplayRedGlow(),
  );
}

TextStyle _customerDisplayPromoAccentStyle(ThemeData theme) {
  return theme.textTheme.titleMedium!.copyWith(
    color: kCustomerDisplayAccentRed,
    height: 1.35,
    fontWeight: FontWeight.w800,
    shadows: _customerDisplayRedGlow(),
  );
}

TextStyle _customerDisplayPhoneStyle(ThemeData theme) {
  return theme.textTheme.headlineMedium!.copyWith(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.6,
    fontSize: 34,
    height: 1.15,
  );
}

/// Карусель промо-карточек (сайт, банк и т.д.) — та же логика, что справа в режиме ожидания.
class CustomerDisplayPromoCarousel extends StatefulWidget {
  const CustomerDisplayPromoCarousel({
    super.key,
    required this.config,
    this.paymentQrData,
  });

  final CustomerDisplayContentConfig config;
  /// На экране с чеком: для карточки с `id == 'bank'` показать оплату по этой строке (QR).
  final String? paymentQrData;

  @override
  State<CustomerDisplayPromoCarousel> createState() =>
      _CustomerDisplayPromoCarouselState();
}

class _CustomerDisplayPromoCarouselState extends State<CustomerDisplayPromoCarousel> {
  Timer? _timer;
  int _index = 0;

  CustomerDisplayContentConfig get _config => widget.config;

  List<CustomerDisplayPromoCardConfig> get _cards {
    return _config.hasCards ? _config.cards : CustomerDisplayContentConfig.fallback().cards;
  }

  CustomerDisplayPromoCardConfig _effectiveCard(CustomerDisplayPromoCardConfig card) {
    final pay = widget.paymentQrData;
    if (pay != null && pay.isNotEmpty && card.id == 'bank') {
      return card.copyWith(
        qrMode: CustomerDisplayQrMode.generated,
        qrText: pay,
        clearQrImage: true,
      );
    }
    return card;
  }

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant CustomerDisplayPromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.rotationSeconds != widget.config.rotationSeconds ||
        oldWidget.config.cards.length != widget.config.cards.length ||
        oldWidget.paymentQrData != widget.paymentQrData) {
      _index = 0;
      _restartTimer();
    } else if (_index >= _cards.length && _cards.isNotEmpty) {
      _index = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    final cards = _cards;
    if (cards.length <= 1) return;
    _timer = Timer.periodic(Duration(seconds: _config.rotationSeconds), (_) {
      if (!mounted || _cards.isEmpty) return;
      setState(() => _index = (_index + 1) % _cards.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    if (cards.isEmpty) return const SizedBox.shrink();
    final raw = cards[_index % cards.length];
    final card = _effectiveCard(raw);

    return LayoutBuilder(
      builder: (context, c) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 340,
              maxHeight: c.maxHeight,
            ),
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: _config.transitionDurationMs),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  _buildTransition(raw.animation, animation, child),
              child: _PromoCardView(
                key: ValueKey('${raw.id}_${card.qrMode.name}_${card.qrText ?? card.qrImagePath ?? ""}'),
                card: card,
                maxViewportHeight: c.maxHeight,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CustomerDisplayIdleRenderer extends StatefulWidget {
  const CustomerDisplayIdleRenderer({
    super.key,
    required this.config,
    this.compact = false,
  });

  final CustomerDisplayContentConfig config;
  /// Узкая колонка (экран меню без выбранного раздела) — вертикальная вёрстка.
  final bool compact;

  @override
  State<CustomerDisplayIdleRenderer> createState() =>
      _CustomerDisplayIdleRendererState();
}

class _CustomerDisplayIdleRendererState extends State<CustomerDisplayIdleRenderer> {
  CustomerDisplayContentConfig get _config => widget.config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = _config.left;

    if (widget.compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxHeight < 560;
          final logoBox = math.min(
            tight ? 220.0 : 280.0,
            constraints.maxWidth.isFinite
                ? math.min(constraints.maxWidth * 0.72, 280.0)
                : 280.0,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    left.headline,
                    textAlign: TextAlign.center,
                    style: _customerDisplayHeadlineStyle(
                      theme,
                      theme.textTheme.headlineMedium?.copyWith(
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  SizedBox(height: tight ? 10 : 18),
                  SizedBox(
                    width: logoBox + 24,
                    height: logoBox + 24,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: _IdleHeroLogo(logoPath: left.logoPath),
                    ),
                  ),
                  SizedBox(height: tight ? 10 : 16),
                  Text(
                    left.brandTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  SizedBox(height: tight ? 12 : 20),
                  SizedBox(
                    height: tight ? 180 : 220,
                    child: CustomerDisplayPromoCarousel(config: _config),
                  ),
                  const SizedBox(height: 16),
                  CustomerDisplayTypingTicker(
                    typing: _config.typing,
                    fallbackText: left.description,
                    textStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.88),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, rowConstraints) {
        final midH = rowConstraints.maxHeight.isFinite
            ? math.min(420.0, rowConstraints.maxHeight * 0.85)
            : 420.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 7,
              child: LayoutBuilder(
                builder: (context, c) {
                  final logoBox = math.min(
                    380.0,
                    math.min(c.maxWidth * 0.96, c.maxHeight.isFinite ? c.maxHeight * 0.52 : 380.0),
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            left.headline,
                            textAlign: TextAlign.center,
                            style: _customerDisplayHeadlineStyle(
                              theme,
                              theme.textTheme.displaySmall?.copyWith(
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          SizedBox(height: c.maxHeight < 520 ? 12 : 28),
                          SizedBox(
                            width: logoBox + 32,
                            height: logoBox + 32,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: _IdleHeroLogo(logoPath: left.logoPath),
                            ),
                          ),
                          SizedBox(height: c.maxHeight < 520 ? 12 : 34),
                          Text(
                            left.brandTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          CustomerDisplayTypingTicker(
                            typing: _config.typing,
                            fallbackText: left.description,
                            textStyle: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.88),
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              width: 1,
              height: midH,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            const SizedBox(width: 28),
            Expanded(
              flex: 3,
              child: CustomerDisplayPromoCarousel(config: _config),
            ),
          ],
        );
      },
    );
  }
}

Widget _buildTransition(
  CustomerDisplayCardAnimation animation,
  Animation<double> animationValue,
  Widget child,
) {
  switch (animation) {
    case CustomerDisplayCardAnimation.fade:
      return FadeTransition(opacity: animationValue, child: child);
    case CustomerDisplayCardAnimation.scale:
      return FadeTransition(
        opacity: animationValue,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animationValue),
          child: child,
        ),
      );
    case CustomerDisplayCardAnimation.slideLeft:
      return FadeTransition(
        opacity: animationValue,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.18, 0),
            end: Offset.zero,
          ).animate(animationValue),
          child: child,
        ),
      );
    case CustomerDisplayCardAnimation.slideUp:
      return FadeTransition(
        opacity: animationValue,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.16),
            end: Offset.zero,
          ).animate(animationValue),
          child: child,
        ),
      );
  }
}

/// Строка с эффектом печати и ротацией фраз.
class CustomerDisplayTypingTicker extends StatefulWidget {
  const CustomerDisplayTypingTicker({
    super.key,
    required this.typing,
    required this.fallbackText,
    required this.textStyle,
  });

  final CustomerDisplayTypingConfig typing;
  final String fallbackText;
  final TextStyle? textStyle;

  @override
  State<CustomerDisplayTypingTicker> createState() =>
      _CustomerDisplayTypingTickerState();
}

class _CustomerDisplayTypingTickerState extends State<CustomerDisplayTypingTicker> {
  Timer? _typeTimer;
  Timer? _cursorTimer;
  int _messageIndex = 0;
  int _visibleChars = 0;
  bool _isPausing = false;
  bool _cursorOn = true;

  List<String> get _messages {
    final typed = widget.typing.effectiveMessages;
    if (typed.isNotEmpty) return typed;
    final fallback = widget.fallbackText.trim();
    if (fallback.isNotEmpty) return [fallback];
    return CustomerDisplayTypingConfig.fallback().effectiveMessages;
  }

  String get _currentMessage => _messages[_messageIndex % _messages.length];

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 520), (_) {
      if (!mounted || _isPausing) return;
      setState(() => _cursorOn = !_cursorOn);
    });
    _scheduleTypingStep();
  }

  @override
  void didUpdateWidget(covariant CustomerDisplayTypingTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prev = oldWidget.typing;
    final next = widget.typing;
    if (prev.pauseSeconds != next.pauseSeconds ||
        prev.charDelayMs != next.charDelayMs ||
        prev.effectiveMessages.join('|') != next.effectiveMessages.join('|')) {
      _restart();
    }
  }

  void _restart() {
    _typeTimer?.cancel();
    _messageIndex = 0;
    _visibleChars = 0;
    _isPausing = false;
    _cursorOn = true;
    _scheduleTypingStep();
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  void _scheduleTypingStep() {
    _typeTimer?.cancel();
    final delay = _isPausing
        ? Duration(seconds: widget.typing.pauseSeconds)
        : Duration(milliseconds: widget.typing.charDelayMs);
    _typeTimer = Timer(delay, _onTypingTick);
  }

  void _onTypingTick() {
    if (!mounted) return;
    final message = _currentMessage;
    if (!_isPausing) {
      if (_visibleChars < message.length) {
        setState(() {
          _visibleChars++;
          _cursorOn = true;
        });
        _scheduleTypingStep();
        return;
      }
      setState(() => _isPausing = true);
      _scheduleTypingStep();
      return;
    }

    setState(() {
      _isPausing = false;
      _messageIndex = (_messageIndex + 1) % _messages.length;
      _visibleChars = 0;
      _cursorOn = true;
    });
    _scheduleTypingStep();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ?? Theme.of(context).textTheme.bodyLarge;
    final message = _currentMessage;
    final shown = message.substring(0, _visibleChars.clamp(0, message.length));
    final showCursor = !_isPausing && _cursorOn;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56, maxWidth: 520),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: style,
            children: [
              TextSpan(text: shown),
              TextSpan(
                text: showCursor ? '|' : ' ',
                style: style?.copyWith(
                  color: kCustomerDisplayAccentRed,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdleHeroLogo extends StatefulWidget {
  const _IdleHeroLogo({required this.logoPath});

  final String? logoPath;

  @override
  State<_IdleHeroLogo> createState() => _IdleHeroLogoState();
}

class _IdleHeroLogoState extends State<_IdleHeroLogo>
    with SingleTickerProviderStateMixin {
  static const _stageSize = 400.0;
  static const _coreBase = 292.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 8000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Синус с целым числом циклов за один оборот [t∈0..1] — начало и конец совпадают.
  double _loopSin(double t, int cycles, [double phaseTurns = 0]) {
    return math.sin((t * cycles + phaseTurns) * math.pi * 2);
  }

  double _loopCos(double t, int cycles, [double phaseTurns = 0]) {
    return math.cos((t * cycles + phaseTurns) * math.pi * 2);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Все частоты — целые циклы за 8 с: бесшовный бесконечный loop.
        final breathe = 0.5 + 0.5 * _loopSin(t, 1);
        final floatRadius = isDark ? 20.0 : 15.0;
        final floatX = _loopSin(t, 1) * floatRadius;
        final floatY = _loopCos(t, 1) * floatRadius;
        final tilt = _loopSin(t, 1, 0.125) * 0.045;
        final scale = 1.0 + breathe * (isDark ? 0.065 : 0.05);
        final glow = (isDark ? 64.0 : 44.0) + breathe * (isDark ? 32.0 : 22.0);
        final coreSize = _coreBase + breathe * (isDark ? 26.0 : 20.0);

        final redGlow = kCustomerDisplayAccentRed.withValues(
          alpha: isDark ? 0.62 + breathe * 0.18 : 0.38 + breathe * 0.14,
        );
        final goldGlow = const Color(0xFFFFD166).withValues(
          alpha: isDark ? 0.42 + breathe * 0.12 : 0.28 + breathe * 0.1,
        );
        final ringAlpha = isDark ? 0.34 + breathe * 0.14 : 0.22 + breathe * 0.1;

        return SizedBox(
          width: _stageSize,
          height: _stageSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(
                angle: t * math.pi * 2,
                child: _IdleOrbitRing(
                  diameter: 392,
                  strokeWidth: 2.8,
                  color: kCustomerDisplayAccentRed.withValues(alpha: ringAlpha * 0.7),
                  dashLength: 22,
                  gapLength: 16,
                ),
              ),
              Transform.rotate(
                angle: -t * math.pi * 2,
                child: _IdleOrbitRing(
                  diameter: 358,
                  strokeWidth: 2.2,
                  color: const Color(0xFFFFD166).withValues(alpha: ringAlpha * 0.85),
                  dashLength: 14,
                  gapLength: 24,
                ),
              ),
              Transform.rotate(
                angle: t * math.pi * 4,
                child: _IdleOrbitRing(
                  diameter: 324,
                  strokeWidth: 1.8,
                  color: Colors.white.withValues(alpha: ringAlpha * 0.55),
                  dashLength: 8,
                  gapLength: 18,
                ),
              ),
              ...List.generate(6, (index) {
                final phaseTurns = index / 6.0;
                final orbitR = 168.0 + index * 6.0;
                final angle = (t + phaseTurns) * math.pi * 2;
                final dx = math.cos(angle) * orbitR;
                final dy = math.sin(angle) * orbitR;
                final spark = 0.4 + 0.6 * _loopSin(t, 2, phaseTurns);
                final sparkSize = 7.0 + index * 1.1;
                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Container(
                    width: sparkSize,
                    height: sparkSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (index.isEven
                              ? kCustomerDisplayAccentRed
                              : const Color(0xFFFFD166))
                          .withValues(alpha: spark * (isDark ? 0.92 : 0.7)),
                      boxShadow: [
                        BoxShadow(
                          color: (index.isEven
                                  ? kCustomerDisplayAccentRed
                                  : const Color(0xFFFFD166))
                              .withValues(alpha: spark * 0.55),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Transform.translate(
                offset: Offset(floatX, floatY),
                child: Transform.rotate(
                  angle: tilt,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: coreSize,
                      height: coreSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (isDark ? Colors.white : const Color(0xFFFFF8F0))
                                .withValues(alpha: isDark ? 0.2 + breathe * 0.06 : 0.55),
                            kCustomerDisplayAccentRed
                                .withValues(alpha: isDark ? 0.12 : 0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                        border: Border.all(
                          color: (isDark ? Colors.white : kCustomerDisplayAccentRed)
                              .withValues(alpha: isDark ? 0.28 + breathe * 0.1 : 0.18 + breathe * 0.08),
                          width: isDark ? 2.0 : 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: redGlow,
                            blurRadius: glow,
                            spreadRadius: 10 + breathe * 10,
                          ),
                          BoxShadow(
                            color: goldGlow,
                            blurRadius: glow * 0.75,
                            spreadRadius: 4 + breathe * 6,
                          ),
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08 + breathe * 0.04),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                        ],
                      ),
                      padding: EdgeInsets.all(isDark ? 22 : 18),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: kCustomerDisplayAccentRed.withValues(
                                alpha: isDark ? 0.18 : 0.12,
                              ),
                              blurRadius: isDark ? 24 : 16,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(
                                alpha: isDark ? 0.35 : 0.9,
                              ),
                              blurRadius: isDark ? 16 : 10,
                              spreadRadius: isDark ? 2 : 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: ClipOval(
                          child: _DisplayImage(
                            path: widget.logoPath ?? 'assets/img/icon_logo.PNG',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Пунктирное кольцо вокруг логотипа.
class _IdleOrbitRing extends StatelessWidget {
  const _IdleOrbitRing({
    required this.diameter,
    required this.strokeWidth,
    required this.color,
    required this.dashLength,
    required this.gapLength,
  });

  final double diameter;
  final double strokeWidth;
  final Color color;
  final double dashLength;
  final double gapLength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(diameter, diameter),
      painter: _DashedRingPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final circumference = 2 * math.pi * radius;
    final segment = dashLength + gapLength;
    final count = (circumference / segment).ceil();
    for (var i = 0; i < count; i++) {
      final startAngle = (i * segment / radius);
      final sweep = dashLength / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

class _PromoCardView extends StatelessWidget {
  const _PromoCardView({
    super.key,
    required this.card,
    this.maxViewportHeight = double.infinity,
  });

  final CustomerDisplayPromoCardConfig card;
  final double maxViewportHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQrImage =
        card.qrMode == CustomerDisplayQrMode.image &&
        (card.qrImagePath ?? '').trim().isNotEmpty;
    final hasQrText =
        card.qrMode == CustomerDisplayQrMode.generated &&
        (card.qrText ?? '').trim().isNotEmpty;
    final vh = maxViewportHeight.isFinite ? maxViewportHeight : 600.0;
    final qrSize = math.min(170.0, (vh * 0.32).clamp(96.0, 170.0));
    final qrImgH = math.min(250.0, (vh * 0.38).clamp(100.0, 250.0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : vh;
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((card.title).trim().isNotEmpty)
                    Text(
                      card.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if ((card.body).trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      card.body,
                      textAlign: TextAlign.center,
                      style: _customerDisplayPromoAccentStyle(theme),
                    ),
                  ],
                  if ((card.logoPath ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _DisplayImage(
                        path: card.logoPath!,
                        height: 56,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                  if (hasQrText || hasQrImage) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: hasQrImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: _DisplayImage(
                                path: card.qrImagePath!,
                                height: qrImgH,
                                fit: BoxFit.cover,
                              ),
                            )
                          : SizedBox(
                              width: qrSize,
                              height: qrSize,
                              child: QrImageView(
                                data: card.qrText!,
                                version: QrVersions.auto,
                                size: qrSize,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF111111),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF111111),
                                ),
                              ),
                            ),
                    ),
                  ],
                  if ((card.footer ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      card.footer!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFFFD166),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if ((card.phone ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      card.phone!,
                      textAlign: TextAlign.center,
                      style: _customerDisplayPhoneStyle(theme),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DisplayImage extends StatelessWidget {
  const _DisplayImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.height,
  });

  final String path;
  final BoxFit fit;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final normalized = path.trim();
    if (normalized.startsWith('assets/')) {
      return Image.asset(normalized, fit: fit, height: height);
    }
    final url = AppConfig.mediaUrl(normalized);
    return RobustNetworkImage(
      url: url,
      fit: fit,
      height: height,
      errorWidget: const SizedBox.shrink(),
    );
  }
}
