import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:dk_digitial_menu/widgets/robust_network_image.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';

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
  });

  final CustomerDisplayContentConfig config;

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

    return LayoutBuilder(
      builder: (context, rowConstraints) {
        final midH = rowConstraints.maxHeight.isFinite
            ? min(420.0, rowConstraints.maxHeight * 0.85)
            : 420.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 7,
              child: LayoutBuilder(
                builder: (context, c) {
                  final logoBox = min(
                    280.0,
                    min(c.maxWidth * 0.92, c.maxHeight.isFinite ? c.maxHeight * 0.42 : 280.0),
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
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: const Color(0xFFFFD166),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
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
                          const SizedBox(height: 22),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(
                              left.description,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.82),
                                height: 1.45,
                              ),
                            ),
                          ),
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

class _IdleHeroLogo extends StatefulWidget {
  const _IdleHeroLogo({required this.logoPath});

  final String? logoPath;

  @override
  State<_IdleHeroLogo> createState() => _IdleHeroLogoState();
}

class _IdleHeroLogoState extends State<_IdleHeroLogo>
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
                child: _DisplayImage(
                  path: widget.logoPath ?? 'assets/img/icon_logo.PNG',
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
    final scheme = theme.colorScheme;
    final hasQrImage =
        card.qrMode == CustomerDisplayQrMode.image &&
        (card.qrImagePath ?? '').trim().isNotEmpty;
    final hasQrText =
        card.qrMode == CustomerDisplayQrMode.generated &&
        (card.qrText ?? '').trim().isNotEmpty;
    final vh = maxViewportHeight.isFinite ? maxViewportHeight : 600.0;
    final qrSize = min(170.0, (vh * 0.32).clamp(96.0, 170.0));
    final qrImgH = min(250.0, (vh * 0.38).clamp(100.0, 250.0));

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
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.84),
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
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
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w700,
                      ),
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
