import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_customer_display_panel.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

/// Чек + QR банка при оплате «сейчас» на экране клиента.
class CustomerDisplayPaymentView extends StatelessWidget {
  const CustomerDisplayPaymentView({
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
    final bankCard =
        promoConfig.bankPaymentCard ??
        CustomerDisplayContentConfig.fallback().bankPaymentCard;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: customerDisplayBackgroundGradient(theme),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Оплата заказа',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _ReceiptPanel(cart: cart),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _BankQrPanel(card: bankCard),
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

class _ReceiptPanel extends StatelessWidget {
  const _ReceiptPanel({required this.cart});

  final CustomerDisplayCartData cart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: customerDisplayCardSurface(theme),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: customerDisplayCardBorder(theme)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                Text(
                  'Ваш чек',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  formatSomoni(cart.total),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: cart.lines.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 18, color: scheme.outlineVariant),
              itemBuilder: (context, index) {
                final line = cart.lines[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${line.quantity}x',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        line.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      formatSomoni(line.lineTotal),
                      style: theme.textTheme.titleSmall?.copyWith(
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
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Text(
                  'Итого к оплате',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  formatSomoni(cart.total),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
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

class _BankQrPanel extends StatelessWidget {
  const _BankQrPanel({this.card});

  final CustomerDisplayPromoCardConfig? card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = card;
    final hasQrImage =
        c != null &&
        c.qrMode == CustomerDisplayQrMode.image &&
        (c.qrImagePath ?? '').trim().isNotEmpty;
    final hasQrText =
        c != null &&
        c.qrMode == CustomerDisplayQrMode.generated &&
        (c.qrText ?? '').trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: customerDisplayGlassFill(theme),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: customerDisplayGlassBorder(theme)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            c?.title.trim().isNotEmpty == true ? c!.title : 'Оплата по QR',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          if ((c?.body ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              c!.body,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (hasQrImage || hasQrText)
            Container(
              decoration: BoxDecoration(
                color: customerDisplayCardSurface(theme),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: customerDisplayCardBorder(theme)),
              ),
              padding: const EdgeInsets.all(14),
              child: hasQrImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _QrImage(path: c.qrImagePath!),
                    )
                  : SizedBox(
                      width: 220,
                      height: 220,
                      child: QrImageView(
                        data: c.qrText ?? '',
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
            )
          else
            Text(
              'QR банка не настроен',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  const _QrImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final normalized = path.trim();
    if (normalized.startsWith('assets/')) {
      return Image.asset(normalized, fit: BoxFit.contain, height: 280);
    }
    return Image.network(
      AppConfig.mediaUrl(normalized),
      fit: BoxFit.contain,
      height: 280,
      errorBuilder: (_, __, ___) => const SizedBox(height: 120),
    );
  }
}
