import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dk_pos/shared/shared.dart';

import 'pos_product_image.dart';

/// Якорь корзины для анимации «товар летит в корзину».
class PosFlyToCartTarget {
  PosFlyToCartTarget._();

  static GlobalKey? cartTargetKey;

  static Rect? targetGlobalRect() {
    final ctx = cartTargetKey?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }
}

/// Визуальный стиль «пузыря» при полёте в корзину.
enum PosFlyToCartVisualStyle {
  /// Цвета из текущей темы (касса).
  adaptive,

  /// Тёмная карточка с красным свечением — как на кассе в тёмной теме.
  customerDisplay,
}

/// Лёгкая overlay-анимация: карточка товара → корзина (не блокирует UI).
class PosFlyToCart {
  PosFlyToCart._();

  static const Duration _duration = Duration(milliseconds: 420);

  static Future<void> play({
    required BuildContext context,
    required Rect fromGlobal,
    required Rect toGlobal,
    PosMenuItem? item,
    PosFlyToCartVisualStyle style = PosFlyToCartVisualStyle.adaptive,
  }) async {
    if (!context.mounted) return;
    if (fromGlobal.width < 8 || fromGlobal.height < 8) return;
    if (toGlobal.width < 8 || toGlobal.height < 8) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final completer = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _FlyBubble(
        from: fromGlobal,
        to: toGlobal,
        item: item,
        style: style,
        onDone: () {
          entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    overlay.insert(entry);
    await completer.future.timeout(
      _duration + const Duration(milliseconds: 120),
      onTimeout: () {
        entry.remove();
      },
    );
  }
}

class _FlyBubbleLook {
  const _FlyBubbleLook({
    required this.surface,
    required this.border,
    required this.glow,
    required this.imageBackdrop,
    required this.arcLift,
    required this.startSize,
    required this.glowBlur,
    required this.glowSpread,
    required this.glowAlpha,
    required this.vignetteAlpha,
  });

  final Color surface;
  final Color border;
  final Color glow;
  final Color imageBackdrop;
  final double arcLift;
  final double startSize;
  final double glowBlur;
  final double glowSpread;
  final double glowAlpha;
  final double vignetteAlpha;

  factory _FlyBubbleLook.resolve(
    ColorScheme scheme,
    PosFlyToCartVisualStyle style,
  ) {
    if (style == PosFlyToCartVisualStyle.customerDisplay) {
      return _FlyBubbleLook(
        surface: const Color(0xFF1F232C),
        border: const Color(0xFF3D4454),
        glow: scheme.primary,
        imageBackdrop: const Color(0xFF171A20),
        arcLift: 96,
        startSize: 68,
        glowBlur: 22,
        glowSpread: 2,
        glowAlpha: 0.58,
        vignetteAlpha: 0.22,
      );
    }
    return _FlyBubbleLook(
      surface: scheme.surfaceContainerLowest,
      border: scheme.outlineVariant,
      glow: scheme.primary,
      imageBackdrop: scheme.surfaceContainerLow,
      arcLift: 72,
      startSize: 56,
      glowBlur: 14,
      glowSpread: 1,
      glowAlpha: 0.35,
      vignetteAlpha: 0,
    );
  }
}

class _FlyBubble extends StatefulWidget {
  const _FlyBubble({
    required this.from,
    required this.to,
    required this.item,
    required this.style,
    required this.onDone,
  });

  final Rect from;
  final Rect to;
  final PosMenuItem? item;
  final PosFlyToCartVisualStyle style;
  final VoidCallback onDone;

  @override
  State<_FlyBubble> createState() => _FlyBubbleState();
}

class _FlyBubbleState extends State<_FlyBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PosFlyToCart._duration,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _pointAt(double t, double arcLift) {
    final start = widget.from.center;
    final end = widget.to.center;
    final arcY = start.dy < end.dy ? start.dy : end.dy;
    final mid = Offset(
      (start.dx + end.dx) / 2,
      arcY - arcLift,
    );
    final u = 1 - t;
    return Offset(
      u * u * start.dx + 2 * u * t * mid.dx + t * t * end.dx,
      u * u * start.dy + 2 * u * t * mid.dy + t * t * end.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final look = _FlyBubbleLook.resolve(scheme, widget.style);
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final t = _t.value;
        final pos = _pointAt(t, look.arcLift);
        final size = look.startSize * (1 - t * 0.55);
        final opacity = (1 - t * 0.22).clamp(0.0, 1.0);
        final vignette = look.vignetteAlpha * (1 - t);

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (vignette > 0.01)
                ColoredBox(color: Colors.black.withValues(alpha: vignette)),
              Positioned(
                left: pos.dx - size / 2,
                top: pos.dy - size / 2,
                width: size,
                height: size,
                child: Opacity(
                  opacity: opacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: look.glow.withValues(alpha: look.glowAlpha),
                          blurRadius: look.glowBlur,
                          spreadRadius: look.glowSpread,
                        ),
                        if (widget.style == PosFlyToCartVisualStyle.customerDisplay)
                          BoxShadow(
                            color: look.glow.withValues(alpha: 0.24),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                      ],
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: look.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: look.border, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _Thumb(
                          item: widget.item,
                          backdrop: look.imageBackdrop,
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

class _Thumb extends StatelessWidget {
  const _Thumb({
    this.item,
    this.backdrop = const Color(0xFF1F232C),
  });

  final PosMenuItem? item;
  final Color backdrop;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backdrop,
      child: PosProductImage(
        imagePath: item?.imagePath,
        padding: const EdgeInsets.all(4),
        placeholderIconSize: 22,
        filterQuality: FilterQuality.low,
      ),
    );
  }
}
