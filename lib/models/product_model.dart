import 'package:flutter/foundation.dart';
import 'cart_model.dart';
import '../services/product_service.dart';
import 'pos_session.dart';

class ProductModel extends ChangeNotifier {
  final List<Product> _products = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final ProductService _productService;
  bool _isLoading = false;
  String? _error;
  String? _baiguullagiinId;
  String? _salbariinId;

  ProductModel({
    ProductService? productService,
  }) : _productService = productService ?? ProductService();

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
      _loadProductsFromAPI();
    } else {
      _products.clear();
      _error = null;
      notifyListeners();
    }
  }

  Future<void> _loadProductsFromAPI() async {
    final org = _baiguullagiinId;
    final branch = _salbariinId;
    if (org == null ||
        org.isEmpty ||
        branch == null ||
        branch.isEmpty) {
      _products.clear();
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
        _products.clear();
        _products.addAll(productResult.products);
        _error = null;
      } else {
        _error = productResult.error;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProducts() async {
    await _loadProductsFromAPI();
  }

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<String> get categories {
    final names = <String>{};
    for (final p in _products) {
      final c = p.category.trim();
      if (c.isNotEmpty) names.add(c);
      final a = p.angilal?.trim();
      if (a != null && a.isNotEmpty) names.add(a);
    }
    final sorted = names.toList()..sort();
    return ['All', ...sorted];
  }

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  List<Product> get filteredProducts {
    final list = _products.where((product) {
      final showAll =
          _selectedCategory == 'All' || _selectedCategory == 'Бүгд';
      final matchesCategory = showAll ||
          product.category == _selectedCategory ||
          product.angilal == _selectedCategory ||
          (product.angilal?.contains(_selectedCategory) == true);
      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.code?.toLowerCase().contains(_searchQuery.toLowerCase()) ==
              true ||
          product.barCode?.toLowerCase().contains(_searchQuery.toLowerCase()) ==
              true;
      return matchesCategory && matchesSearch;
    }).toList();

    bool shelfActive(Product p) {
      final stock = p.uldegdel ?? p.stock;
      return p.isAvailable && stock > 0;
    }

    DateTime stamp(Product p) =>
        p.updatedAt ?? p.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    list.sort((a, b) {
      final aa = shelfActive(a);
      final ab = shelfActive(b);
      if (aa != ab) return aa ? -1 : 1;
      if (!aa) return stamp(b).compareTo(stamp(a));
      return a.name.compareTo(b.name);
    });
    return list;
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Product? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Product> getProductsByCategory(String category) {
    return _products.where((p) => p.category == category).toList();
  }
}
