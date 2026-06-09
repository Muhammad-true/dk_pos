import 'package:dk_digitial_menu/widgets/robust_network_image.dart';
import 'package:flutter/material.dart';

import 'package:dk_pos/core/config/app_config.dart';

/// Фото товара (PNG без фона): целиком в рамке, без обрезки, на нейтральном фоне темы.
class PosProductImage extends StatelessWidget {
  const PosProductImage({
    super.key,
    this.imagePath,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.padding = const EdgeInsets.all(10),
    this.filterQuality = FilterQuality.high,
    this.placeholderIcon = Icons.lunch_dining_rounded,
    this.placeholderIconSize = 48,
    this.backgroundColor,
  });

  final String? imagePath;
  final BoxFit fit;
  final Alignment alignment;
  final EdgeInsets padding;
  final FilterQuality filterQuality;
  final IconData placeholderIcon;
  final double placeholderIconSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = (imagePath ?? '').trim();
    final decoration = _backgroundDecoration(scheme);

    if (normalized.isEmpty) {
      return DecoratedBox(
        decoration: decoration,
        child: Center(
          child: Icon(
            placeholderIcon,
            size: placeholderIconSize,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final pxW = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round().clamp(1, 4096)
            : null;
        final pxH = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * dpr).round().clamp(1, 4096)
            : null;
        final decodeSide = pxW != null && pxH != null
            ? (pxW > pxH ? pxW : pxH)
            : (pxW ?? pxH);

        return DecoratedBox(
          decoration: decoration,
          child: Padding(
            padding: padding,
            child: _buildImage(
              context,
              normalized,
              decodeSide,
              scheme,
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _backgroundDecoration(ColorScheme scheme) {
    if (backgroundColor != null) {
      return BoxDecoration(color: backgroundColor);
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scheme.surfaceContainerLowest,
          scheme.surfaceContainerLow,
        ],
      ),
    );
  }

  Widget _buildImage(
    BuildContext context,
    String normalized,
    int? decodeSide,
    ColorScheme scheme,
  ) {
    final errorIcon = Icon(
      Icons.broken_image_outlined,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
      size: placeholderIconSize * 0.85,
    );

    if (normalized.startsWith('assets/')) {
      return Image.asset(
        normalized,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        cacheWidth: decodeSide,
        errorBuilder: (_, __, ___) => Center(child: errorIcon),
      );
    }

    final url = AppConfig.mediaUrl(normalized);
    if (url.isEmpty) {
      return Center(
        child: Icon(
          placeholderIcon,
          size: placeholderIconSize,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      );
    }

    return RobustNetworkImage(
      url: url,
      fit: fit,
      alignment: alignment,
      cacheWidth: decodeSide,
      filterQuality: filterQuality,
      errorWidget: Center(child: errorIcon),
    );
  }
}
