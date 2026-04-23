import 'dart:convert';

import 'api_service.dart';

/// Purchase list parity: `pages/khyanalt/aguulakh/barimtiinJagsaalt/index.js` tab `hudaldanAvaltJagsaalt` → GET `/orlogoZarlagiinTuukh`.
class HudaldanAvaltService {
  HudaldanAvaltService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  Future<HudaldanAvaltPageResult> fetchPage({
    required String baiguullagiinId,
    required String salbariinId,
    required DateTime ognooFrom,
    required DateTime ognooTo,
    int page = 1,
    int pageSize = 50,
    /// Web `barimtiinJagsaalt`: filter `orlogoZarlagiinTuukh` to one customer.
    String? khariltsagchiinId,
  }) async {
    final queryMap = <String, dynamic>{
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
      'zassanEsekh': {'\$ne': true},
      'turul': {
        '\$nin': ['act', 'busadZarlaga', 'OrlogoUldegdel'],
      },
      'ognoo': {
        '\$gte':
            '${ognooFrom.year.toString().padLeft(4, '0')}-${ognooFrom.month.toString().padLeft(2, '0')}-${ognooFrom.day.toString().padLeft(2, '0')} 00:00:00',
        '\$lte':
            '${ognooTo.year.toString().padLeft(4, '0')}-${ognooTo.month.toString().padLeft(2, '0')}-${ognooTo.day.toString().padLeft(2, '0')} 23:59:59',
      },
    };
    if (khariltsagchiinId != null && khariltsagchiinId.trim().isNotEmpty) {
      queryMap['khariltsagchiinId'] = khariltsagchiinId.trim();
    } else {
      queryMap['khariltsagchiinId'] = {'\$exists': true};
    }

    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/orlogoZarlagiinTuukh',
        queryParams: {
          'query': jsonEncode(queryMap),
          'order': jsonEncode({'ognoo': -1}),
          'khuudasniiDugaar': page.toString(),
          'khuudasniiKhemjee': pageSize.toString(),
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final raw = response.data!['jagsaalt'] as List<dynamic>?;
        final list = raw?.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return HudaldanAvaltRow.fromJson(m);
        }).toList() ??
            [];
        final niitMur = response.data!['niitMur'];
        final totalRows = niitMur is num ? niitMur.toInt() : list.length;
        return HudaldanAvaltPageResult.ok(
          rows: list,
          page: page,
          pageSize: pageSize,
          totalRows: totalRows,
        );
      }

      return HudaldanAvaltPageResult.fail(
        response.message ?? 'Жагсаалт ачаалахад алдаа',
      );
    } catch (e) {
      return HudaldanAvaltPageResult.fail(e.toString());
    }
  }
}

class HudaldanAvaltPageResult {
  const HudaldanAvaltPageResult._({
    required this.ok,
    this.rows = const [],
    this.page = 1,
    this.pageSize = 50,
    this.totalRows = 0,
    this.error,
  });

  final bool ok;
  final List<HudaldanAvaltRow> rows;
  final int page;
  final int pageSize;
  final int totalRows;
  final String? error;

  int get totalPages =>
      totalRows <= 0 ? 1 : ((totalRows - 1) ~/ pageSize) + 1;

  factory HudaldanAvaltPageResult.ok({
    required List<HudaldanAvaltRow> rows,
    required int page,
    required int pageSize,
    required int totalRows,
  }) =>
      HudaldanAvaltPageResult._(
        ok: true,
        rows: rows,
        page: page,
        pageSize: pageSize,
        totalRows: totalRows,
      );

  factory HudaldanAvaltPageResult.fail(String message) =>
      HudaldanAvaltPageResult._(ok: false, error: message);
}

class HudaldanAvaltRow {
  HudaldanAvaltRow({
    required this.id,
    required this.ognoo,
    required this.khariltsagchiinNer,
    required this.niitDun,
    required this.lineQtySum,
    required this.khelber,
  });

  factory HudaldanAvaltRow.fromJson(Map<String, dynamic> m) {
    final baraanuud = m['baraanuud'];
    double qty = 0;
    if (baraanuud is List) {
      for (final b in baraanuud) {
        if (b is Map) {
          final t = b['too'];
          qty += t is num ? t.toDouble() : double.tryParse('$t') ?? 0;
        }
      }
    }
    final ognooRaw = m['ognoo'];
    DateTime ognoo;
    if (ognooRaw is String) {
      ognoo = DateTime.tryParse(ognooRaw) ?? DateTime.now();
    } else if (ognooRaw is Map && ognooRaw['\$date'] != null) {
      ognoo = DateTime.tryParse(ognooRaw['\$date'].toString()) ??
          DateTime.now();
    } else {
      ognoo = DateTime.now();
    }

    final id = m['_id']?.toString() ?? '';

    final nd = m['niitDun'];
    final niitDun =
        nd is num ? nd.toDouble() : double.tryParse(nd?.toString() ?? '') ?? 0;

    return HudaldanAvaltRow(
      id: id,
      ognoo: ognoo,
      khariltsagchiinNer: m['khariltsagchiinNer']?.toString() ?? '',
      niitDun: niitDun,
      lineQtySum: qty,
      khelber: m['khelber']?.toString(),
    );
  }

  final String id;
  final DateTime ognoo;
  final String khariltsagchiinNer;
  final double niitDun;
  final double lineQtySum;
  final String? khelber;
}
