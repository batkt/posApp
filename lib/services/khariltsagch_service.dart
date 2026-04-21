import 'dart:convert';

import 'api_service.dart';

/// Fetches `/khariltsagch` from posBack (same query shape as Next.js).
class KhariltsagchService {
  KhariltsagchService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  /// [search] is applied as case-insensitive regex across ner, ovog, utas, mail, register.
  Future<KhariltsagchListResult> fetchList({
    required String baiguullagiinId,
    required String salbariinId,
    String search = '',
    int page = 1,
    int pageSize = 100,
  }) async {
    final q = search.trim();
    final pattern = RegExp.escape(q);

    final queryMap = <String, dynamic>{
      r'$or': [
        {'ner': {r'$regex': pattern, r'$options': 'i'}},
        {'ovog': {r'$regex': pattern, r'$options': 'i'}},
        {'utas': {r'$regex': pattern, r'$options': 'i'}},
        {'mail': {r'$regex': pattern, r'$options': 'i'}},
        {'register': {r'$regex': pattern, r'$options': 'i'}},
      ],
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
    };

    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/khariltsagch',
        queryParams: {
          'query': jsonEncode(queryMap),
          'order': jsonEncode({'createdAt': -1}),
          'khuudasniiDugaar': page.toString(),
          'khuudasniiKhemjee': pageSize.toString(),
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final raw = response.data!['jagsaalt'] as List<dynamic>?;
        return KhariltsagchListResult.ok(
          raw?.map((e) => e as Map<String, dynamic>).toList() ?? [],
        );
      }

      return KhariltsagchListResult.fail(
        response.message ?? 'Харилцагчдын жагсаалт ачаалахад алдаа',
      );
    } catch (e) {
      return KhariltsagchListResult.fail(e.toString());
    }
  }
}

class KhariltsagchListResult {
  KhariltsagchListResult._({
    required this.success,
    required this.rows,
    this.error,
  });

  final bool success;
  final List<Map<String, dynamic>> rows;
  final String? error;

  factory KhariltsagchListResult.ok(List<Map<String, dynamic>> rows) =>
      KhariltsagchListResult._(success: true, rows: rows);

  factory KhariltsagchListResult.fail(String message) =>
      KhariltsagchListResult._(success: false, rows: [], error: message);
}
