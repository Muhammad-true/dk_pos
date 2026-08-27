import 'package:equatable/equatable.dart';

/// Плотность карточки заказа / счёта на кассе.
enum PosCashierCardDensity {
  compact,
  normal,
  spacious;

  String get label => switch (this) {
        PosCashierCardDensity.compact => 'Компакт',
        PosCashierCardDensity.normal => 'Обычный',
        PosCashierCardDensity.spacious => 'Крупный',
      };

  String get storageValue => name;
}

PosCashierCardDensity parsePosCashierCardDensity(String? raw) {
  return switch (raw) {
    'compact' => PosCashierCardDensity.compact,
    'spacious' => PosCashierCardDensity.spacious,
    _ => PosCashierCardDensity.normal,
  };
}

/// Локальный «конструктор» карточек кассы: размеры текстов и плотность.
class PosCashierBoardSettings extends Equatable {
  const PosCashierBoardSettings({
    required this.density,
    required this.tableHeadlineScale,
    required this.titleScale,
    required this.itemTextScale,
    required this.showTableOnTop,
  });

  final PosCashierCardDensity density;

  /// Крупный номер стола сверху карточки.
  final double tableHeadlineScale;

  /// № заказа и сумма.
  final double titleScale;

  /// Названия блюд в карточке.
  final double itemTextScale;

  /// Показывать номер стола крупно сверху (внизу строка смены стола остаётся).
  final bool showTableOnTop;

  static const defaults = PosCashierBoardSettings(
    density: PosCashierCardDensity.normal,
    tableHeadlineScale: 1.35,
    titleScale: 1,
    itemTextScale: 1,
    showTableOnTop: true,
  );

  static const large = PosCashierBoardSettings(
    density: PosCashierCardDensity.spacious,
    tableHeadlineScale: 1.55,
    titleScale: 1.12,
    itemTextScale: 1.1,
    showTableOnTop: true,
  );

  static const compactPreset = PosCashierBoardSettings(
    density: PosCashierCardDensity.compact,
    tableHeadlineScale: 1.15,
    titleScale: 0.95,
    itemTextScale: 0.92,
    showTableOnTop: true,
  );

  PosCashierBoardSettings copyWith({
    PosCashierCardDensity? density,
    double? tableHeadlineScale,
    double? titleScale,
    double? itemTextScale,
    bool? showTableOnTop,
  }) {
    return PosCashierBoardSettings(
      density: density ?? this.density,
      tableHeadlineScale: tableHeadlineScale ?? this.tableHeadlineScale,
      titleScale: titleScale ?? this.titleScale,
      itemTextScale: itemTextScale ?? this.itemTextScale,
      showTableOnTop: showTableOnTop ?? this.showTableOnTop,
    );
  }

  PosCashierBoardSettings clamped() {
    double c(double v) => v.clamp(0.8, 1.8);
    return PosCashierBoardSettings(
      density: density,
      tableHeadlineScale: c(tableHeadlineScale),
      titleScale: c(titleScale),
      itemTextScale: c(itemTextScale),
      showTableOnTop: showTableOnTop,
    );
  }

  double get cardPadding => switch (density) {
        PosCashierCardDensity.compact => 10,
        PosCashierCardDensity.normal => 12,
        PosCashierCardDensity.spacious => 14,
      };

  double get sectionGap => switch (density) {
        PosCashierCardDensity.compact => 4,
        PosCashierCardDensity.normal => 6,
        PosCashierCardDensity.spacious => 8,
      };

  int get maxItemLinesCompact => switch (density) {
        PosCashierCardDensity.compact => 2,
        PosCashierCardDensity.normal => 3,
        PosCashierCardDensity.spacious => 4,
      };

  int get maxItemLinesExpanded => switch (density) {
        PosCashierCardDensity.compact => 4,
        PosCashierCardDensity.normal => 5,
        PosCashierCardDensity.spacious => 6,
      };

  /// Соотношение сторон сетки карточек заказов (больше = ниже карточка).
  double gridAspectRatio({required int columns}) {
    final base = columns >= 3 ? 1.18 : 1.08;
    var ratio = switch (density) {
      PosCashierCardDensity.compact => base + 0.12,
      PosCashierCardDensity.normal => base,
      PosCashierCardDensity.spacious => base - 0.1,
    };
    // Крупный шрифт → выше ячейка, иначе контент обрезается «в никуда».
    ratio -= _textScaleHeightBoost(maxBoost: 0.35);
    if (showTableOnTop) ratio -= 0.08;
    return ratio.clamp(0.72, 1.45);
  }

  /// Сетка «Счета на оплату» — карточки шире; плотность и масштаб текста меняют высоту.
  double billsGridAspectRatio({required int columns}) {
    final base = columns >= 3 ? 2.2 : 2.0;
    var ratio = switch (density) {
      PosCashierCardDensity.compact => base + 0.15,
      PosCashierCardDensity.normal => base,
      PosCashierCardDensity.spacious => base - 0.22,
    };
    ratio -= _textScaleHeightBoost(maxBoost: 0.95);
    if (showTableOnTop) ratio -= 0.22;
    return ratio.clamp(1.12, 2.45);
  }

  double _textScaleHeightBoost({required double maxBoost}) {
    final avg =
        (tableHeadlineScale * 0.55 + titleScale * 0.3 + itemTextScale * 0.15);
    return ((avg - 1.0).clamp(0.0, 1.0)) * maxBoost;
  }

  @override
  List<Object?> get props => [
        density,
        tableHeadlineScale,
        titleScale,
        itemTextScale,
        showTableOnTop,
      ];
}
