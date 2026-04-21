import 'api_service.dart';

/// Loads organization (байгууллага) for branch resolution when staff has no [salbaruud].
class BaiguullagaService {
  BaiguullagaService({ApiService? apiService})
      : _api = apiService ?? posApiService;

  final ApiService _api;

  /// First салбар `_id` on the org document (`baiguullaga.salbaruud[0]`).
  /// Used when logged-in [ajiltan] has empty `salbaruud` but POS still needs a branch for `/aguulakh`.
  Future<String?> fetchFirstSalbariinId(String baiguullagiinId) async {
    final oid = baiguullagiinId.trim();
    if (oid.isEmpty) return null;
    try {
      final response = await _api.get<dynamic>(
        '/baiguullaga/$oid',
        parser: (data) => data,
      );
      if (!response.success || response.data == null) return null;
      dynamic doc = response.data;
      if (doc is Map && doc['data'] is Map) {
        doc = doc['data'];
      }
      if (doc is! Map) return null;
      final m = Map<String, dynamic>.from(doc);
      final sal = m['salbaruud'];
      if (sal is! List || sal.isEmpty) return null;
      final first = sal.first;
      if (first is Map) {
        return first['_id']?.toString();
      }
      if (first is String) return first;
    } catch (_) {}
    return null;
  }
}
