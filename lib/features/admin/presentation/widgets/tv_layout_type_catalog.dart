import 'package:flutter/material.dart';

import 'package:dk_pos/features/admin/presentation/widgets/tv_layout_type_picker.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

const _kTv2PageTypes = [
  'split',
  'drinks',
  'carousel',
  'list',
  'product_grid',
  'four_showcase',
  'editorial_showcase',
  'two_product_equal',
  'two_product_diagonal',
  'pizza_show',
  'pizza_grid',
  'video_bg',
  'media_only',
  'menu_ribbon',
  'queue',
];

const _kScreenTypes = [
  'carousel',
  'tv2',
  'tv3',
  'tv4',
  'customer_display',
];

const _kTv3PageTypes = [
  'promo_product',
  'promo_combo',
  'promo_video_bg',
  'promo_photo_bg',
];

List<TvLayoutTypeOption> tv2PageTypeOptions(AppLocalizations l10n) {
  return [
    TvLayoutTypeOption(
      id: 'split',
      title: l10n.adminTv2PageTypeSplit,
      description: l10n.adminTv2PageTypeSplitDesc,
      icon: Icons.view_column_rounded,
      accentColor: const Color(0xFFE4002B),
    ),
    TvLayoutTypeOption(
      id: 'drinks',
      title: l10n.adminTv2PageTypeDrinks,
      description: l10n.adminTv2PageTypeDrinksDesc,
      icon: Icons.local_drink_rounded,
      accentColor: Colors.blue.shade700,
    ),
    TvLayoutTypeOption(
      id: 'carousel',
      title: l10n.adminTv2PageTypeCarousel,
      description: l10n.adminTv2PageTypeCarouselDesc,
      icon: Icons.view_carousel_rounded,
      accentColor: Colors.deepPurple,
    ),
    TvLayoutTypeOption(
      id: 'list',
      title: l10n.adminTv2PageTypeList,
      description: l10n.adminTv2PageTypeListDesc,
      icon: Icons.view_list_rounded,
      accentColor: Colors.teal.shade700,
    ),
    TvLayoutTypeOption(
      id: 'product_grid',
      title: l10n.adminTv2PageTypeProductGrid,
      description: l10n.adminTv2PageTypeProductGridDesc,
      icon: Icons.grid_view_rounded,
      accentColor: Colors.orange.shade800,
    ),
    TvLayoutTypeOption(
      id: 'four_showcase',
      title: 'Витрина 4 товара',
      description:
          'Четыре PNG-товара; лишние позиции плавно сменяют друг друга.',
      icon: Icons.view_week_rounded,
      accentColor: const Color(0xFFE4002B),
    ),
    TvLayoutTypeOption(
      id: 'editorial_showcase',
      title: 'Красная витрина',
      description:
          'Большой товар и пять акцентных позиций; лишние товары плавно сменяются.',
      icon: Icons.auto_awesome_mosaic_rounded,
      accentColor: const Color(0xFFE4002B),
    ),
    TvLayoutTypeOption(
      id: 'two_product_equal',
      title: 'Два товара — поровну',
      description:
          'Два крупных товара: отдельные фон, текст и цена слева и справа.',
      icon: Icons.compare_rounded,
      accentColor: const Color(0xFFE4002B),
    ),
    TvLayoutTypeOption(
      id: 'two_product_diagonal',
      title: 'Два товара — акция',
      description:
          'Два товара на диагональном красном фоне с плавным появлением.',
      icon: Icons.change_history_rounded,
      accentColor: const Color(0xFFE4002B),
    ),
    TvLayoutTypeOption(
      id: 'pizza_show',
      title: 'Пицца — шоу',
      description:
          'Крупная пицца: въезд слева, увеличение, цены 25/30/35 внизу.',
      icon: Icons.local_pizza_rounded,
      accentColor: const Color(0xFFE4002B),
    ),
    TvLayoutTypeOption(
      id: 'pizza_grid',
      title: 'Пицца — витрина',
      description: 'Сетка 4–6 пицц с размерами и ценами для быстрого обзора.',
      icon: Icons.grid_on_rounded,
      accentColor: Colors.deepOrange.shade800,
    ),
    TvLayoutTypeOption(
      id: 'video_bg',
      title: l10n.adminTv2PageTypeVideoBg,
      description: l10n.adminTv2PageTypeVideoBgDesc,
      icon: Icons.movie_rounded,
      accentColor: Colors.indigo.shade700,
    ),
    TvLayoutTypeOption(
      id: 'media_only',
      title: 'Только видео/фото',
      description: 'Фон на весь экран без надписей и карточки товара.',
      icon: Icons.wallpaper_rounded,
      accentColor: Colors.blueGrey.shade700,
    ),
    TvLayoutTypeOption(
      id: 'menu_ribbon',
      title: 'Лента меню',
      description: 'Горизонтальные карточки с анимацией появления.',
      icon: Icons.view_carousel_outlined,
      accentColor: Colors.deepOrange.shade700,
    ),
    TvLayoutTypeOption(
      id: 'queue',
      title: 'Очередь заказов',
      description: 'Экран «Готовится / Готово» в ротации с меню и видео.',
      icon: Icons.receipt_long_rounded,
      accentColor: Colors.green.shade700,
    ),
  ];
}

List<TvLayoutTypeOption> tv3PageTypeOptions(AppLocalizations l10n) {
  return [
    TvLayoutTypeOption(
      id: 'promo_product',
      title: l10n.adminTv3PageTypePromoProduct,
      description: l10n.adminTv3PageTypePromoProductDesc,
      icon: Icons.fastfood_rounded,
      accentColor: const Color(0xFFE4002B),
    ),
    TvLayoutTypeOption(
      id: 'promo_combo',
      title: l10n.adminTv3PageTypePromoCombo,
      description: l10n.adminTv3PageTypePromoComboDesc,
      icon: Icons.lunch_dining_rounded,
      accentColor: Colors.orange.shade800,
    ),
    TvLayoutTypeOption(
      id: 'promo_video_bg',
      title: l10n.adminTv3PageTypePromoVideoBg,
      description: l10n.adminTv3PageTypePromoVideoBgDesc,
      icon: Icons.videocam_rounded,
      accentColor: Colors.indigo.shade700,
    ),
    TvLayoutTypeOption(
      id: 'promo_photo_bg',
      title: l10n.adminTv3PageTypePromoPhotoBg,
      description: l10n.adminTv3PageTypePromoPhotoBgDesc,
      icon: Icons.photo_rounded,
      accentColor: Colors.teal.shade700,
    ),
  ];
}

List<TvLayoutTypeOption> tvScreenTypeOptions(AppLocalizations l10n) {
  return [
    TvLayoutTypeOption(
      id: 'carousel',
      title: l10n.adminScreenTypeCarouselShort,
      description: l10n.adminScreenTypeCarouselDesc,
      icon: Icons.slideshow_rounded,
      accentColor: const Color(0xFFE4002B),
    ),
    TvLayoutTypeOption(
      id: 'tv2',
      title: l10n.adminScreenTypeTv2Short,
      description: l10n.adminScreenTypeTv2Desc,
      icon: Icons.tv_rounded,
      accentColor: Colors.blue.shade700,
    ),
    TvLayoutTypeOption(
      id: 'tv3',
      title: l10n.adminScreenTypeTv3Short,
      description: l10n.adminScreenTypeTv3Desc,
      icon: Icons.campaign_rounded,
      accentColor: Colors.deepOrange,
    ),
    TvLayoutTypeOption(
      id: 'tv4',
      title: l10n.adminScreenTypeTv4Short,
      description: l10n.adminScreenTypeTv4Desc,
      icon: Icons.waving_hand_rounded,
      accentColor: Colors.green.shade700,
    ),
    TvLayoutTypeOption(
      id: 'customer_display',
      title: l10n.adminScreenTypeCustomerDisplayShort,
      description: l10n.adminScreenTypeCustomerDisplayDesc,
      icon: Icons.point_of_sale_rounded,
      accentColor: Colors.purple.shade700,
    ),
  ];
}

bool isKnownTv2PageType(String id) => _kTv2PageTypes.contains(id);
bool isKnownScreenType(String id) => _kScreenTypes.contains(id);
bool isKnownTv3PageType(String id) => _kTv3PageTypes.contains(id);
