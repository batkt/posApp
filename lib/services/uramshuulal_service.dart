import 'dart:convert';

import 'api_service.dart';

/// "khamgiinKhyamd" урамшуулал — сагсны N ширхэг тутамд хамгийн хямд 1 нь үнэгүй
/// болох, бараа-үл хамааралтай урамшуулал. Web хувилбартай (`pos` repo) адил
/// `uramshuulal` collection/routes ашиглана (posBack `routes/uramshuulalHunglultRoute.js`)
/// — [uramshuulaliinNukhtsul]/[uramshuulaliinBeleg] хоосон.
/// `POST /uramshuulalShalgay` хариу — сервер сагсыг **бүхэлд нь** дахин
/// тооцоод буцаана (бэлэг мөр нэмэх/хасах, "N-т 1 үнэгүй"-г хуваах г.м).
class UramshuulalShalgayResult {
  const UramshuulalShalgayResult({
    required this.songogdsonEmnuud,
    this.songokhBelegnuud = const [],
    this.dorvonNegTie,
  });

  /// Серверийн эрх мэдэлтэй сагс — клиент үүгээр өөрийн мөрүүдээ солино.
  final List<Map<String, dynamic>> songogdsonEmnuud;

  /// Нэг урамшуулалд хэд хэдэн бэлэг байгаа тул кассчин сонгох ёстой.
  final List<Map<String, dynamic>> songokhBelegnuud;

  /// "N-т 1 үнэгүй"-д чөлөөлөх сүүлийн нэгжүүдийн үнэ тэнцүү болсон үе.
  final Map<String, dynamic>? dorvonNegTie;
}

class UramshuulalService {
  UramshuulalService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  static const String turul = 'khamgiinKhyamd';

  static List<Map<String, dynamic>> _mapList(dynamic v) {
    if (v is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map) out.add(Map<String, dynamic>.from(e));
    }
    return out;
  }

  /// Вэб `uramshuulalShalgakh` — сагс өөрчлөгдөх бүрд дуудаж, урамшууллын
  /// тооцоог СЕРВЕР дээр хийлгэнэ (`turul: "specific"` бэлэг болон
  /// `khamgiinKhyamd` хоёул). Клиент талд давхардуулж тооцохгүй.
  ///
  /// Алдаа гарвал `null` — дуудагч нь сагсаа хэвээр үлдээнэ.
  Future<UramshuulalShalgayResult?> shalgay({
    required String baiguullagiinId,
    required String salbariinId,
    required List<Map<String, dynamic>> songogdsonEmnuud,
    List<Map<String, dynamic>> songogdsonBelegnuud = const [],
    bool baraaHudaldahUne = false,
    Map<String, int> dorvonNegManualPicks = const {},
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/uramshuulalShalgay',
        body: {
          'songogdsonEmnuud': songogdsonEmnuud,
          'baiguullagiinId': baiguullagiinId,
          'salbariinId': salbariinId,
          'songogdsonBelegnuud': songogdsonBelegnuud,
          'baraaHudaldahUne': baraaHudaldahUne,
          'dorvonNegManualPicks': dorvonNegManualPicks,
        },
        parser: (data) => data,
      );
      if (!response.success || response.data is! Map) return null;
      final d = Map<String, dynamic>.from(response.data as Map);
      final rows = _mapList(d['songogdsonEmnuud']);
      if (rows.isEmpty && songogdsonEmnuud.isNotEmpty) {
        // Сервер хоосон буцаасан бол сагсыг цэвэрлэхгүй — алдаа гэж үзнэ.
        return null;
      }
      final tie = d['dorvonNegTie'];
      return UramshuulalShalgayResult(
        songogdsonEmnuud: rows,
        songokhBelegnuud: _mapList(d['songokhBelegnuud']),
        dorvonNegTie: tie is Map ? Map<String, dynamic>.from(tie) : null,
      );
    } catch (_) {
      return null;
    }
  }

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
            'turul': turul,
          }),
          'khuudasniiKhemjee': '50',
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
        final promoSalbar = row['salbariinId']?.toString();
        if (promoSalbar != null && promoSalbar != 'ALL' && promoSalbar != salbariinId) {
          continue;
        }
        if (_isActiveNow(row, now)) return row;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// `POST /uramshuulalKhugtsaaSungyaa` — идэвхтэй урамшууллын хугацааг
  /// сунгана (сунгалтын түүхэд бичигдэнэ).
  Future<bool> khugatsaaSungya({
    required String id,
    required DateTime ekhlekhOgnoo,
    required DateTime duusakhOgnoo,
  }) async {
    try {
      final r = await _api.post<dynamic>(
        '/uramshuulalKhugtsaaSungyaa',
        body: {
          'id': id,
          'ekhlekhOgnoo': ekhlekhOgnoo.toIso8601String(),
          'duusakhOgnoo': duusakhOgnoo.toIso8601String(),
          'ekhlekhTsag': ekhlekhOgnoo.toIso8601String(),
          'duusakhTsag': duusakhOgnoo.toIso8601String(),
        },
        parser: (d) => d,
      );
      return r.success;
    } catch (_) {
      return false;
    }
  }

  /// `DELETE /uramshuulalUstgaya/:id` — урамшууллыг устгаад холбогдох
  /// барааны тэмдэглэгээг нь сэргээнэ.
  Future<bool> ustga(String id) async {
    try {
      final r = await _api.delete<dynamic>(
        '/uramshuulalUstgaya/$id',
        parser: (d) => d,
      );
      return r.success;
    } catch (_) {
      return false;
    }
  }

  /// Урамшууллын төрлийн ХҮНИЙ уншиж болох нэр. Өмнө нь жагсаалтад
  /// `specific` гэсэн түүхий утга шууд гарч байв.
  static String turulLabel(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'khamgiinKhyamd':
        return 'Хамгийн хямдыг үнэгүй (N-т M)';
      case 'specific':
        return 'Тодорхой бараа (нөхцөл → бэлэг)';
      case '':
        return 'Тодорхойгүй';
      default:
        return raw!;
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
