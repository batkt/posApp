import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cart_model.dart';
import '../services/product_service.dart';
import '../services/socket_service.dart';
import 'pos_session.dart';

class InventoryItem {
  final Product product;
  int currentStock;
  int minStockLevel;
  int? reorderPoint;
  String? supplier;
  double? costPrice;
  DateTime? lastRestocked;

  InventoryItem({
    required this.product,
    required this.currentStock,
    this.minStockLevel = 10,
    this.reorderPoint,
    this.supplier,
    this.costPrice,
    this.lastRestocked,
  });

  /// Цөөн үлдсэн: үлдэгдэл 1…[minStockLevel] (жишээ нь 1–10 нь `minStockLevel == 10` үед).
  /// 0 үлдэгдэлтэй барааг энд оруулахгүй — тэдгээр нь [isOutOfStock].
  bool get isLowStock =>
      currentStock > 0 &&
      minStockLevel > 0 &&
      currentStock <= minStockLevel;

  bool get isOutOfStock => currentStock <= 0;

  double get stockValue => (costPrice ?? product.price * 0.6) * currentStock;

  InventoryItem copyWith({
    Product? product,
    int? currentStock,
    int? minStockLevel,
    int? reorderPoint,
    String? supplier,
    double? costPrice,
    DateTime? lastRestocked,
  }) {
    return InventoryItem(
      product: product ?? this.product,
      currentStock: currentStock ?? this.currentStock,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      supplier: supplier ?? this.supplier,
      costPrice: costPrice ?? this.costPrice,
      lastRestocked: lastRestocked ?? this.lastRestocked,
    );
  }
}

class InventoryModel extends ChangeNotifier {
  final List<InventoryItem> _inventory = [];
  String _searchQuery = '';
  String _selectedCategory = 'Бүгд';
  final ProductService _productService;
  bool _isLoading = false;
  String? _error;
  String? _baiguullagiinId;
  String? _salbariinId;
  StreamSubscription<void>? _uldegdelSub;
  String? _socketBranchKey;

  InventoryModel({
    ProductService? productService,
  }) : _productService = productService ?? ProductService();

  /// Called from [ChangeNotifierProxyProvider] when [PosSession] changes after login.
  void syncSession(PosSession? session) {
    final org = session?.baiguullagiinId;
    final branch = session?.salbariinId;

    SocketService.instance.syncPosSession(session);

    final branchKey =
        (org != null && branch != null && org.isNotEmpty && branch.isNotEmpty)
            ? '$org|$branch'
            : null;
    if (branchKey != _socketBranchKey) {
      _socketBranchKey = branchKey;
      _uldegdelSub?.cancel();
      _uldegdelSub = null;
      if (branchKey != null) {
        _uldegdelSub =
            SocketService.instance.uldegdelChanged.listen((_) {
          unawaited(_loadInventoryFromAPI());
        });
      }
    }

    if (org == _baiguullagiinId && branch == _salbariinId) {
      return;
    }
    _baiguullagiinId = org;
    _salbariinId = branch;
    if (org != null &&
        org.isNotEmpty &&
        branch != null &&
        branch.isNotEmpty) {
      _loadInventoryFromAPI();
    } else {
      _inventory.clear();
      _error = null;
      notifyListeners();
    }
  }

  Future<void> _loadInventoryFromAPI() async {
    final org = _baiguullagiinId;
    final branch = _salbariinId;
    if (org == null ||
        org.isEmpty ||
        branch == null ||
        branch.isEmpty) {
      _inventory.clear();
      _error = 'Салбарын мэдээлэл байхгүй';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final productResult = await _productService.getAllProductsForBranch(
        baiguullagiinId: org,
        salbariinId: branch,
      );

      if (productResult.success) {
        _inventory.clear();
        _inventory.addAll(productResult.products.map((product) => InventoryItem(
              product: product,
              currentStock: product.uldegdel ?? product.stock,
              minStockLevel: 10,
              costPrice: product.urtugUne,
              lastRestocked: product.createdAt,
            )));
        _error = null;
      } else {
        _inventory.clear();
        _error = productResult.error ?? 'Бараа ачаалахад алдаа';
      }
    } catch (e) {
      _inventory.clear();
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshInventory() async {
    await _loadInventoryFromAPI();
  }

  List<InventoryItem> get inventory => List.unmodifiable(_inventory);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<InventoryItem> get filteredInventory {
    final showAll =
        _selectedCategory == 'Бүгд' || _selectedCategory == 'All';
    return _inventory.where((item) {
      final p = item.product;
      final matchesCategory = showAll ||
          p.category == _selectedCategory ||
          p.angilal == _selectedCategory ||
          (p.angilal?.contains(_selectedCategory) == true);
      final matchesSearch = _searchQuery.isEmpty ||
          item.product.name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          item.product.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.product.code
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ==
              true ||
          item.product.barCode
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ==
              true;
      return matchesCategory && matchesSearch;
    }).toList();
  }

  List<InventoryItem> get lowStockItems {
    return _inventory.where((item) => item.isLowStock).toList();
  }

  List<InventoryItem> get outOfStockItems {
    return _inventory.where((item) => item.isOutOfStock).toList();
  }

  List<String> get categories {
    final names = <String>{};
    for (final i in _inventory) {
      final c = i.product.category.trim();
      if (c.isNotEmpty) names.add(c);
      final a = i.product.angilal?.trim();
      if (a != null && a.isNotEmpty) names.add(a);
    }
    final sorted = names.toList()..sort();
    return ['Бүгд', ...sorted];
  }

  /// Out-of-stock rows for the current branch, newest first; optional category + name/code search.
  List<InventoryItem> outOfStockItemsFiltered({
    required String category,
    required String searchQuery,
  }) {
    final showAll = category == 'Бүгд' || category == 'All';
    final q = searchQuery.trim().toLowerCase();

    bool matchesCategory(InventoryItem item) {
      if (showAll) return true;
      final p = item.product;
      return p.category == category ||
          p.angilal == category ||
          (p.angilal?.contains(category) == true);
    }

    bool matchesSearch(InventoryItem item) {
      if (q.isEmpty) return true;
      final p = item.product;
      return p.name.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          (p.code?.toLowerCase().contains(q) == true) ||
          (p.barCode?.toLowerCase().contains(q) == true);
    }

    final list = _inventory
        .where((i) => i.isOutOfStock)
        .where(matchesCategory)
        .where(matchesSearch)
        .toList();

    int sortKey(InventoryItem i) {
      final t = i.product.createdAt ??
          i.product.updatedAt ??
          i.lastRestocked ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return t.millisecondsSinceEpoch;
    }

    list.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
    return list;
  }

  /// Low-stock rows for the current branch, newest first; optional category + name/code search.
  List<InventoryItem> lowStockItemsFiltered({
    required String category,
    required String searchQuery,
  }) {
    final showAll = category == 'Бүгд' || category == 'All';
    final q = searchQuery.trim().toLowerCase();

    bool matchesCategory(InventoryItem item) {
      if (showAll) return true;
      final p = item.product;
      return p.category == category ||
          p.angilal == category ||
          (p.angilal?.contains(category) == true);
    }

    bool matchesSearch(InventoryItem item) {
      if (q.isEmpty) return true;
      final p = item.product;
      return p.name.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          (p.code?.toLowerCase().contains(q) == true) ||
          (p.barCode?.toLowerCase().contains(q) == true);
    }

    final list = _inventory
        .where((i) => i.isLowStock)
        .where(matchesCategory)
        .where(matchesSearch)
        .toList();

    int sortKey(InventoryItem i) {
      final t = i.product.createdAt ??
          i.product.updatedAt ??
          i.lastRestocked ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return t.millisecondsSinceEpoch;
    }

    list.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
    return list;
  }

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  int get totalStockCount =>
      _inventory.fold(0, (sum, item) => sum + item.currentStock);
  double get totalInventoryValue =>
      _inventory.fold(0, (sum, item) => sum + item.stockValue);
  int get lowStockCount => lowStockItems.length;

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void addProduct(Product product,
      {int initialStock = 0, double? costPrice, int? minStockLevel}) {
    final existingIndex =
        _inventory.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _inventory[existingIndex] = _inventory[existingIndex].copyWith(
        currentStock: _inventory[existingIndex].currentStock + initialStock,
        costPrice: costPrice ?? _inventory[existingIndex].costPrice,
        minStockLevel: minStockLevel ?? _inventory[existingIndex].minStockLevel,
        lastRestocked: DateTime.now(),
      );
    } else {
      _inventory.add(InventoryItem(
        product: product,
        currentStock: initialStock,
        costPrice: costPrice,
        minStockLevel: minStockLevel ?? 10,
        lastRestocked: initialStock > 0 ? DateTime.now() : null,
      ));
    }
    notifyListeners();
  }

  void updateStock(String productId, int newStock) {
    final index = _inventory.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _inventory[index] = _inventory[index].copyWith(
        currentStock: newStock,
        lastRestocked: newStock > _inventory[index].currentStock
            ? DateTime.now()
            : _inventory[index].lastRestocked,
      );
      notifyListeners();
    }
  }

  void restock(String productId, int amount) {
    final index = _inventory.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _inventory[index] = _inventory[index].copyWith(
        currentStock: _inventory[index].currentStock + amount,
        lastRestocked: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void deductStock(String productId, int amount) {
    final index = _inventory.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      final newStock =
          (_inventory[index].currentStock - amount).clamp(0, 999999);
      _inventory[index] = _inventory[index].copyWith(currentStock: newStock);
      notifyListeners();
    }
  }

  void updateProduct(Product updatedProduct) {
    final index =
        _inventory.indexWhere((item) => item.product.id == updatedProduct.id);
    if (index >= 0) {
      _inventory[index] = _inventory[index].copyWith(product: updatedProduct);
      notifyListeners();
    }
  }

  Future<({bool success, String? error})> deleteProduct(String productId) async {
    final result = await _productService.deleteAguulakh(productId);
    if (result.success) {
      _inventory.removeWhere((item) => item.product.id == productId);
      notifyListeners();
    }
    return result;
  }

  InventoryItem? getInventoryItem(String productId) {
    try {
      return _inventory.firstWhere((item) => item.product.id == productId);
    } catch (_) {
      return null;
    }
  }
}
