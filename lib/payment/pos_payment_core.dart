// Shared POS totals — keep in sync with pos/tools/logic/posPaymentCore.js where applicable.

class CashierTotals {
  const CashierTotals({
    required this.cappedDiscount,
    required this.net,
    required this.vat,
    required this.nhhat,
    required this.total,
  });

  final double cappedDiscount;
  final double net;
  final double vat;
  final double nhhat;
  final double total;
}

class StandardSaleTotals {
  const StandardSaleTotals({
    required this.subtotal,
    required this.vat,
    required this.total,
  });

  final double subtotal;
  final double vat;
  final double total;
}

abstract final class PosPaymentCore {
  PosPaymentCore._();

  static const double vatRate = 0.10;

  static const String methodCash = 'cash';
  static const String methodCard = 'card';
  static const String methodAccount = 'account';
  static const String methodCredit = 'credit';
  static const String methodMobile = 'mobile';

  static StandardSaleTotals calculateStandardSaleTotals(
    double subtotal, {
    double vatRate = PosPaymentCore.vatRate,
  }) {
    final s = subtotal;
    final vat = s * vatRate;
    return StandardSaleTotals(subtotal: s, vat: vat, total: s + vat);
  }

  static CashierTotals calculateCashierTotals({
    required double subtotal,
    double discountMnt = 0,
    double nhhatMnt = 0,
    double vatRate = PosPaymentCore.vatRate,
  }) {
    final cappedDiscount = discountMnt.clamp(0.0, subtotal).toDouble();
    final net = (subtotal - cappedDiscount).clamp(0.0, double.infinity);
    final vat = net * vatRate;
    final nh = nhhatMnt.clamp(0.0, double.infinity).toDouble();
    final total = net + vat + nh;
    return CashierTotals(
      cappedDiscount: cappedDiscount,
      net: net,
      vat: vat,
      nhhat: nh,
      total: total,
    );
  }

  static String generateOrderPreview() {
    final n = DateTime.now();
    final tail =
        (n.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'БД${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}$tail';
  }

  static String generateLegacySaleId() {
    return 'SALE-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }
}
