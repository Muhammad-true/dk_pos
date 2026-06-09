import 'package:equatable/equatable.dart';

/// Размер строки позиции в корзине кассы.
enum PosCartLineSize {
  compact,
  normal,
  spacious;

  String get label => switch (this) {
        PosCartLineSize.compact => 'Компакт',
        PosCartLineSize.normal => 'Обычный',
        PosCartLineSize.spacious => 'Крупный',
      };

  String get storageValue => name;
}

PosCartLineSize parsePosCartLineSize(String? raw) {
  return switch (raw) {
    'compact' => PosCartLineSize.compact,
    'spacious' => PosCartLineSize.spacious,
    _ => PosCartLineSize.normal,
  };
}

/// Размер нижней панели: тип заказа, итог, кнопки.
enum PosCartFooterSize {
  compact,
  normal,
  spacious;

  String get label => switch (this) {
        PosCartFooterSize.compact => 'Компакт',
        PosCartFooterSize.normal => 'Обычный',
        PosCartFooterSize.spacious => 'Крупный',
      };

  String get storageValue => name;
}

PosCartFooterSize parsePosCartFooterSize(String? raw) {
  return switch (raw) {
    'compact' => PosCartFooterSize.compact,
    'spacious' => PosCartFooterSize.spacious,
    _ => PosCartFooterSize.normal,
  };
}

class PosCartPanelSettings extends Equatable {
  const PosCartPanelSettings({
    required this.lineSize,
    required this.footerSize,
  });

  final PosCartLineSize lineSize;
  final PosCartFooterSize footerSize;

  static const defaults = PosCartPanelSettings(
    lineSize: PosCartLineSize.normal,
    footerSize: PosCartFooterSize.normal,
  );

  PosCartPanelSettings copyWith({
    PosCartLineSize? lineSize,
    PosCartFooterSize? footerSize,
  }) {
    return PosCartPanelSettings(
      lineSize: lineSize ?? this.lineSize,
      footerSize: footerSize ?? this.footerSize,
    );
  }

  double get lineCardMargin => switch (lineSize) {
        PosCartLineSize.compact => 5,
        PosCartLineSize.normal => 7,
        PosCartLineSize.spacious => 10,
      };

  double get linePaddingV => switch (lineSize) {
        PosCartLineSize.compact => 7,
        PosCartLineSize.normal => 9,
        PosCartLineSize.spacious => 12,
      };

  double get qtyBadgeSize => switch (lineSize) {
        PosCartLineSize.compact => 30,
        PosCartLineSize.normal => 34,
        PosCartLineSize.spacious => 40,
      };

  double get orderTypeRowHeight => switch (footerSize) {
        PosCartFooterSize.compact => 40,
        PosCartFooterSize.normal => 44,
        PosCartFooterSize.spacious => 52,
      };

  double get actionRowHeight => switch (footerSize) {
        PosCartFooterSize.compact => 40,
        PosCartFooterSize.normal => 44,
        PosCartFooterSize.spacious => 52,
      };

  double get sectionGap => switch (footerSize) {
        PosCartFooterSize.compact => 6,
        PosCartFooterSize.normal => 8,
        PosCartFooterSize.spacious => 10,
      };

  @override
  List<Object?> get props => [lineSize, footerSize];
}
