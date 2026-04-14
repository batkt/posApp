import 'package:flutter/material.dart';

import '../payment/pos_payment_core.dart';

/// Checkout UI: payment method labels and icons only (totals come from the sale).
abstract final class PaymentDisplayConfig {
  PaymentDisplayConfig._();

  static double get vatRate => PosPaymentCore.vatRate;

  static const List<PaymentDisplayMethodOption> checkoutMethods = [
    PaymentDisplayMethodOption(
      id: PosPaymentCore.methodCash,
      label: 'Cash',
      labelMn: 'Бэлэн мөнгө',
      icon: Icons.payments_outlined,
    ),
    PaymentDisplayMethodOption(
      id: PosPaymentCore.methodCard,
      label: 'Card',
      labelMn: 'Карт',
      icon: Icons.credit_card_outlined,
    ),
    PaymentDisplayMethodOption(
      id: PosPaymentCore.methodAccount,
      label: 'Account transfer',
      labelMn: 'Данс',
      icon: Icons.account_balance_outlined,
    ),
  ];

  static const String defaultCheckoutMethodId = PosPaymentCore.methodCash;

  static String generateLegacySaleId() => PosPaymentCore.generateLegacySaleId();

  static String generateOrderPreview() => PosPaymentCore.generateOrderPreview();

  static IconData iconForMethod(String id) {
    switch (id) {
      case PosPaymentCore.methodCash:
        return Icons.payments_outlined;
      case PosPaymentCore.methodCard:
        return Icons.credit_card_outlined;
      case PosPaymentCore.methodQpay:
        return Icons.qr_code_2_outlined;
      case PosPaymentCore.methodAccount:
        return Icons.account_balance_outlined;
      case PosPaymentCore.methodCredit:
        return Icons.schedule_outlined;
      case PosPaymentCore.methodMobile:
        return Icons.phone_android_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  static String labelEn(String id) {
    switch (id) {
      case PosPaymentCore.methodCash:
        return 'Cash';
      case PosPaymentCore.methodCard:
        return 'Card';
      case PosPaymentCore.methodQpay:
        return 'QPay';
      case PosPaymentCore.methodAccount:
        return 'Account transfer';
      case PosPaymentCore.methodCredit:
        return 'Credit / receivable';
      case PosPaymentCore.methodMobile:
        return 'Mobile Pay';
      default:
        return 'Other';
    }
  }

  static String labelMn(String id) {
    switch (id) {
      case PosPaymentCore.methodCash:
        return 'Бэлэн мөнгө';
      case PosPaymentCore.methodCard:
        return 'Карт';
      case PosPaymentCore.methodQpay:
        return 'QPay';
      case PosPaymentCore.methodAccount:
        return 'Дансаар';
      case PosPaymentCore.methodCredit:
        return 'Зээл';
      case PosPaymentCore.methodMobile:
        return 'Гар утас';
      default:
        return 'Бусад';
    }
  }
}

class PaymentDisplayMethodOption {
  const PaymentDisplayMethodOption({
    required this.id,
    required this.label,
    required this.labelMn,
    required this.icon,
  });

  final String id;
  final String label;
  final String labelMn;
  final IconData icon;
}
