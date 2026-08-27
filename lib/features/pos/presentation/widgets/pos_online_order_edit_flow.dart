import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/hardware/data/local_hardware_repository.dart';
import 'package:dk_pos/features/menu/bloc/menu_bloc.dart';
import 'package:dk_pos/features/menu/bloc/menu_event.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/data/open_table_bill_from_server.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/presentation/utils/pos_catalog_navigation.dart';
import 'package:dk_pos/features/pos/presentation/utils/website_order_delivery_meta.dart';
import 'package:dk_pos/features/pos/presentation/widgets/open_table_bill_cart_hydrate.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_checkout_flow.dart';

/// Позвонить клиенту онлайн-заказа (если в метке есть телефон).
Future<void> callWebsiteOrderCustomer(BuildContext context, String? phoneRaw) async {
  final tel = normalizePhoneForTelUri(phoneRaw);
  if (tel == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Телефон клиента в заказе не указан')),
      );
    }
    return;
  }
  final uri = Uri(scheme: 'tel', path: tel);
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть звонок: $tel')),
    );
  }
}

/// Печать обновлённого чека после согласованного изменения состава.
Future<void> printConsentUpdatedOrderReceipt(
  BuildContext context, {
  required String orderId,
  required double total,
  required WebsiteOrderDeliveryMeta meta,
}) async {
  try {
    final note =
        'Заказ изменён по согласованию с клиентом (${DateTime.now().toLocal().toString().substring(0, 16)})';
    await context.read<LocalHardwareRepository>().printReceipt(
          orderId: orderId,
          totalAmount: total,
          paymentMethod: 'website_amended',
          receiptTitle: 'ОБНОВЛЁННЫЙ ЗАКАЗ',
          customerName: meta.contact,
          customerPhone: meta.phone,
          deliveryAddress: meta.address,
          deliveryNote: [
            if (meta.comment != null && meta.comment!.isNotEmpty) meta.comment,
            note,
          ].whereType<String>().join(' · '),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Обновлённый чек отправлен на печать')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Печать не удалась: $e')),
    );
  }
}

Future<void> offerPrintConsentUpdatedReceipt(
  BuildContext context, {
  required String orderId,
  required double total,
  required WebsiteOrderDeliveryMeta meta,
}) async {
  if (!context.mounted) return;
  final print = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Обновлённый чек'),
      content: const Text(
        'Состав заказа сохранён. Распечатать чек для клиента?\n\n'
        'На чеке будет указано, что заказ изменён по согласованию с клиентом.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Позже'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Печать'),
        ),
      ],
    ),
  );
  if (print == true && context.mounted) {
    await printConsentUpdatedOrderReceipt(
      context,
      orderId: orderId,
      total: total,
      meta: meta,
    );
  }
}

/// Согласование с клиентом → принять (если нужно) → режим «добавить к счёту».
Future<void> startOnlineOrderEditWithCustomerConsent(
  BuildContext posHostContext, {
  required LocalCashierBoardOrder row,
  required Future<void> Function() onAcknowledgeIncoming,
}) async {
  if (!posHostContext.mounted) return;
  final o = row.order;
  final tableLabel = row.tableLabel?.trim() ?? '';
  final meta = parseWebsiteOrderDeliveryMeta(tableLabel);

  final proceed = await showDialog<bool>(
    context: posHostContext,
    builder: (ctx) => AlertDialog(
      title: Text('Изменить заказ №${o.number}?'),
      content: Text(
        [
          '1. Позвоните клиенту и согласуйте изменение состава.',
          if (meta.phone != null) 'Тел.: ${meta.phone}',
          '2. После согласия откроется каталог — добавьте или уберите позиции.',
          '3. Нажмите «Добавить к счёту (сохранить)».',
          '4. Распечатайте обновлённый чек для клиента.',
        ].join('\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        if (meta.phone != null)
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              callWebsiteOrderCustomer(posHostContext, meta.phone);
            },
            child: const Text('Позвонить'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Клиент согласен'),
        ),
      ],
    ),
  );
  if (proceed != true || !posHostContext.mounted) return;

  try {
    await posHostContext
        .read<LocalOrdersRepository>()
        .recordSiteOrderChangeConsent(orderId: o.id);
  } catch (e) {
    if (posHostContext.mounted) {
      ScaffoldMessenger.of(posHostContext).showSnackBar(
        SnackBar(content: Text('Не удалось начать изменение заказа: $e')),
      );
    }
    return;
  }
  if (!posHostContext.mounted) return;

  if (row.needsCashierAck) {
    await onAcknowledgeIncoming();
    if (!posHostContext.mounted) return;
    await refreshOpenTableBillsIntoHall(posHostContext);
  }

  if (!posHostContext.mounted) return;
  final hall = posHostContext.read<PosHallOrdersCubit>();
  PosTableBill? bill = hall.findOpenBillByOrderId(o.id);
  if (bill == null) {
    try {
      final dtos = await posHostContext.read<LocalOrdersRepository>().fetchOpenTableBills(
            branchId: AppConfig.storeBranchId,
          );
      if (!posHostContext.mounted) return;
      final match = dtos.where((d) => d.id == o.id).toList();
      if (match.isNotEmpty) {
        bill = posTableBillFromServerDto(match.first);
        hall.mergeHydrateFromServer(
          dtos.map(posTableBillFromServerDto).toList(),
        );
      }
    } catch (_) {}
  }

  if (bill == null) {
    if (!posHostContext.mounted) return;
    ScaffoldMessenger.of(posHostContext).showSnackBar(
      const SnackBar(
        content: Text(
          'Счёт заказа не найден. Нажмите «Принять», затем повторите «Изменить».',
        ),
      ),
    );
    return;
  }

  final menuState = posHostContext.read<MenuBloc>().state;
  if (menuState.loading || menuState.categoryRoots.isEmpty) {
    ScaffoldMessenger.of(posHostContext).showSnackBar(
      const SnackBar(content: Text('Дождитесь загрузки меню и повторите.')),
    );
    return;
  }

  final hydrated = hydrateOpenTableBillIntoCartLines(
    menuRoots: menuState.categoryRoots,
    bill: bill,
  );
  posHostContext.read<CartBloc>().add(CartActiveCheckReplaced(hydrated.cartLines));
  posHostContext.read<CartBloc>().add(
        CartOrderTypeIndexChanged(posOrderTypeIndexForOpenBill(bill)),
      );
  final menuPath = initialMenuPathForProductPicker(menuState.categoryRoots);
  if (menuPath.isNotEmpty) {
    posHostContext.read<MenuBloc>().add(MenuCatalogPathSet(menuPath));
  }
  posHostContext.read<PosHallOrdersCubit>().startOpenBillAppend(
        bill,
        baselineQtyByLineKey: hydrated.baselineQtyByLineKey,
        kitchenQtyLockedByLineKey: hydrated.kitchenQtyLockedByLineKey,
        customerConsentEdit: true,
        consentReceiptMeta: meta,
      );

  if (!posHostContext.mounted) return;
  ScaffoldMessenger.of(posHostContext).showSnackBar(
    SnackBar(
      content: Text(
        hydrated.cartLines.isEmpty && bill.lines.isNotEmpty
            ? 'Изменение заказа №${o.number}: добавьте позиции вручную, затем «Добавить к счёту».'
            : 'Изменение заказа №${o.number}: скорректируйте корзину и нажмите «Добавить к счёту».',
      ),
      duration: const Duration(seconds: 6),
    ),
  );
}
