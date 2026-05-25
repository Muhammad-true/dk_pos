import 'package:equatable/equatable.dart';

/// Размер карточки товара в сетке каталога POS.
enum PosCatalogCardSize {
  compact,
  normal,
  large;

  String get label => switch (this) {
        PosCatalogCardSize.compact => 'Компакт',
        PosCatalogCardSize.normal => 'Обычный',
        PosCatalogCardSize.large => 'Крупный',
      };

  String get storageValue => name;

  double get minCellWidth => switch (this) {
        PosCatalogCardSize.compact => 100,
        PosCatalogCardSize.normal => 132,
        PosCatalogCardSize.large => 168,
      };

  double get aspectRatio => switch (this) {
        PosCatalogCardSize.compact => 0.64,
        PosCatalogCardSize.normal => 0.76,
        PosCatalogCardSize.large => 0.90,
      };
}

PosCatalogCardSize parsePosCatalogCardSize(String? raw) {
  return switch (raw) {
    'compact' => PosCatalogCardSize.compact,
    'large' => PosCatalogCardSize.large,
    _ => PosCatalogCardSize.normal,
  };
}

/// Настройки сетки товаров (колонки и высота карточки).
class PosCatalogGridSettings extends Equatable {
  const PosCatalogGridSettings({
    required this.useAutoColumns,
    required this.manualColumnCount,
    required this.cardSize,
  });

  final bool useAutoColumns;
  final int manualColumnCount;
  final PosCatalogCardSize cardSize;

  static const defaults = PosCatalogGridSettings(
    useAutoColumns: true,
    manualColumnCount: 4,
    cardSize: PosCatalogCardSize.normal,
  );

  PosCatalogGridSettings copyWith({
    bool? useAutoColumns,
    int? manualColumnCount,
    PosCatalogCardSize? cardSize,
  }) {
    return PosCatalogGridSettings(
      useAutoColumns: useAutoColumns ?? this.useAutoColumns,
      manualColumnCount: manualColumnCount ?? this.manualColumnCount,
      cardSize: cardSize ?? this.cardSize,
    );
  }

  /// Сколько колонок получится при заданной ширине области каталога.
  int columnsFor({
    required double catalogPaneWidth,
    required bool sideCategoryNav,
  }) {
    if (!useAutoColumns) {
      return manualColumnCount.clamp(2, 8);
    }
    const categoryRailWidth = 200.0;
    final side = sideCategoryNav ? categoryRailWidth : 0.0;
    const pad = 24.0;
    final gridW = catalogPaneWidth - side - pad;
    if (gridW < 200) return 2;
    const gutter = 12.0;
    final minCell = cardSize.minCellWidth;
    final n = ((gridW + gutter) / (minCell + gutter)).floor();
    return n.clamp(2, 8);
  }

  double aspectRatioFor({
    required double catalogPaneWidth,
    bool orderAppendMode = false,
  }) {
    final base = cardSize.aspectRatio;
    if (!orderAppendMode) return base;
    if (catalogPaneWidth < 520) return base - 0.06;
    if (catalogPaneWidth < 720) return base - 0.02;
    return base;
  }

  @override
  List<Object?> get props => [useAutoColumns, manualColumnCount, cardSize];
}
