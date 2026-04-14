import 'package:flutter/foundation.dart';

import '../data/payment_display_config.dart';
import '../payment/pos_payment_core.dart';
import 'cart_model.dart';

class SaleItem {
  final Product product;
  int quantity;
  final double unitPrice;

  SaleItem({
    required this.product,
    required this.unitPrice,
    this.quantity = 1,
  });

  double get total => unitPrice * quantity;

  SaleItem copyWith({
    Product? product,
    int? quantity,
    double? unitPrice,
  }) {
    return SaleItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

class CompletedSale {
  final String id;
  final List<SaleItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final String paymentMethod;
  final DateTime timestamp;
  final String? notes;
  /// Хөнгөлөлт (MNT), applied before VAT.
  final double discount;
  /// НХАТ (MNT), added after VAT on net taxable amount.
  final double nhhat;

  /// Staff snapshot from `guilgeeniiTuukh` / local completion (if available).
  final Map<String, dynamic>? ajiltan;

  CompletedSale({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.timestamp,
    this.notes,
    this.discount = 0,
    this.nhhat = 0,
    this.ajiltan,
  });

  double get netSubtotal => (subtotal - discount).clamp(0.0, double.infinity);
}

class SalesModel extends ChangeNotifier {
  final List<SaleItem> _currentSale = [];
  final List<CompletedSale> _salesHistory = [];

  /// Matches web POS `guilgeeniiDugaar` from `POST /zakhialgiinDugaarAvya`.
  String? _guilgeeniiDugaar;
  String? get guilgeeniiDugaar => _guilgeeniiDugaar;

  void setGuilgeeniiDugaar(String? value) {
    _guilgeeniiDugaar = value;
    notifyListeners();
  }

  // Current Sale getters
  List<SaleItem> get currentSaleItems => List.unmodifiable(_currentSale);
  bool get isSaleEmpty => _currentSale.isEmpty;
  int get saleItemCount => _currentSale.fold(0, (sum, item) => sum + item.quantity);
  int get uniqueSaleItems => _currentSale.length;

  double get subtotal => _currentSale.fold(0, (sum, item) => sum + item.total);
  double get tax =>
      PosPaymentCore.calculateStandardSaleTotals(subtotal).vat;
  double get total =>
      PosPaymentCore.calculateStandardSaleTotals(subtotal).total;

  // Sales history getters
  List<CompletedSale> get salesHistory => List.unmodifiable(_salesHistory);

  double get todayRevenue {
    final today = DateTime.now();
    return _salesHistory
        .where((sale) =>
            sale.timestamp.year == today.year &&
            sale.timestamp.month == today.month &&
            sale.timestamp.day == today.day)
        .fold(0, (sum, sale) => sum + sale.total);
  }

  int get todayTransactions {
    final today = DateTime.now();
    return _salesHistory
        .where((sale) =>
            sale.timestamp.year == today.year &&
            sale.timestamp.month == today.month &&
            sale.timestamp.day == today.day)
        .length;
  }

  /// Sum of all completed sales kept in local history (this session / device).
  double get totalRecordedRevenue =>
      _salesHistory.fold(0.0, (sum, sale) => sum + sale.total);

  int get totalRecordedSaleCount => _salesHistory.length;

  // Current Sale methods
  void addToSale(Product product, {double? customPrice}) {
    final existingIndex = _currentSale.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _currentSale[existingIndex].quantity++;
    } else {
      _currentSale.add(SaleItem(
        product: product,
        unitPrice: customPrice ?? product.price,
      ));
    }
    notifyListeners();
  }

  void removeFromSale(String productId) {
    _currentSale.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateSaleQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromSale(productId);
      return;
    }
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _currentSale[index].quantity = quantity;
      notifyListeners();
    }
  }

  void incrementSaleQuantity(String productId) {
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _currentSale[index].quantity++;
      notifyListeners();
    }
  }

  void decrementSaleQuantity(String productId) {
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (_currentSale[index].quantity > 1) {
        _currentSale[index].quantity--;
        notifyListeners();
      } else {
        removeFromSale(productId);
      }
    }
  }

  void updateSaleItemPrice(String productId, double newPrice) {
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _currentSale[index] = _currentSale[index].copyWith(unitPrice: newPrice);
      notifyListeners();
    }
  }

  void clearSale() {
    _currentSale.clear();
    _guilgeeniiDugaar = null;
    notifyListeners();
  }

  // Complete sale and add to history
  CompletedSale completeSale(
    String paymentMethod, {
    String? notes,
    String? orderId,
  }) {
    final sale = CompletedSale(
      id: orderId ?? PaymentDisplayConfig.generateLegacySaleId(),
      items: List.from(_currentSale),
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      timestamp: DateTime.now(),
      notes: notes,
    );
    _salesHistory.add(sale);
    clearSale();
    return sale;
  }

  /// Cashier checkout: discount and НХАТ adjust totals; VAT (10%) on net subtotal.
  CompletedSale completeCashierSale({
    required String paymentMethod,
    double discountMnt = 0,
    double nhhatMnt = 0,
    String? notes,
    String? orderId,
  }) {
    final t = PosPaymentCore.calculateCashierTotals(
      subtotal: subtotal,
      discountMnt: discountMnt,
      nhhatMnt: nhhatMnt,
    );
    final now = DateTime.now();
    final resolvedOrderId = orderId ?? PaymentDisplayConfig.generateOrderPreview();

    final sale = CompletedSale(
      id: resolvedOrderId,
      items: List.from(_currentSale),
      subtotal: subtotal,
      tax: t.vat,
      total: t.total,
      paymentMethod: paymentMethod,
      timestamp: now,
      notes: notes,
      discount: t.cappedDiscount,
      nhhat: t.nhhat,
    );
    _salesHistory.add(sale);
    clearSale();
    return sale;
  }
}
