import 'dart:async';

import 'package:dk_digitial_menu/data/display_image_prefetch.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_sync_state.dart';
import 'package:dk_pos/shared/shared.dart';

/// Абсолютный URL фото товара для кеша (HTTP) или `null` для assets/пустого.
String? posMenuImageAbsoluteUrl(String? imagePath) {
  final raw = (imagePath ?? '').trim();
  if (raw.isEmpty || raw.startsWith('assets/')) return null;
  final url = AppConfig.mediaUrl(raw);
  return url.isEmpty ? null : url;
}

Set<String> collectPosMenuImageUrls(Iterable<PosCategory> roots) {
  final out = <String>{};
  void walk(PosCategory category) {
    for (final item in category.items) {
      final url = posMenuImageAbsoluteUrl(item.imagePath);
      if (url != null) out.add(url);
    }
    for (final child in category.children) {
      walk(child);
    }
  }

  for (final root in roots) {
    walk(root);
  }
  return out;
}

Set<String> collectPosMenuImageUrlsFromItems(Iterable<PosMenuItem> items) {
  final out = <String>{};
  for (final item in items) {
    final url = posMenuImageAbsoluteUrl(item.imagePath);
    if (url != null) out.add(url);
  }
  return out;
}

Set<String> collectCustomerDisplayProductImageUrls(
  Iterable<CustomerDisplayMenuProductData> products,
) {
  final out = <String>{};
  for (final product in products) {
    final url = posMenuImageAbsoluteUrl(product.imagePath);
    if (url != null) out.add(url);
  }
  return out;
}

/// Скачать на диск (если нужно) и прогреть RAM — повторный показ без спиннера.
Future<void> prefetchPosMenuImageUrls(
  Set<String> urls, {
  Iterable<String> priorityUrls = const [],
  bool awaitCompletion = false,
}) {
  if (urls.isEmpty) return Future<void>.value();
  return DisplayImagePrefetch.instance.prefetchUrls(
    urls,
    priorityUrls: priorityUrls,
    awaitCompletion: awaitCompletion,
  );
}

Future<void> prefetchPosMenuCatalog(
  Iterable<PosCategory> roots, {
  Iterable<PosMenuItem> priorityItems = const [],
  bool awaitCompletion = false,
}) {
  final all = collectPosMenuImageUrls(roots);
  final priority = <String>[
    for (final item in priorityItems)
      if (posMenuImageAbsoluteUrl(item.imagePath) case final url?) url,
  ];
  return prefetchPosMenuImageUrls(
    all,
    priorityUrls: priority,
    awaitCompletion: awaitCompletion,
  );
}

Future<void> prefetchPosMenuItems(
  Iterable<PosMenuItem> items, {
  bool awaitCompletion = false,
}) {
  final urls = collectPosMenuImageUrlsFromItems(items);
  return prefetchPosMenuImageUrls(
    urls,
    priorityUrls: urls,
    awaitCompletion: awaitCompletion,
  );
}

Future<void> prefetchCustomerDisplayProducts(
  Iterable<CustomerDisplayMenuProductData> products, {
  bool awaitCompletion = false,
}) {
  final urls = collectCustomerDisplayProductImageUrls(products);
  return prefetchPosMenuImageUrls(
    urls,
    priorityUrls: urls,
    awaitCompletion: awaitCompletion,
  );
}
