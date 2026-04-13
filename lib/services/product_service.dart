import 'api_service.dart';
import '../models/cart_model.dart';

class ProductService {
  final ApiService _apiService;

  ProductService({ApiService? apiService})
      : _apiService = apiService ?? posApiService;

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
          'query': '{\"\$or\":[{\"ner\":{\"\$regex\":\"$search\",\"\$options\":\"i\"}},{\"barCode\":{\"\$regex\":\"$search\",\"\$options\":\"i\"}},{\"code\":{\"\$regex\":\"$search\",\"\$options\":\"i\"}},{\"boginoNer\":{\"\$regex\":\"$search\",\"\$options\":\"i\"}}],\"uldegdel\":{\"\$gt\":0},\"idevkhteiEsekh\":{\"\$ne\":false},\"baiguullagiinId\":\"$baiguullagiinId\",\"salbariinId\":\"$salbariinId\"}',
          'order': '{"createdAt":-1}',
          'khuadasniiDugaar': page.toString(),
          'khuadasniiKhemjee': limit.toString(),
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

        return ProductResult.success(
          products: products,
          currentPage: response.data!['khuadasniiDugaar'] ?? page,
          totalItems: products.length,
          totalPages: 1,
        );
      }

      return ProductResult.failure(
        error: response.message ?? 'Failed to fetch products',
      );
    } catch (e) {
      return ProductResult.failure(error: e.toString());
    }
  }

  /// Get product by ID
  Future<Product?> getProductById(
    String id, {
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    try {
      final result = await getProducts(
        baiguullagiinId: baiguullagiinId,
        salbariinId: salbariinId,
      );
      if (result.success) {
        return result.products.firstWhere(
          (product) => product.id == id,
          orElse: () => throw Exception('Product not found'),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get products by category
  Future<ProductResult> getProductsByCategory(
    String category, {
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    try {
      final result = await getProducts(
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
    return getProducts(
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
