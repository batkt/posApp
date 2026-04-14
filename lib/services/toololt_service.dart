import 'dart:convert';

import 'api_service.dart';

/// Branch stock counts (`toollogo` collection) — same API as web `useToollogiinJagsaaltAvya`.
class ToololtService {
  ToololtService({ApiService? apiService})
      : _api = apiService ?? posApiService;

  final ApiService _api;

  Future<ToololtListResult> listToollogs({
    required String baiguullagiinId,
    required String salbariinId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final query = <String, dynamic>{
      'baiguullagiinId': baiguullagiinId,
      'salbariinId': salbariinId,
    };
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
