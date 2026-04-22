import 'api_service.dart';
import '../models/cart_model.dart';

/// Matches zevback CRUD / posBack list handlers (`khuudasniiDugaar`, `khuudasniiKhemjee`).
const _khuudasniiDugaar = 'khuudasniiDugaar';
const _khuudasniiKhemjee = 'khuudasniiKhemjee';

class ProductService {
  final ApiService _apiService;

  ProductService({ApiService? apiService})
      : _apiService = apiService ?? posApiService;

  int _readPage(Map<String, dynamic> data, int fallback) {
    final v = data[_khuudasniiDugaar] ?? data['khuadasniiDugaar'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Fetch products from aguulakh endpoint
  /// API: GET /api/aguulakh
  Future<ProductResult> getProducts({
    String search = '',
    required String baiguullagiinId,
    required String salbariinId,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/aguulakh',
        queryParams: {
          // No `uldegdel` filter: show zero-stock items in POS (tap can still block sale).
          'query':
              '{\"\$or\":[{\"ner\":{\"\$regex\":\"$search\",\"\$options\":\"i\"}},{\"barCode\":{\"\$regex\":\"$search\",\"\$options\":\"i\"}},{\"code\":{\"\$regex\":\"$search\",\"\$options\":\"i\"}},{\"boginoNer\":{\"\$regex\":\"$search\",\"\$options\":\"i\"}}],\"idevkhteiEsekh\":{\"\$ne\":false},\"baiguullagiinId\":\"$baiguullagiinId\",\"salbariinId\":\"$salbariinId\"}',
          'order': '{"createdAt":-1}',
          _khuudasniiDugaar: page.toString(),
          _khuudasniiKhemjee: limit.toString(),
          'baiguullagiinId': baiguullagiinId,
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final productsList = response.data!['jagsaalt'] as List<dynamic>?;
        final products = productsList
                ?.map((json) => Product.fromJson(json as Map<String, dynamic>))
                .toList() ??
            [];

        final d = response.data!;
        final rawNiit = d['niitKhuudas'];
        int totalPages = 1;
        if (rawNiit is int) {
          totalPages = rawNiit < 1 ? 1 : rawNiit;
        } else if (rawNiit is num) {
          final n = rawNiit.toInt();
          totalPages = n < 1 ? 1 : n;
        }

        return ProductResult.success(
          products: products,
          currentPage: _readPage(d, page),
          totalItems: products.length,
          totalPages: totalPages,
        );
      }

      return ProductResult.failure(
        error: response.message ?? 'Failed to fetch products',
      );
    } catch (e) {
      return ProductResult.failure(error: e.toString());
    }
  }

  /// Loads every page from `/aguulakh` for this branch (POS catalog).
  ///
  /// Stops when the server returns an empty page, when `niitKhuudas` ([totalPages])
  /// says the last page was reached, or when a page adds no new rows (duplicate /
  /// capped responses). Does **not** stop on `jagsaalt.length < limit` alone, because
  /// the API may cap below our requested [pageSize] while still having more pages.
  Future<ProductResult> getAllProductsForBranch({
    String search = '',
    required String baiguullagiinId,
    required String salbariinId,
    int pageSize = 200,
    int maxPages = 100,
  }) async {
    final merged = <Product>[];
    final seen = <String>{};
    for (var page = 1; page <= maxPages; page++) {
      final beforeCount = merged.length;
      final batch = await getProducts(
        search: search,
        baiguullagiinId: baiguullagiinId,
        salbariinId: salbariinId,
        page: page,
        limit: pageSize,
      );
      if (!batch.success) {
        return merged.isEmpty
            ? batch
            : ProductResult.success(
                products: merged.toList(),
                currentPage: page - 1,
                totalItems: merged.length,
                totalPages: page - 1,
              );
      }
      for (final p in batch.products) {
        if (seen.add(p.id)) merged.add(p);
      }
      if (batch.products.isEmpty) break;
      final tp = batch.totalPages;
      if (tp > 1 && page >= tp) break;
      if (merged.length == beforeCount) break;
    }
    return ProductResult.success(
      products: merged,
      currentPage: 1,
      totalItems: merged.length,
      totalPages: 1,
    );
  }

  /// Get product by ID
  Future<Product?> getProductById(
    String id, {
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    const pageSize = 200;
    const maxPages = 100;
    final seenIds = <String>{};
    for (var page = 1; page <= maxPages; page++) {
      final result = await getProducts(
        baiguullagiinId: baiguullagiinId,
        salbariinId: salbariinId,
        page: page,
        limit: pageSize,
      );
      if (!result.success) return null;
      var newRows = 0;
      for (final p in result.products) {
        if (seenIds.add(p.id)) newRows++;
        if (p.id == id) return p;
      }
      if (result.products.isEmpty) break;
      final tp = result.totalPages;
      if (tp > 1 && page >= tp) break;
      if (newRows == 0) break;
    }
    return null;
  }

  /// Get products by category
  Future<ProductResult> getProductsByCategory(
    String category, {
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    try {
      final result = await getAllProductsForBranch(
        baiguullagiinId: baiguullagiinId,
        salbariinId: salbariinId,
      );
      if (result.success) {
        final filteredProducts = result.products
            .where((product) => product.angilal?.contains(category) ?? false)
            .toList();
        
        return ProductResult.success(
          products: filteredProducts,
          currentPage: 1,
          totalItems: filteredProducts.length,
          totalPages: 1,
        );
      }
      return ProductResult.failure(error: result.error ?? 'Failed to filter products');
    } catch (e) {
      return ProductResult.failure(error: e.toString());
    }
  }

  /// Search products
  Future<ProductResult> searchProducts(
    String query, {
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    return getAllProductsForBranch(
      search: query,
      baiguullagiinId: baiguullagiinId,
      salbariinId: salbariinId,
    );
  }
}

class ProductResult {
  final bool success;
  final List<Product> products;
  final int currentPage;
  final int totalItems;
  final int totalPages;
  final String? error;

  ProductResult({
    required this.success,
    required this.products,
    required this.currentPage,
    required this.totalItems,
    required this.totalPages,
    this.error,
  });

  factory ProductResult.success({
    required List<Product> products,
    required int currentPage,
    required int totalItems,
    required int totalPages,
  }) {
    return ProductResult(
      success: true,
      products: products,
      currentPage: currentPage,
      totalItems: totalItems,
      totalPages: totalPages,
    );
  }

  factory ProductResult.failure({required String error}) {
    return ProductResult(
      success: false,
      products: [],
      currentPage: 1,
      totalItems: 0,
      totalPages: 0,
      error: error,
    );
  }
}
