import 'package:flutter/foundation.dart';

import 'cart_model.dart';
import '../services/product_service.dart';
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

  bool get isLowStock => currentStock <= minStockLevel;
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

  InventoryModel({
    ProductService? productService,
  }) : _productService = productService ?? ProductService();

  /// Called from [ChangeNotifierProxyProvider] when [PosSession] changes after login.
  void syncSession(PosSession? session) {
    final org = session?.baiguullagiinId;
    final branch = session?.salbariinId;
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
              minStockLevel: 5,
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
      final matchesCategory = showAll ||
          item.product.angilal?.contains(_selectedCategory) == true ||
          item.product.category == _selectedCategory;
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
    final categories = _inventory
        .map((i) => i.product.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Бүгд', ...categories];
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

  void deleteProduct(String productId) {
    _inventory.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  InventoryItem? getInventoryItem(String productId) {
    try {
      return _inventory.firstWhere((item) => item.product.id == productId);
    } catch (_) {
      return null;
    }
  }
}
