import 'package:flutter/foundation.dart';

import '../data/payment_display_config.dart';
import '../payment/pos_payment_core.dart';
import '../utils/buunii_une_helper.dart';
import 'cart_model.dart';
import 'customer_model.dart';
import 'inventory_model.dart';

class SaleItem {
  final Product product;
  int quantity;
  double unitPrice;

  /// Жижиглэнгийн нэгж үнэ (эхний оруулалт / гараар өөрчилсөн суурь).
  final double retailUnitPrice;

  /// `POST /guilgeeniiTuukhKhadgalya` → `baraa.uramshuulaliinId` (сонгосон урамшуулал).
  String? uramshuulaliinId;

  /// Үнэ гараар тохируулсан эсвэл бөөний тiers-ээс гадуурх нэгж үнэ — тоо өөрчлөхөд автомат бөөнөөр дахин тооцохгүй.
  bool forceRetailPricing;

  /// Хайрцагтай бараа: задлаж зарсан **нийт ширхэг** (вэб `zadlakhToo`). Хоосон бол
  /// `quantity` хайрцаг × [Product.negKhairtsaganDahiShirhegiinToo].
  double? boxPiecesSold;

  SaleItem({
    required this.product,
    required this.unitPrice,
    required this.retailUnitPrice,
    this.quantity = 1,
    this.uramshuulaliinId,
    this.forceRetailPricing = false,
    this.boxPiecesSold,
  });

  double get _negPerBox {
    final n = product.negKhairtsaganDahiShirhegiinToo ?? 1;
    return n < 1 ? 1.0 : n.toDouble();
  }

  /// Нэг хайрцаг дахь ширхэг (хайрцагтай бараанд).
  double get negPerBox => _negPerBox;

  /// Нийт ширхэг (хайрцагтайд задлах эсвэл энгийн бараанд `quantity`).
  double get effectivePieces {
    if (product.isBoxSaleUnit) {
      return boxPiecesSold ?? (quantity * _negPerBox);
    }
    return quantity.toDouble();
  }

  /// API `too`: хайрцагтайд хайрцгийн тоо (дробь зөвшөөрнө), бусадад `quantity`.
  double get apiTooUnits {
    if (product.isBoxSaleUnit) {
      return effectivePieces / _negPerBox;
    }
    return quantity.toDouble();
  }

  double get total {
    if (product.isBoxSaleUnit) {
      final perPiece = unitPrice / _negPerBox;
      return perPiece * effectivePieces;
    }
    return unitPrice * quantity;
  }

  SaleItem copyWith({
    Product? product,
    int? quantity,
    double? unitPrice,
    double? retailUnitPrice,
    String? uramshuulaliinId,
    bool? forceRetailPricing,
    double? boxPiecesSold,
  }) {
    return SaleItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      retailUnitPrice: retailUnitPrice ?? this.retailUnitPrice,
      uramshuulaliinId: uramshuulaliinId ?? this.uramshuulaliinId,
      forceRetailPricing: forceRetailPricing ?? this.forceRetailPricing,
      boxPiecesSold: boxPiecesSold ?? this.boxPiecesSold,
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
  /// НХАТ (MNT). With web-parity cashier totals this is summed from line splits, not typed in.
  final double nhhat;

  /// НӨАТ-гүй дүн (суурь), web `noatguiDun` aggregate — thermal slip breakdown.
  final double noatguiSum;

  /// Staff snapshot from `guilgeeniiTuukh` / local completion (if available).
  final Map<String, dynamic>? ajiltan;

  /// From `guilgee.ebarimtAvsanEsekh` when loaded from POS API.
  final bool ebarimtAvsan;

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
    this.noatguiSum = 0,
    this.ajiltan,
    this.ebarimtAvsan = false,
  });

  double get netSubtotal => (subtotal - discount).clamp(0.0, double.infinity);
}

class SalesModel extends ChangeNotifier {
  final List<SaleItem> _currentSale = [];
  final List<CompletedSale> _salesHistory = [];
  Customer? _selectedCustomer;

  Customer? get selectedCustomer => _selectedCustomer;

  void setSelectedCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  /// Matches web POS `guilgeeniiDugaar` from `POST /zakhialgiinDugaarAvya`.
  String? _guilgeeniiDugaar;
  String? get guilgeeniiDugaar => _guilgeeniiDugaar;

  void setGuilgeeniiDugaar(String? value) {
    _guilgeeniiDugaar = value;
    notifyListeners();
  }

  /// Incremented when the user leaves the receipt screen to start a new sale so
  /// mobile cashier [POSScreen] can jump the PageView back to the product grid.
  int _cashierReturnToProductsEpoch = 0;
  int get cashierReturnToProductsEpoch => _cashierReturnToProductsEpoch;

  void signalCashierReturnToProductsAfterReceipt() {
    _cashierReturnToProductsEpoch++;
    notifyListeners();
  }

  // Current Sale getters
  List<SaleItem> get currentSaleItems => List.unmodifiable(_currentSale);
  bool get isSaleEmpty => _currentSale.isEmpty;
  int get saleItemCount => _currentSale.fold(0, (sum, item) => sum + item.quantity);

  /// Нийт ширхэгийн ойролцоо (хайрцагтай мөрүүдэд задласан ширхэг).
  int get salePieceCountApprox => _currentSale.fold(
        0,
        (sum, item) =>
            sum +
            (item.product.isBoxSaleUnit
                ? item.effectivePieces.round()
                : item.quantity),
      );

  /// Distinct бараа (төрөл), not raw row count — same бараа may appear as separate
  /// [SaleItem] rows; [currentSaleItems] stays separate for receipt / API lines.
  int get uniqueSaleItems {
    final keys = <String>{};
    for (final item in _currentSale) {
      keys.add(_distinctProductKey(item.product));
    }
    return keys.length;
  }

  static String _distinctProductKey(Product p) {
    final id = p.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    final c = (p.code ?? '').toString().trim();
    final s = (p.salbariinId ?? '').toString().trim();
    return 'code:$c|$s';
  }

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
  void _reapplyWholesaleForIndex(int index) {
    if (index < 0 || index >= _currentSale.length) return;
    final line = _currentSale[index];
    if (line.forceRetailPricing) return;
    if (line.product.buuniiUneEsekh != true ||
        line.product.buuniiUneJagsaalt.isEmpty) {
      line.unitPrice = line.retailUnitPrice;
      return;
    }
    final tierQty = line.product.isBoxSaleUnit
        ? line.apiTooUnits
        : line.quantity.toDouble();
    final tier = BuuniiUneHelper.resolveUnitPrice(
      qty: tierQty,
      buuniiUneJagsaalt: line.product.buuniiUneJagsaalt,
      retailUnit: line.retailUnitPrice,
    );
    line.unitPrice = tier ?? line.retailUnitPrice;
  }

  void addToSale(Product product, {double? customPrice}) {
    final retail = customPrice ?? product.price;
    final existingIndex =
        _currentSale.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      final line = _currentSale[existingIndex];
      line.boxPiecesSold = null;
      line.quantity++;
      _reapplyWholesaleForIndex(existingIndex);
    } else {
      _currentSale.add(SaleItem(
        product: product,
        unitPrice: retail,
        retailUnitPrice: retail,
      ));
      _reapplyWholesaleForIndex(_currentSale.length - 1);
    }
    notifyListeners();
  }

  /// Бөөний түвшингийн нэгж үнэ (гарын авлага) — дараагийн тоо өөрчлөлтөд tier дахин тооцохгүй.
  void applyWholesaleTierUnit(String productId, double tierUnitPrice) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].unitPrice = tierUnitPrice;
    _currentSale[i].forceRetailPricing = true;
    notifyListeners();
  }

  void applyRetailUnitForLine(String productId) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].unitPrice = _currentSale[i].retailUnitPrice;
    _currentSale[i].forceRetailPricing = true;
    notifyListeners();
  }

  /// Тоо ширхэгээр бөөний tier автоматаар (вэб `buuniiUneAvakh`).
  void useAutomaticWholesaleForProduct(String productId) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].forceRetailPricing = false;
    _reapplyWholesaleForIndex(i);
    notifyListeners();
  }

  void setLineUramshuulal(String productId, String? uramshuulaliinId) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].uramshuulaliinId = uramshuulaliinId;
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
      _currentSale[index].boxPiecesSold = null;
      _currentSale[index].quantity = quantity;
      _reapplyWholesaleForIndex(index);
      notifyListeners();
    }
  }

  void incrementSaleQuantity(String productId) {
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      final line = _currentSale[index];
      line.boxPiecesSold = null;
      line.quantity++;
      _reapplyWholesaleForIndex(index);
      notifyListeners();
    }
  }

  void decrementSaleQuantity(String productId) {
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (_currentSale[index].quantity > 1) {
        final line = _currentSale[index];
        line.boxPiecesSold = null;
        line.quantity--;
        _reapplyWholesaleForIndex(index);
        notifyListeners();
      } else {
        removeFromSale(productId);
      }
    }
  }

  /// Хайрцагтай мөр: задлах ширхэг (вэб `khemjikhNegjUurchlukh`). [pieces] нь агуулах дахь
  /// нийт ширхэгийн хязгаарт байх ёстой.
  void setBoxLinePieces(
    String productId,
    double pieces, {
    InventoryModel? inventory,
  }) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    final line = _currentSale[i];
    if (!line.product.isBoxSaleUnit) return;
    final neg = line.negPerBox;
    final maxPieces = (line.product.uldegdel ?? line.product.stock) * neg;
    final clamped = pieces.clamp(0.01, maxPieces);
    final newQty = (clamped / neg).ceil().clamp(1, 999999);
    final oldQty = line.quantity;
    line.boxPiecesSold = clamped;
    line.quantity = newQty;
    if (inventory != null && oldQty != newQty) {
      if (oldQty > newQty) {
        inventory.restock(productId, oldQty - newQty);
      } else {
        inventory.deductStock(productId, newQty - oldQty);
      }
    }
    _reapplyWholesaleForIndex(i);
    notifyListeners();
  }

  void clearBoxLinePiecesOverride(String productId) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].boxPiecesSold = null;
    _reapplyWholesaleForIndex(i);
    notifyListeners();
  }

  void updateSaleItemPrice(String productId, double newPrice) {
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _currentSale[index].unitPrice = newPrice;
      _currentSale[index].forceRetailPricing = true;
      notifyListeners();
    }
  }

  void clearSale() {
    _currentSale.clear();
    _guilgeeniiDugaar = null;
    _selectedCustomer = null;
    notifyListeners();
  }

  /// Replace cart with parked-sale lines and restore receipt number (web `huleelgeesHudaldahruuZakhialgaKhiiy`).
  void restoreParkedSale(
    List<SaleItem> lines, {
    required String guilgeeniiDugaar,
  }) {
    _currentSale
      ..clear()
      ..addAll(lines);
    _guilgeeniiDugaar = guilgeeniiDugaar;
    notifyListeners();
  }

  // Complete sale and add to history
  CompletedSale completeSale(
    String paymentMethod, {
    String? notes,
    String? orderId,
  }) {
    final std = PosPaymentCore.calculateStandardSaleTotals(subtotal);
    final sale = CompletedSale(
      id: orderId ?? PaymentDisplayConfig.generateLegacySaleId(),
      items: List.from(_currentSale),
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      timestamp: DateTime.now(),
      notes: notes,
      noatguiSum: std.net,
    );
    _salesHistory.add(sale);
    clearSale();
    return sale;
  }

  /// Cashier checkout: discount and НХАТ adjust totals; VAT (10%) on net subtotal.
  ///
  /// When [totalsSnapshot] is set (web-parity НӨАТ/НХАТ split), it is used instead of
  /// flat [calculateCashierTotals].
  CompletedSale completeCashierSale({
    required String paymentMethod,
    double discountMnt = 0,
    double nhhatMnt = 0,
    CashierTotals? totalsSnapshot,
    String? notes,
    String? orderId,
  }) {
    final t = totalsSnapshot ??
        PosPaymentCore.calculateCashierTotals(
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
      noatguiSum: t.net,
    );
    _salesHistory.add(sale);
    clearSale();
    return sale;
  }
}
