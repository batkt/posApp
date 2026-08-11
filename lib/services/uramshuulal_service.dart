import 'dart:convert';

import 'api_service.dart';

/// "khamgiinKhyamd" урамшуулал — сагсны N ширхэг тутамд хамгийн хямд 1 нь үнэгүй
/// болох, бараа-үл хамааралтай урамшуулал. Web хувилбартай (`pos` repo) адил
/// `uramshuulal` collection/routes ашиглана (posBack `routes/uramshuulalHunglultRoute.js`)
/// — [uramshuulaliinNukhtsul]/[uramshuulaliinBeleg] хоосон.
class UramshuulalService {
  UramshuulalService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  static const String turul = 'khamgiinKhyamd';

  /// Идэвхтэй (одоогийн огноо хугацааны цонхонд орсон) "khamgiinKhyamd" урамшуулал байвал буцаана.
  Future<Map<String, dynamic>?> fetchActive({
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/uramshuulal',
        queryParams: {
          'query': jsonEncode({
            'baiguullagiinId': baiguullagiinId,
            'salbariinId': salbariinId,
            'turul': turul,
          }),
          'khuudasniiKhemjee': '20',
        },
        parser: (data) => data as Map<String, dynamic>,
      );
      if (!response.success || response.data == null) return null;
      final raw = response.data!['jagsaalt'] as List<dynamic>?;
      if (raw == null || raw.isEmpty) return null;
      final now = DateTime.now();
      for (final e in raw) {
        if (e is! Map) continue;
        final row = Map<String, dynamic>.from(e);
        if (_isActiveNow(row, now)) return row;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isActiveNow(Map<String, dynamic> row, DateTime now) {
    final startD = DateTime.tryParse(row['ekhlekhOgnoo']?.toString() ?? '');
    final endD = DateTime.tryParse(row['duusakhOgnoo']?.toString() ?? '');
    if (startD == null || endD == null) return false;
    return !now.isBefore(startD) && !now.isAfter(endD);
  }
}

final uramshuulalService = UramshuulalService();
