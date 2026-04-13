import 'api_service.dart';
import '../models/category_model.dart';

class CategoryService {
  final ApiService _apiService;

  CategoryService({ApiService? apiService})
      : _apiService = apiService ?? posApiService;

  /// Fetch categories from BaraaniiAngilal endpoint
  /// API: GET /api/BaraaniiAngilal
  Future<CategoryResult> getCategories({
    String search = '',
    required String baiguullagiinId,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/BaraaniiAngilal',
        queryParams: {
          'query':
              '{\"\$or\":[{\"angilal\":{\"\$regex\":\"$search\",\"\$options\":\"i\"}},\"baiguullagiinId\":\"$baiguullagiinId\"]}',
          'order': '{"createdAt":-1}',
          'khuadasniiDugaar': page.toString(),
          'khuadasniiKhemjee': limit.toString(),
          'baiguullagiinId': baiguullagiinId,
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final categoriesList = response.data!['jagsaalt'] as List<dynamic>?;
        final categories = categoriesList
                ?.map((json) => Category.fromJson(json as Map<String, dynamic>))
                .toList() ??
            [];

        return CategoryResult.success(
          categories: categories,
          currentPage: response.data!['khuadasniiDugaar'] ?? page,
          totalItems: categories.length,
          totalPages: 1,
        );
      }

      return CategoryResult.failure(
        error: response.message ?? 'Failed to fetch categories',
      );
    } catch (e) {
      return CategoryResult.failure(error: e.toString());
    }
  }

  /// Get category by ID
  Future<Category?> getCategoryById(
    String id, {
    required String baiguullagiinId,
  }) async {
    try {
      final result = await getCategories(baiguullagiinId: baiguullagiinId);
      if (result.success) {
        return result.categories.firstWhere(
          (category) => category.id == id,
          orElse: () => throw Exception('Category not found'),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class CategoryResult {
  final bool success;
  final List<Category> categories;
  final int currentPage;
  final int totalItems;
  final int totalPages;
  final String? error;

  CategoryResult({
    required this.success,
    required this.categories,
    required this.currentPage,
    required this.totalItems,
    required this.totalPages,
    this.error,
  });

  factory CategoryResult.success({
    required List<Category> categories,
    required int currentPage,
    required int totalItems,
    required int totalPages,
  }) {
    return CategoryResult(
      success: true,
      categories: categories,
      currentPage: currentPage,
      totalItems: totalItems,
      totalPages: totalPages,
    );
  }

  factory CategoryResult.failure({required String error}) {
    return CategoryResult(
      success: false,
      categories: [],
      currentPage: 1,
      totalItems: 0,
      totalPages: 0,
      error: error,
    );
  }
}
