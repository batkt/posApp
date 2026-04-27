import 'dart:convert';

import 'api_service.dart';
import '../models/category_model.dart';

const _khuudasniiDugaar = 'khuudasniiDugaar';
const _khuudasniiKhemjee = 'khuudasniiKhemjee';

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
      // Match web `BaraaniiAngilal` list: org filter; optional `angilal` search.
      // The old `$or` string was invalid JSON (second array item was not an object), so
      // the API often returned an empty `jagsaalt` and category-based тооллого could not start.
      final s = search.trim();
      final query = <String, dynamic>{
        'baiguullagiinId': baiguullagiinId,
        if (s.isNotEmpty) 'angilal': {r'$regex': s, r'$options': 'i'},
      };
      final response = await _apiService.get<Map<String, dynamic>>(
        '/BaraaniiAngilal',
        queryParams: {
          'query': jsonEncode(query),
          'order': jsonEncode({r'createdAt': -1}),
          _khuudasniiDugaar: page.toString(),
          _khuudasniiKhemjee: limit.toString(),
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
          currentPage: response.data![_khuudasniiDugaar] ??
              response.data!['khuadasniiDugaar'] ??
              page,
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
