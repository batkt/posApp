import 'package:flutter/foundation.dart';
import 'cart_model.dart';

enum PaymentMethod { cash, card, transfer, credit, mixed }

enum TransactionStatus { pending, completed, cancelled, refunded }

class TransactionItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double discount;
  final String? unit;

  const TransactionItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0.0,
    this.unit,
  });

  double get subtotal => unitPrice * quantity;
  double get total => subtotal - discount;
}

class Transaction {
  final String id;
  final String receiptNumber;
  final DateTime timestamp;
  final List<TransactionItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final PaymentMethod paymentMethod;
  final double? cashReceived;
  final double? change;
  final String? customerId;
  final String? customerName;
  final String cashierId;
  final String cashierName;
  final TransactionStatus status;
  final String? eBarimtId;
  final String? notes;
  final String? branchId;

  const Transaction({
    required this.id,
    required this.receiptNumber,
    required this.timestamp,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    this.cashReceived,
    this.change,
    this.customerId,
    this.customerName,
    required this.cashierId,
    required this.cashierName,
    this.status = TransactionStatus.completed,
    this.eBarimtId,
    this.notes,
    this.branchId,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return 'Бэлэн төлөлт';
      case PaymentMethod.card:
        return 'Карт';
      case PaymentMethod.transfer:
        return 'Шилжүүлэг';
      case PaymentMethod.credit:
        return 'Зээл';
      case PaymentMethod.mixed:
        return 'Холимог';
    }
  }
}

class TransactionModel extends ChangeNotifier {
  final List<Transaction> _transactions = [];

  List<Transaction> get transactions => List.unmodifiable(_transactions);

  List<Transaction> get todayTransactions {
    final today = DateTime.now();
    return _transactions.where((t) {
      return t.timestamp.year == today.year &&
          t.timestamp.month == today.month &&
          t.timestamp.day == today.day;
    }).toList();
  }

  double get todaySales {
    return todayTransactions
        .where((t) => t.status == TransactionStatus.completed)
        .fold(0, (sum, t) => sum + t.total);
  }

  int get todayTransactionCount => todayTransactions.length;

  void addTransaction(Transaction transaction) {
    _transactions.insert(0, transaction);
    notifyListeners();
  }

  Transaction? getTransactionById(String id) {
    try {
      return _transactions.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Transaction> getTransactionsByDate(DateTime date) {
    return _transactions.where((t) {
      return t.timestamp.year == date.year &&
          t.timestamp.month == date.month &&
          t.timestamp.day == date.day;
    }).toList();
  }

  List<Transaction> getTransactionsByCustomer(String customerId) {
    return _transactions.where((t) => t.customerId == customerId).toList();
  }

  String generateReceiptNumber() {
    final now = DateTime.now();
    final prefix = 'REC';
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final count = (_transactions.length + 1).toString().padLeft(4, '0');
    return '$prefix$timestamp$count';
  }

  Transaction createFromCart({
    required CartModel cart,
    required PaymentMethod paymentMethod,
    required String cashierId,
    required String cashierName,
    String? customerId,
    String? customerName,
    double? cashReceived,
    double? discount,
  }) {
    final items = cart.items.map((cartItem) {
      return TransactionItem(
        productId: cartItem.product.id,
        productName: cartItem.product.name,
        unitPrice: cartItem.product.price,
        quantity: cartItem.quantity,
        discount: 0.0,
      );
    }).toList();

    final transactionDiscount = discount ?? 0.0;
    final subtotal = cart.subtotal - transactionDiscount;
    final tax = subtotal * 0.10;
    final total = subtotal + tax;

    double? change;
    if (paymentMethod == PaymentMethod.cash && cashReceived != null) {
      change = cashReceived - total;
    }

    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      receiptNumber: generateReceiptNumber(),
      timestamp: DateTime.now(),
      items: items,
      subtotal: cart.subtotal,
      discount: transactionDiscount,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      cashReceived: cashReceived,
      change: change,
      customerId: customerId,
      customerName: customerName,
      cashierId: cashierId,
      cashierName: cashierName,
      status: TransactionStatus.completed,
    );
  }
}
