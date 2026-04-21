import 'package:intl/intl.dart';

import 'api_service.dart';

/// Mirrors web `pages/khyanalt/hynalt/index.js` — POST `/dashboardMedeelelAvya`, `/borluulaltTopJagsaaltAvya`.
class HynaltTailanService {
  HynaltTailanService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  static final _df = DateFormat('yyyy-MM-dd HH:mm:ss');

  Future<DashboardMedeelelResult> fetchDashboardMedeelel({
    required String baiguullagiinId,
    required String salbariinId,
    required DateTime ekhlekh,
    required DateTime duusakh,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/dashboardMedeelelAvya',
        body: {
          'baiguullagiinId': baiguullagiinId,
          'salbariinId': salbariinId,
          'ekhlekhOgnoo': _df.format(ekhlekh),
          'duusakhOgnoo': _df.format(duusakh),
        },
        parser: (d) => d as Map<String, dynamic>,
      );
      if (response.success && response.data != null) {
        final m = response.data!;
        return DashboardMedeelelResult.ok(
          borluulalt: _toDouble(m['borluulalt']),
          ashig: _toDouble(m['ashig']),
          avlaga: _toDouble(m['avlaga']),
          uglug: _toDouble(m['uglug']),
        );
      }
      return DashboardMedeelelResult.fail(response.message ?? 'Алдаа');
    } catch (e) {
      return DashboardMedeelelResult.fail(e.toString());
    }
  }

  Future<BorluulaltTopResult> fetchBorluulaltTop({
    required String baiguullagiinId,
    required String salbariinId,
    required DateTime ekhlekh,
    required DateTime duusakh,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/borluulaltTopJagsaaltAvya',
        body: {
          'baiguullagiinId': baiguullagiinId,
          'salbariinId': salbariinId,
          'ekhlekhOgnoo': _df.format(ekhlekh),
          'duusakhOgnoo': _df.format(duusakh),
        },
        parser: (d) => d,
      );
      if (response.success && response.data != null) {
        final raw = response.data;
        if (raw is! List) {
          return BorluulaltTopResult.fail('Буруу хариу');
        }
        final rows = <BorluulaltTopRow>[];
        for (final e in raw) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final id = m['_id'];
          String ner = '';
          if (id is Map) {
            ner = id['ner']?.toString() ?? '';
          }
          rows.add(BorluulaltTopRow(
            ner: ner,
            niitToo: _toDouble(m['niitToo']),
            zarsanNiitUne: _toDouble(m['zarsanNiitUne']),
          ));
        }
        return BorluulaltTopResult.ok(rows);
      }
      return BorluulaltTopResult.fail(response.message ?? 'Алдаа');
    } catch (e) {
      return BorluulaltTopResult.fail(e.toString());
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class DashboardMedeelelResult {
  const DashboardMedeelelResult._({
    required this.ok,
    this.borluulalt = 0,
    this.ashig = 0,
    this.avlaga = 0,
    this.uglug = 0,
    this.error,
  });

  final bool ok;
  final double borluulalt;
  final double ashig;
  final double avlaga;
  final double uglug;
  final String? error;

  factory DashboardMedeelelResult.ok({
    required double borluulalt,
    required double ashig,
    required double avlaga,
    required double uglug,
  }) =>
      DashboardMedeelelResult._(
        ok: true,
        borluulalt: borluulalt,
        ashig: ashig,
        avlaga: avlaga,
        uglug: uglug,
      );

  factory DashboardMedeelelResult.fail(String message) =>
      DashboardMedeelelResult._(ok: false, error: message);
}

class BorluulaltTopResult {
  const BorluulaltTopResult._({
    required this.ok,
    this.rows = const [],
    this.error,
  });

  final bool ok;
  final List<BorluulaltTopRow> rows;
  final String? error;

  factory BorluulaltTopResult.ok(List<BorluulaltTopRow> rows) =>
      BorluulaltTopResult._(ok: true, rows: rows);

  factory BorluulaltTopResult.fail(String message) =>
      BorluulaltTopResult._(ok: false, error: message);
}

class BorluulaltTopRow {
  const BorluulaltTopRow({
    required this.ner,
    required this.niitToo,
    required this.zarsanNiitUne,
  });

  final String ner;
  final double niitToo;
  final double zarsanNiitUne;
}
