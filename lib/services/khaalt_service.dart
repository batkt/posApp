import 'api_service.dart';

/// Cash register close (`khaalt`) — same endpoints as web `components/modalBody/posSystem/khaalt.js`.
class KhaaltService {
  KhaaltService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  /// Latest `khaalt` row for this staff / branch / type, or `null`.
  Future<Map<String, dynamic>?> fetchSuuliinKhaalt({
    required String baiguullagiinId,
    required String salbariinId,
    required String burtgesenAjiltan,
    String turul = 'pos',
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/suuliinKhaaltOgnooAvya',
        body: {
          'baiguullagiinId': baiguullagiinId,
          'salbariinId': salbariinId,
          'burtgesenAjiltan': burtgesenAjiltan,
          'turul': turul,
        },
        parser: (data) => data,
      );
      if (!response.success || response.data == null) return null;
      final d = response.data;
      if (d is! Map) return null;
      return Map<String, dynamic>.from(d);
    } catch (_) {
      return null;
    }
  }

  /// `POST /khaalt` — returns true when backend answers `Amjilttai`.
  Future<bool> submitKhaalt(Map<String, dynamic> body) async {
    try {
      final response = await _api.post<dynamic>(
        '/khaalt',
        body: body,
        parser: (data) => data,
      );
      final data = response.data;
      return response.success &&
          (data == 'Amjilttai' || data?.toString() == 'Amjilttai');
    } catch (_) {
      return false;
    }
  }
}

final khaaltService = KhaaltService();
