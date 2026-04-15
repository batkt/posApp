import 'dart:convert';

import 'api_service.dart';

/// Escape user input so Mongo `$regex` treats it as a literal (barcodes often contain `()` etc.).
String _mongoRegexLiteral(String input) {
  final b = StringBuffer();
  for (final c in input.split('')) {
    switch (c) {
      case r'\':
      case '^':
      case r'$':
      case '.':
      case '|':
      case '?':
      case '*':
      case '+':
      case '(':
      case ')':
      case '[':
      case ']':
      case '{':
      case '}':
        b.write(r'\');
        b.write(c);
        break;
      default:
        b.write(c);
    }
  }
  return b.toString();
}

/// Branch stock counts (`toollogo`) — same API as web warehouse toollogo screen.
class ToololtService {
  ToololtService({ApiService? apiService})
      : _api = apiService ?? posApiService;

  final ApiService _api;

  static const Duration _startCountTimeout = Duration(minutes: 10);

  Future<ToololtListResult> listToollogs({
    required String baiguullagiinId,
    required String salbariinId,
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    final query = <String, dynamic>{
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
    };
    final s = search?.trim();
    if (s != null && s.isNotEmpty) {
      final lit = _mongoRegexLiteral(s);
      query[r'$or'] = [
        {'ner': {r'$regex': lit, r'$options': 'i'}},
        {'turul': {r'$regex': lit, r'$options': 'i'}},
        {'baraanuud.code': {r'$regex': lit, r'$options': 'i'}},
        {'baraanuud.barCode': {r'$regex': lit, r'$options': 'i'}},
      ];
    }
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/toollogiinJagsaaltAvya',
        queryParams: {
          'query': jsonEncode(query),
          'order': jsonEncode({'createdAt': -1}),
          'khuudasniiDugaar': page.toString(),
          'khuudasniiKhemjee': pageSize.toString(),
          'baiguullagiinId': baiguullagiinId,
        },
        parser: (data) => data as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final raw = response.data!['jagsaalt'] as List<dynamic>?;
        final rows = raw
                ?.map((e) => ToololtRow.fromDoc(e as Map<String, dynamic>))
                .toList() ??
            [];
        return ToololtListResult.ok(rows);
      }
      return ToololtListResult.fail(
        response.message ?? 'Тооллогын жагсаалт ачаалахад алдаа',
      );
    } catch (e) {
      return ToololtListResult.fail(e.toString());
    }
  }

  /// Web `POST /ekhelsenToollogoAvya` — current in-progress count session + page of lines.
  Future<ToololtActiveFetchResult> fetchActiveToollogo({
    required String baiguullagiinId,
    required String salbariinId,
    int page = 1,
    int pageSize = 50,
    String? khaikhUtga,
    List<String>? baraanuudFilter,
  }) async {
    final body = <String, dynamic>{
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
      'khuudasniiDugaar': page,
      'khuudasniiKhemjee': pageSize,
      'order': {'createdAt': -1},
    };
    final k = khaikhUtga?.trim();
    if (k != null && k.isNotEmpty) {
      // Backend uses this string inside `$regex`; escape so barcodes match literally.
      body['khaikhUtga'] = _mongoRegexLiteral(k);
    }
    if (baraanuudFilter != null && baraanuudFilter.isNotEmpty) {
      body['baraanuud'] = baraanuudFilter;
    }
    try {
      final response = await _api.post<dynamic>(
        '/ekhelsenToollogoAvya',
        body: body,
        parser: (d) => d,
      );
      if (!response.success) {
        return ToololtActiveFetchResult.fail(
          response.message ?? 'Идэвхтэй тооллого ачаалахад алдаа',
        );
      }
      final data = response.data;
      if (data is String) {
        final s = data.toLowerCase();
        if (s.contains('obso') ||
            s.contains('идэвхтэй') ||
            s.contains('идэвхгүй')) {
          return ToololtActiveFetchResult.inactive();
        }
        return ToololtActiveFetchResult.fail(data);
      }
      if (data is! Map) {
        return ToololtActiveFetchResult.fail(data.toString());
      }
      final map = Map<String, dynamic>.from(data);
      final session = ToololtActiveSession.fromApi(map);
      if (session.id.isEmpty) {
        return ToololtActiveFetchResult.inactive();
      }
      return ToololtActiveFetchResult.ok(session);
    } catch (e) {
      return ToololtActiveFetchResult.fail(e.toString());
    }
  }

  /// Web `POST /toololtEkhleye`
  Future<ToololtActionResult> startToololt({
    required String baiguullagiinId,
    required String salbariinId,
    required String ner,
    required String ekhlekhOgnoo,
    required String duusakhOgnoo,
    required String turul,
    bool uldegdelteiBaraaToolohEsekh = true,
    bool toogKharuulakhEsekh = true,
    List<String>? baraanuudCodes,
    List<String>? angilaluud,
  }) async {
    final body = <String, dynamic>{
      'salbariinId': salbariinId,
      'baiguullagiinId': baiguullagiinId,
      'ner': ner,
      'ekhlekhOgnoo': ekhlekhOgnoo,
      'duusakhOgnoo': duusakhOgnoo,
      'uldegdelteiBaraaToolohEsekh': uldegdelteiBaraaToolohEsekh,
      'toogKharuulakhEsekh': toogKharuulakhEsekh,
      'turul': turul,
    };
    if (baraanuudCodes != null && baraanuudCodes.isNotEmpty) {
      body['baraanuud'] = baraanuudCodes;
    }
    if (angilaluud != null && angilaluud.isNotEmpty) {
      body['angilaluud'] = angilaluud;
    }
    try {
      final response = await _api.post<dynamic>(
        '/toololtEkhleye',
        body: body,
        parser: (d) => d,
        timeout: _startCountTimeout,
      );
      if (!response.success) {
        return ToololtActionResult.fail(
          response.message ?? 'Тооллого эхлүүлэхэд алдаа',
        );
      }
      final ok = response.data?.toString().contains('Amjilttai') == true;
      if (ok) return ToololtActionResult.ok();
      return ToololtActionResult.fail(response.data?.toString() ?? 'Алдаа');
    } catch (e) {
      return ToololtActionResult.fail(e.toString());
    }
  }

  /// Web `POST /toololtKhadgalyaa`
  Future<ToololtActionResult> saveCountedQty({
    required String toollogoId,
    required String code,
    required double too,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/toololtKhadgalyaa',
        body: {
          'id': toollogoId,
          'code': code,
          'too': too,
        },
        parser: (d) => d,
      );
      if (!response.success) {
        return ToololtActionResult.fail(
          response.message ?? 'Хадгалахад алдаа',
        );
      }
      final ok = response.data?.toString().contains('Amjilttai') == true;
      if (ok) return ToololtActionResult.ok();
      return ToololtActionResult.fail(response.data?.toString() ?? 'Алдаа');
    } catch (e) {
      return ToololtActionResult.fail(e.toString());
    }
  }

  /// Web `POST /toollogoDuusgay`
  Future<ToololtActionResult> completeToololt({
    required String toollogoId,
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/toollogoDuusgay',
        body: {
          'id': toollogoId,
          'salbariinId': salbariinId,
          'baiguullagiinId': baiguullagiinId,
        },
        parser: (d) => d,
      );
      if (!response.success) {
        return ToololtActionResult.fail(
          response.message ?? 'Дуусгахад алдаа',
        );
      }
      final ok = response.data?.toString().contains('Amjilttai') == true;
      if (ok) return ToololtActionResult.ok();
      return ToololtActionResult.fail(response.data?.toString() ?? 'Алдаа');
    } catch (e) {
      return ToololtActionResult.fail(e.toString());
    }
  }

  /// Web `POST /toollogoTsutsalya` (deletes active session document).
  Future<ToololtActionResult> cancelToololt({required String toollogoId}) async {
    try {
      final response = await _api.post<dynamic>(
        '/toollogoTsutsalya',
        body: {'id': toollogoId},
        parser: (d) => d,
      );
      if (!response.success) {
        return ToololtActionResult.fail(
          response.message ?? 'Цуцлахад алдаа',
        );
      }
      final ok = response.data?.toString().contains('Amjilttai') == true;
      if (ok) return ToololtActionResult.ok();
      return ToololtActionResult.fail(response.data?.toString() ?? 'Алдаа');
    } catch (e) {
      return ToololtActionResult.fail(e.toString());
    }
  }
}

class ToololtBaraaLine {
  ToololtBaraaLine({
    required this.code,
    required this.ner,
    this.barCode,
    required this.etssiinUldegdel,
    required this.toolsonToo,
    required this.negjKhudaldakhUne,
    required this.negjUrtugUne,
    this.zoruu,
  });

  final String code;
  final String ner;
  final String? barCode;
  final double etssiinUldegdel;
  final double toolsonToo;
  final double negjKhudaldakhUne;
  final double negjUrtugUne;
  final Map<String, dynamic>? zoruu;

  factory ToololtBaraaLine.fromJson(Map<String, dynamic> d) {
    double num_(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    Map<String, dynamic>? z;
    final zv = d['zoruu'];
    if (zv is Map) {
      z = Map<String, dynamic>.from(zv);
    }
    return ToololtBaraaLine(
      code: d['code']?.toString() ?? '',
      ner: d['ner']?.toString() ?? '',
      barCode: d['barCode']?.toString(),
      etssiinUldegdel: num_(d['etssiinUldegdel']),
      toolsonToo: num_(d['toolsonToo']),
      negjKhudaldakhUne: num_(d['negjKhudaldakhUne']),
      negjUrtugUne: num_(d['negjUrtugUne']),
      zoruu: z,
    );
  }
}

class ToololtActiveSession {
  ToololtActiveSession({
    required this.id,
    required this.ner,
    required this.turul,
    required this.lines,
    required this.niitMur,
    required this.khuudasniiDugaar,
    required this.khuudasniiKhemjee,
    required this.niitKhuudas,
    required this.toologdooguiBaraaniiToo,
    required this.niitTooKhemjee,
    required this.niitMungunDun,
    this.ekhlekhOgnoo,
    this.duusakhOgnoo,
  });

  final String id;
  final String ner;
  final String turul;
  final List<ToololtBaraaLine> lines;
  final int niitMur;
  final int khuudasniiDugaar;
  final int khuudasniiKhemjee;
  final int niitKhuudas;
  final int toologdooguiBaraaniiToo;
  final double niitTooKhemjee;
  final double niitMungunDun;
  final DateTime? ekhlekhOgnoo;
  final DateTime? duusakhOgnoo;

  static String _readId(Map<String, dynamic> d) {
    final id = d['_id'];
    if (id is String) return id;
    if (id is Map) {
      final oid = id['\$oid'] ?? id['_oid'];
      if (oid != null) return oid.toString();
    }
    return id?.toString() ?? '';
  }

  factory ToololtActiveSession.fromApi(Map<String, dynamic> d) {
    DateTime? dt(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return DateTime.tryParse(v.toString());
    }

    int n(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    double dbl(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final rawLines = d['baraanuud'];
    final lines = <ToololtBaraaLine>[];
    if (rawLines is List) {
      for (final e in rawLines) {
        if (e is Map<String, dynamic>) {
          lines.add(ToololtBaraaLine.fromJson(e));
        } else if (e is Map) {
          lines.add(
            ToololtBaraaLine.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    return ToololtActiveSession(
      id: _readId(d),
      ner: d['ner']?.toString() ?? '',
      turul: d['turul']?.toString() ?? '',
      lines: lines,
      niitMur: n(d['niitMur']),
      khuudasniiDugaar: n(d['khuudasniiDugaar'], 1),
      khuudasniiKhemjee: n(d['khuudasniiKhemjee'], 50),
      niitKhuudas: n(d['niitKhuudas']),
      toologdooguiBaraaniiToo: n(d['toologdooguiBaraaniiToo']),
      niitTooKhemjee: dbl(d['niitTooKhemjee']),
      niitMungunDun: dbl(d['niitMungunDun']),
      ekhlekhOgnoo: dt(d['ekhlekhOgnoo']),
      duusakhOgnoo: dt(d['duusakhOgnoo']),
    );
  }
}

class ToololtActiveFetchResult {
  ToololtActiveFetchResult._({
    required this.success,
    required this.hasActive,
    this.session,
    this.error,
  });

  final bool success;
  final bool hasActive;
  final ToololtActiveSession? session;
  final String? error;

  factory ToololtActiveFetchResult.ok(ToololtActiveSession session) =>
      ToololtActiveFetchResult._(
        success: true,
        hasActive: true,
        session: session,
      );

  factory ToololtActiveFetchResult.inactive() => ToololtActiveFetchResult._(
        success: true,
        hasActive: false,
      );

  factory ToololtActiveFetchResult.fail(String error) =>
      ToololtActiveFetchResult._(
        success: false,
        hasActive: false,
        error: error,
      );
}

class ToololtActionResult {
  ToololtActionResult._({required this.success, this.error});

  final bool success;
  final String? error;

  factory ToololtActionResult.ok() => ToololtActionResult._(success: true);

  factory ToololtActionResult.fail(String error) =>
      ToololtActionResult._(success: false, error: error);
}

class ToololtRow {
  ToololtRow({
    required this.id,
    required this.tuluv,
    required this.turul,
    required this.ner,
    this.ekhelsenOgnoo,
    this.duussanOgnoo,
    this.niitBaraa,
    this.toologdoogui,
  });

  final String id;
  final String tuluv;
  final String turul;
  final String ner;
  final DateTime? ekhelsenOgnoo;
  final DateTime? duussanOgnoo;
  final int? niitBaraa;
  final int? toologdoogui;

  factory ToololtRow.fromDoc(Map<String, dynamic> d) {
    DateTime? p(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return DateTime.tryParse(v.toString());
    }

    int? n(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return ToololtRow(
      id: d['_id']?.toString() ?? '',
      tuluv: d['tuluv']?.toString() ?? '',
      turul: d['turul']?.toString() ?? '',
      ner: d['ner']?.toString() ?? '',
      ekhelsenOgnoo: p(d['ekhelsenOgnoo'] ?? d['ekhlekhOgnoo'] ?? d['createdAt']),
      duussanOgnoo: p(d['duussanOgnoo']),
      niitBaraa: n(d['niitbaraaniiToo']),
      toologdoogui: n(d['toologdooguiBaraaniiToo']),
    );
  }
}

class ToololtListResult {
  ToololtListResult._({
    required this.success,
    required this.rows,
    this.error,
  });

  final bool success;
  final List<ToololtRow> rows;
  final String? error;

  factory ToololtListResult.ok(List<ToololtRow> rows) => ToololtListResult._(
        success: true,
        rows: rows,
      );

  factory ToololtListResult.fail(String error) => ToololtListResult._(
        success: false,
        rows: [],
        error: error,
      );
}

final toololtService = ToololtService();
