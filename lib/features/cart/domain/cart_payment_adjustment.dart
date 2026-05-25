import 'package:equatable/equatable.dart';

/// Промокод / баллы для активного чека (без выбора печати чека).
class CartPaymentAdjustment extends Equatable {
  const CartPaymentAdjustment({
    required this.baseTotal,
    this.promoCode = '',
    this.promoDiscountAmount = 0,
    this.loyaltyDiscountAmount = 0,
    this.loyaltyCardNo = '',
    this.customerId,
  });

  final double baseTotal;
  final String promoCode;
  final double promoDiscountAmount;
  final double loyaltyDiscountAmount;
  final String loyaltyCardNo;
  final int? customerId;

  double get totalDiscount => promoDiscountAmount + loyaltyDiscountAmount;

  double get payableAmount =>
      (baseTotal - totalDiscount).clamp(0, double.infinity);

  bool get hasDiscount => totalDiscount > 0.009;

  @override
  List<Object?> get props => [
        baseTotal,
        promoCode,
        promoDiscountAmount,
        loyaltyDiscountAmount,
        loyaltyCardNo,
        customerId,
      ];
}
